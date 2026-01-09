# Karpenter 완전 이해하기

이 문서는 Karpenter가 무엇을 하는지, 어떻게 동작하는지, NodePool이 무엇인지 명확하게 설명합니다.

## 🎯 Karpenter의 역할

### 간단히 말하면

**Karpenter = Kubernetes 클러스터에 노드(EC2 인스턴스)를 자동으로 생성/삭제하는 컨트롤러**

### 기존 Kubernetes와의 차이

#### ❌ Karpenter 없이 (수동 관리)

```
1. Pod가 스케줄링 대기 (Pending 상태)
   ↓
2. 기존 노드에 자리가 없음
   ↓
3. ❌ Pod가 계속 Pending 상태로 대기
   ↓
4. 수동으로 EC2 인스턴스 생성 필요
   ↓
5. 노드를 클러스터에 추가
   ↓
6. Pod가 스케줄링됨
```

#### ✅ Karpenter 있으면 (자동 관리)

```
1. Pod가 스케줄링 대기 (Pending 상태)
   ↓
2. 기존 노드에 자리가 없음
   ↓
3. ✅ Karpenter가 자동으로 감지
   ↓
4. ✅ Karpenter가 EC2 인스턴스 자동 생성 (초 단위)
   ↓
5. ✅ 노드가 클러스터에 자동 추가
   ↓
6. ✅ Pod가 자동으로 스케줄링됨
```

## 🔗 Karpenter와 Kubernetes의 연결

### 1. Kubernetes API 모니터링

Karpenter는 Kubernetes API를 지속적으로 모니터링합니다:

```yaml
# Karpenter가 모니터링하는 것들:
- Pending 상태의 Pod (스케줄링 대기 중)
- Pod의 리소스 요구사항 (CPU, Memory)
- 기존 노드의 가용 리소스
- NodePool 설정
```

### 2. 실제 연결 구조

```
┌─────────────────────────────────────────────────┐
│         Kubernetes API Server                   │
│  (모든 리소스 상태를 관리하는 중앙 서버)          │
└───────────────┬─────────────────────────────────┘
                │
        ┌───────┴────────┐
        │                 │
┌───────▼──────┐  ┌──────▼────────┐
│  Karpenter   │  │  Kubernetes   │
│  Controller  │  │  Scheduler    │
│              │  │               │
│  - Pod 감지  │  │  - Pod 배치   │
│  - 노드 생성  │  │  - 노드 선택  │
└───────┬──────┘  └──────┬───────┘
        │                 │
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │   AWS API      │
        │  (EC2 생성)     │
        └─────────────────┘
```

### 3. 코드에서의 연결

```hcl
# main.tf - Karpenter Helm 설치
resource "helm_release" "karpenter" {
  # Karpenter가 EKS 클러스터에 설치됨
  # → Kubernetes API에 접근 가능
  # → Pod 상태를 모니터링 가능
}
```

Karpenter는 Kubernetes 클러스터 내부에 Pod로 실행됩니다:

```bash
# Karpenter Pod 확인
kubectl get pods -n karpenter-system

# 출력 예시:
# NAME                        READY   STATUS
# karpenter-xxx               1/1     Running
```

## 📦 NodePool이란?

### NodePool = "어떤 노드를 만들지 정의하는 템플릿"

NodePool은 Karpenter에게 **"이런 조건의 노드를 만들어라"**라고 알려주는 설정입니다.

### NodePool 구조 분석

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  # 1. 노드 템플릿 (이 노드에 어떤 레이블/어노테이션을 붙일지)
  template:
    metadata:
      labels:
        workload-type: general
        environment: production
  
  # 2. 노드 요구사항 (어떤 조건의 노드를 만들지)
  requirements:
    # 아키텍처: amd64만
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64"]
    
    # 인스턴스 타입: t3.medium, t3.large 등
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["t3.medium", "t3.large", "t3.xlarge"]
    
    # 가용 영역: us-west-2a, us-west-2b 등
    - key: topology.kubernetes.io/zone
      operator: In
      values: ["us-west-2a", "us-west-2b", "us-west-2c"]
    
    # 용량 타입: on-demand (Spot 아님)
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["on-demand"]
  
  # 3. 제한 (최대 얼마나 만들 수 있는지)
  limits:
    cpu: "1000"      # 최대 1000 CPU 코어
    memory: 1000Gi   # 최대 1000Gi 메모리
  
  # 4. 노드 삭제 정책 (언제 노드를 삭제할지)
  disruption:
    consolidateAfter: 30s      # 30초 후 통합 시작
    consolidatePolicy: WhenUnderutilized  # 사용률이 낮으면 삭제
    expireAfter: 720h          # 30일 후 만료
```

### NodePool의 역할

1. **노드 생성 규칙 정의**
   - 어떤 인스턴스 타입을 사용할지
   - 어떤 가용 영역에 만들지
   - 어떤 레이블을 붙일지

2. **리소스 제한**
   - 최대 CPU/메모리 제한
   - 비용 제어

3. **노드 삭제 정책**
   - 언제 노드를 삭제할지
   - 사용하지 않는 노드 자동 정리

## 🔄 실제 동작 흐름 (상세)

### 시나리오: 웹앱 배포

```yaml
# webapp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m      # 0.1 CPU 코어 필요
            memory: 128Mi  # 128MB 메모리 필요
```

### 단계별 동작

#### 1단계: 웹앱 배포

```bash
kubectl apply -f webapp.yaml
```

#### 2단계: Kubernetes Scheduler 시도

```
Kubernetes Scheduler:
  "Pod를 스케줄링해야 하는데..."
  "기존 노드에 자리가 있나?"
  → 없음 (클러스터가 비어있음)
  → Pod가 Pending 상태로 대기
```

#### 3단계: Karpenter 감지

```
Karpenter Controller:
  "Pending Pod를 발견!"
  "리소스 요구사항 분석:"
    - CPU: 100m × 2 = 200m 필요
    - Memory: 128Mi × 2 = 256Mi 필요
  
  "NodePool 확인:"
    - default NodePool 사용 가능
    - 인스턴스 타입: t3.medium (2 CPU, 4GB RAM) 충분함
```

#### 4단계: 노드 생성

```
Karpenter → AWS API 호출:
  ec2:RunInstances({
    InstanceType: "t3.medium",
    SubnetId: "subnet-xxx",  # EC2NodeClass에서 가져옴
    SecurityGroupIds: ["sg-xxx"],  # EC2NodeClass에서 가져옴
    IamInstanceProfile: "KarpenterNodeInstanceProfile",
    ...
  })
```

#### 5단계: 노드 등록

```
EC2 인스턴스 생성 완료
  ↓
노드가 EKS 클러스터에 자동 등록
  ↓
Kubernetes Scheduler가 노드 발견
  ↓
Pod가 노드에 스케줄링됨
```

#### 6단계: 노드 정리 (나중에)

```
워크로드가 줄어듦
  ↓
Karpenter가 사용률 낮은 노드 감지
  ↓
30초 후 (consolidateAfter)
  ↓
노드의 Pod를 다른 노드로 이동
  ↓
빈 노드 삭제
```

## 📊 NodePool vs EC2NodeClass

### NodePool
- **역할**: 어떤 노드를 만들지 정의 (인스턴스 타입, 가용 영역 등)
- **예시**: "t3.medium 인스턴스를 us-west-2a에 만들어라"

### EC2NodeClass
- **역할**: 노드의 AWS 설정 정의 (서브넷, 보안 그룹, IAM 역할 등)
- **예시**: "이 서브넷과 보안 그룹을 사용하고, 이 IAM 역할을 사용해라"

### 관계

```
NodePool
  ↓ (nodeClassRef 참조)
EC2NodeClass
  ↓ (실제 AWS 리소스)
서브넷, 보안 그룹, IAM 역할
```

## 💡 실제 예시

### 예시 1: 웹앱 배포

```bash
# 1. 웹앱 배포
kubectl apply -f examples/webapp.yaml

# 2. Pod 상태 확인
kubectl get pods -n webapp
# NAME                     READY   STATUS    NODE
# webapp-xxx               0/1     Pending  <none>

# 3. Karpenter가 노드 생성 (약 30초)
kubectl get nodes
# NAME                          STATUS   AGE
# ip-10-0-1-xxx.ec2.internal   Ready    30s  ← Karpenter가 생성!

# 4. Pod가 스케줄링됨
kubectl get pods -n webapp
# NAME                     READY   STATUS    NODE
# webapp-xxx               1/1     Running   ip-10-0-1-xxx
```

### 예시 2: 여러 NodePool 사용

```yaml
# GPU 워크로드용 NodePool
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: gpu-nodepool
spec:
  requirements:
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["g4dn.xlarge"]  # GPU 인스턴스
```

```yaml
# GPU 워크로드
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
spec:
  template:
    spec:
      nodeSelector:
        karpenter.sh/nodepool: gpu-nodepool  # GPU NodePool 사용
      containers:
      - name: gpu-app
        resources:
          requests:
            nvidia.com/gpu: 1  # GPU 필요
```

## 🎯 핵심 정리

### Karpenter의 역할

1. **Pod 모니터링**: Pending 상태의 Pod를 감지
2. **리소스 분석**: Pod가 필요한 CPU/메모리 계산
3. **노드 생성**: NodePool 설정에 따라 EC2 인스턴스 생성
4. **노드 정리**: 사용하지 않는 노드 자동 삭제

### NodePool의 역할

1. **노드 템플릿**: 어떤 조건의 노드를 만들지 정의
2. **리소스 제한**: 최대 생성 가능한 리소스 제한
3. **삭제 정책**: 언제 노드를 삭제할지 정의

### 기존 Kubernetes와의 연결

- **Kubernetes API**: Karpenter가 Pod 상태를 모니터링
- **Kubernetes Scheduler**: 노드가 생성되면 자동으로 Pod 배치
- **AWS API**: Karpenter가 EC2 인스턴스를 생성/삭제

## 🔍 확인 방법

### Karpenter 로그 확인

```bash
# Karpenter가 무엇을 하고 있는지 확인
kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter -f
```

### NodePool 확인

```bash
# NodePool 설정 확인
kubectl get nodepool default -o yaml
```

### 노드 생성 확인

```bash
# 노드 목록 확인
kubectl get nodes

# 노드 상세 정보
kubectl describe node <node-name>
```

## 🔐 권한 구조

Karpenter가 Pod를 모니터링하고 AWS에 EC2를 생성하는 권한에 대해 궁금하신가요?

👉 **[KARPENTER_PERMISSIONS.md](KARPENTER_PERMISSIONS.md)** 문서를 읽어보세요!

간단 요약:
- **Pod 모니터링**: Kubernetes RBAC (ClusterRole) - Helm 차트가 자동 생성
- **AWS EC2 생성**: IRSA (IAM Roles for Service Accounts) - Terraform으로 설정

## 📚 참고

- [Karpenter 공식 문서](https://karpenter.sh/)
- [NodePool 문서](https://karpenter.sh/docs/concepts/nodepools/)
- [EC2NodeClass 문서](https://karpenter.sh/docs/concepts/nodeclasses/)
- [Karpenter 권한 구조](KARPENTER_PERMISSIONS.md) ⭐
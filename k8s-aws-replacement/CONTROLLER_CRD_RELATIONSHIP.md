# Controller와 CRD의 관계 - 정확한 이해

## ❌ 흔한 오해

```
Controller가 CRD YAML 파일을 읽어서 배포한다? ❌ 틀림!
```

## ✅ 올바른 이해

```
1. CRD = 필드 정의서 (스키마) - 한 번만 등록
2. 사용자가 Custom Resource 인스턴스 생성 (YAML)
3. Controller가 Kubernetes API를 통해 Custom Resource를 감시
4. Controller가 실제 동작 수행 (예: Deployment 생성, EC2 인스턴스 생성 등)
```

## 전체 흐름 (단계별)

### 1단계: CRD 등록 (한 번만)

```bash
# CRD를 등록 (스키마 정의)
kubectl apply -f webapp-crd.yaml

# 이제 "WebApp"이라는 리소스 타입이 Kubernetes에 등록됨
```

**CRD는 "필드 정의서"일 뿐, 실제 데이터가 아님!**

### 2단계: Custom Resource 인스턴스 생성 (사용자가 작성)

```yaml
# webapp-instance.yaml (사용자가 작성)
apiVersion: example.com/v1
kind: WebApp
metadata:
  name: my-webapp
spec:
  replicas: 3
  image: nginx:latest
```

```bash
# Custom Resource 인스턴스 생성
kubectl apply -f webapp-instance.yaml

# 이제 Kubernetes에 "my-webapp"이라는 WebApp 리소스가 생성됨
```

**중요**: Controller는 이 **Custom Resource 인스턴스**를 감시합니다, CRD 파일 자체를 읽는 게 아닙니다!

### 3단계: Controller 동작 (Go 프로그램)

Controller는 다음과 같이 동작합니다:

```go
// Controller 코드 (개념)
func (r *WebAppController) Reconcile(ctx context.Context, req reconcile.Request) {
    // 1. Kubernetes API를 통해 Custom Resource 인스턴스 가져오기
    //    (CRD 파일이 아니라, 생성된 Custom Resource!)
    webapp := &examplev1.WebApp{}
    err := r.Get(ctx, req.NamespacedName, webapp)
    // req.NamespacedName = {Namespace: "default", Name: "my-webapp"}
    
    // 2. Custom Resource의 spec을 읽어서
    desiredReplicas := webapp.Spec.Replicas  // 3
    desiredImage := webapp.Spec.Image        // "nginx:latest"
    
    // 3. 실제 동작 수행 (Deployment 생성)
    deployment := &appsv1.Deployment{
        Spec: appsv1.DeploymentSpec{
            Replicas: &desiredReplicas,  // 3
            Template: corev1.PodTemplateSpec{
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Image: desiredImage,  // "nginx:latest"
                        },
                    },
                },
            },
        },
    }
    
    // 4. Deployment를 Kubernetes에 생성
    r.Create(ctx, deployment)
}
```

### 핵심 포인트

1. **Controller는 CRD YAML 파일을 읽지 않음**
   - CRD는 이미 등록되어 있음 (스키마 정의)
   - Controller는 **Custom Resource 인스턴스**를 Kubernetes API를 통해 가져옴

2. **Controller는 Kubernetes API를 사용**
   ```go
   // CRD 파일 읽기 ❌
   // 읽기 file.ReadFile("webapp-crd.yaml")
   
   // Kubernetes API 사용 ✅
   r.Get(ctx, req.NamespacedName, webapp)
   ```

3. **CRD는 검증만 담당**
   - 사용자가 Custom Resource를 생성할 때
   - Kubernetes가 CRD 스키마를 확인해서 필드가 맞는지 검증

## Karpenter의 정확한 구조

### 질문: Karpenter Controller가 있고 NodePool 등이 Karpenter CRD인가?

**답변: 네, 맞습니다!**

```
Karpenter
├── Karpenter Controller (Go 프로그램)
│   └── Pod로 실행: karpenter-controller
│
└── CRD들 (Karpenter가 정의)
    ├── NodePool CRD          ← 스키마 정의
    ├── EC2NodeClass CRD      ← 스키마 정의
    └── NodeClaim CRD         ← 스키마 정의 (내부용)
```

### Karpenter 설치 시

```bash
helm install karpenter oci://public.ecr.aws/karpenter/karpenter

# 내부적으로:
# 1. CRD 등록 (스키마 정의)
#    - NodePool CRD
#    - EC2NodeClass CRD
#    - NodeClaim CRD
#
# 2. Controller 배포 (Go 프로그램)
#    - karpenter-controller Deployment
```

### 실제 사용 흐름

#### 1. CRD 등록 (Karpenter 설치 시 자동)

```yaml
# 이것은 Karpenter가 설치할 때 자동으로 등록
# (우리가 직접 안 봄)
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: nodepools.karpenter.sh
spec:
  # ... 필드 정의 (스키마) ...
```

#### 2. 사용자가 NodePool 인스턴스 생성

```yaml
# nodepool.yaml (사용자가 작성)
apiVersion: karpenter.sh/v1beta1
kind: NodePool          # ← CRD로 정의된 리소스 타입
metadata:
  name: default
spec:
  limits:
    cpu: "1000"
    memory: "1000Gi"
```

```bash
kubectl apply -f nodepool.yaml

# 이제 Kubernetes에 "default"라는 NodePool 리소스가 생성됨
```

#### 3. Karpenter Controller 동작

```go
// Karpenter Controller 코드 (개념)
func (c *NodePoolController) Reconcile(ctx context.Context, req reconcile.Request) {
    // 1. Kubernetes API를 통해 NodePool 리소스 가져오기
    //    (CRD 파일이 아니라, 생성된 NodePool 인스턴스!)
    nodepool := &karpenterv1beta1.NodePool{}
    err := c.Get(ctx, req.NamespacedName, nodepool)
    // req.NamespacedName = {Name: "default"}
    
    // 2. NodePool의 spec을 읽어서
    cpuLimit := nodepool.Spec.Limits.Cpu      // "1000"
    memoryLimit := nodepool.Spec.Limits.Memory // "1000Gi"
    
    // 3. Pending 상태인 Pod 확인
    pods := &corev1.PodList{}
    c.List(ctx, pods, client.MatchingFields{"status.phase": "Pending"})
    
    // 4. Pod가 스케줄링 가능한지 확인
    for _, pod := range pods.Items {
        // 5. NodePool 설정에 맞춰서 EC2 인스턴스 생성 (AWS API 호출)
        instance, err := c.awsClient.RunInstances(&ec2.RunInstancesInput{
            // NodePool의 limits 등을 참고
            InstanceType: aws.String("t3.medium"),
            // ...
        })
        
        // 6. 노드가 클러스터에 조인될 때까지 대기
        c.waitForNodeJoin(instance.InstanceId)
    }
    
    // 7. 사용하지 않는 노드 제거
    c.consolidateNodes(nodepool)
}
```

## 전체 관계도

```
┌─────────────────────────────────────────────────────────────┐
│ Karpenter 설치 (Helm)                                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. CRD 등록 (스키마 정의)                                  │
│     ┌────────────────────────────────────┐                  │
│     │ NodePool CRD                       │                  │
│     │ - spec.limits.cpu (string)         │                  │
│     │ - spec.limits.memory (string)      │                  │
│     │ - spec.template (...)              │                  │
│     └────────────────────────────────────┘                  │
│                                                              │
│  2. Controller 배포 (Go 프로그램)                           │
│     ┌────────────────────────────────────┐                  │
│     │ karpenter-controller Pod           │                  │
│     │ - NodePool 리소스를 감시           │                  │
│     │ - Kubernetes API 사용              │                  │
│     └────────────────────────────────────┘                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 사용자가 NodePool 인스턴스 생성                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  kubectl apply -f nodepool.yaml                             │
│                                                              │
│  ┌────────────────────────────────────┐                     │
│  │ NodePool 리소스 (인스턴스)         │                     │
│  │ metadata.name: "default"           │                     │
│  │ spec.limits.cpu: "1000"            │                     │
│  │ spec.limits.memory: "1000Gi"       │                     │
│  └────────────────────────────────────┘                     │
│                                                              │
│  (이것이 Kubernetes API에 저장됨)                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Controller 동작 (Go 프로그램)                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controller가:                                              │
│  1. Kubernetes API를 통해 NodePool 리소스 가져오기          │
│     (CRD 파일 읽기 ❌)                                       │
│     (API로 인스턴스 가져오기 ✅)                            │
│                                                              │
│  2. NodePool의 spec 읽기                                    │
│     - limits.cpu: "1000"                                    │
│     - limits.memory: "1000Gi"                               │
│                                                              │
│  3. 실제 동작 수행                                          │
│     - AWS API 호출 (EC2 인스턴스 생성)                     │
│     - 노드 조인 대기                                        │
│     - Pod 스케줄링                                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 핵심 정리

### Q1: Controller가 CRD YAML 파일을 읽어서 배포하는가?

**A: 아니요!**

- Controller는 **CRD YAML 파일을 읽지 않습니다**
- Controller는 **Kubernetes API를 통해 Custom Resource 인스턴스를 가져옵니다**
- CRD는 이미 등록되어 있고, Custom Resource 인스턴스만 생성/수정/삭제됨

### Q2: Karpenter Controller가 있고 NodePool 등이 Karpenter CRD인가?

**A: 네, 맞습니다!**

- **Karpenter Controller**: Go로 작성된 프로그램 (Pod로 실행)
- **NodePool CRD**: Karpenter가 정의한 스키마 (필드 정의서)
- **NodePool 리소스**: 사용자가 작성하는 인스턴스 (실제 데이터)

### 관계 정리

```
Karpenter Controller (Go 프로그램)
  │
  ├── CRD 정의 (설치 시)
  │   ├── NodePool CRD         ← 스키마 정의
  │   ├── EC2NodeClass CRD     ← 스키마 정의
  │   └── NodeClaim CRD        ← 스키마 정의
  │
  └── Controller 동작
      │
      ├── Kubernetes API를 통해 NodePool 리소스 감시
      │   (CRD 파일 읽기 ❌)
      │   (API로 인스턴스 가져오기 ✅)
      │
      └── NodePool 리소스의 spec을 읽어서 실제 동작 수행
          (EC2 인스턴스 생성 등)
```

## 실제 확인 방법

```bash
# 1. CRD 확인 (스키마 정의)
kubectl get crd nodepools.karpenter.sh

# 2. NodePool 리소스 확인 (인스턴스)
kubectl get nodepool

# 3. NodePool 리소스 상세 확인 (Controller가 읽는 데이터)
kubectl get nodepool default -o yaml

# 4. Controller Pod 확인
kubectl get pods -n karpenter-system

# 5. Controller 로그 확인 (실제 동작 확인)
kubectl logs -n karpenter-system deployment/karpenter
```

## 비교: 기본 리소스도 동일

Deployment도 마찬가지입니다:

```bash
# Deployment 리소스 생성
kubectl apply -f deployment.yaml

# Kubernetes Controller (Deployment Controller)가:
# 1. Kubernetes API를 통해 Deployment 리소스를 가져옴
# 2. Deployment의 spec을 읽어서 ReplicaSet 생성
# 3. ReplicaSet Controller가 Pod 생성
```

차이점:
- **Deployment**: Kubernetes 코어에 내장된 Controller
- **NodePool**: Karpenter가 추가한 Custom Controller

하지만 동작 방식은 동일합니다!

## 요약

1. **CRD = 스키마 정의서** (필드 정의, 한 번만 등록)
2. **Custom Resource = 인스턴스** (사용자가 작성하는 실제 데이터)
3. **Controller = 감시 프로그램** (Kubernetes API를 통해 Custom Resource를 감시)
4. **Controller는 CRD 파일을 읽지 않음**, Custom Resource 인스턴스를 읽음
5. **Karpenter = Controller + CRD 정의** (둘 다 Karpenter가 제공)


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

**⚠️ 주의**: Custom Resource를 생성하려면 먼저 CRD가 등록되어 있어야 합니다!

```yaml
# webapp-instance.yaml (사용자가 작성)
apiVersion: example.com/v1
kind: WebApp              # ← CRD가 이미 등록되어 있어야 함
metadata:
  name: my-webapp
spec:
  replicas: 3
  image: nginx:latest     # ← CRD에서 정의한 필드
```

```bash
# 먼저 CRD 등록 (한 번만)
kubectl apply -f webapp-crd.yaml

# 그 다음 Custom Resource 인스턴스 생성
kubectl apply -f webapp-instance.yaml

# 이제 Kubernetes에 "my-webapp"이라는 WebApp 리소스가 생성됨
```

**중요**: 
1. **CRD를 먼저 등록**해야 Custom Resource를 생성할 수 있음
2. Controller는 이 **Custom Resource 인스턴스**를 감시합니다 (CRD 파일 자체를 읽는 게 아님!)
3. Controller가 없어도 Custom Resource는 생성 가능하지만, 아무 일도 일어나지 않음

### Custom Resource에 이미지가 필요한가?

**답변: 아니요! CRD가 어떤 필드를 정의하느냐에 따라 다릅니다.**

각 Custom Resource의 목적에 따라 필요한 필드가 다릅니다:

#### 예시 1: WebApp CRD (이미지 필요)
```yaml
# WebApp CRD가 이미지 필드를 정의
apiVersion: example.com/v1
kind: WebApp
spec:
  replicas: 3
  image: nginx:latest     # ← 컨테이너 이미지 필요
```

#### 예시 2: NodePool CRD (이미지 불필요)
```yaml
# NodePool CRD는 노드 설정만 정의 (이미지 필드 없음)
apiVersion: karpenter.sh/v1beta1
kind: NodePool
spec:
  limits:
    cpu: "1000"
    memory: "1000Gi"
  template:
    spec:
      nodeClassRef:
        kind: EC2NodeClass
  # 이미지 필드 없음! ← 노드 프로비저닝 설정만 있음
```

**왜 차이가 나는가?**
- **WebApp**: 애플리케이션 배포용 → 컨테이너 이미지 필요
- **NodePool**: 노드 프로비저닝용 → 노드 설정만 필요 (이미지는 EC2 AMI로 관리)

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

## 질문: Custom Resource를 먼저 생성하는가?

**답변: 네, 맞습니다! 하지만 순서가 중요합니다:**

1. **CRD 등록** (먼저 해야 함 - 스키마 정의)
2. **Custom Resource 생성** (그 다음 - 인스턴스)
3. **Controller 동작** (이미 실행 중이어야 함 - 감시)

### 전체 순서

```bash
# 1단계: CRD 등록 (스키마 정의)
kubectl apply -f webapp-crd.yaml

# 2단계: Controller 배포 (선택사항이지만 동작하려면 필요)
kubectl apply -f controller-deployment.yaml

# 3단계: Custom Resource 생성 (인스턴스)
kubectl apply -f webapp-instance.yaml

# 이제 Controller가 Custom Resource를 감시하고 동작함
```

**중요**: 
- Controller 없이도 Custom Resource는 생성 가능 (하지만 아무 일도 안 일어남)
- CRD 없이는 Custom Resource 생성 불가 (스키마가 없어서 검증 실패)

## 질문: Custom Resource에 이미지가 필요한가?

**답변: 아니요! CRD가 어떤 필드를 정의하느냐에 따라 다릅니다.**

각 Custom Resource의 목적에 따라 필요한 필드가 다릅니다.

### 예시 비교

#### WebApp CRD (이미지 필요)
```yaml
# WebApp CRD - 애플리케이션 배포용
apiVersion: example.com/v1
kind: WebApp
spec:
  replicas: 3
  image: nginx:latest     # ← 컨테이너 이미지 필요 (애플리케이션 배포용)
  port: 80
```

**이유**: WebApp은 애플리케이션을 배포하는 용도이므로 컨테이너 이미지가 필요함.

#### NodePool CRD (이미지 불필요)
```yaml
# NodePool CRD - 노드 프로비저닝용
apiVersion: karpenter.sh/v1beta1
kind: NodePool
spec:
  limits:
    cpu: "1000"
    memory: "1000Gi"
  template:
    spec:
      nodeClassRef:
        kind: EC2NodeClass
      requirements:
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium", "t3.large"]
  # 이미지 필드 없음! ← 노드 설정만 있음
```

**이유**: NodePool은 노드(EC2 인스턴스)를 프로비저닝하는 용도이므로:
- 이미지는 EC2 AMI (Amazon Machine Image)로 관리됨
- NodePool은 어떤 AMI를 쓸지, 어떤 인스턴스 타입을 쓸지만 설정
- 실제 이미지는 EC2NodeClass에서 관리

### EC2NodeClass에서 이미지 관리

```yaml
# EC2NodeClass - 노드 이미지 설정
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2              # Amazon Linux 2
  # 또는
  # amiSelectorTerms:         # 커스텀 AMI 선택
  #   - tags:
  #       karpenter.sh/discovery: "my-cluster"
```

**정리**:
- **WebApp**: 애플리케이션 배포 → 컨테이너 이미지 필요
- **NodePool**: 노드 프로비저닝 → 노드 설정만 필요 (이미지는 EC2NodeClass에서 관리)

### 다른 예시들

#### Cert-Manager Certificate (이미지 불필요)
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
spec:
  secretName: my-cert
  issuerRef:
    name: letsencrypt
  dnsNames:
    - example.com
  # 이미지 필드 없음 - TLS 인증서 관리용
```

#### PrometheusRule (이미지 불필요)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
spec:
  groups:
    - name: alerts
      rules:
        - alert: HighCPU
          expr: cpu_usage > 0.8
  # 이미지 필드 없음 - 알림 규칙 정의용
```

**결론**: Custom Resource에 이미지가 필요한 것은 아닙니다. 각 Custom Resource의 목적에 따라 필요한 필드가 다릅니다!

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

#### 3. Karpenter Controller 동작 (상세)

**질문: Controller가 NodePool을 읽어서 AWS API로 EC2 인스턴스를 생성하는가?**

**답변: 네, 맞습니다! 하지만 정확한 방식은:**

1. **Kubernetes API**를 통해 NodePool 리소스를 읽음
2. **AWS SDK (Go)**를 사용하여 AWS API 직접 호출 (`awscli`가 아님!)
3. **EC2 RunInstances API**를 호출하여 인스턴스 생성
4. 노드가 클러스터에 조인될 때까지 대기
5. Kubernetes Scheduler가 Pod를 스케줄링

```go
// Karpenter Controller 코드 (실제와 유사한 개념)
import (
    "github.com/aws/aws-sdk-go-v2/service/ec2"
    "github.com/aws/aws-sdk-go-v2/aws"
    karpenterv1beta1 "github.com/aws/karpenter-core/pkg/apis/v1beta1"
    corev1 "k8s.io/api/core/v1"
)

func (c *NodePoolController) Reconcile(ctx context.Context, req reconcile.Request) {
    // 1. Kubernetes API를 통해 NodePool 리소스 가져오기
    //    (Kubernetes API Server에 HTTP 요청)
    nodepool := &karpenterv1beta1.NodePool{}
    err := c.k8sClient.Get(ctx, req.NamespacedName, nodepool)
    // req.NamespacedName = {Name: "default"}
    
    // 2. NodePool의 spec을 읽어서
    cpuLimit := nodepool.Spec.Limits.Cpu      // "1000"
    memoryLimit := nodepool.Spec.Limits.Memory // "1000Gi"
    
    // 3. Pending 상태인 Pod 확인 (Kubernetes API)
    pods := &corev1.PodList{}
    c.k8sClient.List(ctx, pods, client.MatchingFields{"status.phase": "Pending"})
    
    // 4. Pod가 스케줄링 가능한지 확인
    for _, pod := range pods.Items {
        if !c.canSchedule(pod, nodepool) {
            continue
        }
        
        // 5. NodePool 설정에 맞춰서 EC2 인스턴스 생성
        //    AWS SDK (Go)를 사용하여 AWS API 직접 호출
        //    (awscli를 실행하는 게 아니라 Go SDK 사용!)
        instance, err := c.ec2Client.RunInstances(ctx, &ec2.RunInstancesInput{
            // NodePool의 설정을 참고
            InstanceType: aws.String("t3.medium"),  // requirements에서 선택
            MinCount:     aws.Int32(1),
            MaxCount:     aws.Int32(1),
            
            // EC2NodeClass에서 가져온 설정
            ImageId:      aws.String("ami-xxx"),     // EC2NodeClass의 amiFamily 참고
            IamInstanceProfile: &ec2types.IamInstanceProfileSpecification{
                Name: aws.String("karpenter-node-profile"),
            },
            
            // 사용자 데이터 (노드가 클러스터에 조인하도록 설정)
            UserData: aws.String(c.generateBootstrapScript(clusterName)),
            
            TagSpecifications: []ec2types.TagSpecification{
                {
                    ResourceType: ec2types.ResourceTypeInstance,
                    Tags: []ec2types.Tag{
                        {Key: aws.String("karpenter.sh/nodepool"), Value: aws.String(nodepool.Name)},
                        {Key: aws.String("Name"), Value: aws.String(fmt.Sprintf("karpenter-%s", uuid.New()))},
                    },
                },
            },
        })
        
        if err != nil {
            return reconcile.Result{}, err
        }
        
        // 6. 노드가 클러스터에 조인될 때까지 대기
        //    (Kubernetes API를 주기적으로 확인)
        nodeName := *instance.Instances[0].PrivateDnsName
        err = c.waitForNodeJoin(ctx, nodeName, 5*time.Minute)
        
        if err != nil {
            // 노드 조인 실패 시 인스턴스 종료
            c.ec2Client.TerminateInstances(ctx, &ec2.TerminateInstancesInput{
                InstanceIds: []string{*instance.Instances[0].InstanceId},
            })
            return reconcile.Result{}, err
        }
        
        // 7. 노드가 조인되면 Kubernetes Scheduler가 자동으로 Pod를 스케줄링
        //    (Controller가 직접 스케줄링하지 않음)
    }
    
    // 8. 사용하지 않는 노드 제거 (통합 정책)
    c.consolidateNodes(ctx, nodepool)
}
```

### 핵심 포인트

1. **Kubernetes API 사용** (NodePool 읽기)
   ```go
   // Kubernetes API Server에 HTTP 요청
   c.k8sClient.Get(ctx, req.NamespacedName, nodepool)
   ```

2. **AWS SDK (Go) 사용** (EC2 생성)
   ```go
   // awscli를 실행하는 게 아님!
   // Go SDK를 사용하여 AWS API 직접 호출
   c.ec2Client.RunInstances(ctx, &ec2.RunInstancesInput{...})
   ```

3. **실제 AWS API 호출**
   - `ec2:RunInstances` - 인스턴스 생성
   - `ec2:DescribeInstances` - 인스턴스 상태 확인
   - `ec2:TerminateInstances` - 인스턴스 종료
   - `ssm:GetParameter` - AMI ID 가져오기 등

4. **노드 조인 대기**
   - 노드가 EC2에서 실행됨
   - 노드가 Kubernetes 클러스터에 조인 (kubelet이 API Server에 등록)
   - Controller가 Kubernetes API를 통해 노드 상태 확인
   - 노드가 Ready 상태가 되면 Kubernetes Scheduler가 Pod 스케줄링

### 전체 흐름도

```
┌─────────────────────────────────────────────────────────────┐
│ 1. 사용자가 NodePool 생성                                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  kubectl apply -f nodepool.yaml                             │
│                                                              │
│  apiVersion: karpenter.sh/v1beta1                           │
│  kind: NodePool                                              │
│  spec:                                                       │
│    limits: { cpu: "1000", memory: "1000Gi" }               │
│    template: { nodeClassRef: {...} }                        │
│                                                              │
│  (이것이 Kubernetes API Server에 저장됨)                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Controller가 NodePool 읽기 (Kubernetes API)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controller (Go 프로그램):                                  │
│  - Kubernetes API Server에 HTTP 요청                        │
│  - NodePool 리소스 가져오기                                 │
│  - spec.limits.cpu: "1000"                                 │
│  - spec.limits.memory: "1000Gi"                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Pending Pod 확인 (Kubernetes API)                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controller:                                                │
│  - Kubernetes API Server에 HTTP 요청                        │
│  - Pending 상태인 Pod 목록 가져오기                         │
│  - Pod가 NodePool 요구사항에 맞는지 확인                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. EC2 인스턴스 생성 (AWS API - AWS SDK Go 사용)           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controller:                                                │
│  - AWS SDK (Go) 사용                                        │
│  - AWS EC2 API 직접 호출 (HTTP 요청)                       │
│                                                              │
│  ec2Client.RunInstances({                                   │
│    InstanceType: "t3.medium",                              │
│    ImageId: "ami-xxx",                                     │
│    UserData: "<bootstrap script>",                         │
│    ...                                                      │
│  })                                                         │
│                                                              │
│  ↓                                                          │
│                                                              │
│  AWS EC2: EC2 인스턴스 생성됨                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. 노드가 클러스터에 조인 대기 (Kubernetes API)             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controller:                                                │
│  - 주기적으로 Kubernetes API 호출                           │
│  - 노드가 API Server에 등록되었는지 확인                    │
│  - 노드가 Ready 상태가 될 때까지 대기                      │
│                                                              │
│  kubectl get nodes                                          │
│  # NAME               STATUS   AGE                          │
│  # ip-10-0-1-100     Ready    30s  ← 조인됨!              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Kubernetes Scheduler가 Pod 스케줄링                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Kubernetes Scheduler (내장):                               │
│  - Pending Pod를 발견                                       │
│  - 새로 생성된 노드에 Pod 스케줄링 (자동)                  │
│                                                              │
│  (Controller가 직접 스케줄링하지 않음)                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 정확한 기술 스택

| 작업 | 사용 기술 | 설명 |
|------|----------|------|
| **NodePool 읽기** | Kubernetes API (HTTP) | Kubernetes API Server에 요청 |
| **Pod 확인** | Kubernetes API (HTTP) | Kubernetes API Server에 요청 |
| **EC2 인스턴스 생성** | AWS SDK for Go | AWS EC2 API 직접 호출 (HTTP) |
| **노드 조인 확인** | Kubernetes API (HTTP) | Kubernetes API Server에 요청 |
| **Pod 스케줄링** | Kubernetes Scheduler | Kubernetes 내장 기능 |

**중요**: `awscli`를 사용하지 않습니다! AWS SDK (Go)를 사용하여 AWS API를 직접 호출합니다.

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


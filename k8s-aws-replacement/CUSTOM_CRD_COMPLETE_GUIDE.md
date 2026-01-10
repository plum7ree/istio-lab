# Custom Resource Definition (CRD) 완전 가이드

이 문서는 Kubernetes Custom Resource Definition (CRD)과 Controller의 개념을 완전히 이해하기 위한 종합 가이드입니다.

## 목차

1. [기본 개념](#1-기본-개념)
2. [kind와 파라미터는 어디서 오는가?](#2-kind와-파라미터는-어디서-오는가)
3. [CRD란 무엇인가?](#3-crd란-무엇인가)
4. [CRD가 YAML 필드를 정의하는 방법](#4-crd가-yaml-필드를-정의하는-방법)
5. [Controller는 무엇인가?](#5-controller는-무엇인가)
6. [Karpenter 예시로 완전 이해하기](#6-karpenter-예시로-완전-이해하기)
7. [실제 개발 순서](#7-실제-개발-순서)
8. [요약 및 핵심 정리](#8-요약-및-핵심-정리)

---

## 1. 기본 개념

### ❌ 잘못된 이해

```
Karpenter = CRD  ❌ 틀림!
```

### ✅ 올바른 이해

```
Karpenter = Controller 프로그램 (Go로 작성)
  │
  ├── NodePool CRD를 정의함 (YAML)
  │     └── 이 CRD가 필드 정의 (스키마)
  │
  └── Controller가 NodePool 리소스를 감시하고 동작 수행
```

### 핵심 구분

| 항목 | 설명 | 언어/형식 | 예시 |
|------|------|----------|------|
| **Built-in Resource** | Kubernetes 코어에 포함된 리소스 | - | `Deployment`, `Service` |
| **Custom Resource** | 사용자가 정의한 리소스 | YAML | `WebApp`, `NodePool` |
| **CRD** | Custom Resource의 스키마 정의 | **YAML** | `CustomResourceDefinition` |
| **Controller** | Custom Resource를 처리하는 프로그램 | **Go** | Karpenter Controller |
| **Operator** | CRD + Controller + Domain Logic | Go + YAML | Prometheus Operator, Karpenter |

---

## 2. kind와 파라미터는 어디서 오는가?

### 기본 리소스 (Built-in Resources)

`kind: Deployment`, `kind: Service` 같은 기본 리소스들은 **Kubernetes 코어 API**에 정의되어 있습니다.

```yaml
apiVersion: apps/v1  # API 그룹과 버전
kind: Deployment     # 리소스 타입
```

#### Kubernetes API 구조

Kubernetes는 RESTful API로 구성되어 있으며, 다음과 같은 구조를 가집니다:

```
/api/v1/                    # Core API 그룹 (Pod, Service, ConfigMap 등)
/apis/apps/v1/              # Apps API 그룹 (Deployment, StatefulSet 등)
/apis/networking.k8s.io/v1/ # Networking API 그룹 (Ingress, NetworkPolicy 등)
/apis/storage.k8s.io/v1/    # Storage API 그룹 (StorageClass, PVC 등)
```

#### 실제 위치

- **코드 위치**: Kubernetes 소스 코드의 `pkg/apis/` 디렉토리
- **예시**: `pkg/apis/apps/v1/types.go`에 Deployment 구조가 정의됨

### API 버전 확인하기

클러스터에서 사용 가능한 API 리소스를 확인할 수 있습니다:

```bash
# 모든 API 리소스 확인
kubectl api-resources

# 특정 리소스의 API 버전 확인
kubectl explain deployment

# Deployment의 serviceAccountName 필드 확인
kubectl explain deployment.spec.template.spec.serviceAccountName
```

### kind의 종류

#### Core API 그룹 (`apiVersion: v1`)
- `Pod`
- `Service`
- `ConfigMap`
- `Secret`
- `Namespace`
- `ServiceAccount`

#### Apps API 그룹 (`apiVersion: apps/v1`)
- `Deployment`
- `StatefulSet`
- `DaemonSet`
- `ReplicaSet`

#### 기타 API 그룹
- `batch/v1`: `Job`, `CronJob`
- `autoscaling/v2`: `HorizontalPodAutoscaler`
- `networking.k8s.io/v1`: `Ingress`, `NetworkPolicy`
- `storage.k8s.io/v1`: `StorageClass`, `PersistentVolume`

---

## 3. CRD란 무엇인가?

### CRD 정의

**Custom Resource Definition (CRD)**은 Kubernetes에 새로운 `kind`를 추가하는 방법입니다.

### CRD와 기본 리소스의 차이

| 항목 | Built-in Resource | Custom Resource |
|------|------------------|-----------------|
| 정의 위치 | Kubernetes 코어 (하드코딩) | CRD (런타임에 추가) |
| 예시 | `Deployment`, `Service` | `NodePool`, `Gateway` (Istio) |
| 확인 방법 | `kubectl explain deployment` | `kubectl explain nodepool` |

### 간단한 CRD 예제

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: webapps.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
                minimum: 1
                maximum: 10
              image:
                type: string
              port:
                type: integer
          status:
            type: object
            properties:
              availableReplicas:
                type: integer
  scope: Namespaced
  names:
    plural: webapps
    singular: webapp
    kind: WebApp
    shortNames:
    - wa
```

CRD를 생성한 후, 새로운 `kind: WebApp`을 사용할 수 있습니다:

```yaml
apiVersion: example.com/v1
kind: WebApp
metadata:
  name: my-webapp
  namespace: default
spec:
  replicas: 3
  image: nginx:latest
  port: 80
```

---

## 4. CRD가 YAML 필드를 정의하는 방법

### 질문: 어떤 YAML 파일의 필드를 작성해야 하는지 CRD에서 정의하나요?

**답변: 네, 맞습니다!**

CRD는 Custom Resource의 **스키마(Schema)**를 정의합니다. 즉, 어떤 필드를 쓸 수 있고, 어떤 타입인지, 필수인지 선택인지 등을 정의합니다.

### 실제 예시: NodePool (Karpenter)

#### 1단계: Karpenter가 CRD를 정의 (설치 시 자동)

```yaml
# 이것은 Karpenter가 설치할 때 자동으로 등록하는 CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: nodepools.karpenter.sh
spec:
  group: karpenter.sh
  versions:
  - name: v1beta1
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:                    # ← 여기서 "spec" 필드를 정의
            type: object
            properties:
              template:            # ← "template" 필드 정의
                type: object
                properties:
                  metadata:
                    type: object
                    properties:
                      labels:      # ← "labels" 필드 정의
                        type: object
              limits:              # ← "limits" 필드 정의
                type: object
                properties:
                  cpu:             # ← "cpu" 필드는 string 타입
                    type: string
                  memory:          # ← "memory" 필드는 string 타입
                    type: string
              disruption:          # ← "disruption" 필드 정의
                type: object
                properties:
                  consolidateAfter:
                    type: string
          status:                  # ← "status" 필드 정의 (읽기 전용)
            type: object
            properties:
              nodes:
                type: integer
  names:
    kind: NodePool
    plural: nodepools
```

#### 2단계: 사용자가 CRD가 정의한 대로 YAML 작성

CRD가 위와 같이 정의되어 있으므로, 사용자는 **그 정의에 맞춰서** YAML을 작성해야 합니다:

```yaml
# 이것은 사용자가 작성하는 YAML
# CRD에서 정의한 필드만 사용 가능!
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:                    # ✅ CRD에서 정의한 필드
  template:              # ✅ CRD에서 정의한 필드
    metadata:
      labels:            # ✅ CRD에서 정의한 필드
        workload-type: general
  limits:                # ✅ CRD에서 정의한 필드
    cpu: "1000"          # ✅ CRD에서 정의한 타입 (string)
    memory: "1000Gi"     # ✅ CRD에서 정의한 타입 (string)
  disruption:            # ✅ CRD에서 정의한 필드
    consolidateAfter: 30s
```

#### 3단계: 잘못된 필드 사용 시 에러

만약 CRD에 정의되지 않은 필드를 사용하면:

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
spec:
  replicas: 3  # ❌ 에러! CRD에 "replicas" 필드가 정의되어 있지 않음
  limits:
    cpu: "1000"
```

Kubernetes는 이 YAML을 거부합니다:
```
Error: unknown field "replicas" in spec
```

### 필드 확인 방법

```bash
# CRD가 정의한 필드 확인
kubectl explain nodepool

# 출력:
# KIND:     NodePool
# VERSION:  karpenter.sh/v1beta1
# 
# FIELDS:
#    apiVersion   <string>
#    kind <string>
#    metadata     <Object>
#    spec <Object>
#       limits    <Object>        ← CRD에서 정의한 필드
#       template  <Object>        ← CRD에서 정의한 필드

# 더 자세히
kubectl explain nodepool.spec.limits

# 출력:
# KIND:     NodePool
# VERSION:  karpenter.sh/v1beta1
# 
# RESOURCE: limits <Object>
# 
# FIELDS:
#    cpu    <string>    ← CRD에서 정의: string 타입
#    memory <string>    ← CRD에서 정의: string 타입
```

### 비교: 기본 리소스도 동일

Deployment도 마찬가지입니다:

```bash
# Deployment의 필드 정의 확인
kubectl explain deployment.spec.replicas

# 출력:
# KIND:     Deployment
# VERSION:  apps/v1
# 
# FIELD:    replicas <integer>  ← Kubernetes 코어에서 정의
```

차이점:
- **Deployment**: Kubernetes 코어에 하드코딩 (Built-in)
- **NodePool**: CRD로 런타임에 추가 (Custom)

하지만 개념은 동일합니다!

---

## 5. Controller는 무엇인가?

### Controller의 역할

**CRD만으로는 아무 일도 일어나지 않습니다.** 실제 동작을 하려면 **Controller**가 필요합니다.

Controller는 Custom Resource를 감시하고, 원하는 상태를 구현하는 프로그램입니다.

### Controller 동작 방식 (개념)

```go
// 예시 코드 (실제 구현은 더 복잡함)
func (c *Controller) Reconcile(ctx context.Context, req reconcile.Request) {
    // 1. Custom Resource 가져오기
    webapp := &examplev1.WebApp{}
    err := c.Get(ctx, req.NamespacedName, webapp)
    
    // 2. 원하는 상태 확인
    desiredReplicas := webapp.Spec.Replicas
    
    // 3. 현재 상태 확인 (Deployment가 있는지 확인)
    deployment := &appsv1.Deployment{}
    
    // 4. 원하는 상태와 현재 상태를 비교
    // 5. 차이가 있으면 Deployment 생성/수정
    // 6. 상태 업데이트
}
```

### Operator란?

**Operator**는 CRD + Controller + Custom Logic을 묶은 것입니다.

- **CRD**: 새로운 리소스 타입 정의
- **Controller**: 리소스 감시 및 조정
- **Custom Logic**: 도메인 지식 (예: 데이터베이스 백업, 업그레이드 등)

#### 유명한 Operator 예시

1. **Prometheus Operator**: Prometheus를 Kubernetes에서 쉽게 운영
2. **Cert-Manager**: TLS 인증서 자동 관리
3. **Istio Operator**: Istio 설치 및 관리
4. **Karpenter**: 노드 자동 프로비저닝
5. **Database Operators**: PostgreSQL, MySQL 등을 Kubernetes에서 운영

---

## 6. Karpenter 예시로 완전 이해하기

### ⚠️ 중요: Karpenter는 CRD가 아닙니다!

**Karpenter ≠ CRD**

- **Karpenter**: Controller 프로그램 (Go로 작성)
- **NodePool CRD**: Karpenter가 정의한 Custom Resource 스키마 (YAML)
- **NodePool 리소스**: 사용자가 작성하는 인스턴스 (YAML)

### Karpenter 설치 시 하는 일

```bash
# Karpenter를 Helm으로 설치하면:
helm install karpenter oci://public.ecr.aws/karpenter/karpenter

# 내부적으로:
# 1. CRD 설치 (YAML)
#    - NodePool CRD
#    - EC2NodeClass CRD
#    - NodeClaim CRD (내부용)
#
# 2. Controller 배포 (Go 프로그램, Pod로 실행)
#    - karpenter-controller Deployment
```

### Karpenter Controller (Go 프로그램)

Controller는 Go로 작성되어 있으며, 다음과 같은 일을 합니다:

```go
// 예시 코드 (실제 Karpenter 소스는 더 복잡함)
package main

func (c *NodePoolController) Reconcile(ctx context.Context, req reconcile.Request) {
    // 1. NodePool 리소스 가져오기
    nodepool := &karpenterv1beta1.NodePool{}
    err := c.Get(ctx, req.NamespacedName, nodepool)
    
    // 2. Pending 상태인 Pod 확인
    pods := &corev1.PodList{}
    c.List(ctx, pods, client.MatchingFields{"status.phase": "Pending"})
    
    // 3. Pod가 스케줄링 가능한지 확인
    for _, pod := range pods.Items {
        if !c.canSchedule(pod, nodepool) {
            continue
        }
        
        // 4. EC2 인스턴스 생성 (AWS API 호출)
        instance, err := c.awsClient.RunInstances(...)
        
        // 5. 노드가 클러스터에 조인될 때까지 대기
        c.waitForNodeJoin(instance.ID)
        
        // 6. Pod 스케줄링
        // (이미 Kubernetes Scheduler가 자동으로 처리)
    }
    
    // 7. 사용하지 않는 노드 제거
    c.consolidateNodes(nodepool)
}
```

이 Controller는 **Pod로 실행**됩니다:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: karpenter-controller
  namespace: karpenter-system
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: controller
        image: public.ecr.aws/karpenter/karpenter:v1.0.0  # Go로 컴파일된 바이너리
        command: ["karpenter"]
```

### 전체 흐름도

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Karpenter 설치 (Helm)                                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐         ┌──────────────────────┐     │
│  │ CRD 설치 (YAML) │         │ Controller 배포 (Go) │     │
│  │                 │         │                      │     │
│  │ NodePool CRD    │         │ karpenter-controller │     │
│  │ EC2NodeClass CRD│         │ Pod                  │     │
│  └─────────────────┘         └──────────────────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. 사용자가 YAML 작성 (CRD가 정의한 필드만 사용)          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  kubectl apply -f nodepool.yaml                             │
│                                                              │
│  apiVersion: karpenter.sh/v1beta1                           │
│  kind: NodePool  ← CRD로 정의된 리소스                      │
│  spec:                                                       │
│    limits:        ← CRD가 정의한 필드                       │
│      cpu: "1000"  ← CRD가 정의한 타입 (string)             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Kubernetes 검증                                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ✅ CRD에 정의된 필드인가?                                  │
│  ✅ 타입이 맞는가?                                          │
│  ✅ 필수 필드가 있는가?                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Controller 동작 (Go 프로그램)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controller가 감시:                                         │
│  - NodePool 리소스 변경                                     │
│  - Pending Pod 존재                                         │
│                                                              │
│  Controller가 실행:                                         │
│  - AWS API 호출 (EC2 인스턴스 생성)                        │
│  - 노드가 클러스터에 조인될 때까지 대기                    │
│  - Pod 스케줄링 (Kubernetes Scheduler가 처리)              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 실제 확인하기

```bash
# 1. CRD 확인 (필드 정의서)
kubectl get crd | grep karpenter

# 출력:
# nodepools.karpenter.sh      2024-01-01T00:00:00Z

# 2. CRD가 정의한 필드 확인
kubectl explain nodepool.spec

# 3. 특정 필드 확인
kubectl explain nodepool.spec.limits.cpu

# 4. 생성된 NodePool 리소스 확인
kubectl get nodepool

# 5. Controller Pod 확인
kubectl get pods -n karpenter-system
```

---

## 7. 실제 개발 순서

### 1단계: CRD 정의 (YAML)

```yaml
# myapp-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myapps.example.com
spec:
  group: example.com
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - replicas
            properties:
              replicas:
                type: integer
                minimum: 1
                maximum: 10
              image:
                type: string
  scope: Namespaced
  names:
    plural: myapps
    singular: myapp
    kind: MyApp
    shortNames:
    - ma
```

### 2단계: CRD 설치

```bash
kubectl apply -f myapp-crd.yaml

# CRD 확인
kubectl get crd myapps.example.com

# 필드 확인
kubectl explain myapp.spec
```

### 3단계: Controller 개발 (Go)

```go
// main.go
package main

import (
    "context"
    "fmt"
    
    apierrors "k8s.io/apimachinery/pkg/api/errors"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/reconcile"
    ctrl "sigs.k8s.io/controller-runtime"
    
    examplev1 "example.com/api/v1"
    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type MyAppReconciler struct {
    client.Client
}

func (r *MyAppReconciler) Reconcile(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
    // 1. MyApp 리소스 가져오기
    myapp := &examplev1.MyApp{}
    if err := r.Get(ctx, req.NamespacedName, myapp); err != nil {
        if apierrors.IsNotFound(err) {
            return reconcile.Result{}, nil
        }
        return reconcile.Result{}, err
    }
    
    // 2. Deployment 생성/수정
    deployment := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      myapp.Name,
            Namespace: myapp.Namespace,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &myapp.Spec.Replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: map[string]string{"app": myapp.Name},
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{"app": myapp.Name},
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  myapp.Name,
                            Image: myapp.Spec.Image,
                        },
                    },
                },
            },
        },
    }
    
    // 3. Deployment 생성 또는 업데이트
    if err := r.Create(ctx, deployment); err != nil {
        if apierrors.IsAlreadyExists(err) {
            // 이미 존재하면 업데이트
            existing := &appsv1.Deployment{}
            if err := r.Get(ctx, client.ObjectKeyFromObject(deployment), existing); err != nil {
                return reconcile.Result{}, err
            }
            existing.Spec = deployment.Spec
            return reconcile.Result{}, r.Update(ctx, existing)
        }
        return reconcile.Result{}, err
    }
    
    return reconcile.Result{}, nil
}

func main() {
    // Controller Manager 설정
    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme: scheme.Scheme,
    })
    if err != nil {
        panic(err)
    }
    
    // MyApp Controller 등록
    if err = ctrl.NewControllerManagedBy(mgr).
        For(&examplev1.MyApp{}).
        Complete(&MyAppReconciler{
            Client: mgr.GetClient(),
        }); err != nil {
        panic(err)
    }
    
    // Controller 실행
    if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
        panic(err)
    }
}
```

### 4단계: Controller 빌드 및 배포

```bash
# Go 빌드
go build -o myapp-controller .

# Docker 이미지 빌드
docker build -t myapp-controller:latest .

# Kubernetes에 배포
kubectl apply -f controller-deployment.yaml
```

### 5단계: Custom Resource 사용

```yaml
# myapp-instance.yaml
apiVersion: example.com/v1
kind: MyApp
metadata:
  name: test
  namespace: default
spec:
  replicas: 3
  image: nginx:latest
```

```bash
kubectl apply -f myapp-instance.yaml

# Controller가 자동으로 Deployment 생성
kubectl get deployment test
```

---

## 8. 요약 및 핵심 정리

### 핵심 질문과 답변

#### Q1: `kind: Karpenter` 같은 것을 만들려면 Go로 만드는 건가?

**A: 반은 맞고 반은 틀립니다!**

- ✅ **Controller는 Go로 작성**합니다 (예: Karpenter Controller)
- ❌ **CRD는 YAML로 정의**합니다 (예: NodePool CRD)

#### Q2: CRD뿐만 아니라 Controller도 만들어야 하나?

**A: 네, 맞습니다!** 둘 다 필요합니다.

- CRD만 있으면: 리소스를 생성/조회할 수 있지만 아무 동작도 하지 않음
- Controller만 있으면: 동작할 리소스 구조가 없음
- 둘 다 있어야: Custom Resource 생성 → Controller 감시 → 실제 동작 수행

#### Q3: 어떤 YAML 필드를 작성해야 하는지 CRD에서 정의하나요?

**A: 네, 맞습니다!**

- CRD = 필드 정의서 (스키마)
- 사용자는 CRD가 정의한 필드만 사용 가능
- `kubectl explain` 명령으로 확인 가능

#### Q4: Karpenter는 CRD가 아니야?

**A: 네, 맞습니다!**

- **Karpenter**: Controller 프로그램 (Go)
- **NodePool CRD**: Karpenter가 정의한 필드 정의서 (YAML)
- **NodePool 리소스**: 사용자가 작성하는 인스턴스 (YAML)

### 최종 정리

| 항목 | 정의 방법 | 역할 | 필수 여부 |
|------|----------|------|----------|
| **CRD** | YAML 파일로 정의 | 리소스 구조 정의 (스키마) | ✅ 필수 |
| **Custom Resource** | YAML 파일로 작성 | CRD로 정의된 리소스 인스턴스 | ✅ 사용 시 필수 |
| **Controller** | Go로 개발 | Custom Resource를 감시하고 실제 동작 수행 | ✅ 동작하려면 필수 |

### 핵심 포인트

1. ✅ **CRD는 YAML로 정의** (Go 불필요)
2. ✅ **Controller는 Go로 개발** (실제 동작 구현)
3. ✅ **둘 다 필요함**: CRD만으로는 아무 일도 일어나지 않음
4. ✅ **Karpenter가 완벽한 예시**: CRD (YAML) + Controller (Go)
5. ✅ **CRD = 필드 정의서**: 어떤 필드를 쓸 수 있는지 정의
6. ✅ **확인 방법**: `kubectl explain <resource>.<field>`

### 실제 예시 파일

이 프로젝트의 `crd-examples/` 폴더에 실습 가능한 예제가 있습니다:

- `webapp-crd.yaml`: 간단한 WebApp CRD 정의
- `webapp-instance.yaml`: WebApp Custom Resource 인스턴스
- `database-crd.yaml`: 복잡한 Database CRD 정의 (Operator 예시)
- `database-instance.yaml`: Database Custom Resource 인스턴스

## 추가 자료

더 자세한 내용은 다음 문서를 참고하세요:

- **[CONTROLLER_CRD_RELATIONSHIP.md](CONTROLLER_CRD_RELATIONSHIP.md)** - Controller가 CRD를 어떻게 사용하는지 정확한 이해
  - Controller는 CRD YAML 파일을 읽지 않는다는 점
  - Karpenter의 정확한 구조
  - Kubernetes API를 통한 통신 방식

## 참고 자료

- [Kubernetes API Concepts](https://kubernetes.io/docs/reference/using-api/api-concepts/)
- [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [Karpenter 소스 코드](https://github.com/aws/karpenter)
- [Kubebuilder Tutorial](https://book.kubebuilder.io/)
- [Operator SDK](https://sdk.operatorframework.io/)


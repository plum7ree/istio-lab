# ServiceAccount 완전 이해하기

이 문서는 ServiceAccount가 무엇인지, 어떻게 Pod에 권한을 부여하는지 명확하게 설명합니다.

## 🎯 핵심 질문

1. **ServiceAccount가 Pod에게 권한을 주는가?** → ✅ 네, 맞습니다!
2. **ServiceAccount를 어떻게 Pod에 연결하는가?** → Deployment의 `spec.serviceAccountName`으로 연결
3. **파일로 작성하면 권한이 생기는가?** → ✅ 네, `kubectl apply`하면 권한이 생깁니다

## 📦 ServiceAccount란?

### 간단히 말하면

**ServiceAccount = Pod가 사용할 수 있는 "신원(Identity)"**

- Kubernetes RBAC 권한을 부여받는 주체
- AWS IAM Role을 사용할 수 있는 주체 (IRSA)

### 일반 사용자 vs ServiceAccount

```
일반 사용자 (User)
  - kubectl을 사용하는 사람
  - 예: 개발자, 운영자

ServiceAccount
  - Pod가 사용하는 "가상 사용자"
  - 예: Karpenter Pod, 웹앱 Pod
```

## 🔗 ServiceAccount와 Pod의 연결

### 1. ServiceAccount 생성

```yaml
# templates/serviceaccount.yaml.tpl
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  namespace: karpenter-system
  annotations:
    eks.amazonaws.com/role-arn: ${controller_role_arn}  # IRSA 설정
```

**이 파일을 `kubectl apply`하면:**
- ServiceAccount가 Kubernetes 클러스터에 생성됨
- 하지만 아직 아무 Pod도 사용하지 않음

### 2. Pod에 ServiceAccount 연결

**Helm 차트가 자동으로 연결합니다!**

Karpenter Helm 차트를 설치하면 다음과 같은 Deployment가 생성됩니다:

```yaml
# Helm 차트가 자동 생성 (우리 코드에는 없지만 Helm이 생성)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: karpenter
  namespace: karpenter-system
spec:
  template:
    spec:
      serviceAccountName: karpenter  # ← 여기서 ServiceAccount 연결!
      containers:
      - name: karpenter
        image: public.ecr.aws/karpenter/karpenter:latest
```

### 3. 연결 과정

```
1. ServiceAccount 생성
   kubectl apply -f serviceaccount.yaml
   → ServiceAccount "karpenter" 생성됨

2. Pod 생성 (Deployment)
   Helm 차트가 Deployment 생성
   → spec.serviceAccountName: karpenter 지정

3. Pod 실행
   Kubernetes가 Pod를 생성할 때
   → ServiceAccount "karpenter"를 Pod에 연결
   → Pod가 이 ServiceAccount의 권한을 사용
```

## 🔐 권한 부여 메커니즘

### 1. Kubernetes RBAC 권한

#### ClusterRole 생성 (권한 정의)

```yaml
# Helm 차트가 자동 생성
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: karpenter
rules:
- apiGroups: [""]
  resources: ["pods", "nodes"]
  verbs: ["get", "list", "watch"]  # Pod 읽기 권한
```

#### ClusterRoleBinding 생성 (권한 부여)

```yaml
# Helm 차트가 자동 생성
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karpenter
roleRef:
  kind: ClusterRole
  name: karpenter  # 위에서 만든 ClusterRole 참조
subjects:
- kind: ServiceAccount
  name: karpenter        # ← ServiceAccount에 권한 부여!
  namespace: karpenter-system
```

**핵심**: ClusterRoleBinding이 **ServiceAccount**에 권한을 부여합니다!

### 2. AWS IAM 권한 (IRSA)

#### IAM Role 생성 (Terraform)

```hcl
# modules/iam/main.tf
resource "aws_iam_role" "karpenter_controller" {
  # IRSA 설정: 이 ServiceAccount만 사용 가능
  assume_role_policy = {
    Condition = {
      StringEquals = {
        "...:sub" = "system:serviceaccount:karpenter-system:karpenter"
      }
    }
  }
}
```

#### ServiceAccount에 IAM Role 연결

```yaml
# templates/serviceaccount.yaml.tpl
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: ${controller_role_arn}  # ← IAM Role ARN
```

**핵심**: ServiceAccount annotation에 IAM Role ARN을 지정하면, Pod가 자동으로 AWS 권한을 획득합니다!

## 📊 전체 권한 부여 흐름

### 단계별 설명

```
1. ServiceAccount 생성
   kubectl apply -f serviceaccount.yaml
   ↓
   ServiceAccount "karpenter" 생성됨
   (아직 권한 없음)

2. ClusterRole + ClusterRoleBinding 생성
   Helm 차트가 자동 생성
   ↓
   ClusterRoleBinding이 ServiceAccount에 권한 부여
   ↓
   ServiceAccount가 Kubernetes RBAC 권한 획득 ✅

3. IAM Role 생성
   Terraform apply
   ↓
   IAM Role 생성됨
   (ServiceAccount annotation에 ARN 지정)

4. Pod 생성
   Helm 차트가 Deployment 생성
   ↓
   spec.serviceAccountName: karpenter 지정
   ↓
   Pod가 ServiceAccount 사용
   ↓
   Pod가 Kubernetes RBAC 권한 획득 ✅
   Pod가 AWS IAM 권한 획득 (IRSA) ✅
```

## 🔍 코드에서의 실제 연결

### 1. ServiceAccount 생성 (Terraform)

```hcl
# main.tf
resource "kubectl_manifest" "karpenter_serviceaccount" {
  yaml_body = templatefile("${path.module}/templates/serviceaccount.yaml.tpl", {
    controller_role_arn = module.karpenter_iam.karpenter_controller_role_arn
  })
}
```

이 코드는:
- ServiceAccount YAML을 생성
- `kubectl apply`를 실행
- ServiceAccount가 클러스터에 생성됨

### 2. Pod에 ServiceAccount 연결 (Helm)

```hcl
# main.tf
resource "helm_release" "karpenter" {
  set {
    # Helm 차트의 Deployment에 ServiceAccount 지정
    name  = "serviceAccount.name"
    value = "karpenter"
  }
  
  set {
    # ServiceAccount annotation에 IAM Role ARN 지정
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_iam.karpenter_controller_role_arn
  }
}
```

이 코드는:
- Helm 차트를 설치
- Helm 차트가 Deployment 생성
- Deployment의 `spec.serviceAccountName: karpenter` 지정
- Pod가 ServiceAccount를 사용하게 됨

## 💡 파일로 작성하면 권한이 생기는가?

### 답: 네, 하지만 완전한 답변

#### 1. ServiceAccount 파일만으로는 권한 없음

```yaml
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
```

이 파일만으로는:
- ✅ ServiceAccount는 생성됨
- ❌ 권한은 없음 (아직)

#### 2. ClusterRoleBinding 파일로 권한 부여

```yaml
# clusterrolebinding.yaml (Helm 차트가 생성)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karpenter
subjects:
- kind: ServiceAccount
  name: karpenter  # ← ServiceAccount에 권한 부여
  namespace: karpenter-system
roleRef:
  kind: ClusterRole
  name: karpenter
```

이 파일을 `kubectl apply`하면:
- ✅ ServiceAccount에 Kubernetes RBAC 권한 부여됨

#### 3. Pod에 ServiceAccount 연결

```yaml
# deployment.yaml (Helm 차트가 생성)
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: karpenter  # ← Pod가 ServiceAccount 사용
```

이 파일을 `kubectl apply`하면:
- ✅ Pod가 ServiceAccount를 사용
- ✅ Pod가 ServiceAccount의 권한을 획득

## 🎯 실제 예시

### 예시 1: Karpenter

```yaml
# 1. ServiceAccount 생성
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123:role/karpenter-controller

# 2. ClusterRoleBinding (권한 부여)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
subjects:
- kind: ServiceAccount
  name: karpenter  # ← 이 ServiceAccount에 권한 부여

# 3. Deployment (Pod에 ServiceAccount 연결)
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: karpenter  # ← Pod가 이 ServiceAccount 사용
```

### 예시 2: 일반 웹앱

```yaml
# 1. ServiceAccount 생성
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp

# 2. Deployment (Pod에 ServiceAccount 연결)
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: webapp  # ← Pod가 이 ServiceAccount 사용
      containers:
      - name: webapp
        image: nginx
```

## 🔄 전체 흐름 정리

### 파일 작성 → 권한 획득 과정

```
1. ServiceAccount YAML 작성
   ↓
2. kubectl apply -f serviceaccount.yaml
   ↓
3. ServiceAccount가 클러스터에 생성됨
   (아직 권한 없음)
   ↓
4. ClusterRoleBinding YAML 작성
   (ServiceAccount에 권한 부여)
   ↓
5. kubectl apply -f clusterrolebinding.yaml
   ↓
6. ServiceAccount가 Kubernetes RBAC 권한 획득 ✅
   ↓
7. Deployment YAML 작성
   (serviceAccountName: karpenter 지정)
   ↓
8. kubectl apply -f deployment.yaml
   ↓
9. Pod가 생성되고 ServiceAccount 사용
   ↓
10. Pod가 ServiceAccount의 권한 획득 ✅
```

## 📋 핵심 정리

### ServiceAccount의 역할

1. **Pod의 신원(Identity)**
   - Pod가 누구인지 식별
   - Pod가 어떤 권한을 가질지 결정

2. **권한 부여의 중간 매개체**
   - ClusterRoleBinding → ServiceAccount → Pod
   - IAM Role (IRSA) → ServiceAccount → Pod

### 권한 부여 과정

```
ClusterRole (권한 정의)
    ↓
ClusterRoleBinding (권한 부여)
    ↓
ServiceAccount (권한을 받는 주체)
    ↓
Pod (ServiceAccount 사용)
    ↓
Pod가 권한 획득 ✅
```

### 파일과 권한의 관계

- **파일 작성만으로는 권한 없음**
- **`kubectl apply`로 클러스터에 적용해야 권한 생김**
- **여러 파일이 함께 작동해야 완전한 권한 부여**

## 🔍 확인 방법

### ServiceAccount 확인

```bash
# ServiceAccount 확인
kubectl get serviceaccount karpenter -n karpenter-system -o yaml

# 출력 예시:
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   annotations:
#     eks.amazonaws.com/role-arn: arn:aws:iam::123:role/karpenter-controller
```

### Pod가 사용하는 ServiceAccount 확인

```bash
# Pod 확인
kubectl get pod -n karpenter-system -o yaml | grep serviceAccount

# 또는
kubectl describe pod <pod-name> -n karpenter-system
# Service Account: karpenter  ← 여기서 확인
```

### 권한 확인

```bash
# ClusterRoleBinding 확인
kubectl get clusterrolebinding karpenter -o yaml

# ClusterRole 확인
kubectl get clusterrole karpenter -o yaml
```

## 💡 실무 팁

### 1. ServiceAccount는 네임스페이스별로 관리

```yaml
# karpenter-system 네임스페이스
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  namespace: karpenter-system  # ← 네임스페이스 지정
```

### 2. Pod는 같은 네임스페이스의 ServiceAccount만 사용 가능

```yaml
# Pod와 ServiceAccount는 같은 네임스페이스에 있어야 함
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: karpenter-system
spec:
  template:
    spec:
      serviceAccountName: karpenter  # 같은 네임스페이스의 ServiceAccount
```

### 3. 기본 ServiceAccount

ServiceAccount를 지정하지 않으면 `default` ServiceAccount를 사용합니다.

```yaml
# ServiceAccount 지정 안 함
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      # serviceAccountName 없음
      # → 자동으로 "default" ServiceAccount 사용
```

## 📚 참고 자료

- [Kubernetes ServiceAccount 문서](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [Kubernetes RBAC 문서](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [EKS IRSA 문서](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

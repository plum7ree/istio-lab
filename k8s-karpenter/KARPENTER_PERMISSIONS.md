# Karpenter 권한 구조 완전 이해하기

이 문서는 Karpenter가 어떻게 Pod를 모니터링하고 AWS에 EC2를 생성하는 권한을 얻는지 설명합니다.

## 🎯 핵심 질문

1. **Pod 모니터링 권한**: Kubernetes RBAC로 얻음
2. **AWS EC2 생성 권한**: IRSA (IAM Roles for Service Accounts)로 얻음

## 📊 전체 권한 구조

```
┌─────────────────────────────────────────────────────────┐
│              Karpenter Pod (컨테이너)                     │
│  karpenter-system/karpenter ServiceAccount 사용          │
└───────────────┬─────────────────────────────────────────┘
                │
        ┌───────┴────────┐
        │                │
┌───────▼──────┐  ┌──────▼────────┐
│ Kubernetes   │  │     AWS       │
│   RBAC       │  │     IRSA      │
│              │  │               │
│ ClusterRole  │  │ IAM Role      │
│ - Pod 읽기   │  │ - EC2 생성    │
│ - Node 읽기  │  │ - EC2 삭제    │
│ - Node 생성   │  │               │
└──────────────┘  └────────────────┘
```

## 1️⃣ Pod 모니터링 권한 (Kubernetes RBAC)

### Karpenter가 Pod를 모니터링하는 방법

Karpenter는 **Kubernetes API Server**에 직접 접근하여 Pod 상태를 모니터링합니다.

### 권한 획득 방법

**Helm 차트가 자동으로 생성합니다!**

Karpenter Helm 차트를 설치하면 자동으로 다음이 생성됩니다:

```yaml
# Helm 차트가 자동 생성 (우리 코드에는 없지만 Helm이 생성)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: karpenter
rules:
- apiGroups: [""]
  resources: ["pods", "nodes", "namespaces"]
  verbs: ["get", "list", "watch"]  # Pod 모니터링 권한
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["create", "delete"]  # 노드 생성/삭제 권한
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karpenter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: karpenter
subjects:
- kind: ServiceAccount
  name: karpenter
  namespace: karpenter-system
```

### 코드에서의 연결

```hcl
# main.tf - Karpenter Helm 설치
resource "helm_release" "karpenter" {
  # Helm 차트가 자동으로:
  # 1. ClusterRole 생성 (Pod 읽기 권한)
  # 2. ClusterRoleBinding 생성 (ServiceAccount에 권한 부여)
  # 3. ServiceAccount 생성
}
```

### 확인 방법

```bash
# ClusterRole 확인
kubectl get clusterrole karpenter -o yaml

# ClusterRoleBinding 확인
kubectl get clusterrolebinding karpenter -o yaml

# ServiceAccount 확인
kubectl get serviceaccount karpenter -n karpenter-system -o yaml
```

## 2️⃣ AWS EC2 생성 권한 (IRSA)

### IRSA란?

**IRSA (IAM Roles for Service Accounts)** = Kubernetes ServiceAccount가 AWS IAM Role을 사용할 수 있게 해주는 기능

### 권한 획득 과정

#### 1단계: IAM Role 생성

```hcl
# modules/iam/main.tf
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"
  
  # IRSA 설정: ServiceAccount가 이 Role을 사용할 수 있도록
  assume_role_policy = jsonencode({
    Principal = {
      Federated = var.cluster_oidc_provider_arn  # EKS OIDC Provider
    }
    Condition = {
      # 이 ServiceAccount만 사용 가능
      StringEquals = {
        "...:sub" = "system:serviceaccount:karpenter-system:karpenter"
      }
    }
  })
}
```

#### 2단계: IAM Policy (EC2 생성 권한)

```hcl
# modules/iam/main.tf
resource "aws_iam_role_policy" "karpenter_controller" {
  role = aws_iam_role.karpenter_controller.id
  
  policy = jsonencode({
    Statement = [{
      Action = [
        "ec2:RunInstances",      # ← EC2 생성 권한!
        "ec2:TerminateInstances", # ← EC2 삭제 권한!
        "ec2:DescribeInstances",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        # ... 기타 권한들
      ]
      Resource = "*"
    }]
  })
}
```

#### 3단계: ServiceAccount에 IAM Role 연결

```yaml
# templates/serviceaccount.yaml.tpl
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  namespace: karpenter-system
  annotations:
    # ← 이게 핵심! IAM Role ARN을 annotation으로 지정
    eks.amazonaws.com/role-arn: ${controller_role_arn}
```

#### 4단계: Pod가 IAM Role 사용

```
Karpenter Pod 실행
    ↓
ServiceAccount 사용 (karpenter-system/karpenter)
    ↓
EKS OIDC Provider가 확인
    ↓
IAM Role 임시 자격 증명 발급
    ↓
Pod가 AWS API 호출 가능 (EC2 생성 등)
```

### 코드에서의 연결

```hcl
# main.tf
resource "helm_release" "karpenter" {
  set {
    # ServiceAccount에 IAM Role ARN 지정
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_iam.karpenter_controller_role_arn
  }
}
```

## 🔄 전체 동작 흐름

### 1. Karpenter Pod 시작

```
Karpenter Pod 실행
    ↓
ServiceAccount: karpenter-system/karpenter 사용
    ↓
┌─────────────────────────────────────┐
│ 1. Kubernetes RBAC 권한 획득        │
│    - ClusterRoleBinding 통해        │
│    - Pod 읽기/모니터링 권한          │
│                                     │
│ 2. AWS IAM Role 권한 획득           │
│    - IRSA 통해                      │
│    - EC2 생성/삭제 권한              │
└─────────────────────────────────────┘
```

### 2. Pod 모니터링

```
Karpenter Controller
    ↓
Kubernetes API Server 접근
    ↓
RBAC 권한으로 Pod 목록 조회
    ↓
Pending 상태의 Pod 발견
```

### 3. EC2 생성

```
Karpenter Controller
    ↓
AWS STS (Security Token Service) 호출
    ↓
IRSA로 IAM Role 임시 자격 증명 획득
    ↓
AWS EC2 API 호출 (ec2:RunInstances)
    ↓
EC2 인스턴스 생성 완료
```

## 📋 권한 상세 분석

### Kubernetes RBAC 권한

```yaml
# Helm 차트가 자동 생성 (우리 코드에는 없음)
ClusterRole: karpenter
  - pods: [get, list, watch]      # Pod 모니터링
  - nodes: [get, list, watch, create, delete]  # 노드 관리
  - namespaces: [get, list]        # 네임스페이스 확인
```

### AWS IAM 권한

```json
{
  "Action": [
    "ec2:RunInstances",           // EC2 인스턴스 생성
    "ec2:TerminateInstances",     // EC2 인스턴스 삭제
    "ec2:DescribeInstances",      // 인스턴스 정보 조회
    "ec2:DescribeSubnets",       // 서브넷 정보 조회
    "ec2:DescribeSecurityGroups", // 보안 그룹 정보 조회
    "ec2:CreateLaunchTemplate",   // Launch Template 생성
    "ec2:CreateFleet",            // Fleet 생성
    "iam:PassRole"                // IAM Role 전달 (노드용)
  ]
}
```

## 🔍 확인 방법

### 1. Kubernetes RBAC 확인

```bash
# ClusterRole 확인
kubectl get clusterrole karpenter -o yaml

# ClusterRoleBinding 확인
kubectl get clusterrolebinding karpenter -o yaml

# ServiceAccount 확인
kubectl get serviceaccount karpenter -n karpenter-system -o yaml
```

### 2. AWS IAM 권한 확인

```bash
# IAM Role 확인
aws iam get-role --role-name <CLUSTER_NAME>-karpenter-controller

# IAM Policy 확인
aws iam get-role-policy \
  --role-name <CLUSTER_NAME>-karpenter-controller \
  --policy-name <CLUSTER_NAME>-karpenter-controller-policy
```

### 3. 실제 동작 확인

```bash
# Karpenter Pod에서 AWS 자격 증명 확인
kubectl exec -n karpenter-system <karpenter-pod> -- \
  aws sts get-caller-identity

# Karpenter 로그 확인 (권한 관련 에러 확인)
kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter
```

## 💡 핵심 정리

### Pod 모니터링 권한

- **방법**: Kubernetes RBAC (ClusterRole + ClusterRoleBinding)
- **생성**: Helm 차트가 자동 생성
- **권한**: Pod, Node, Namespace 읽기/쓰기

### AWS EC2 생성 권한

- **방법**: IRSA (IAM Roles for Service Accounts)
- **생성**: Terraform으로 IAM Role 생성
- **연결**: ServiceAccount annotation에 IAM Role ARN 지정
- **권한**: EC2 생성/삭제, 서브넷/보안그룹 조회 등

### 전체 흐름

```
1. Helm 차트 설치
   → ClusterRole/ClusterRoleBinding 자동 생성
   → ServiceAccount 생성

2. Terraform으로 IAM Role 생성
   → EC2 생성 권한 부여

3. ServiceAccount에 IAM Role 연결
   → annotation: eks.amazonaws.com/role-arn

4. Karpenter Pod 실행
   → Kubernetes RBAC 권한으로 Pod 모니터링
   → IRSA로 AWS IAM 권한으로 EC2 생성
```

## 🔐 보안 고려사항

### 1. 최소 권한 원칙

현재 설정은 `Resource = "*"`로 모든 리소스에 접근 가능합니다. 프로덕션에서는 특정 리소스로 제한하는 것이 좋습니다.

### 2. IRSA 조건

```hcl
# modules/iam/main.tf
Condition = {
  StringEquals = {
    # 특정 ServiceAccount만 사용 가능하도록 제한
    "...:sub" = "system:serviceaccount:karpenter-system:karpenter"
  }
}
```

이 조건으로 다른 Pod는 이 IAM Role을 사용할 수 없습니다.

## 📚 참고 자료

- [Kubernetes RBAC 문서](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [EKS IRSA 문서](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Karpenter 권한 설정](https://karpenter.sh/docs/getting-started/getting-started-with-eks/)
- [ServiceAccount 완전 이해하기](../SERVICEACCOUNT_EXPLAINED.md) ⭐ **ServiceAccount가 궁금하면 여기!**
- [Kubernetes 권한 검증 흐름](../KUBERNETES_AUTH_FLOW.md) ⭐ **내부 컴포넌트가 궁금하면 여기!**

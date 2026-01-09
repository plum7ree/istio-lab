# Terraform과 Kubernetes 통합 가이드

이 문서는 Terraform과 Kubernetes 리소스가 어떻게 통합되어 있는지 설명합니다.

## 🔗 통합 구조

### 전체 흐름

```
┌─────────────────────────────────────────────────────────┐
│                  ./deploy-all.sh                         │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼────────┐               ┌──────▼────────┐
│   Terraform    │               │  Kubernetes   │
│   (인프라)      │               │   (리소스)     │
└───────┬────────┘               └──────┬────────┘
        │                               │
        │ 1. VPC 생성                   │
        │ 2. EKS 클러스터 생성           │
        │ 3. IAM 역할 생성               │
        │ 4. SQS 큐 생성                 │
        │ 5. Karpenter Helm 설치         │
        │                               │
        └───────────────┬───────────────┘
                        │
                ┌───────▼────────┐
                │  kubectl_manifest │
                │  (템플릿 사용)    │
                └───────┬────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼────────┐               ┌──────▼────────┐
│  Namespace     │               │  ServiceAccount│
│  ConfigMap     │               │  NodePool      │
│  EC2NodeClass  │               │                │
└────────────────┘               └────────────────┘
```

## 📊 리소스 매핑

### Terraform → Kubernetes

| Terraform 리소스 | Kubernetes 리소스 | 통합 방법 |
|-----------------|------------------|----------|
| `module.vpc` | 서브넷 태그 | 태그로 연결 |
| `module.eks` | 클러스터 | 직접 생성 |
| `module.karpenter_iam` | ServiceAccount | IRSA annotation |
| `module.karpenter_sqs` | ConfigMap | 큐 이름 전달 |
| `helm_release.karpenter` | Karpenter Controller | Helm 설치 |
| `kubectl_manifest.*` | 모든 K8s 리소스 | 템플릿 사용 |

## 🔄 데이터 흐름

### 1. IAM 역할 → ServiceAccount

```hcl
# Terraform
module.karpenter_iam.karpenter_controller_role_arn
    ↓
# 템플릿
templates/serviceaccount.yaml.tpl
    ↓
# Kubernetes
ServiceAccount (IRSA annotation)
```

### 2. SQS 큐 → ConfigMap

```hcl
# Terraform
module.karpenter_sqs.queue_name
    ↓
# 템플릿
templates/karpenter-config.yaml.tpl
    ↓
# Kubernetes
ConfigMap (interruptionQueue)
```

### 3. 클러스터 이름 → 모든 리소스

```hcl
# Terraform
var.cluster_name
    ↓
# 템플릿
모든 템플릿 파일
    ↓
# Kubernetes
태그, 설정값 등
```

## 🎯 통합 포인트

### 1. 태그 기반 연결

Terraform이 생성한 리소스에 태그를 자동으로 추가:

```hcl
# VPC 서브넷 태그
private_subnet_tags = {
  "karpenter.sh/discovery" = var.cluster_name
}

# 보안 그룹 태그
tags = {
  "karpenter.sh/discovery" = var.cluster_name
}
```

Kubernetes 리소스에서 태그로 찾음:

```yaml
# EC2NodeClass
subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${cluster_name}
```

### 2. IRSA (IAM Roles for Service Accounts)

Terraform이 IAM 역할을 생성하고 Kubernetes ServiceAccount에 연결:

```hcl
# Terraform
module.karpenter_iam.karpenter_controller_role_arn
    ↓
# 템플릿
eks.amazonaws.com/role-arn: ${controller_role_arn}
    ↓
# Kubernetes
ServiceAccount annotation
```

### 3. Helm + kubectl_manifest

Helm으로 Karpenter를 설치하고, kubectl_manifest로 추가 리소스를 생성:

```hcl
# 1. Helm 설치
resource "helm_release" "karpenter" { ... }

# 2. Kubernetes 리소스 생성 (의존성)
resource "kubectl_manifest" "karpenter_nodepool" {
  depends_on = [helm_release.karpenter]
}
```

## 🔧 커스터마이징

### Terraform 변수 수정

변수를 수정하면 자동으로 Kubernetes 리소스에도 반영됩니다:

```hcl
# terraform.tfvars
instance_types = ["t3.medium", "t3.large"]
    ↓
# templates/nodepool.yaml.tpl
values:
  - t3.medium
  - t3.large
```

### 템플릿 수정

템플릿을 수정하면 다음 배포 시 자동으로 반영됩니다:

```bash
# 템플릿 수정
vim terraform/templates/nodepool.yaml.tpl

# 재배포
terraform apply
```

## 📝 배포 순서

Terraform은 다음 순서로 리소스를 생성합니다:

1. **인프라 리소스**
   - VPC, 서브넷
   - EKS 클러스터
   - IAM 역할
   - SQS 큐

2. **Karpenter 설치**
   - Helm release

3. **Kubernetes 리소스**
   - Namespace (Helm이 생성하지만 명시적으로 관리)
   - ServiceAccount (IRSA 설정)
   - ConfigMap
   - NodePool
   - EC2NodeClass

## ⚠️ 주의사항

### 1. 의존성 관리

Kubernetes 리소스는 Helm 설치 후에 생성됩니다:

```hcl
depends_on = [helm_release.karpenter]
```

### 2. 태그 일관성

모든 리소스에 동일한 태그를 사용해야 합니다:

```hcl
"karpenter.sh/discovery" = var.cluster_name
```

### 3. 리소스 이름

Terraform과 Kubernetes 리소스의 이름이 일치해야 합니다:

- NodePool: `default`
- EC2NodeClass: `default`
- Namespace: `karpenter-system`

## 🔍 문제 해결

### 리소스가 연결되지 않음

1. **태그 확인**
   ```bash
   aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=<CLUSTER_NAME>"
   ```

2. **IAM 역할 확인**
   ```bash
   terraform output karpenter_controller_role_arn
   kubectl get serviceaccount karpenter -n karpenter-system -o yaml
   ```

3. **Terraform 상태 확인**
   ```bash
   terraform state list
   terraform show
   ```

### Kubernetes 리소스가 생성되지 않음

1. **Helm 설치 확인**
   ```bash
   kubectl get pods -n karpenter-system
   ```

2. **템플릿 확인**
   ```bash
   terraform plan
   ```

3. **kubectl provider 확인**
   ```bash
   kubectl cluster-info
   ```

## 📚 참고 자료

- [Terraform 문서](terraform/README.md)
- [프로젝트 구조](PROJECT_STRUCTURE.md)
- [Karpenter 공식 문서](https://karpenter.sh/)

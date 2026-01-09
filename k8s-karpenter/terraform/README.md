# Karpenter Terraform 모듈

이 디렉토리에는 Terraform을 사용하여 Karpenter를 완전히 구동하는데 필요한 모든 리소스가 포함되어 있습니다.

## 📋 목차

- [개요](#개요)
- [구조](#구조)
- [사전 요구사항](#사전-요구사항)
- [빠른 시작](#빠른-시작)
- [모듈 설명](#모듈-설명)
- [변수 설명](#변수-설명)
- [출력값](#출력값)
- [기존 클러스터 사용](#기존-클러스터-사용)

---

## 개요

이 Terraform 모듈은 다음을 자동으로 생성합니다:

- ✅ **VPC 및 네트워킹** (서브넷, NAT Gateway, 보안 그룹)
- ✅ **EKS 클러스터** (관리형 노드 그룹 포함, 선택사항)
- ✅ **IAM 역할 및 정책** (Controller, Node)
- ✅ **SQS 큐** (Spot 인터럽션 처리)
- ✅ **EventBridge 규칙** (Spot 인터럽션 이벤트)
- ✅ **Karpenter Helm 설치**
- ✅ **NodePool 및 EC2NodeClass** (Kubernetes 리소스)
- ✅ **태그 설정** (Karpenter가 리소스를 찾기 위한)

---

## 구조

```
terraform/
├── main.tf                    # 메인 Terraform 설정
├── variables.tf               # 변수 정의
├── outputs.tf                # 출력값 정의
├── terraform.tfvars.example  # 변수 예시 파일
├── README.md                 # 이 파일
├── modules/
│   ├── iam/                  # IAM 역할 및 정책 모듈
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── sqs/                  # SQS 큐 모듈
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── templates/
    ├── nodepool.yaml.tpl     # NodePool 템플릿
    └── ec2nodeclass.yaml.tpl # EC2NodeClass 템플릿
```

---

## 사전 요구사항

### 필수 도구

- ✅ Terraform >= 1.0
- ✅ AWS CLI 설치 및 설정
- ✅ kubectl 설치
- ✅ Helm 3 설치 (선택사항, Helm provider 사용)

### AWS 권한

다음 AWS 권한이 필요합니다:

- VPC 생성 및 관리
- EKS 클러스터 생성 및 관리
- IAM 역할 및 정책 생성
- SQS 큐 생성 및 관리
- EventBridge 규칙 생성
- EC2 인스턴스 관리

### Terraform Provider

다음 Provider가 자동으로 설치됩니다:

- `hashicorp/aws` (~> 5.0)
- `hashicorp/kubernetes` (~> 2.23)
- `hashicorp/helm` (~> 2.11)
- `gavinbunney/kubectl` (~> 1.14)

---

## 빠른 시작

### 1단계: 변수 파일 생성

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 열어서 실제 값으로 수정:

```hcl
aws_region = "us-west-2"
cluster_name = "my-eks-cluster"
environment = "dev"
```

### 2단계: Terraform 초기화

```bash
terraform init
```

### 3단계: 계획 확인

```bash
terraform plan
```

### 4단계: 배포

```bash
terraform apply
```

배포가 완료되면 약 15-20분 정도 소요됩니다.

### 5단계: kubectl 설정

```bash
# 출력된 명령어 사용
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <REGION>

# 또는 Terraform 출력 사용
terraform output -raw kubectl_config_command | bash
```

### 6단계: 확인

```bash
# Karpenter Pod 확인
kubectl get pods -n karpenter-system

# NodePool 확인
kubectl get nodepool

# EC2NodeClass 확인
kubectl get ec2nodeclass
```

---

## 모듈 설명

### IAM 모듈 (`modules/iam/`)

Karpenter에 필요한 IAM 역할과 정책을 생성합니다:

- **Controller Role** (IRSA)
  - EC2 인스턴스 생성/삭제
  - Launch Template 관리
  - Spot 인터럽션 처리
  - SQS 메시지 읽기/삭제

- **Node Role**
  - EKS 클러스터 접근
  - CloudWatch 로그 전송
  - ECR 이미지 Pull
  - SSM 접근 (선택사항)

- **Instance Profile**
  - Node Role을 EC2 인스턴스에 연결

### SQS 모듈 (`modules/sqs/`)

Spot 인터럽션 처리를 위한 SQS 큐와 EventBridge 규칙을 생성합니다:

- **SQS 큐**: Spot 인터럽션 메시지 수신
- **EventBridge 규칙**: 
  - Spot Instance Interruption Warning
  - EC2 Instance Rebalance Recommendation

---

## 변수 설명

### 필수 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `cluster_name` | EKS 클러스터 이름 | - (필수) |
| `aws_region` | AWS 리전 | `us-west-2` |

### 선택 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `environment` | 환경 이름 | `dev` |
| `kubernetes_version` | Kubernetes 버전 | `1.28` |
| `vpc_cidr` | VPC CIDR | `10.0.0.0/16` |
| `karpenter_version` | Karpenter 버전 | `v0.37.0` |
| `instance_types` | 인스턴스 타입 리스트 | `["t3.medium", ...]` |
| `capacity_types` | 용량 타입 | `["spot", "on-demand"]` |
| `node_pool_cpu_limit` | NodePool CPU 제한 | `"1000"` |
| `node_pool_memory_limit` | NodePool 메모리 제한 | `"1000Gi"` |

전체 변수 목록은 `variables.tf`를 참고하세요.

---

## 출력값

배포 후 다음 출력값을 사용할 수 있습니다:

```bash
# 클러스터 이름
terraform output cluster_name

# 클러스터 엔드포인트
terraform output cluster_endpoint

# Karpenter Controller Role ARN
terraform output karpenter_controller_role_arn

# Karpenter Node Role ARN
terraform output karpenter_node_role_arn

# kubectl 설정 명령어
terraform output kubectl_config_command
```

전체 출력값 목록은 `outputs.tf`를 참고하세요.

---

## 기존 클러스터 사용

기존 EKS 클러스터가 있는 경우, VPC와 EKS 모듈을 제거하고 data source를 사용하세요.

### 예시: 기존 클러스터 사용

```hcl
# main.tf에서 VPC 및 EKS 모듈 제거하고 다음 추가:

data "aws_eks_cluster" "existing" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  name = var.cluster_name
}

data "aws_vpc" "existing" {
  id = var.existing_vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# 서브넷 태그 추가 (Karpenter가 찾기 위해)
resource "aws_ec2_tag" "subnet_karpenter" {
  for_each = toset(data.aws_subnets.private.ids)
  
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
```

---

## 비용 최적화 팁

1. **단일 NAT Gateway 사용**
   ```hcl
   single_nat_gateway = true
   ```

2. **Spot 인스턴스 우선 사용**
   ```hcl
   capacity_types = ["spot", "on-demand"]
   ```

3. **NodePool 제한 설정**
   ```hcl
   node_pool_cpu_limit = "500"
   node_pool_memory_limit = "500Gi"
   ```

4. **인스턴스 타입 범위 축소**
   ```hcl
   instance_types = ["t3.medium", "t3.large"]
   ```

---

## 트러블슈팅

### Terraform 적용 실패

1. **IAM 권한 확인**
   ```bash
   aws sts get-caller-identity
   ```

2. **Provider 버전 확인**
   ```bash
   terraform providers
   ```

3. **상태 파일 확인**
   ```bash
   terraform state list
   ```

### Karpenter가 노드를 생성하지 않음

1. **태그 확인**
   ```bash
   aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=<CLUSTER_NAME>"
   aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=<CLUSTER_NAME>"
   ```

2. **IAM 역할 확인**
   ```bash
   terraform output karpenter_controller_role_arn
   terraform output karpenter_node_role_arn
   ```

3. **Karpenter 로그 확인**
   ```bash
   kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter
   ```

---

## 삭제

전체 리소스 삭제:

```bash
terraform destroy
```

⚠️ **주의**: 이 명령은 모든 리소스를 삭제합니다. 백업이 필요한 데이터는 미리 확인하세요.

---

## 참고 자료

- [Karpenter 공식 문서](https://karpenter.sh/)
- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS 모듈 문서](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

---

## 다음 단계

배포가 완료되면:

1. 테스트 워크로드 배포: `kubectl apply -f ../examples/test-workload.yaml`
2. 노드 생성 확인: `kubectl get nodes -w`
3. 추가 NodePool 생성: `kubectl apply -f ../examples/nodepool-gpu.yaml`

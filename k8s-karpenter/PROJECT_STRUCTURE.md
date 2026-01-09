# 프로젝트 구조

이 문서는 Karpenter 프로젝트의 전체 구조와 각 파일의 역할을 설명합니다.

## 📁 디렉토리 구조

```
k8s-karpenter/
├── README.md                    # 메인 문서
├── QUICKSTART.md                # 빠른 시작 가이드
├── PROJECT_STRUCTURE.md         # 이 파일
│
├── deploy-all.sh                # 통합 배포 스크립트 (Terraform + Kubernetes)
├── destroy-all.sh               # 통합 삭제 스크립트
│
├── terraform/                    # Terraform 인프라 코드
│   ├── main.tf                  # 메인 Terraform 설정
│   ├── variables.tf             # 변수 정의
│   ├── outputs.tf                # 출력값 정의
│   ├── versions.tf               # Provider 버전
│   ├── terraform.tfvars.example  # 변수 예시
│   ├── Makefile                  # 편의 명령어
│   ├── README.md                 # Terraform 문서
│   ├── QUICKSTART.md             # Terraform 빠른 시작
│   │
│   ├── modules/                  # Terraform 모듈
│   │   ├── iam/                  # IAM 역할 및 정책
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── sqs/                  # SQS 큐 및 EventBridge
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── templates/                # Kubernetes 리소스 템플릿
│       ├── namespace.yaml.tpl
│       ├── serviceaccount.yaml.tpl
│       ├── karpenter-config.yaml.tpl
│       ├── profile-eks.yaml.tpl
│       ├── nodepool.yaml.tpl
│       └── ec2nodeclass.yaml.tpl
│
└── examples/                     # 예제 파일
    ├── README.md
    ├── test-workload.yaml        # 테스트 워크로드
    ├── nodepool-gpu.yaml         # GPU NodePool 예시
    ├── nodepool-arm.yaml          # ARM NodePool 예시
    └── nodepool-windows.yaml      # Windows NodePool 예시
```

## 🔄 배포 흐름

```
./deploy-all.sh
    ↓
1. Terraform 초기화 (terraform init)
    ↓
2. VPC, 서브넷, NAT Gateway 생성
    ↓
3. EKS 클러스터 생성
    ↓
4. IAM 역할 및 정책 생성
    ↓
5. Karpenter Helm 설치
    ↓
6. Karpenter Helm 설치
    ↓
7. Kubernetes 리소스 배포 (템플릿 사용)
   - Namespace
   - ServiceAccount (IRSA)
   - ConfigMap
   - NodePool
   - EC2NodeClass
    ↓
8. kubectl 자동 설정
    ↓
✅ 완료!
```

## 📋 파일 역할

### 통합 스크립트

| 파일 | 역할 |
|------|------|
| `deploy-all.sh` | 전체 통합 배포 (Terraform + Kubernetes) |
| `destroy-all.sh` | 전체 통합 삭제 |

### Terraform 파일

| 파일 | 역할 |
|------|------|
| `terraform/main.tf` | 메인 Terraform 설정 (VPC, EKS, Karpenter) |
| `terraform/variables.tf` | 변수 정의 |
| `terraform/outputs.tf` | 출력값 정의 |
| `terraform/modules/iam/` | IAM 역할 및 정책 모듈 |
| `terraform/modules/sqs/` | SQS 큐 및 EventBridge 모듈 |
| `terraform/templates/*.tpl` | Kubernetes 리소스 템플릿 |

### Kubernetes 리소스

모든 Kubernetes 리소스는 Terraform 템플릿으로 관리됩니다:

| Terraform 템플릿 | Kubernetes 리소스 |
|-----------------|------------------|
| `templates/namespace.yaml.tpl` | Namespace |
| `templates/serviceaccount.yaml.tpl` | ServiceAccount (IRSA) |
| `templates/karpenter-config.yaml.tpl` | ConfigMap |
| `templates/nodepool.yaml.tpl` | NodePool |
| `templates/ec2nodeclass.yaml.tpl` | EC2NodeClass |
| `templates/profile-eks.yaml.tpl` | EKS 프로파일 ConfigMap |

## 🔗 통합 관계

### Terraform → Kubernetes 리소스

Terraform은 다음 순서로 리소스를 생성합니다:

1. **인프라 리소스** (VPC, EKS, IAM, SQS)
2. **Karpenter Helm 설치**
3. **Kubernetes 리소스** (템플릿 사용)
   - Namespace
   - ServiceAccount (IRSA annotation 자동 설정)
   - ConfigMap (Terraform 출력값 사용)
   - NodePool (Terraform 변수 사용)
   - EC2NodeClass (Terraform 출력값 사용)

### 데이터 흐름

```
Terraform 변수
    ↓
Terraform 모듈 (IAM, SQS)
    ↓
Terraform 출력값
    ↓
템플릿 파일 (*.tpl)
    ↓
Kubernetes 리소스 (kubectl_manifest)
    ↓
Kubernetes 클러스터
```

## 🎯 사용 시나리오

### 시나리오 1: 통합 배포 (권장)

```bash
# Terraform으로 모든 것을 생성
./deploy-all.sh
```

### 시나리오 2: Terraform 직접 사용

```bash
cd terraform
terraform init
terraform apply
```

## 🔧 커스터마이징

### Terraform 변수 수정

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 수정
```

### Kubernetes 리소스 수정

`terraform/templates/*.tpl` 파일을 수정한 후 `terraform apply`를 실행하면 변경사항이 반영됩니다.

### 추가 NodePool 생성

```bash
# 예제 사용
kubectl apply -f examples/nodepool-gpu.yaml
```

## 📚 참고 문서

- [메인 README](README.md)
- [Terraform README](terraform/README.md)
- [빠른 시작 가이드](QUICKSTART.md)
- [예제 README](examples/README.md)

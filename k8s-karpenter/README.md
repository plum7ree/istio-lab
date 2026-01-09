# Karpenter - 노드 자동 프로비저닝 (완전 통합 프로젝트)

이 프로젝트는 **Karpenter**를 사용한 Kubernetes 노드 자동 프로비저닝 설정을 제공합니다. **Terraform과 Kubernetes 리소스가 완전히 통합**되어 있어 하나의 명령으로 전체 인프라를 배포할 수 있습니다.

## 🎯 프로젝트 특징

- ✅ **완전 통합**: Terraform이 모든 인프라와 Kubernetes 리소스를 관리
- ✅ **원클릭 배포**: `./deploy-all.sh terraform` 하나로 전체 배포
- ✅ **프로파일 기반**: 로컬/수동/Terraform 모드 지원
- ✅ **자동화**: VPC, EKS, IAM, SQS, Karpenter까지 모두 자동 생성
- ✅ **일관성**: Terraform 변수가 자동으로 Kubernetes 리소스에 반영

## 📋 목차

- [개요](#개요)
- [Karpenter 완전 이해하기](#karpenter-완전-이해하기) ⭐ **추천**
- [Karpenter 권한 구조](#karpenter-권한-구조) 🔐 **권한 궁금하면 여기!**
- [프로젝트 구조](#프로젝트-구조)
- [빠른 시작](#빠른-시작)
- [아키텍처](#아키텍처)
- [사전 요구사항](#사전-요구사항)
- [설정 가이드](#설정-가이드)
- [트러블슈팅](#트러블슈팅)

---

## 개요

### Karpenter란?

**Karpenter**는 Kubernetes 클러스터의 노드를 자동으로 프로비저닝하고 최적화하는 오픈소스 프로젝트입니다. AWS EKS에서 EC2 인스턴스를 동적으로 생성/삭제하여 워크로드 요구사항에 맞게 클러스터를 자동으로 확장/축소합니다.

### 주요 특징

- ⚡ **빠른 노드 프로비저닝**: 초 단위로 노드 생성
- 💰 **비용 최적화**: Spot 인스턴스 자동 활용
- 🎯 **워크로드 기반 스케줄링**: Pod 요구사항에 맞는 노드 선택
- 🔄 **자동 통합**: 사용하지 않는 노드 자동 제거
- 📊 **다양한 인스턴스 타입**: 최적의 인스턴스 자동 선택

---

## Karpenter 완전 이해하기

**Karpenter가 무엇을 하는지, NodePool이 무엇인지 궁금하신가요?**

👉 **[KARPENTER_EXPLAINED.md](KARPENTER_EXPLAINED.md)** 문서를 읽어보세요!

간단 요약:
- **Karpenter** = Kubernetes 클러스터에 노드(EC2)를 자동으로 생성/삭제하는 컨트롤러
- **NodePool** = "어떤 노드를 만들지" 정의하는 템플릿
- **동작**: Pod가 Pending 상태 → Karpenter 감지 → 노드 자동 생성 → Pod 스케줄링

## Karpenter 권한 구조

**Karpenter가 Pod를 모니터링하고 AWS에 EC2를 생성하는 권한을 어떻게 얻는지 궁금하신가요?**

👉 **[KARPENTER_PERMISSIONS.md](KARPENTER_PERMISSIONS.md)** 문서를 읽어보세요!

**ServiceAccount가 무엇인지, 어떻게 Pod에 권한을 부여하는지 궁금하신가요?**

👉 **[SERVICEACCOUNT_EXPLAINED.md](SERVICEACCOUNT_EXPLAINED.md)** 문서를 읽어보세요!

간단 요약:
- **Pod 모니터링 권한**: Kubernetes RBAC (ClusterRole) - Helm 차트가 자동 생성
- **AWS EC2 생성 권한**: IRSA (IAM Roles for Service Accounts) - Terraform으로 설정
- **연결**: ServiceAccount annotation에 IAM Role ARN 지정 → Pod가 자동으로 AWS 권한 획득
- **ServiceAccount**: Pod의 "신원" - ClusterRoleBinding이 ServiceAccount에 권한 부여 → Pod가 ServiceAccount 사용

**Kubernetes 내부에서 권한 검증이 어떻게 이루어지는지 궁금하신가요?**

👉 **[KUBERNETES_AUTH_FLOW.md](KUBERNETES_AUTH_FLOW.md)** 문서를 읽어보세요!

**Kubernetes 클러스터의 구성 요소와 컴포넌트들이 궁금하신가요?**

👉 **[KUBERNETES_CLUSTER_COMPONENTS.md](KUBERNETES_CLUSTER_COMPONENTS.md)** 문서를 읽어보세요!

간단 요약:
- **API Server**: 모든 요청의 중앙 게이트웨이, 권한 검증 수행
- **RBAC Authorizer**: ClusterRole/ClusterRoleBinding 확인하여 권한 검증
- **ServiceAccount Controller**: ServiceAccount Token 생성/관리
- **Kubernetes API**: Control Plane에 위치, 클러스터 생성 시 자동 구성
- **주요 컴포넌트**: API Server, etcd, Controller Manager, Scheduler, kubelet, kube-proxy

---

## 프로젝트 구조

이 프로젝트는 **Terraform과 Kubernetes 리소스가 완전히 통합**되어 있습니다.

### 통합 구조

```
Terraform (인프라)
    ↓
VPC, EKS, IAM, SQS 생성
    ↓
Karpenter Helm 설치
    ↓
Kubernetes 리소스 배포 (템플릿 사용)
    ↓
완전한 Karpenter 환경
```

### 주요 파일

- `deploy-all.sh` - **통합 배포 스크립트** (Terraform + Kubernetes)
- `terraform/` - Terraform 인프라 코드
- `terraform/templates/` - Kubernetes 리소스 템플릿
- `examples/` - 예제 워크로드 및 NodePool

자세한 구조는 [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)를 참고하세요.

---

## 빠른 시작

### 🚀 통합 배포 (권장)

**하나의 명령으로 전체 인프라를 배포합니다!**

```bash
# 1. Terraform 변수 파일 생성
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일을 열어서 cluster_name, aws_region 등 수정
cd ..

# 2. 통합 배포 실행
./deploy-all.sh
```

이 명령은 다음을 자동으로 수행합니다:
- ✅ VPC, 서브넷, NAT Gateway 생성
- ✅ EKS 클러스터 생성
- ✅ IAM 역할 및 정책 생성
- ✅ Karpenter Helm 설치
- ✅ Karpenter NodePool 및 EC2NodeClass 배포
- ✅ 웹앱 배포 (선택사항, `deploy_webapp = true`일 때)
- ✅ kubectl 자동 설정

### 🔧 Terraform 직접 사용

Terraform을 직접 사용하려면:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

자세한 내용은 [terraform/README.md](terraform/README.md)를 참고하세요.

## 📱 웹앱 배포

### Terraform으로 자동 배포 (권장)

`terraform.tfvars`에서 `deploy_webapp = true`로 설정하면 웹앱이 자동으로 배포됩니다:

```bash
# terraform.tfvars
deploy_webapp = true

# 배포
./deploy-all.sh
```

이렇게 하면:
- ✅ EKS 클러스터 생성
- ✅ Karpenter 설치
- ✅ 웹앱 자동 배포 (Namespace, Deployment, Service)

### kubectl로 수동 배포

Terraform으로 인프라만 생성하고 웹앱은 수동으로 배포할 수도 있습니다:

```bash
# 1. 인프라만 생성
cd terraform
terraform apply

# 2. 웹앱 수동 배포
kubectl apply -f examples/webapp.yaml
```

자세한 내용은 [WEBAPP_DEPLOYMENT.md](WEBAPP_DEPLOYMENT.md)를 참고하세요.

---

## 아키텍처

### 전체 구조

```
                ┌──────────────┐
                │ Application  │
                │   (Pods)     │
                └───────┬──────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼────────┐               ┌──────▼────────┐
│ Local Cluster  │               │     EKS       │
│ (kind/minikube│               │               │
│  static nodes)│               │  Karpenter    │
│               │               │               │
│ ❌ Karpenter  │               │ ✅ Karpenter  │
│   사용 불가     │               │   자동 노드    │
└────────────────┘               └────────────────┘
```

### Karpenter 동작 흐름

```
1. Pod가 스케줄링 대기 상태
   ↓
2. Karpenter가 Pod 요구사항 분석
   (CPU, Memory, GPU, 특수 요구사항)
   ↓
3. 최적의 EC2 인스턴스 타입 선택
   (Spot 우선, 비용 최적화)
   ↓
4. 노드 프로비저닝 (초 단위)
   ↓
5. Pod 스케줄링 완료
   ↓
6. 워크로드 완료 후 노드 자동 제거
```

---

## 사전 요구사항

### 필수 도구

- ✅ Terraform >= 1.0
- ✅ AWS CLI 설치 및 설정
- ✅ kubectl 설치
- ✅ Helm 3 설치 (선택사항)

### AWS 권한

다음 AWS 권한이 필요합니다:

- VPC 생성 및 관리
- EKS 클러스터 생성 및 관리
- IAM 역할 및 정책 생성
- SQS 큐 생성 및 관리
- EventBridge 규칙 생성
- EC2 인스턴스 관리

---

## 설정 가이드

### Terraform 변수 설정

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

주요 변수:

```hcl
aws_region = "us-west-2"
cluster_name = "my-eks-cluster"
environment = "dev"

# 인스턴스 타입
instance_types = ["t3.medium", "t3.large", "t3.xlarge"]

# 용량 타입
capacity_types = ["spot", "on-demand"]
```

### NodePool 커스터마이징

Terraform 변수를 수정하면 자동으로 NodePool에 반영됩니다:

```hcl
# terraform.tfvars
node_pool_cpu_limit = "500"
node_pool_memory_limit = "500Gi"
```

### 추가 NodePool 생성

```bash
# 예제 사용
kubectl apply -f examples/nodepool-gpu.yaml
```

---

## 트러블슈팅

### 노드가 생성되지 않아요

1. **태그 확인**
   ```bash
   aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=<CLUSTER_NAME>"
   ```

2. **IAM 역할 확인**
   ```bash
   terraform output karpenter_controller_role_arn
   kubectl get serviceaccount karpenter -n karpenter-system -o yaml
   ```

3. **Karpenter 로그 확인**
   ```bash
   kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter
   ```

### Terraform 적용 실패

1. **상태 확인**
   ```bash
   terraform state list
   terraform show
   ```

2. **Provider 확인**
   ```bash
   terraform providers
   ```

---

## 삭제

### 전체 삭제

```bash
./destroy-all.sh terraform
```

⚠️ **주의**: 이 명령은 모든 리소스를 삭제합니다.

---

## 참고 자료

- [프로젝트 구조](PROJECT_STRUCTURE.md) - 상세한 파일 구조 설명
- [통합 가이드](INTEGRATION.md) - Terraform과 Kubernetes 통합 방법
- [Terraform 문서](terraform/README.md) - Terraform 상세 가이드
- [빠른 시작](QUICKSTART.md) - 빠른 시작 가이드
- [Karpenter 공식 문서](https://karpenter.sh/)

---

## 핵심 요약

### ✅ 가능한 것

- 프로파일로 앱과 설정 분기 (로컬 + EKS)
- EKS에서 Karpenter로 노드 자동 프로비저닝
- HPA와 함께 완전한 자동 스케일링
- **Terraform으로 모든 인프라 자동 생성**

### ❌ 불가능한 것

- 로컬 환경에서 Karpenter 사용 (의미 없음)
- AWS 외 클라우드에서 Karpenter 사용 (AWS 전용)

### 💡 실무 전략

> **"앱은 공통, 인프라는 환경별"**

- 애플리케이션과 Kubernetes 리소스는 공통
- 노드 자동화는 환경별로 분기
- 로컬: 정적 노드
- EKS: Karpenter (Terraform으로 자동 생성)

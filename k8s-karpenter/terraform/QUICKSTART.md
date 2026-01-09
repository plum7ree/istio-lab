# Terraform 빠른 시작 가이드

이 가이드는 Terraform을 사용하여 Karpenter를 빠르게 배포하는 방법을 설명합니다.

## 🚀 5분 빠른 시작

### 1단계: 사전 요구사항 확인

```bash
# Terraform 설치 확인
terraform version

# AWS CLI 설정 확인
aws sts get-caller-identity

# kubectl 설치 확인
kubectl version --client
```

### 2단계: 변수 파일 생성

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 열어서 최소한 다음 값들을 수정:

```hcl
aws_region = "us-west-2"
cluster_name = "my-eks-cluster"
environment = "dev"
```

### 3단계: Terraform 초기화

```bash
terraform init
```

이 명령은 필요한 Provider를 다운로드합니다 (약 1-2분 소요).

### 4단계: 배포 계획 확인

```bash
terraform plan
```

생성될 리소스를 확인합니다. 문제가 없으면 다음 단계로 진행.

### 5단계: 배포 실행

```bash
terraform apply
```

확인 메시지에 `yes`를 입력하면 배포가 시작됩니다.

**배포 시간**: 약 15-20분 소요

### 6단계: kubectl 설정

```bash
# Terraform 출력 사용
terraform output -raw kubectl_config_command | bash

# 또는 직접 실행
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <REGION>
```

### 7단계: 확인

```bash
# Karpenter Pod 확인
kubectl get pods -n karpenter-system

# NodePool 확인
kubectl get nodepool

# EC2NodeClass 확인
kubectl get ec2nodeclass
```

### 8단계: 테스트

```bash
# 테스트 워크로드 배포
kubectl apply -f ../examples/test-workload.yaml

# 노드 생성 확인
kubectl get nodes -w
```

## 📝 Makefile 사용 (선택사항)

```bash
# 초기화
make init

# 계획 확인
make plan

# 적용
make apply

# 삭제
make destroy

# 검증
make validate

# 포맷팅
make fmt
```

## ⚠️ 주의사항

1. **비용**: EKS 클러스터와 NAT Gateway는 비용이 발생합니다
2. **리전**: `aws_region` 변수를 실제 사용할 리전으로 설정하세요
3. **클러스터 이름**: 고유한 이름을 사용하세요
4. **삭제**: `terraform destroy`는 모든 리소스를 삭제합니다

## 🔧 문제 해결

### Terraform 초기화 실패

```bash
# Provider 캐시 삭제 후 재시도
rm -rf .terraform
terraform init
```

### 배포 실패

```bash
# 상태 확인
terraform state list

# 특정 리소스 재생성
terraform apply -replace=<RESOURCE_ADDRESS>
```

### kubectl 연결 실패

```bash
# AWS 자격 증명 확인
aws sts get-caller-identity

# 클러스터 상태 확인
aws eks describe-cluster --name <CLUSTER_NAME>
```

## 📚 다음 단계

- [상세 문서](README.md) 참고
- [Karpenter 설정 가이드](../README.md) 참고
- [예제 워크로드](../examples/) 테스트

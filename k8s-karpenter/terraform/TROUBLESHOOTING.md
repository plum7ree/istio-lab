# Terraform 트러블슈팅 가이드

이 문서는 Terraform 사용 중 발생하는 일반적인 문제와 해결 방법을 설명합니다.

## 🔧 Provider 플러그인 로드 실패

### 증상

```
Error: Failed to load plugin schemas
Error while loading schemas for plugin components: Failed to obtain provider schema: Could
not load the schema for provider registry.terraform.io/hashicorp/aws: failed to instantiate
provider "registry.terraform.io/hashicorp/aws" to obtain schema: timeout while waiting for
plugin to start..
```

### 해결 방법

#### 1. Terraform 캐시 정리

```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### 2. 네트워크 확인

```bash
# Terraform Registry 접근 확인
curl -I https://registry.terraform.io

# AWS Provider 다운로드 확인
curl -I https://registry.terraform.io/v1/providers/hashicorp/aws/versions
```

#### 3. Provider 버전 확인

`main.tf`에서 Provider 버전이 올바른지 확인:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # 버전 확인
    }
  }
}
```

#### 4. 수동 Provider 다운로드

```bash
# Provider 캐시 디렉토리 확인
ls -la ~/.terraform.d/plugins/

# Provider 수동 다운로드
terraform providers mirror ~/.terraform.d/plugins/
```

#### 5. Terraform 버전 확인

```bash
terraform version
# Terraform >= 1.0 필요
```

## 🔧 기타 일반적인 문제

### 문제: Module 다운로드 실패

```bash
# 해결: 모듈 캐시 정리
rm -rf .terraform/modules
terraform init
```

### 문제: IAM 권한 부족

```bash
# AWS 자격 증명 확인
aws sts get-caller-identity

# 필요한 권한 확인
# - VPC 생성/관리
# - EKS 클러스터 생성/관리
# - IAM 역할 생성
# - EC2 인스턴스 관리
```

### 문제: kubectl 연결 실패

```bash
# kubectl 설정 확인
kubectl cluster-info

# EKS 클러스터 연결
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <REGION>
```

### 문제: Helm Provider 오류

```bash
# Helm 설치 확인
helm version

# Helm 저장소 확인
helm repo list
```

## 🔍 디버깅 팁

### Terraform 로그 활성화

```bash
export TF_LOG=DEBUG
terraform init
terraform plan
```

### Provider 상태 확인

```bash
terraform providers
```

### 상태 파일 확인

```bash
terraform state list
terraform show
```

## 📚 참고 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform 트러블슈팅](https://www.terraform.io/docs/cli/commands/debug.html)

.PHONY: init plan apply destroy validate fmt

# Terraform 초기화
init:
	terraform init

# 계획 확인
plan:
	terraform plan

# 적용
apply:
	terraform apply

# 자동 승인 적용 (주의: 프로덕션에서는 사용하지 마세요)
apply-auto:
	terraform apply -auto-approve

# 삭제
destroy:
	terraform destroy

# 자동 승인 삭제 (주의)
destroy-auto:
	terraform destroy -auto-approve

# 검증
validate:
	terraform validate

# 포맷팅
fmt:
	terraform fmt -recursive

# 상태 확인
state:
	terraform state list

# 출력 확인
output:
	terraform output

# 클린업 (상태 파일 제외)
clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl

# 전체 클린업 (주의: 상태 파일도 삭제)
clean-all: clean
	rm -f terraform.tfstate terraform.tfstate.backup

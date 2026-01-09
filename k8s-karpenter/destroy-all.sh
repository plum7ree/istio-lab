#!/bin/bash

set -e

# 통합 삭제 스크립트
# Terraform으로 생성된 모든 리소스를 삭제합니다

TERRAFORM_DIR="terraform"

echo "🗑️  Karpenter 통합 삭제 시작..."
echo ""

# 색상 정의
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 확인 메시지
echo -e "${YELLOW}⚠️  경고: 이 작업은 모든 리소스를 삭제합니다.${NC}"
echo -e "${YELLOW}   EKS 클러스터, VPC, IAM 역할 등 모든 인프라가 삭제됩니다.${NC}"
echo ""
read -p "정말 삭제하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "취소되었습니다."
    exit 0
fi

echo -e "${BLUE}🗑️  Terraform 삭제 중...${NC}"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}❌ terraform 디렉토리를 찾을 수 없습니다.${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

echo -e "${BLUE}1️⃣  Kubernetes 리소스 삭제 중...${NC}"
# Kubernetes 리소스는 Terraform이 자동으로 삭제하지만, 
# Helm release를 먼저 삭제하는 것이 좋습니다
kubectl delete nodepool --all --ignore-not-found=true || true
kubectl delete ec2nodeclass --all --ignore-not-found=true || true

echo ""
echo -e "${BLUE}2️⃣  Terraform destroy 실행 중...${NC}"
terraform destroy -auto-approve

cd ..

echo ""
echo -e "${BLUE}✅ Terraform 삭제 완료!${NC}"

echo ""
echo -e "${BLUE}✅ 삭제 완료!${NC}"

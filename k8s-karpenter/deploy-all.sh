#!/bin/bash

set -e

# 통합 배포 스크립트
# Terraform으로 인프라를 생성하고 Kubernetes 리소스를 배포합니다

TERRAFORM_DIR="terraform"

echo "🚀 Karpenter 통합 배포 시작..."
echo ""

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 Terraform을 사용한 전체 배포${NC}"
echo ""
    
    # Terraform 디렉토리 확인
    if [ ! -d "$TERRAFORM_DIR" ]; then
        echo -e "${RED}❌ terraform 디렉토리를 찾을 수 없습니다.${NC}"
        exit 1
    fi
    
    # terraform.tfvars 확인
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        echo -e "${YELLOW}⚠️  terraform.tfvars 파일이 없습니다.${NC}"
        echo -e "${YELLOW}   terraform.tfvars.example을 복사하여 생성하세요.${NC}"
        read -p "계속하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    cd "$TERRAFORM_DIR"
    
    echo -e "${BLUE}1️⃣  Terraform 초기화 중...${NC}"
    terraform init
    
    echo ""
    echo -e "${BLUE}2️⃣  배포 계획 확인 중...${NC}"
    terraform plan
    
    echo ""
    read -p "배포를 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "취소되었습니다."
        exit 0
    fi
    
    echo ""
    echo -e "${BLUE}3️⃣  Terraform 적용 중...${NC}"
    terraform apply -auto-approve
    
    echo ""
    echo -e "${BLUE}4️⃣  kubectl 설정 중...${NC}"
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || grep -E '^aws_region' terraform.tfvars | cut -d'"' -f2 || echo "us-west-2")
    
    if [ -n "$CLUSTER_NAME" ]; then
        aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" || true
    else
        echo -e "${YELLOW}⚠️  클러스터 이름을 자동으로 가져올 수 없습니다. 수동으로 설정하세요.${NC}"
    fi
    
    cd ..
    
    echo ""
    echo -e "${GREEN}✅ Terraform 배포 완료!${NC}"
    echo ""
    echo -e "${BLUE}📊 배포 상태 확인:${NC}"
    echo ""
    kubectl get pods -n karpenter-system || true
    kubectl get nodepool || true
    kubectl get ec2nodeclass || true

echo ""
echo -e "${GREEN}✅ 배포 완료!${NC}"
echo ""
echo -e "${BLUE}💡 다음 단계:${NC}"
echo "   1. 테스트 워크로드 배포: kubectl apply -f examples/test-workload.yaml"
echo "   2. 노드 생성 확인: kubectl get nodes -w"
echo "   3. Karpenter 로그 확인: kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter"

#!/bin/bash

set -e

echo "🗑️  Kubernetes AWS 대체 프로젝트 삭제 시작..."

# 색상 정의
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}📊 Monitoring 삭제 중...${NC}"
kubectl delete -f monitoring/ --ignore-not-found=true

echo -e "${RED}⏰ CronJob 삭제 중...${NC}"
kubectl delete -f cronjob/ --ignore-not-found=true

echo -e "${RED}⚡ Knative 삭제 중...${NC}"
kubectl delete -f knative/ --ignore-not-found=true

echo -e "${RED}🔐 Cert-Manager 삭제 중...${NC}"
kubectl delete -f cert-manager/ --ignore-not-found=true

echo -e "${RED}🌍 Ingress 삭제 중...${NC}"
kubectl delete -f ingress/ --ignore-not-found=true

echo -e "${RED}🌐 Gateway 삭제 중...${NC}"
kubectl delete -f gateway/ --ignore-not-found=true

echo -e "${RED}🗄️  StatefulSet 삭제 중...${NC}"
kubectl delete -f statefulset/ --ignore-not-found=true

echo -e "${RED}🔒 NetworkPolicy 삭제 중...${NC}"
kubectl delete -f security-policies/ --ignore-not-found=true

echo -e "${RED}📈 HPA 삭제 중...${NC}"
kubectl delete -f hpa/ --ignore-not-found=true

echo -e "${RED}🔧 서비스 삭제 중...${NC}"
kubectl delete -f backend2/ --ignore-not-found=true
kubectl delete -f backend/ --ignore-not-found=true
kubectl delete -f frontend/ --ignore-not-found=true

echo -e "${RED}💾 Storage 삭제 중...${NC}"
kubectl delete -f storage/ --ignore-not-found=true

echo -e "${RED}📊 Resource Quotas 삭제 중...${NC}"
kubectl delete -f quotas/ --ignore-not-found=true

echo -e "${RED}📦 공통 리소스 삭제 중...${NC}"
kubectl delete -f shared/ --ignore-not-found=true

echo ""
echo "✅ 삭제 완료!"

#!/bin/bash

set -e

echo "🚀 Kubernetes AWS 대체 프로젝트 전체 배포 시작..."
echo ""

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 1. 공통 리소스 배포 중...${NC}"
kubectl apply -f shared/

echo -e "${BLUE}📊 2. Resource Quotas 배포 중...${NC}"
kubectl apply -f quotas/ || echo -e "${YELLOW}⚠️  Resource Quotas 배포 실패 (선택사항)${NC}"

echo -e "${BLUE}💾 3. Storage 설정 배포 중...${NC}"
kubectl apply -f storage/ || echo -e "${YELLOW}⚠️  Storage 배포 실패 (선택사항)${NC}"

echo -e "${BLUE}🔧 4. Frontend 서비스 배포 중...${NC}"
kubectl apply -f frontend/

echo -e "${BLUE}🔧 5. Backend 서비스 배포 중...${NC}"
kubectl apply -f backend/

echo -e "${BLUE}🔧 6. Backend2 서비스 배포 중...${NC}"
kubectl apply -f backend2/

echo -e "${BLUE}📈 7. HPA (Auto Scaling) 배포 중...${NC}"
kubectl apply -f hpa/ || echo -e "${YELLOW}⚠️  HPA 배포 실패 (Metrics Server 필요)${NC}"

echo -e "${BLUE}🔒 8. NetworkPolicy 배포 중...${NC}"
kubectl apply -f security-policies/ || echo -e "${YELLOW}⚠️  NetworkPolicy 배포 실패 (CNI 플러그인 필요)${NC}"

echo -e "${BLUE}🗄️  9. StatefulSet (Database) 배포 중...${NC}"
kubectl apply -f statefulset/ || echo -e "${YELLOW}⚠️  StatefulSet 배포 실패 (선택사항)${NC}"

echo -e "${BLUE}🌐 10. Gateway 배포 중...${NC}"
kubectl apply -f gateway/

echo -e "${BLUE}🌍 11. Ingress 배포 중...${NC}"
kubectl apply -f ingress/ || echo -e "${YELLOW}⚠️  Ingress 배포 실패 (Ingress Controller 필요)${NC}"

echo -e "${BLUE}🔐 12. Cert-Manager 설정 배포 중...${NC}"
kubectl apply -f cert-manager/ || echo -e "${YELLOW}⚠️  Cert-Manager 배포 실패 (Cert-Manager 설치 필요)${NC}"

echo -e "${BLUE}⚡ 13. Knative 서버리스 배포 중...${NC}"
kubectl apply -f knative/ || echo -e "${YELLOW}⚠️  Knative 배포 실패 (Knative 설치 필요)${NC}"

echo -e "${BLUE}⏰ 14. CronJob 배포 중...${NC}"
kubectl apply -f cronjob/

echo -e "${BLUE}📊 15. Monitoring 설정 배포 중...${NC}"
kubectl apply -f monitoring/ || echo -e "${YELLOW}⚠️  Monitoring 배포 실패 (Prometheus Operator 필요)${NC}"

echo ""
echo -e "${GREEN}✅ 배포 완료!${NC}"
echo ""

echo -e "${BLUE}⏳ Pod들이 준비될 때까지 대기 중...${NC}"
kubectl wait --for=condition=ready pod -l app=frontend -n microservices-demo --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=backend -n microservices-demo --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=backend2 -n microservices-demo --timeout=60s || true

echo ""
echo -e "${GREEN}📊 배포 상태 확인:${NC}"
echo ""
echo "=== Pods ==="
kubectl get pods -n microservices-demo
echo ""
echo "=== Services ==="
kubectl get services -n microservices-demo
echo ""
echo "=== Gateway & VirtualService ==="
kubectl get gateway,virtualservice -n microservices-demo || true
echo ""
echo "=== HPA ==="
kubectl get hpa -n microservices-demo || true
echo ""
echo "=== StatefulSets ==="
kubectl get statefulset -n microservices-demo || true
echo ""
echo "=== CronJobs ==="
kubectl get cronjob -n microservices-demo || true

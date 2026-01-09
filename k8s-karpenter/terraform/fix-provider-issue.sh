#!/bin/bash

# Terraform Provider 플러그인 로드 문제 해결 스크립트

set -e

echo "🔧 Terraform Provider 문제 해결 중..."
echo ""

cd "$(dirname "$0")"

# 1. 완전 정리
echo "1️⃣  Terraform 캐시 정리 중..."
rm -rf .terraform .terraform.lock.hcl
echo "✅ 캐시 정리 완료"
echo ""

# 2. Provider 플러그인 디렉토리 정리
echo "2️⃣  Provider 플러그인 정리 중..."
rm -rf .terraform/providers
echo "✅ Provider 플러그인 정리 완료"
echo ""

# 3. Terraform 버전 확인
echo "3️⃣  Terraform 버전 확인:"
terraform version
echo ""

# 4. 재초기화
echo "4️⃣  Terraform 재초기화 중..."
echo "   (이 과정은 몇 분 걸릴 수 있습니다)"
echo ""

terraform init -upgrade

echo ""
echo "✅ 완료!"
echo ""
echo "이제 다음 명령을 실행하세요:"
echo "  terraform plan"
echo "  또는"
echo "  ./deploy-all.sh"

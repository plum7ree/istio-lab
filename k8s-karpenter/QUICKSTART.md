# Karpenter 빠른 시작 가이드

이 가이드는 Karpenter를 빠르게 시작하기 위한 단계별 가이드입니다.

## 🚀 5분 빠른 시작

### 1단계: 사전 요구사항 확인

```bash
# kubectl 연결 확인
kubectl cluster-info

# Karpenter 설치 확인
kubectl get namespace karpenter-system
```

### 2단계: 환경 변수 설정

```bash
export CLUSTER_NAME="my-eks-cluster"
export KARPENTER_NODE_ROLE="arn:aws:iam::123456789012:role/KarpenterNodeRole"
export KARPENTER_CONTROLLER_ROLE_ARN="arn:aws:iam::123456789012:role/KarpenterControllerRole"
```

### 3단계: 설정 파일 수정

다음 파일들을 열어서 `<CLUSTER_NAME>`, `<KARPENTER_NODE_ROLE>` 등을 실제 값으로 교체:

- `ec2nodeclass.yaml`
- `serviceaccount.yaml`
- `karpenter-config.yaml`
- `profiles/eks.yaml`

### 4단계: 배포

```bash
./deploy.sh eks
```

### 5단계: 테스트

```bash
# 테스트 워크로드 배포
kubectl apply -f examples/test-workload.yaml

# 노드 생성 확인
kubectl get nodes -w

# Pod 상태 확인
kubectl get pods -w
```

## 📝 상세 가이드

더 자세한 내용은 [README.md](README.md)를 참고하세요.

## 🔧 문제 해결

### 노드가 생성되지 않아요

1. IAM 권한 확인
2. 서브넷/보안그룹 태그 확인
3. Karpenter 로그 확인: `kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter`

### 설정 파일을 어떻게 수정하나요?

각 파일의 `<PLACEHOLDER>` 값을 실제 값으로 교체하세요:

- `<CLUSTER_NAME>` → EKS 클러스터 이름
- `<KARPENTER_NODE_ROLE>` → Karpenter 노드 IAM 역할 ARN
- `<KARPENTER_CONTROLLER_ROLE_ARN>` → Karpenter Controller IAM 역할 ARN

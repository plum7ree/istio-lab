# Karpenter 예제

이 디렉토리에는 Karpenter 사용 예제가 포함되어 있습니다.

## 파일 목록

### 테스트 워크로드

- `test-workload.yaml`: Karpenter 동작을 테스트하기 위한 다양한 워크로드
  - 기본 워크로드 (5개 Pod)
  - CPU 집약적 워크로드 (3개 Pod)
  - 메모리 집약적 워크로드 (2개 Pod)

### 특수 NodePool 예시

- `nodepool-gpu.yaml`: GPU 워크로드용 NodePool
- `nodepool-arm.yaml`: ARM64 아키텍처용 NodePool
- `nodepool-windows.yaml`: Windows 컨테이너용 NodePool

## 사용 방법

### 테스트 워크로드 배포

```bash
# 기본 워크로드 배포
kubectl apply -f examples/test-workload.yaml

# 노드 생성 확인
kubectl get nodes -w

# Pod 상태 확인
kubectl get pods -w

# 워크로드 삭제 (노드도 자동으로 제거됨)
kubectl delete -f examples/test-workload.yaml
```

### 특수 NodePool 배포

```bash
# GPU NodePool 배포
kubectl apply -f examples/nodepool-gpu.yaml

# ARM NodePool 배포
kubectl apply -f examples/nodepool-arm.yaml

# Windows NodePool 배포
kubectl apply -f examples/nodepool-windows.yaml
```

## 주의사항

- GPU NodePool은 GPU 인스턴스 타입이 필요합니다
- ARM NodePool은 ARM64 이미지를 사용하는 워크로드에만 적용됩니다
- Windows NodePool은 별도의 Windows EC2NodeClass가 필요합니다

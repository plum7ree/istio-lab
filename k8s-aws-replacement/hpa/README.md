# Horizontal Pod Autoscaler (HPA)

HPA는 CPU, 메모리 또는 커스텀 메트릭을 기반으로 Pod 수를 자동으로 조정합니다 (AWS Auto Scaling 대체).

## 사전 요구사항

Metrics Server가 설치되어 있어야 합니다:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 특징

- CPU/메모리 기반 자동 스케일링
- 커스텀 메트릭 지원
- 스케일 다운/업 정책 설정 가능


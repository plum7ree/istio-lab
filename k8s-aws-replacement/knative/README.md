# Knative 서버리스

Knative는 Kubernetes에서 서버리스 워크로드를 실행하는 플랫폼입니다 (AWS Lambda 대체).

## 설치 필요

```bash
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.11.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.11.0/serving-core.yaml
```

## 특징

- 자동 스케일링 (0개 Pod까지 스케일 다운)
- 트래픽 분할 및 카나리 배포 지원
- 리비전 관리


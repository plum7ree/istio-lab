# Monitoring

Prometheus 및 Grafana를 사용한 모니터링 설정 (AWS CloudWatch 대체).

## 설치 필요

### Prometheus Operator
```bash
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
```

### Prometheus & Grafana
```bash
# Helm을 사용한 설치 예시
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

## 포함된 리소스

- **ServiceMonitor**: 서비스 메트릭 수집
- **PodMonitor**: Pod 메트릭 수집
- **PrometheusRule**: 알림 규칙 정의

## 메트릭

- CPU/메모리 사용률
- Pod 재시작 횟수
- 서비스 가용성
- 네트워크 트래픽


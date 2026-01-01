# Ingress Controller

Kubernetes Ingress는 외부 트래픽을 클러스터 내부 서비스로 라우팅합니다 (AWS ALB/NLB 대체).

## 설치 필요 (NGINX Ingress Controller)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

## 특징

- HTTP/HTTPS 로드 밸런싱
- SSL/TLS 종료
- URL 기반 라우팅
- 호스트 기반 라우팅


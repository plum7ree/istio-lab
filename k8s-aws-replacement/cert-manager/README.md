# Cert-Manager

Cert-Manager는 Kubernetes에서 TLS 인증서를 자동으로 발급하고 갱신합니다 (AWS ACM 대체).

## 설치

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

## 특징

- Let's Encrypt 인증서 자동 발급
- 인증서 자동 갱신
- HTTP-01 및 DNS-01 챌린지 지원
- Ingress와 통합

## 사용법

1. ClusterIssuer 생성 (cert-manager/issuer.yaml)
2. Ingress에 cert-manager 어노테이션 추가
3. Certificate 리소스 생성 (선택사항)


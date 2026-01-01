# Kubernetes AWS 대체 프로젝트

이 프로젝트는 **Kubernetes가 AWS를 대체**하는 완전한 예제 모음입니다. AWS의 주요 서비스들을 Kubernetes 네이티브 서비스로 대체하여 클라우드 벤더 종속성 없이 동일한 기능을 구현합니다.

## 프로젝트 구조

```
k8s-aws-replacement/
├── frontend/              # Frontend 서비스
├── backend/               # Backend 서비스
├── backend2/              # Backend2 서비스
├── gateway/               # Istio Gateway (API Gateway 대체)
├── knative/               # Knative 서버리스 (AWS Lambda 대체)
├── ingress/               # Ingress Controller (AWS ALB/NLB 대체)
├── cert-manager/          # TLS 인증서 관리 (AWS ACM 대체)
├── hpa/                   # Horizontal Pod Autoscaler (Auto Scaling 대체)
├── security-policies/     # NetworkPolicy (Security Groups 대체)
├── storage/               # PersistentVolume/StorageClass (AWS EBS 대체)
├── statefulset/           # StatefulSet (AWS RDS 대체 예시)
├── cronjob/               # CronJob (AWS EventBridge 대체)
├── monitoring/            # Prometheus 모니터링 (AWS CloudWatch 대체)
├── quotas/                # Resource Quotas & Limit Ranges
└── shared/                # 공통 리소스
    ├── namespace.yaml
    ├── service-accounts.yaml
    ├── secrets.yaml       # Secrets (AWS Secrets Manager 대체)
    └── security.yaml      # Istio mTLS
```

## Kubernetes가 AWS를 대체하는 방법

이 프로젝트는 AWS 클라우드 서비스들을 Kubernetes 네이티브 리소스로 완전히 대체합니다. 클라우드 벤더 종속성 없이 동일한 기능을 구현할 수 있습니다.

### AWS 서비스 대체 매핑

| AWS 서비스 | Kubernetes 대체 | 위치 |
|-----------|----------------|------|
| Lambda | Knative | `knative/` |
| ALB/NLB | Ingress Controller | `ingress/` |
| ACM | Cert-Manager | `cert-manager/` |
| Auto Scaling | HPA | `hpa/` |
| Security Groups | NetworkPolicy | `security-policies/` |
| EBS | PersistentVolume/StorageClass | `storage/` |
| RDS | StatefulSet (예시) | `statefulset/` |
| EventBridge | CronJob | `cronjob/` |
| CloudWatch | Prometheus/Grafana | `monitoring/` |
| Secrets Manager | Secrets | `shared/secrets.yaml` |
| API Gateway | Istio Gateway | `gateway/` |

## 사전 요구사항

### 필수
- Kubernetes 클러스터 (1.24+)
- kubectl
- Istio 설치

### 선택 사항 (각 기능별)
- **Knative**: Knative Serving 설치 필요
- **Ingress**: NGINX Ingress Controller 설치 필요
- **Cert-Manager**: Cert-Manager 설치 필요
- **HPA**: Metrics Server 설치 필요
- **NetworkPolicy**: CNI 플러그인 (Calico, Cilium 등)
- **Monitoring**: Prometheus Operator 설치 필요

## 빠른 시작

### 기본 배포 (필수 구성)

```bash
# 1. 공통 리소스
kubectl apply -f shared/

# 2. 서비스 배포
kubectl apply -f frontend/
kubectl apply -f backend/
kubectl apply -f backend2/

# 3. Gateway 배포
kubectl apply -f gateway/
```

### 전체 배포 스크립트 사용

```bash
./deploy.sh
```

## 상세 가이드

### 1. Knative 서버리스 (AWS Lambda 대체)

서버리스 워크로드를 실행합니다.

```bash
# Knative 설치 필요
kubectl apply -f knative/
```

자세한 내용: [knative/README.md](knative/README.md)

### 2. Ingress Controller (AWS ALB/NLB 대체)

외부 트래픽을 클러스터 내부로 라우팅합니다.

```bash
# NGINX Ingress Controller 설치 필요
kubectl apply -f ingress/
```

자세한 내용: [ingress/README.md](ingress/README.md)

### 3. Cert-Manager (AWS ACM 대체)

TLS 인증서를 자동으로 발급하고 갱신합니다.

```bash
# Cert-Manager 설치 필요
kubectl apply -f cert-manager/
```

자세한 내용: [cert-manager/README.md](cert-manager/README.md)

### 4. HPA (Auto Scaling 대체)

CPU/메모리 기반 자동 스케일링

```bash
# Metrics Server 설치 필요
kubectl apply -f hpa/
```

자세한 내용: [hpa/README.md](hpa/README.md)

### 5. NetworkPolicy (Security Groups 대체)

Pod 간 네트워크 통신 제어

```bash
kubectl apply -f security-policies/
```

자세한 내용: [security-policies/README.md](security-policies/README.md)

### 6. Persistent Storage (AWS EBS 대체)

영구 스토리지 관리

```bash
kubectl apply -f storage/
```

자세한 내용: [storage/README.md](storage/README.md)

### 7. StatefulSet (데이터베이스 예시)

상태가 있는 애플리케이션 배포

```bash
kubectl apply -f statefulset/
```

자세한 내용: [statefulset/README.md](statefulset/README.md)

### 8. CronJob (AWS EventBridge 대체)

스케줄링된 작업 실행

```bash
kubectl apply -f cronjob/
```

자세한 내용: [cronjob/README.md](cronjob/README.md)

### 9. Monitoring (AWS CloudWatch 대체)

Prometheus 기반 모니터링 및 알림

```bash
# Prometheus Operator 설치 필요
kubectl apply -f monitoring/
```

자세한 내용: [monitoring/README.md](monitoring/README.md)

### 10. Resource Quotas

리소스 할당량 및 제한 관리

```bash
kubectl apply -f quotas/
```

자세한 내용: [quotas/README.md](quotas/README.md)

## 배포 순서 권장사항

1. **공통 리소스** (필수)
   ```bash
   kubectl apply -f shared/
   kubectl apply -f quotas/  # 리소스 제한 설정
   ```

2. **스토리지** (필요시)
   ```bash
   kubectl apply -f storage/
   ```

3. **서비스 배포**
   ```bash
   kubectl apply -f frontend/
   kubectl apply -f backend/
   kubectl apply -f backend2/
   ```

4. **오토스케일링**
   ```bash
   kubectl apply -f hpa/
   ```

5. **보안 정책**
   ```bash
   kubectl apply -f security-policies/
   ```

6. **Gateway/Ingress**
   ```bash
   kubectl apply -f gateway/
   kubectl apply -f ingress/  # 선택사항
   ```

7. **서버리스** (선택사항)
   ```bash
   kubectl apply -f knative/
   ```

8. **스케줄링** (선택사항)
   ```bash
   kubectl apply -f cronjob/
   ```

9. **모니터링** (선택사항)
   ```bash
   kubectl apply -f monitoring/
   ```

## 아키텍처

```
                    [Internet]
                         |
                    [Ingress]
                         |
                    [Istio Gateway]
                         |
        +----------------+----------------+
        |                |                |
    [Frontend]      [Backend]       [Backend2]
        |                |
        |            [Database]
        |         (StatefulSet)
        |
    [Knative Service]
    (Serverless)
```

## 삭제

전체 리소스 삭제:

```bash
./destroy.sh
```

또는 개별 삭제:

```bash
kubectl delete -f monitoring/
kubectl delete -f cronjob/
kubectl delete -f knative/
kubectl delete -f ingress/
kubectl delete -f gateway/
kubectl delete -f security-policies/
kubectl delete -f hpa/
kubectl delete -f statefulset/
kubectl delete -f storage/
kubectl delete -f backend2/
kubectl delete -f backend/
kubectl delete -f frontend/
kubectl delete -f quotas/
kubectl delete -f shared/
```

## 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Istio 문서](https://istio.io/latest/docs/)
- [Knative 문서](https://knative.dev/docs/)
- [Prometheus 문서](https://prometheus.io/docs/)

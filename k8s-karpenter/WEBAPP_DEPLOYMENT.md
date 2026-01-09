# 웹앱 배포 가이드

이 문서는 Terraform으로 Karpenter를 배포한 후 웹앱을 배포하는 방법을 설명합니다.

## 📋 배포 방법

### 방법 1: Terraform으로 자동 배포 (권장)

Terraform이 웹앱을 자동으로 배포합니다:

```bash
# terraform.tfvars에서 설정
deploy_webapp = true

# 배포
./deploy-all.sh
```

이렇게 하면:
- ✅ EKS 클러스터 생성
- ✅ Karpenter 설치
- ✅ 웹앱 자동 배포 (Namespace, Deployment, Service)

### 방법 2: kubectl로 수동 배포

Terraform으로 인프라만 생성하고 웹앱은 수동으로 배포:

```bash
# 1. Terraform으로 인프라만 생성
cd terraform
terraform apply

# 2. 웹앱 수동 배포
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: webapp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: webapp
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
EOF
```

## 🔍 확인

### 웹앱 상태 확인

```bash
# Pod 확인
kubectl get pods -n webapp

# Service 확인 (LoadBalancer 주소 확인)
kubectl get svc -n webapp

# 노드 확인 (Karpenter가 자동으로 노드 생성)
kubectl get nodes
```

### 웹앱 접속

```bash
# LoadBalancer 주소 가져오기
EXTERNAL_IP=$(kubectl get svc webapp -n webapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 접속 테스트
curl http://$EXTERNAL_IP
```

## 🎯 Karpenter 동작 확인

웹앱을 배포하면 Karpenter가 자동으로 노드를 생성합니다:

```bash
# Pod가 Pending 상태인지 확인
kubectl get pods -n webapp -w

# 노드 생성 확인
kubectl get nodes -w

# Karpenter 로그 확인
kubectl logs -n karpenter-system -l app.kubernetes.io/name=karpenter -f
```

## 📝 커스터마이징

### 웹앱 이미지 변경

Terraform 템플릿 수정:

```bash
vim terraform/templates/webapp.yaml.tpl
# image: nginx:alpine → image: your-image:tag
terraform apply
```

또는 kubectl로 직접 수정:

```bash
kubectl set image deployment/webapp webapp=your-image:tag -n webapp
```

### 리소스 요청 변경

```bash
kubectl edit deployment webapp -n webapp
# resources 섹션 수정
```

## 🗑️ 삭제

### Terraform으로 배포한 경우

```bash
# Terraform destroy 시 자동 삭제됨
./destroy-all.sh
```

### 수동으로 배포한 경우

```bash
kubectl delete namespace webapp
```

## 💡 팁

1. **자동 스케일링**: HPA를 추가하여 Pod 수를 자동으로 조정할 수 있습니다
2. **노드 자동 생성**: Pod가 스케줄링되면 Karpenter가 자동으로 노드를 생성합니다
3. **비용 최적화**: 사용하지 않는 노드는 자동으로 제거됩니다

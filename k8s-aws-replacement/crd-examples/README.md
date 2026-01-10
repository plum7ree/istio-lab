# Custom Resource Definition (CRD) 예제

이 디렉토리에는 Kubernetes Custom Resource를 만드는 예제가 포함되어 있습니다.

## 파일 설명

- `webapp-crd.yaml`: 간단한 WebApp CRD 정의
- `webapp-instance.yaml`: WebApp Custom Resource 인스턴스
- `database-crd.yaml`: 복잡한 Database CRD 정의 (Operator 예시)
- `database-instance.yaml`: Database Custom Resource 인스턴스

## 사용 방법

### 1. WebApp CRD 예제

```bash
# 1. CRD 생성
kubectl apply -f webapp-crd.yaml

# 2. CRD 확인
kubectl get crd webapps.example.com

# 3. Custom Resource 인스턴스 생성
kubectl apply -f webapp-instance.yaml

# 4. 생성된 WebApp 확인
kubectl get webapp
kubectl get webapp my-webapp -o yaml

# 5. 삭제
kubectl delete -f webapp-instance.yaml
kubectl delete -f webapp-crd.yaml
```

### 2. CRD만으로는 동작하지 않음

⚠️ **중요**: CRD를 생성하고 Custom Resource 인스턴스를 만들어도 **아무 일도 일어나지 않습니다**.

실제로 동작하게 하려면 **Controller**가 필요합니다. Controller는 Custom Resource를 감시하고, 원하는 상태(예: Deployment 생성)를 구현합니다.

### 3. Controller 개발

Controller를 개발하려면:

1. **Kubernetes Client Library** 사용
   - Go: `client-go`
   - Python: `kubernetes`
   - Java: `fabric8io/kubernetes-client`

2. **Operator SDK** 또는 **Kubebuilder** 사용
   - Operator 프레임워크로 빠르게 개발 가능

### 4. 실제 동작하는 예제

실제로 동작하는 Operator 예제를 보려면:
- [Kubebuilder Tutorial](https://book.kubebuilder.io/)
- [Operator SDK](https://sdk.operatorframework.io/)

## CRD vs Controller

| 항목 | 설명 | 필수 여부 |
|------|------|----------|
| **CRD** | 리소스의 구조(스키마) 정의 | ✅ 필수 |
| **Controller** | 리소스를 실제로 처리하는 프로그램 | ✅ 필수 (동작하려면) |

## kubectl explain으로 확인

CRD를 생성한 후, 기본 리소스처럼 설명을 볼 수 있습니다:

```bash
# CRD 설명 확인
kubectl explain webapp

# 특정 필드 확인
kubectl explain webapp.spec.replicas
kubectl explain webapp.spec.image
```

## 참고

- [Kubernetes Custom Resources 공식 문서](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [CRD Best Practices](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)


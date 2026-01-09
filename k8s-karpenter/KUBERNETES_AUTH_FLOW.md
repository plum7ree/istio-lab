# Kubernetes 권한 검증 완전 이해하기

이 문서는 Kubernetes 클러스터 내부에서 권한 검증이 어떻게 이루어지는지, 어떤 컴포넌트들이 관여하는지 설명합니다.

## 🎯 핵심 질문

**"클러스터 내부를 관리하는 애가 ServiceAccount를 보고 해당 Pod가 어떤 요청을 할 때 그게 가능한지 보는거야?"**

→ **네, 맞습니다!** 하지만 더 정확히는 여러 컴포넌트가 협력합니다.

## 📊 Kubernetes 권한 검증 아키텍처

### 전체 흐름

```
Pod (Karpenter)
    ↓
Kubernetes API Server에 요청
    ↓
┌─────────────────────────────────────┐
│      API Server (중앙 게이트웨이)      │
│                                       │
│  1. Authentication (인증)            │
│     - ServiceAccount Token 확인      │
│     - "이 Pod가 누구인지" 확인        │
│                                       │
│  2. Authorization (인증)             │
│     - RBAC Authorizer                │
│     - ClusterRoleBinding 확인         │
│     - "이 요청이 허용되는지" 확인      │
│                                       │
│  3. Admission Control                │
│     - 리소스 검증/수정                │
└─────────────────────────────────────┘
    ↓
요청 허용/거부
```

## 🔍 관여하는 Kubernetes 내부 요소들

### 1. API Server (kube-apiserver)

**역할**: 모든 요청의 중앙 게이트웨이

```
Pod → API Server → 권한 검증 → 요청 처리
```

**기능**:
- 모든 Kubernetes 리소스 접근의 단일 진입점
- Authentication (인증)
- Authorization (인증)
- Admission Control

### 2. ServiceAccount Controller

**역할**: ServiceAccount와 관련된 토큰 관리

**기능**:
- ServiceAccount 생성 시 자동으로 Secret 생성
- ServiceAccount Token 생성/갱신
- Pod에 ServiceAccount Token 마운트

**동작**:
```
ServiceAccount 생성
    ↓
ServiceAccount Controller가 감지
    ↓
Secret 생성 (토큰 포함)
    ↓
Pod에 토큰 자동 마운트
```

### 3. Token Controller

**역할**: ServiceAccount Token 관리

**기능**:
- ServiceAccount Token 생성
- Token 만료 관리
- IRSA (EKS)의 경우 AWS STS와 연동

### 4. RBAC Authorizer

**역할**: 권한 검증 (가장 중요!)

**기능**:
- ClusterRole 확인
- ClusterRoleBinding 확인
- ServiceAccount가 요청한 작업을 할 수 있는지 검증

**검증 과정**:
```
API Server가 요청 받음
    ↓
RBAC Authorizer 호출
    ↓
1. 요청자 확인 (ServiceAccount)
2. 요청한 작업 확인 (get pods)
3. ClusterRoleBinding에서 권한 확인
4. ClusterRole에서 허용된 작업 확인
    ↓
권한 있음 → 요청 허용 ✅
권한 없음 → 요청 거부 ❌
```

### 5. Admission Controllers

**역할**: 리소스 생성/수정 시 추가 검증 및 수정

**종류**:
- **MutatingAdmissionWebhook**: 리소스 수정 (예: ServiceAccount Token 자동 주입)
- **ValidatingAdmissionWebhook**: 리소스 검증

**예시**:
```
Pod 생성 요청
    ↓
MutatingAdmissionWebhook
    ↓
ServiceAccount가 지정되지 않았으면
→ 자동으로 "default" ServiceAccount 지정
    ↓
ValidatingAdmissionWebhook
    ↓
리소스 검증 (형식, 권한 등)
```

## 🔄 실제 요청 흐름 (상세)

### 시나리오: Karpenter가 Pod 목록 조회

```
1. Karpenter Pod 내부
   ↓
   코드: client.Pods().List()
   ↓
   Kubernetes API 호출: GET /api/v1/pods

2. API Server 수신
   ↓
   요청 분석:
   - 요청자: ServiceAccount "karpenter-system:karpenter"
   - 요청: GET /api/v1/pods
   - 인증 정보: ServiceAccount Token

3. Authentication (인증)
   ↓
   ServiceAccount Token 검증
   ↓
   "이 요청은 karpenter-system:karpenter ServiceAccount에서 온 것"
   ✅ 인증 성공

4. Authorization (인증)
   ↓
   RBAC Authorizer 호출
   ↓
   ClusterRoleBinding 확인:
   - subjects: ServiceAccount "karpenter"
   - roleRef: ClusterRole "karpenter"
   ↓
   ClusterRole 확인:
   - resources: ["pods"]
   - verbs: ["get", "list", "watch"]
   ↓
   요청 검증:
   - 요청: GET /api/v1/pods (list pods)
   - 권한: pods에 대한 list 권한 있음
   ✅ 인증 성공

5. Admission Control
   ↓
   추가 검증/수정
   ✅ 통과

6. 요청 처리
   ↓
   Pod 목록 반환
   ✅ 성공
```

## 📋 각 컴포넌트의 역할

### API Server

```yaml
# 모든 요청이 여기를 거침
API Server
  ├─ Authentication: "누구인가?"
  ├─ Authorization: "무엇을 할 수 있는가?"
  └─ Admission Control: "추가 검증/수정"
```

**코드에서의 위치**:
- Kubernetes 클러스터의 핵심 컴포넌트
- `kube-apiserver` 프로세스로 실행

### ServiceAccount Controller

```yaml
# ServiceAccount 관리
ServiceAccount Controller
  ├─ ServiceAccount 생성 감지
  ├─ Secret (Token) 자동 생성
  └─ Pod에 Token 마운트
```

**코드에서의 위치**:
- `kube-controller-manager` 내부
- Kubernetes 클러스터에 기본 포함

### RBAC Authorizer

```yaml
# 권한 검증
RBAC Authorizer
  ├─ ClusterRole 확인
  ├─ ClusterRoleBinding 확인
  └─ 요청 허용/거부 결정
```

**코드에서의 위치**:
- API Server 내부
- Kubernetes 클러스터에 기본 포함

## 🔐 ServiceAccount Token의 역할

### Token 생성

```
ServiceAccount 생성
    ↓
ServiceAccount Controller가 감지
    ↓
Secret 생성 (자동)
    ↓
Token 포함
    ↓
Pod에 자동 마운트
```

### Token 사용

```
Pod 실행
    ↓
Token이 /var/run/secrets/kubernetes.io/serviceaccount/ 에 마운트됨
    ↓
Pod 내부 코드가 Token 사용
    ↓
Kubernetes API 호출 시 Token 포함
    ↓
API Server가 Token 검증
```

### 실제 위치

```bash
# Pod 내부에서 확인
kubectl exec -n karpenter-system <pod-name> -- \
  ls -la /var/run/secrets/kubernetes.io/serviceaccount/

# 출력:
# token          # ServiceAccount Token
# ca.crt         # 클러스터 CA 인증서
# namespace      # 네임스페이스 이름
```

## 🔄 전체 권한 검증 흐름

### 1. Pod 시작 시

```
Pod 생성 요청
    ↓
API Server (Admission Control)
    ↓
ServiceAccount 확인
    ↓
ServiceAccount Controller
    ↓
Token Secret 생성/확인
    ↓
Pod에 Token 마운트
    ↓
Pod 실행
```

### 2. Pod가 API 호출 시

```
Pod 내부 코드
    ↓
Kubernetes API 호출 (Token 포함)
    ↓
API Server 수신
    ↓
Authentication
    ↓ Token 검증
    ↓ ServiceAccount 확인
    ↓
Authorization
    ↓ RBAC Authorizer
    ↓ ClusterRoleBinding 확인
    ↓ ClusterRole 확인
    ↓ 권한 검증
    ↓
요청 허용/거부
```

## 💡 실제 예시

### 예시 1: Karpenter가 Pod 목록 조회

```
1. Karpenter Pod 내부
   client.Pods().List()
   ↓
2. API Server
   GET /api/v1/pods
   Header: Authorization: Bearer <token>
   ↓
3. Authentication
   Token 검증 → ServiceAccount "karpenter" 확인
   ↓
4. Authorization
   RBAC Authorizer:
   - ClusterRoleBinding "karpenter" 확인
   - ClusterRole "karpenter" 확인
   - pods에 대한 list 권한 있음 ✅
   ↓
5. 요청 허용
   Pod 목록 반환
```

### 예시 2: 권한 없는 요청

```
1. Pod 내부
   client.Nodes().Delete("node-1")
   ↓
2. API Server
   DELETE /api/v1/nodes/node-1
   ↓
3. Authentication
   Token 검증 → ServiceAccount 확인 ✅
   ↓
4. Authorization
   RBAC Authorizer:
   - ClusterRole 확인
   - nodes에 대한 delete 권한 없음 ❌
   ↓
5. 요청 거부
   Error: Forbidden (403)
```

## 🔍 코드에서의 확인

### 1. API Server 확인

```bash
# API Server Pod 확인
kubectl get pods -n kube-system | grep apiserver

# API Server 로그 확인
kubectl logs -n kube-system <apiserver-pod> | grep authorization
```

### 2. ServiceAccount Controller 확인

```bash
# Controller Manager 확인
kubectl get pods -n kube-system | grep controller-manager

# ServiceAccount Secret 확인
kubectl get secrets -n karpenter-system | grep karpenter
```

### 3. RBAC 확인

```bash
# ClusterRole 확인
kubectl get clusterrole karpenter -o yaml

# ClusterRoleBinding 확인
kubectl get clusterrolebinding karpenter -o yaml
```

## 📊 컴포넌트 간 상호작용

### 전체 구조

```
┌─────────────────────────────────────────────────┐
│           Kubernetes 클러스터                    │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │      API Server (kube-apiserver)         │  │
│  │  - 모든 요청의 중앙 게이트웨이              │  │
│  │  - Authentication                         │  │
│  │  - Authorization (RBAC Authorizer)        │  │
│  │  - Admission Control                      │  │
│  └──────────────────────────────────────────┘  │
│                    ↑                            │
│                    │                            │
│  ┌─────────────────┴─────────────────────────┐  │
│  │  Controller Manager                       │  │
│  │  - ServiceAccount Controller              │  │
│  │  - Token Controller                       │  │
│  └───────────────────────────────────────────┘  │
│                    ↑                            │
│                    │                            │
│  ┌─────────────────┴─────────────────────────┐  │
│  │  Pod (Karpenter)                          │  │
│  │  - ServiceAccount Token 사용               │  │
│  │  - Kubernetes API 호출                     │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## 🎯 핵심 정리

### 관여하는 Kubernetes 내부 요소들

1. **API Server** (kube-apiserver)
   - 모든 요청의 중앙 게이트웨이
   - Authentication, Authorization, Admission Control

2. **ServiceAccount Controller**
   - ServiceAccount Token 생성/관리
   - Pod에 Token 마운트

3. **RBAC Authorizer**
   - 권한 검증
   - ClusterRole/ClusterRoleBinding 확인

4. **Admission Controllers**
   - 리소스 검증/수정
   - ServiceAccount 자동 주입 등

### 권한 검증 과정

```
Pod 요청
    ↓
API Server
    ↓
1. Authentication: ServiceAccount Token 검증
2. Authorization: RBAC Authorizer가 권한 확인
3. Admission Control: 추가 검증
    ↓
요청 허용/거부
```

### 파일과 권한의 관계

- **파일 작성**: 권한 정의 (ClusterRole, ClusterRoleBinding)
- **kubectl apply**: 클러스터에 적용
- **API Server**: 실제 권한 검증 수행

## 📚 참고 자료

- [Kubernetes API Server 문서](https://kubernetes.io/docs/concepts/overview/components/#kube-apiserver)
- [Kubernetes RBAC 문서](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [ServiceAccount 문서](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [Admission Controllers 문서](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Kubernetes 클러스터 구성 요소](../KUBERNETES_CLUSTER_COMPONENTS.md) ⭐ **클러스터 구조가 궁금하면 여기!**
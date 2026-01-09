# Controller Manager 완전 이해하기

이 문서는 Kubernetes Controller Manager와 포함된 다양한 Controller들의 역할을 상세히 설명합니다.

## 🎯 Controller Manager란?

### 간단히 말하면

**Controller Manager = Kubernetes 클러스터의 상태를 원하는 상태로 유지하는 여러 Controller들을 실행하는 프로세스**

### 핵심 개념

```
현재 상태 (Current State)
    ↓
Controller가 감지
    ↓
원하는 상태 (Desired State)와 비교
    ↓
차이가 있으면 조치 취함
    ↓
현재 상태를 원하는 상태로 맞춤
```

## 📊 Controller Manager 구조

### 전체 구조

```
┌─────────────────────────────────────────────────┐
│      Controller Manager (kube-controller-manager) │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Node Controller                          │  │
│  │  - Node 상태 모니터링                      │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Replication Controller                   │  │
│  │  - ReplicaSet 관리                         │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  ServiceAccount Controller                │  │
│  │  - ServiceAccount Token 생성               │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Token Controller                         │  │
│  │  - ServiceAccount Token 관리              │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Namespace Controller                     │  │
│  │  - Namespace 관리                         │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Endpoints Controller                     │  │
│  │  - Service Endpoints 관리                  │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Service Controller                       │  │
│  │  - Service 관리                            │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Job Controller                           │  │
│  │  - Job 관리                                │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  Deployment Controller                    │  │
│  │  - Deployment 관리                         │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ... 기타 Controller들 ...                        │
└─────────────────────────────────────────────────┘
```

## 🔍 주요 Controller 종류

### 1. Node Controller

**역할**: Node 상태 모니터링 및 관리

**기능**:
- Node 상태 확인 (Ready, NotReady 등)
- Node가 응답하지 않으면 Taint 추가
- Node 삭제 처리
- Node Heartbeat 관리

**동작 예시**:
```
Node가 응답하지 않음
    ↓
Node Controller가 감지
    ↓
Node 상태를 NotReady로 변경
    ↓
Taint 추가 (NoSchedule)
    ↓
새 Pod가 해당 Node에 스케줄링되지 않음
```

**확인 방법**:
```bash
# Node 상태 확인
kubectl get nodes

# Node 상세 정보
kubectl describe node <node-name>
```

### 2. Replication Controller

**역할**: ReplicaSet의 Pod 수 관리

**기능**:
- ReplicaSet의 desired replicas 확인
- 현재 Pod 수 확인
- 부족하면 Pod 생성
- 초과하면 Pod 삭제

**동작 예시**:
```
ReplicaSet: replicas: 3
현재 Pod: 2개
    ↓
Replication Controller가 감지
    ↓
Pod 1개 생성
    ↓
Pod 수: 3개 (desired 상태)
```

**확인 방법**:
```bash
# ReplicaSet 확인
kubectl get replicaset

# Pod 수 확인
kubectl get pods
```

### 3. ServiceAccount Controller

**역할**: ServiceAccount Token 생성 및 관리

**기능**:
- ServiceAccount 생성 감지
- 자동으로 Secret 생성 (Token 포함)
- Pod에 Token 마운트 준비

**동작 예시**:
```
ServiceAccount 생성
    ↓
ServiceAccount Controller가 감지
    ↓
Secret 생성 (자동)
    ↓
Token 포함
    ↓
Pod가 ServiceAccount 사용 시 Token 사용 가능
```

**확인 방법**:
```bash
# ServiceAccount 확인
kubectl get serviceaccount

# ServiceAccount의 Secret 확인
kubectl get secrets | grep <serviceaccount-name>
```

### 4. Token Controller

**역할**: ServiceAccount Token 관리

**기능**:
- ServiceAccount Token 생성
- Token 만료 관리
- IRSA (EKS)의 경우 AWS STS와 연동

**동작 예시**:
```
ServiceAccount Token 만료 임박
    ↓
Token Controller가 감지
    ↓
새 Token 생성
    ↓
Secret 업데이트
```

**확인 방법**:
```bash
# ServiceAccount Token 확인
kubectl get secrets -n <namespace> | grep <serviceaccount-name>
```

### 5. Namespace Controller

**역할**: Namespace 관리

**기능**:
- Namespace 생성/삭제 처리
- Namespace 삭제 시 리소스 정리
- Finalizer 관리

**동작 예시**:
```
Namespace 삭제 요청
    ↓
Namespace Controller가 감지
    ↓
Namespace 내 모든 리소스 삭제
    ↓
Finalizer 제거
    ↓
Namespace 삭제 완료
```

**확인 방법**:
```bash
# Namespace 확인
kubectl get namespaces

# Namespace 상세 정보
kubectl describe namespace <namespace-name>
```

### 6. Endpoints Controller

**역할**: Service의 Endpoints 관리

**기능**:
- Service와 Pod 연결
- Pod IP 주소 수집
- Endpoints 리소스 업데이트

**동작 예시**:
```
Service 생성
    selector: app=webapp
    ↓
Endpoints Controller가 감지
    ↓
Label이 app=webapp인 Pod 찾기
    ↓
Pod IP 주소 수집
    ↓
Endpoints 리소스 생성/업데이트
```

**확인 방법**:
```bash
# Endpoints 확인
kubectl get endpoints

# Service와 Endpoints 연결 확인
kubectl get endpoints <service-name>
```

### 7. Service Controller

**역할**: Service 관리 (특히 LoadBalancer 타입)

**기능**:
- LoadBalancer Service 생성 시 클라우드 로드밸런서 생성
- Service 삭제 시 로드밸런서 삭제
- 클라우드 프로바이더와 통신

**동작 예시**:
```
LoadBalancer Service 생성
    ↓
Service Controller가 감지
    ↓
AWS ELB 생성 요청
    ↓
로드밸런서 생성 완료
    ↓
Service의 EXTERNAL-IP 업데이트
```

**확인 방법**:
```bash
# Service 확인
kubectl get services

# LoadBalancer Service 확인
kubectl get svc -o wide
```

### 8. Job Controller

**역할**: Job 관리

**기능**:
- Job 실행 관리
- 완료된 Job 정리
- CronJob 스케줄링

**동작 예시**:
```
Job 생성
    ↓
Job Controller가 감지
    ↓
Pod 생성 (Job 실행)
    ↓
Pod 완료 대기
    ↓
Pod 완료 시 Job 상태 업데이트
```

**확인 방법**:
```bash
# Job 확인
kubectl get jobs

# CronJob 확인
kubectl get cronjobs
```

### 9. Deployment Controller

**역할**: Deployment 관리

**기능**:
- Deployment의 desired state 확인
- ReplicaSet 생성/관리
- 롤링 업데이트 관리
- 롤백 처리

**동작 예시**:
```
Deployment 생성
    replicas: 3
    ↓
Deployment Controller가 감지
    ↓
ReplicaSet 생성
    ↓
ReplicaSet Controller가 Pod 생성
    ↓
Pod 3개 실행
```

**확인 방법**:
```bash
# Deployment 확인
kubectl get deployments

# Deployment 상세 정보
kubectl describe deployment <deployment-name>
```

### 10. StatefulSet Controller

**역할**: StatefulSet 관리

**기능**:
- StatefulSet의 Pod 순서 관리
- Pod 이름 규칙 유지 (statefulset-name-0, statefulset-name-1 등)
- PersistentVolume 관리

**동작 예시**:
```
StatefulSet 생성
    replicas: 3
    ↓
StatefulSet Controller가 감지
    ↓
Pod 순서대로 생성 (0, 1, 2)
    ↓
각 Pod에 PersistentVolume 연결
```

**확인 방법**:
```bash
# StatefulSet 확인
kubectl get statefulsets

# StatefulSet Pod 확인
kubectl get pods -l app=<app-name>
```

### 11. DaemonSet Controller

**역할**: DaemonSet 관리

**기능**:
- 모든 노드에 Pod 배치
- 새 노드 추가 시 자동 Pod 배치
- 노드 삭제 시 Pod 정리

**동작 예시**:
```
DaemonSet 생성
    ↓
DaemonSet Controller가 감지
    ↓
모든 노드에 Pod 배치
    ↓
새 노드 추가
    ↓
새 노드에 자동으로 Pod 배치
```

**확인 방법**:
```bash
# DaemonSet 확인
kubectl get daemonsets

# DaemonSet Pod 확인
kubectl get pods -l app=<app-name>
```

### 12. PersistentVolume Controller

**역할**: PersistentVolume 관리

**기능**:
- PersistentVolume 생성/삭제
- PersistentVolumeClaim과 바인딩
- StorageClass 관리

**동작 예시**:
```
PersistentVolumeClaim 생성
    ↓
PersistentVolume Controller가 감지
    ↓
적절한 PersistentVolume 찾기
    ↓
바인딩
    ↓
Pod에서 사용 가능
```

**확인 방법**:
```bash
# PersistentVolume 확인
kubectl get pv

# PersistentVolumeClaim 확인
kubectl get pvc
```

## 🔄 Controller 동작 원리

### 일반적인 Controller 패턴

```
1. Watch (감시)
   Controller가 API Server를 watch
   ↓
2. Compare (비교)
   현재 상태 vs 원하는 상태 비교
   ↓
3. Reconcile (조정)
   차이가 있으면 조치 취함
   ↓
4. Update (업데이트)
   API Server에 상태 업데이트
   ↓
5. Repeat (반복)
   계속 watch하며 반복
```

### 실제 예시: Replication Controller

```
1. Watch
   ReplicaSet 리소스를 watch
   ↓
2. Compare
   desired replicas: 3
   current replicas: 2
   차이: 1개 부족
   ↓
3. Reconcile
   Pod 1개 생성 요청
   ↓
4. Update
   API Server에 Pod 생성 요청
   ↓
5. Repeat
   계속 watch하며 상태 확인
```

## 📋 Controller Manager 확인 방법

### 1. Controller Manager Pod 확인

```bash
# Controller Manager Pod 확인
kubectl get pods -n kube-system | grep controller-manager

# 출력 예시:
# kube-controller-manager-ip-10-0-1-xxx    1/1   Running
```

### 2. Controller Manager 로그 확인

```bash
# Controller Manager 로그 확인
kubectl logs -n kube-system <controller-manager-pod>

# 특정 Controller 로그만 확인
kubectl logs -n kube-system <controller-manager-pod> | grep "Node Controller"
```

### 3. Controller Manager 설정 확인

```bash
# Controller Manager Pod 상세 정보
kubectl describe pod -n kube-system <controller-manager-pod>

# Controller Manager 명령어 옵션 확인
kubectl logs -n kube-system <controller-manager-pod> | head -20
```

## 💡 Controller와 Karpenter의 관계

### Karpenter도 Controller입니다!

Karpenter는 **별도의 Controller**로 실행되지만, Controller Manager와 유사한 패턴을 사용합니다:

```
Karpenter Controller
    ↓
Watch: Pending Pod 감시
    ↓
Compare: Pod 요구사항 vs 현재 노드
    ↓
Reconcile: 노드 생성/삭제
    ↓
Update: API Server에 노드 정보 업데이트
```

### 차이점

| 구분 | Controller Manager | Karpenter |
|------|-------------------|-----------|
| 위치 | Control Plane | Worker Node (Pod로 실행) |
| 관리 대상 | Kubernetes 내부 리소스 | EC2 인스턴스 (외부) |
| 실행 방식 | 시스템 프로세스 | Pod (Deployment) |

## 🎯 핵심 정리

### Controller Manager

- **역할**: 클러스터 상태를 원하는 상태로 유지
- **위치**: Control Plane (마스터 노드)
- **실행 방식**: 시스템 프로세스 (kube-controller-manager)

### 주요 Controller 종류

1. **Node Controller**: Node 상태 관리
2. **Replication Controller**: ReplicaSet Pod 수 관리
3. **ServiceAccount Controller**: ServiceAccount Token 생성
4. **Token Controller**: ServiceAccount Token 관리
5. **Namespace Controller**: Namespace 관리
6. **Endpoints Controller**: Service Endpoints 관리
7. **Service Controller**: LoadBalancer 관리
8. **Job Controller**: Job 실행 관리
9. **Deployment Controller**: Deployment 관리
10. **StatefulSet Controller**: StatefulSet 관리
11. **DaemonSet Controller**: DaemonSet 관리
12. **PersistentVolume Controller**: PV/PVC 관리

### Controller 동작 원리

```
Watch → Compare → Reconcile → Update → Repeat
```

## 📚 참고 자료

- [Kubernetes Controller Manager 문서](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Kubernetes Controller 패턴](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Kubernetes 리소스 문서](https://kubernetes.io/docs/concepts/)

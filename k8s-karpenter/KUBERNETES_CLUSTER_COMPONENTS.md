# Kubernetes 클러스터 구성 요소 완전 이해하기

이 문서는 Kubernetes 클러스터의 주요 컴포넌트들과 그들의 역할, 위치를 설명합니다.

## 🎯 핵심 질문

1. **Kubernetes API는 클러스터 안에 있는 서비스인가?** → ✅ 네, 맞습니다!
2. **자동으로 구성되는가?** → ✅ 네, 클러스터 생성 시 자동 구성됩니다!
3. **다른 요소들이 뭐가 있는가?** → 여러 컴포넌트가 있습니다!

## 📊 Kubernetes 클러스터 구조

### 전체 구조

```
┌─────────────────────────────────────────────────────────┐
│              Kubernetes 클러스터                          │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Control Plane (마스터 노드)                │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  API Server (kube-apiserver)             │  │   │
│  │  │  - 모든 요청의 중앙 게이트웨이              │  │   │
│  │  │  - 인증/인가 처리                          │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  etcd                                      │  │   │
│  │  │  - 클러스터 상태 저장                       │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  Controller Manager                       │  │   │
│  │  │  - 다양한 Controller 실행                 │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  Scheduler                                │  │   │
│  │  │  - Pod를 노드에 배치                       │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Worker Nodes (워커 노드)                 │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  kubelet                                   │  │   │
│  │  │  - Pod 실행 관리                            │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  kube-proxy                                │  │   │
│  │  │  - 네트워크 프록시                          │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  Container Runtime                        │  │   │
│  │  │  - Docker, containerd 등                   │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 🎛️ Control Plane (마스터 노드) 컴포넌트

### 1. API Server (kube-apiserver)

**위치**: Control Plane (마스터 노드)  
**자동 구성**: ✅ 네, 클러스터 생성 시 자동 구성  
**역할**: 모든 요청의 중앙 게이트웨이

**기능**:
- 모든 Kubernetes 리소스 접근의 단일 진입점
- RESTful API 제공
- Authentication (인증)
- Authorization (인증)
- Admission Control

**실행 위치**:
```bash
# EKS의 경우
kubectl get pods -n kube-system | grep apiserver

# 출력 예시:
# kube-apiserver-ip-10-0-1-xxx    1/1   Running
```

**접근 방법**:
```bash
# API Server 주소 확인
kubectl cluster-info

# 출력 예시:
# Kubernetes control plane is running at https://xxx.yl4.us-west-2.eks.amazonaws.com
```

### 2. etcd

**위치**: Control Plane (마스터 노드)  
**자동 구성**: ✅ 네, 클러스터 생성 시 자동 구성  
**역할**: 클러스터 상태 저장소

**기능**:
- 모든 Kubernetes 리소스의 상태 저장
- 분산 키-값 저장소
- 클러스터의 "단일 진실 소스"

**데이터 저장**:
- Pod 정보
- Node 정보
- ServiceAccount 정보
- ConfigMap, Secret 등 모든 리소스

**실행 위치**:
```bash
# EKS의 경우 (관리형 서비스이므로 직접 접근 불가)
# AWS가 관리하는 내부 컴포넌트
```

### 3. Controller Manager (kube-controller-manager)

**위치**: Control Plane (마스터 노드)  
**자동 구성**: ✅ 네, 클러스터 생성 시 자동 구성  
**역할**: 다양한 Controller 실행

**포함된 Controller들**:
- **Node Controller**: Node 상태 모니터링
- **Replication Controller**: ReplicaSet 관리
- **ServiceAccount Controller**: ServiceAccount Token 생성
- **Token Controller**: ServiceAccount Token 관리
- **Namespace Controller**: Namespace 관리
- **Endpoints Controller**: Service Endpoints 관리
- 등등...

**실행 위치**:
```bash
# EKS의 경우
kubectl get pods -n kube-system | grep controller-manager

# 출력 예시:
# kube-controller-manager-ip-10-0-1-xxx    1/1   Running
```

### 4. Scheduler (kube-scheduler)

**위치**: Control Plane (마스터 노드)  
**자동 구성**: ✅ 네, 클러스터 생성 시 자동 구성  
**역할**: Pod를 적절한 노드에 배치

**기능**:
- Pending 상태의 Pod 감지
- 적절한 노드 선택
- 리소스 요구사항 확인
- 노드 제약 조건 확인

**실행 위치**:
```bash
# EKS의 경우
kubectl get pods -n kube-system | grep scheduler

# 출력 예시:
# kube-scheduler-ip-10-0-1-xxx    1/1   Running
```

## 🔧 Worker Node (워커 노드) 컴포넌트

### 1. kubelet

**위치**: 각 Worker Node  
**자동 구성**: ✅ 네, 노드 등록 시 자동 구성  
**역할**: Pod 실행 관리

**기능**:
- API Server와 통신
- Pod 실행/중지
- 컨테이너 상태 모니터링
- 노드 상태 보고

**실행 위치**:
```bash
# 각 노드에서 시스템 서비스로 실행
# 직접 확인은 어렵지만, 노드 상태로 확인 가능
kubectl get nodes
kubectl describe node <node-name>
```

### 2. kube-proxy

**위치**: 각 Worker Node  
**자동 구성**: ✅ 네, 노드 등록 시 자동 구성  
**역할**: 네트워크 프록시

**기능**:
- Service의 가상 IP 관리
- Pod 간 네트워크 라우팅
- LoadBalancer/NodePort 구현

**실행 위치**:
```bash
# 각 노드에서 DaemonSet으로 실행
kubectl get pods -n kube-system | grep kube-proxy

# 출력 예시:
# kube-proxy-xxx    1/1   Running
```

### 3. Container Runtime

**위치**: 각 Worker Node  
**자동 구성**: ✅ 네, 노드 등록 시 자동 구성  
**역할**: 컨테이너 실행

**종류**:
- Docker
- containerd (최신 기본값)
- CRI-O

**기능**:
- 컨테이너 이미지 다운로드
- 컨테이너 실행/중지
- 컨테이너 로그 관리

## 🔄 컴포넌트 간 상호작용

### 예시: Pod 생성 흐름

```
1. 사용자
   kubectl apply -f pod.yaml
   ↓
2. API Server
   - 요청 수신
   - 인증/인가 확인
   - etcd에 Pod 정보 저장
   ↓
3. etcd
   - Pod 정보 저장
   ↓
4. Controller Manager
   - Pod 상태 확인
   ↓
5. Scheduler
   - Pending Pod 감지
   - 적절한 노드 선택
   - etcd에 노드 정보 업데이트
   ↓
6. API Server
   - 노드 정보 업데이트
   ↓
7. kubelet (선택된 노드)
   - API Server에서 Pod 정보 가져옴
   - Container Runtime에 컨테이너 실행 요청
   ↓
8. Container Runtime
   - 컨테이너 실행
   ↓
9. kubelet
   - Pod 상태를 API Server에 보고
   ↓
10. etcd
    - Pod 상태 업데이트
```

## 📍 EKS (Elastic Kubernetes Service)의 경우

### 관리형 서비스

EKS는 AWS가 관리하는 Kubernetes 서비스입니다:

**AWS가 관리하는 것들**:
- ✅ Control Plane (API Server, etcd, Controller Manager, Scheduler)
- ✅ 자동 업데이트 및 패치
- ✅ 고가용성 구성

**사용자가 관리하는 것들**:
- Worker Nodes (EC2 인스턴스)
- Pod, Service 등 애플리케이션 리소스

### 확인 방법

```bash
# Control Plane 컴포넌트 확인
kubectl get pods -n kube-system

# 출력 예시:
# NAME                                    READY   STATUS
# kube-apiserver-xxx                      1/1     Running
# kube-controller-manager-xxx              1/1     Running
# kube-scheduler-xxx                       1/1     Running
# kube-proxy-xxx                           1/1     Running
```

## 🔍 실제 확인 방법

### 1. API Server 확인

```bash
# 클러스터 정보 확인
kubectl cluster-info

# API Server 주소 확인
kubectl config view | grep server

# API Server Pod 확인 (EKS의 경우)
kubectl get pods -n kube-system | grep apiserver
```

### 2. Controller Manager 확인

```bash
# Controller Manager Pod 확인
kubectl get pods -n kube-system | grep controller-manager

# Controller Manager 로그 확인
kubectl logs -n kube-system <controller-manager-pod>
```

### 3. Scheduler 확인

```bash
# Scheduler Pod 확인
kubectl get pods -n kube-system | grep scheduler

# Scheduler 로그 확인
kubectl logs -n kube-system <scheduler-pod>
```

### 4. kube-proxy 확인

```bash
# kube-proxy Pod 확인
kubectl get pods -n kube-system | grep kube-proxy

# kube-proxy DaemonSet 확인
kubectl get daemonset -n kube-system kube-proxy
```

### 5. 전체 컴포넌트 확인

```bash
# 모든 시스템 Pod 확인
kubectl get pods -n kube-system

# 노드 정보 확인
kubectl get nodes -o wide

# 노드 상세 정보
kubectl describe node <node-name>
```

## 💡 핵심 정리

### Kubernetes API Server

- **위치**: Control Plane (마스터 노드)
- **자동 구성**: ✅ 네, 클러스터 생성 시 자동 구성
- **역할**: 모든 요청의 중앙 게이트웨이

### 주요 컴포넌트

**Control Plane (마스터 노드)**:
1. **API Server**: 모든 요청의 중앙 게이트웨이
2. **etcd**: 클러스터 상태 저장소
3. **Controller Manager**: 다양한 Controller 실행
4. **Scheduler**: Pod를 노드에 배치

**Worker Node (워커 노드)**:
1. **kubelet**: Pod 실행 관리
2. **kube-proxy**: 네트워크 프록시
3. **Container Runtime**: 컨테이너 실행

### EKS의 경우

- Control Plane은 AWS가 관리 (사용자 접근 불가)
- Worker Nodes는 사용자가 관리
- 모든 컴포넌트는 자동으로 구성됨

## 📚 참고 자료

- [Kubernetes 컴포넌트 문서](https://kubernetes.io/docs/concepts/overview/components/)
- [EKS 아키텍처](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Kubernetes API Server](https://kubernetes.io/docs/concepts/overview/components/#kube-apiserver)

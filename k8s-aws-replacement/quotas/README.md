# Resource Quotas 및 Limit Ranges

리소스 할당량과 제한을 관리하여 클러스터 리소스를 효율적으로 사용합니다.

## ResourceQuota

네임스페이스 전체에 대한 리소스 제한을 설정합니다.

- CPU/메모리 요청 및 제한
- PVC, Pod, Service 수 제한
- Secret, ConfigMap 수 제한

## LimitRange

컨테이너에 대한 기본 리소스 제한을 설정합니다.

- 기본 CPU/메모리 제한
- 최소/최대 리소스 제한
- PVC 크기 제한


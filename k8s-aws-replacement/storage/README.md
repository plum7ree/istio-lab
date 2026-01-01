# Persistent Storage

Kubernetes PersistentVolume 및 PersistentVolumeClaim을 사용하여 영구 스토리지를 관리합니다 (AWS EBS 대체).

## StorageClass 타입

- **fast-ssd**: 고성능 SSD 스토리지 (GP3)
- **standard-hdd**: 표준 HDD 스토리지 (ST1)

## 특징

- 동적 볼륨 프로비저닝
- 볼륨 확장 지원
- 접근 모드: ReadWriteOnce, ReadWriteMany, ReadOnlyMany
- 리클레임 정책: Delete, Retain


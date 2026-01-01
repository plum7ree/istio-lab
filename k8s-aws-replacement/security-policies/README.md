# NetworkPolicy

NetworkPolicy는 Pod 간 네트워크 통신을 제어합니다 (AWS Security Groups 대체).

## 특징

- Pod 레벨 네트워크 격리
- 네임스페이스 레벨 접근 제어
- 인그레스/이그레스 규칙 정의
- 포트 기반 필터링

## 주의사항

NetworkPolicy를 사용하려면 CNI 플러그인이 NetworkPolicy를 지원해야 합니다 (예: Calico, Cilium, Weave Net).


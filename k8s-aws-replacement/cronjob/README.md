# CronJob 및 Job

CronJob은 스케줄링된 작업을 실행합니다 (AWS EventBridge/CloudWatch Events 대체).

## CronJob 특징

- Cron 표현식으로 스케줄 정의
- 동시 실행 정책 (Allow, Forbid, Replace)
- 성공/실패 히스토리 보관
- 시간대 설정 가능

## Job 특징

- 일회성 작업 실행
- 완료/병렬성 제어
- 재시도 정책

## Cron 표현식 예시

- `0 * * * *` - 매시간
- `0 0 * * *` - 매일 자정
- `0 0 * * 0` - 매주 일요일
- `*/5 * * * *` - 5분마다


# StatefulSet

StatefulSet은 상태가 있는 애플리케이션을 배포할 때 사용합니다 (데이터베이스, 캐시 등 - AWS RDS 대체 예시).

## 특징

- 안정적인 네트워크 식별자
- 안정적인 스토리지
- 순서대로 배포 및 스케일링
- 순서대로 삭제 및 업데이트

## 사용 사례

- 데이터베이스 (MySQL, PostgreSQL, MongoDB)
- 캐시 (Redis, Memcached)
- 메시징 시스템 (Kafka, RabbitMQ)


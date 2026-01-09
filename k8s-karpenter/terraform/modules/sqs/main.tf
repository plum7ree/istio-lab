# SQS 큐 (Spot 인터럽션)
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  receive_wait_time_seconds = 20

  tags = {
    Name = "${var.cluster_name}-karpenter-interruption"
  }
}

# SQS 큐 정책 (EventBridge가 메시지를 보낼 수 있도록)
resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = var.karpenter_controller_role_arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

# EventBridge Rule (Spot 인터럽션 이벤트)
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Spot 인스턴스 인터럽션 이벤트"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Name = "${var.cluster_name}-karpenter-spot-interruption"
  }
}

# EventBridge Target (SQS 큐로 전송)
resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# EventBridge Rule (Rebalance 권장 이벤트)
resource "aws_cloudwatch_event_rule" "rebalance_recommendation" {
  name        = "${var.cluster_name}-karpenter-rebalance-recommendation"
  description = "EC2 Rebalance 권장 이벤트"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = {
    Name = "${var.cluster_name}-karpenter-rebalance-recommendation"
  }
}

# EventBridge Target (SQS 큐로 전송)
resource "aws_cloudwatch_event_target" "rebalance_recommendation" {
  rule      = aws_cloudwatch_event_rule.rebalance_recommendation.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

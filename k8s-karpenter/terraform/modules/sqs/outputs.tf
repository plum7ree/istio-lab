output "queue_name" {
  description = "SQS 큐 이름"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "queue_url" {
  description = "SQS 큐 URL"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "queue_arn" {
  description = "SQS 큐 ARN"
  value       = aws_sqs_queue.karpenter_interruption.arn
}

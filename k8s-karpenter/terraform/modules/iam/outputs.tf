output "karpenter_controller_role_arn" {
  description = "Karpenter Controller IAM 역할 ARN"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_arn" {
  description = "Karpenter Node IAM 역할 ARN"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Karpenter Node 인스턴스 프로파일 이름"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_node_instance_profile_arn" {
  description = "Karpenter Node 인스턴스 프로파일 ARN"
  value       = aws_iam_instance_profile.karpenter_node.arn
}

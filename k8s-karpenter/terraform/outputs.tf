output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS 클러스터 CA 인증서"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "EKS 클러스터 보안 그룹 ID"
  value       = module.eks.cluster_security_group_id
}

output "karpenter_controller_role_arn" {
  description = "Karpenter Controller IAM 역할 ARN"
  value       = module.karpenter_iam.karpenter_controller_role_arn
}

output "karpenter_node_role_arn" {
  description = "Karpenter Node IAM 역할 ARN"
  value       = module.karpenter_iam.karpenter_node_role_arn
}

output "karpenter_node_instance_profile_name" {
  description = "Karpenter Node 인스턴스 프로파일 이름"
  value       = module.karpenter_iam.karpenter_node_instance_profile_name
}


output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 리스트"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 리스트"
  value       = module.vpc.public_subnets
}

output "aws_region" {
  description = "AWS 리전"
  value       = var.aws_region
}

output "kubectl_config_command" {
  description = "kubectl 설정 명령어"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

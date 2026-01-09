variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "karpenter_controller_role_arn" {
  description = "Karpenter Controller IAM 역할 ARN"
  type        = string
}

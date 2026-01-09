variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "EKS 클러스터 OIDC Provider ARN"
  type        = string
}

variable "cluster_oidc_provider_url" {
  description = "EKS 클러스터 OIDC Provider URL"
  type        = string
}

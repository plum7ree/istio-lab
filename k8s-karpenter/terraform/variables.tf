variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes 버전"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 블록 리스트"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록 리스트"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "single_nat_gateway" {
  description = "단일 NAT Gateway 사용 여부 (비용 절감)"
  type        = bool
  default     = false
}

variable "create_managed_node_group" {
  description = "EKS 관리형 노드 그룹 생성 여부 (Karpenter와 함께 사용 가능)"
  type        = bool
  default     = true
}

variable "karpenter_version" {
  description = "Karpenter Helm 차트 버전"
  type        = string
  default     = "v0.37.0"
}

variable "instance_types" {
  description = "Karpenter가 사용할 인스턴스 타입 리스트"
  type        = list(string)
  default = [
    "t3.medium",
    "t3.large",
    "t3.xlarge",
    "m5.large",
    "m5.xlarge",
    "c5.large",
    "c5.xlarge"
  ]
}

variable "capacity_types" {
  description = "용량 타입 (on-demand만 사용, spot은 제거됨)"
  type        = list(string)
  default     = ["on-demand"]
}

variable "node_pool_cpu_limit" {
  description = "NodePool 최대 CPU 제한"
  type        = string
  default     = "1000"
}

variable "node_pool_memory_limit" {
  description = "NodePool 최대 메모리 제한"
  type        = string
  default     = "1000Gi"
}

variable "ami_family" {
  description = "AMI 패밀리 (AL2, Bottlerocket, Ubuntu 등)"
  type        = string
  default     = "AL2"
}

variable "block_device_mappings" {
  description = "EBS 블록 디바이스 매핑"
  type = list(object({
    device_name = string
    ebs = object({
      volume_size = number
      volume_type = string
      encrypted   = bool
      delete_on_termination = bool
    })
  }))
  default = [{
    device_name = "/dev/xvda"
    ebs = {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }]
}

variable "deploy_webapp" {
  description = "웹앱 자동 배포 여부"
  type        = bool
  default     = true
}

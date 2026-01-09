terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Karpenter"
    }
  }
}

# Kubernetes Provider (EKS 클러스터 연결)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

# Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name
      ]
    }
  }
}

# Kubectl Provider
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC 모듈 (기존 VPC 사용 시 이 모듈 제거하고 data source 사용)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    # Karpenter가 서브넷을 찾기 위한 태그
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# EKS 클러스터
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS 관리형 노드 그룹 (선택사항 - Karpenter와 함께 사용 가능)
  eks_managed_node_groups = var.create_managed_node_group ? {
    initial = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  } : {}

  # 클러스터 엔드포인트 접근 제어
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # 클러스터 보안 그룹 태그 (Karpenter가 찾기 위해)
  cluster_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                = "Karpenter webhook"
      protocol                   = "tcp"
      from_port                  = 8443
      to_port                    = 8443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # 클러스터 태그
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# 보안 그룹 태그 (Karpenter가 찾기 위해)
resource "aws_security_group" "karpenter" {
  name        = "${var.cluster_name}-karpenter-sg"
  description = "Security group for Karpenter nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow all traffic from cluster"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                        = "${var.cluster_name}-karpenter-sg"
    "karpenter.sh/discovery"    = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Karpenter IAM 역할 및 정책
module "karpenter_iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_oidc_provider_url = module.eks.oidc_provider_url
}

# Karpenter Helm 설치
resource "helm_release" "karpenter" {
  namespace        = "karpenter-system"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.defaultInstanceProfile"
    value = module.karpenter_iam.karpenter_node_instance_profile_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_iam.karpenter_controller_role_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter_iam.karpenter_node_instance_profile_name
  }

  depends_on = [
    module.eks,
    module.karpenter_iam
  ]
}

# Karpenter Namespace (Helm이 생성하지만 명시적으로 관리)
resource "kubectl_manifest" "karpenter_namespace" {
  yaml_body = templatefile("${path.module}/templates/namespace.yaml.tpl", {})

  depends_on = [
    helm_release.karpenter
  ]
}

# Karpenter ServiceAccount (IRSA annotation 업데이트)
resource "kubectl_manifest" "karpenter_serviceaccount" {
  yaml_body = templatefile("${path.module}/templates/serviceaccount.yaml.tpl", {
    controller_role_arn = module.karpenter_iam.karpenter_controller_role_arn
  })

  depends_on = [
    helm_release.karpenter
  ]
}

# Karpenter ConfigMap (추가 설정)
resource "kubectl_manifest" "karpenter_config" {
  yaml_body = templatefile("${path.module}/templates/karpenter-config.yaml.tpl", {
    cluster_name         = var.cluster_name
    instance_profile     = module.karpenter_iam.karpenter_node_instance_profile_name
  })

  depends_on = [
    helm_release.karpenter
  ]
}

# Karpenter Profile ConfigMap (EKS 환경 정보)
resource "kubectl_manifest" "karpenter_profile_eks" {
  yaml_body = templatefile("${path.module}/templates/profile-eks.yaml.tpl", {
    cluster_name         = var.cluster_name
    node_role_arn        = module.karpenter_iam.karpenter_node_role_arn
    instance_profile     = module.karpenter_iam.karpenter_node_instance_profile_name
    aws_region           = var.aws_region
  })

  depends_on = [
    helm_release.karpenter
  ]
}

# Karpenter NodePool
resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = templatefile("${path.module}/templates/nodepool.yaml.tpl", {
    cluster_name = var.cluster_name
    node_class_name = "default"
    instance_types = var.instance_types
    availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)
    capacity_types = var.capacity_types
    cpu_limit = var.node_pool_cpu_limit
    memory_limit = var.node_pool_memory_limit
  })

  depends_on = [
    helm_release.karpenter
  ]
}

# Karpenter EC2NodeClass
resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  yaml_body = templatefile("${path.module}/templates/ec2nodeclass.yaml.tpl", {
    cluster_name          = var.cluster_name
    node_role_arn         = module.karpenter_iam.karpenter_node_role_arn
    ami_family            = var.ami_family
    block_device_mappings = var.block_device_mappings
  })

  depends_on = [
    helm_release.karpenter
  ]
}

# 웹앱 배포 (선택사항)
resource "kubectl_manifest" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  yaml_body = templatefile("${path.module}/templates/webapp.yaml.tpl", {})

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_ec2nodeclass
  ]
}

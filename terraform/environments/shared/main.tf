terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "kodatala-terraform-state"
    key            = "3-tier-user-platform/shared/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Cluster-wide resources that both qa and (eventually) prod depend on.
# Apply this once -- do not duplicate it per-environment.
module "cluster_shared" {
  source = "../../modules/cluster-shared"

  aws_region                = var.aws_region
  eks_cluster_name          = var.eks_cluster_name
  alb_controller_role_name  = var.alb_controller_role_name
}

output "oidc_provider_arn" {
  value = module.cluster_shared.oidc_provider_arn
}

output "alb_controller_role_arn" {
  value = module.cluster_shared.alb_controller_role_arn
}

output "ebs_csi_role_arn" {
  value = module.cluster_shared.ebs_csi_role_arn
}

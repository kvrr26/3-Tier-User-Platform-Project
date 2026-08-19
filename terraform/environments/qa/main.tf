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
    key            = "3-tier-user-platform/qa/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "qa" {
  source = "../../modules/namespace-infra"

  environment       = "qa"
  aws_region        = var.aws_region
  eks_cluster_name  = var.eks_cluster_name
  route53_zone_name = var.route53_zone_name
  app_hostname      = var.app_hostname
  alb_dns_name      = var.alb_dns_name

  eso_service_account_name = "eso-qa-sa"
  mysql_secret_name         = "qa/mysql-secret"
  mysql_secret_values       = var.mysql_secret_values
}

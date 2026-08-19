variable "aws_region" {
  description = "AWS region the EKS cluster lives in."
  type        = string
  default     = "ap-south-1"
}

variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster (created outside this Terraform, via eksctl)."
  type        = string
  default     = "my-cluster"
}

variable "alb_controller_namespace" {
  type    = string
  default = "kube-system"
}

variable "alb_controller_service_account_name" {
  type    = string
  default = "aws-load-balancer-controller"
}

variable "alb_controller_role_name" {
  description = <<-EOT
    Name of the existing IAM role bound to the aws-load-balancer-controller service account.
    eksctl auto-generated this name when the role was originally created. Find it with:
      aws iam list-roles --query "Roles[?contains(RoleName, 'aws-load-balancer-controller')].RoleName" --output text
  EOT
  type = string
}

variable "ebs_csi_namespace" {
  type    = string
  default = "kube-system"
}

variable "ebs_csi_service_account_name" {
  type    = string
  default = "ebs-csi-controller-sa"
}

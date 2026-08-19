variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "eks_cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "alb_controller_role_name" {
  description = <<-EOT
    Name of the existing IAM role bound to the aws-load-balancer-controller service account.
    eksctl auto-generated this name when the role was originally created. Find it with:
      aws iam list-roles --query "Roles[?contains(RoleName, 'aws-load-balancer-controller')].RoleName" --output text
  EOT
  type = string
}

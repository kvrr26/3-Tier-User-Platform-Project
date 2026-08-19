variable "environment" {
  description = "Environment name (qa, prod, ...). Used for naming and matches the Kubernetes namespace."
  type        = string
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "eks_cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "route53_zone_name" {
  description = "Existing Route 53 public hosted zone name. Must already exist -- not created by this module."
  type        = string
}

variable "app_hostname" {
  description = "Hostname the app's ingress is reachable at, e.g. qa.kodatala.space."
  type        = string
}

variable "alb_dns_name" {
  description = <<-EOT
    DNS name of the ALB the AWS Load Balancer Controller created for this environment's ingress.
    Not known until after `kubectl apply -f k8-manifests/<env>/app-ingress.yaml` has run once. Get it with:
      kubectl get ingress app-ingress -n <environment> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    This module does not manage the Ingress object or the ALB itself -- only this one DNS record.
  EOT
  type = string
}

variable "eso_service_account_name" {
  type    = string
  default = "eso-qa-sa"
}

variable "mysql_secret_name" {
  description = "Secrets Manager secret name, e.g. qa/mysql-secret. Must match the `key` used in k8-manifests/<env>/external-secret.yaml."
  type        = string
}

variable "mysql_secret_values" {
  description = "MySQL credentials stored in Secrets Manager. Pass via a gitignored terraform.tfvars or TF_VAR_mysql_secret_values -- never commit real values."
  type = object({
    MYSQL_ROOT_PASSWORD = string
    MYSQL_DATABASE      = string
    MYSQL_USER          = string
    MYSQL_PASSWORD      = string
    DATABASE_URL        = string
  })
  sensitive = true
}

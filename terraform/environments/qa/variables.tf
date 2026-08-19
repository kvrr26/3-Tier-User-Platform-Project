variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "eks_cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "route53_zone_name" {
  type    = string
  default = "kodatala.space"
}

variable "app_hostname" {
  type    = string
  default = "qa.kodatala.space"
}

variable "alb_dns_name" {
  description = "Get with: kubectl get ingress app-ingress -n qa -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  type        = string
}

variable "mysql_secret_values" {
  type = object({
    MYSQL_ROOT_PASSWORD = string
    MYSQL_DATABASE      = string
    MYSQL_USER          = string
    MYSQL_PASSWORD      = string
    DATABASE_URL        = string
  })
  sensitive = true
}

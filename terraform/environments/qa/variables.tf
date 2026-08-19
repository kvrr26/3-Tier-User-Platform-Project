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
  # Not sensitive -- just the ALB's DNS name. Defaulted so CI (which has no local terraform.tfvars)
  # can still run `terraform plan` for drift detection. Update this if the ALB is ever recreated
  # (e.g. after deleting/reapplying the Ingress) and the hostname changes.
  default = "k8s-qa-appingre-0e3ea22415-650864527.ap-south-1.elb.amazonaws.com"
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
  # This placeholder is safe: aws_secretsmanager_secret_version.mysql (in the namespace-infra
  # module) has `lifecycle { ignore_changes = [secret_string] }`, so whatever value this variable
  # holds during `plan`/`apply` is never compared against or written to the real secret in AWS --
  # the actual credentials only ever live in Secrets Manager and in the gitignored local
  # terraform.tfvars. This default exists purely so CI can run `terraform plan` without needing
  # real passwords anywhere in git or in GitHub secrets.
  default = {
    MYSQL_ROOT_PASSWORD = "placeholder-not-real-see-comment-above"
    MYSQL_DATABASE      = "placeholder-not-real-see-comment-above"
    MYSQL_USER           = "placeholder-not-real-see-comment-above"
    MYSQL_PASSWORD        = "placeholder-not-real-see-comment-above"
    DATABASE_URL          = "placeholder-not-real-see-comment-above"
  }
}

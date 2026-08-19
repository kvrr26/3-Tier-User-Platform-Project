output "eso_role_arn" {
  value = module.qa.eso_role_arn
}

output "acm_certificate_arn" {
  value = module.qa.acm_certificate_arn
}

output "mysql_secret_arn" {
  value = module.qa.mysql_secret_arn
}

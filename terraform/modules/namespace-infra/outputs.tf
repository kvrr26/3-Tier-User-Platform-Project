output "eso_role_arn" {
  value = aws_iam_role.eso.arn
}

output "eso_policy_arn" {
  value = aws_iam_policy.eso_secrets_read.arn
}

output "mysql_secret_arn" {
  value = aws_secretsmanager_secret.mysql.arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate_validation.app.certificate_arn
}

output "app_hostname" {
  value = var.app_hostname
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_route53_zone" "this" {
  name         = var.route53_zone_name
  private_zone = false
}

# ---------------------------------------------------------------------------
# External Secrets Operator: IAM policy + IRSA role, scoped to this namespace's secret only
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eso_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.environment}:${var.eso_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eso_secrets_read" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.mysql_secret_name}*",
    ]
  }
}

resource "aws_iam_policy" "eso_secrets_read" {
  name        = "ESOSecretsManager${upper(var.environment)}ReadPolicy"
  description = "Read-only access to ${var.mysql_secret_name} for External Secrets Operator (${var.environment})."
  policy      = data.aws_iam_policy_document.eso_secrets_read.json

  # description is set at creation only -- AWS's API has no "update description" call, so
  # Terraform treats any drift here as force-replace. The policy was created manually via the
  # AWS CLI with no description set; rather than destroying/recreating the live policy (which
  # would briefly detach ESO's Secrets Manager access), just ignore drift on this field.
  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_iam_role" "eso" {
  name               = "eso-${var.environment}-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json

  # This role was originally created by eksctl, which tagged it with alpha.eksctl.io/* /
  # eksctl.cluster.k8s.io/* bookkeeping tags. We don't declare tags here, so ignore them
  # instead of having every `apply` want to strip them.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_iam_role_policy_attachment" "eso" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_secrets_read.arn
}

# ---------------------------------------------------------------------------
# Secrets Manager: the MySQL credentials ESO syncs into a Kubernetes Secret
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "mysql" {
  name        = var.mysql_secret_name
  description = "MySQL credentials for the ${var.environment} namespace, synced into Kubernetes by External Secrets Operator."
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id     = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode(var.mysql_secret_values)

  # The secret's value can be rotated/updated out-of-band (manually, or by a rotation Lambda) --
  # don't fight that on every `terraform apply`.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# ACM certificate for the app's ingress hostname, DNS-validated via Route 53
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "app" {
  domain_name       = var.app_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "app_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.app_cert_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# DNS record pointing the app hostname at the ALB the AWS Load Balancer
# Controller created. This does NOT manage the Ingress object or the ALB
# itself -- alb_dns_name is a manual input (see variables.tf).
# ---------------------------------------------------------------------------

resource "aws_route53_record" "app" {
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = var.app_hostname
  type            = "CNAME"
  ttl             = 300
  records         = [var.alb_dns_name]
  allow_overwrite = true
}

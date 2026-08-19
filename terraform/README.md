# Terraform for 3-Tier-User-Platform-Project

This codifies the AWS-side infrastructure that was set up manually while getting `qa` working:
IAM roles/policies for IRSA (ESO, EBS CSI driver, ALB controller), the `qa/mysql-secret` in
Secrets Manager, the ACM certificate for `qa.kodatala.space`, and the Route 53 records.

## What this does NOT manage

On purpose, to keep risk low and match what's proven working:

- The EKS cluster and its VPC/subnets (`my-cluster`) -- still created/managed via `eksctl`.
- The Helm releases for the AWS Load Balancer Controller and External Secrets Operator.
- All Kubernetes objects under `k8-manifests/` (StorageClass, MySQL StatefulSet/Service,
  SecretStore, ExternalSecret, app Deployment/Service/Ingress) -- still applied via `kubectl`.

The seam between the two: `alb_dns_name` in `environments/qa` is a manual input you copy from
`kubectl get ingress` after applying the Ingress -- this Terraform only manages the DNS record
that points at it, not the ALB or the Ingress object itself.

## Layout

```
terraform/
  modules/
    cluster-shared/     # OIDC lookup, EBS CSI driver role+addon, ALB controller role -- apply once
    namespace-infra/     # per-environment: ESO role+policy, Secrets Manager secret, ACM cert, DNS
  environments/
    shared/               # calls cluster-shared -- run this first
    qa/                    # calls namespace-infra with environment = "qa"
```

To add `prod` later: copy `environments/qa` to `environments/prod`, change the `environment`,
`app_hostname`, and secret values, and reuse `environments/shared` as-is (don't reapply it a
second time from a different environment folder).

## First-time setup: importing existing resources

Every resource this Terraform defines **already exists** in AWS -- it was created manually via
the AWS CLI / `eksctl` while setting up `qa`. Running `terraform apply` without importing first
will fail with "already exists" errors (or worse, try to create duplicates). Import each resource
into state before your first `plan`/`apply`.

### 1. `environments/shared`

```bash
cd terraform/environments/shared
cp terraform.tfvars.example terraform.tfvars   # fill in alb_controller_role_name -- see the file for how to find it
terraform init

terraform import module.cluster_shared.aws_iam_role.alb_controller <ALB_CONTROLLER_ROLE_NAME>
terraform import module.cluster_shared.aws_iam_role_policy_attachment.alb_controller \
  <ALB_CONTROLLER_ROLE_NAME>/arn:aws:iam::986232521987:policy/AWSLoadBalancerControllerIAMPolicy

terraform import module.cluster_shared.aws_iam_role.ebs_csi AmazonEKS_EBS_CSI_DriverRole
terraform import module.cluster_shared.aws_iam_role_policy_attachment.ebs_csi \
  AmazonEKS_EBS_CSI_DriverRole/arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy

terraform import module.cluster_shared.aws_eks_addon.ebs_csi my-cluster:aws-ebs-csi-driver

terraform plan   # should show no changes (or only cosmetic ones, e.g. missing tags)
```

### 2. `environments/qa`

```bash
cd terraform/environments/qa
cp terraform.tfvars.example terraform.tfvars   # fill in alb_dns_name and the real mysql_secret_values
terraform init

terraform import module.qa.aws_iam_policy.eso_secrets_read \
  arn:aws:iam::986232521987:policy/ESOSecretsManagerQAReadPolicy
terraform import module.qa.aws_iam_role.eso eso-qa-secrets-role
terraform import module.qa.aws_iam_role_policy_attachment.eso \
  eso-qa-secrets-role/arn:aws:iam::986232521987:policy/ESOSecretsManagerQAReadPolicy

terraform import module.qa.aws_secretsmanager_secret.mysql qa/mysql-secret
# Get the current version ID first:
#   aws secretsmanager describe-secret --secret-id qa/mysql-secret --query "VersionIdsToStages"
terraform import module.qa.aws_secretsmanager_secret_version.mysql qa/mysql-secret|<VERSION_ID>

terraform import module.qa.aws_acm_certificate.app \
  arn:aws:acm:ap-south-1:986232521987:certificate/56677b9e-b6b9-41a0-bc88-143b7c58df17
terraform import module.qa.aws_acm_certificate_validation.app \
  arn:aws:acm:ap-south-1:986232521987:certificate/56677b9e-b6b9-41a0-bc88-143b7c58df17

terraform plan   # should show no changes
```

The two `aws_route53_record` resources (the cert validation CNAME and the `qa.kodatala.space`
CNAME) don't need explicit import -- both are declared with `allow_overwrite = true`, so the
first `apply` will just adopt the existing records in place rather than failing or duplicating
them.

## Day-to-day usage

Once imported and `plan` shows no unexpected changes:

```bash
terraform plan
terraform apply
```

Treat this as the source of truth going forward -- future changes to these AWS resources (e.g.
rotating the ESO policy, adding a new ACM domain) should go through Terraform rather than the
AWS CLI, so state doesn't drift again.

## Remote state

Both `environments/*/main.tf` default to local state (`terraform.tfstate` on disk, gitignored)
so `terraform init` works with zero extra setup. Before more than one person touches this, move
to a remote backend (S3 + DynamoDB lock table) -- an example block is commented out at the top of
each `main.tf`. Note the existing `kodatala.space` Route 53 zone is already Terraform-managed
elsewhere (its `CallerReference` shows a `terraform-...` origin) -- ask whoever owns that config
whether there's already a shared state bucket/backend convention you should reuse here.

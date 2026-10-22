output "region" {
  value = var.region
}

output "account_id" {
  value = local.account_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "s3_bucket_names" {
  value = module.s3_storage.bucket_names
}

output "s3_kms_key_arns" {
  value = module.s3_storage.kms_key_arns
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "grafana_db_endpoint" {
  value = module.rds_grafana.endpoint
}

output "grafana_db_credentials_secret_arn" {
  value = module.rds_grafana.credentials_secret_arn
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --alias observability"
}

output "irsa_role_arns" {
  value = module.iam_irsa.role_arns
}

output "s3_bucket_arns" {
  value = module.s3_storage.bucket_arns
}

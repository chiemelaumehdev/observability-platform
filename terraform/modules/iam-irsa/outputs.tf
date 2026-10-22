output "role_arns" {
  description = "IRSA role ARNs keyed by workload name."
  value       = { for k, r in aws_iam_role.irsa : k => r.arn }
}

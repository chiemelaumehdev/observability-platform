output "endpoint" {
  value = aws_db_instance.grafana.address
}

output "port" {
  value = aws_db_instance.grafana.port
}

output "db_name" {
  value = aws_db_instance.grafana.db_name
}

output "security_group_id" {
  value = aws_security_group.grafana_db.id
}

output "credentials_secret_arn" {
  value = aws_secretsmanager_secret.grafana_db.arn
}

output "credentials_secret_name" {
  value = aws_secretsmanager_secret.grafana_db.name
}

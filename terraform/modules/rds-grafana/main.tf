resource "random_password" "grafana_db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "grafana_db" {
  name                    = "${var.name}-db-credentials"
  description             = "RDS credentials for the Grafana config database"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "grafana_db" {
  secret_id = aws_secretsmanager_secret.grafana_db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.grafana_db.result
    engine   = "postgres"
    host     = aws_db_instance.grafana.address
    port     = aws_db_instance.grafana.port
    dbname   = aws_db_instance.grafana.db_name
  })
}

resource "aws_db_subnet_group" "grafana" {
  name       = "${var.name}-grafana"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "grafana_db" {
  name        = "${var.name}-grafana-db"
  description = "RDS access for Grafana"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Postgres from allowed security groups"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "grafana" {
  identifier     = "${var.name}-grafana"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "grafana"
  username = var.db_username
  password = random_password.grafana_db.result

  db_subnet_group_name   = aws_db_subnet_group.grafana.name
  vpc_security_group_ids = [aws_security_group.grafana_db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  deletion_protection      = false
  skip_final_snapshot      = true
  delete_automated_backups = true

  performance_insights_enabled = true
  monitoring_interval          = 0
  copy_tags_to_snapshot        = true

  tags = {
    Name = "${var.name}-grafana"
  }
}

output "db_endpoint" {
  description = "Writer endpoint for the database"
  value       = local.is_aurora ? aws_rds_cluster.main[0].endpoint : aws_db_instance.main[0].address
}

output "db_reader_endpoint" {
  description = "Reader endpoint (Aurora reader / same as writer for standard RDS)"
  value       = local.is_aurora ? aws_rds_cluster.main[0].reader_endpoint : aws_db_instance.main[0].address
}

output "db_port" {
  description = "Database port"
  value       = local.db_port
}

output "db_name" {
  description = "Name of the created database"
  value       = var.db_name
}

output "db_username" {
  description = "Master DB username"
  value       = var.db_username
}

output "security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret (null if secrets_manager=false)"
  value       = var.secrets_manager ? aws_secretsmanager_secret.db_credentials[0].arn : null
}

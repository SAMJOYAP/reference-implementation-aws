output "primary_endpoint" {
  description = "Primary endpoint for the Redis cluster"
  value = local.is_cluster_mode ? (
    aws_elasticache_replication_group.cluster[0].configuration_endpoint_address
    ) : (
    aws_elasticache_replication_group.main[0].primary_endpoint_address
  )
}

output "reader_endpoint" {
  description = "Reader endpoint (Cluster Mode Disabled only, same as primary for Cluster Mode Enabled)"
  value = local.is_cluster_mode ? (
    aws_elasticache_replication_group.cluster[0].configuration_endpoint_address
    ) : (
    aws_elasticache_replication_group.main[0].reader_endpoint_address
  )
}

output "port" {
  description = "Redis port"
  value       = 6379
}

output "security_group_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis.id
}

output "auth_token_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the AUTH token (null if auth disabled)"
  value       = var.auth_enabled ? aws_secretsmanager_secret.auth_token[0].arn : null
}

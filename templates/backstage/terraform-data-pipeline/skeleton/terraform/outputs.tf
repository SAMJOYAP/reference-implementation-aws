output "s3_bucket_name" {
  description = "S3 Data Lake bucket name"
  value       = aws_s3_bucket.datalake.bucket
}

output "s3_bucket_arn" {
  description = "S3 Data Lake bucket ARN"
  value       = aws_s3_bucket.datalake.arn
}

output "glue_database_name" {
  description = "Glue Catalog database name (null if Glue not enabled)"
  value       = local.use_glue ? aws_glue_catalog_database.main[0].name : null
}

output "glue_crawler_name" {
  description = "Glue Crawler name (null if Glue not enabled)"
  value       = local.use_glue ? aws_glue_crawler.main[0].name : null
}

output "glue_job_name" {
  description = "Glue Job name (null if Glue not enabled)"
  value       = local.use_glue ? aws_glue_job.main[0].name : null
}

output "emr_cluster_id" {
  description = "EMR Cluster ID (null if EMR not enabled)"
  value       = local.use_emr ? aws_emr_cluster.main[0].id : null
}

output "emr_master_public_dns" {
  description = "EMR Master node public DNS (null if EMR not enabled)"
  value       = local.use_emr ? aws_emr_cluster.main[0].master_public_dns : null
}

output "kms_key_arn" {
  description = "KMS key ARN (null if KMS encryption disabled)"
  value       = var.kms_encryption ? aws_kms_key.pipeline[0].arn : null
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name (null if logging disabled)"
  value       = var.cloudwatch_logs ? aws_cloudwatch_log_group.pipeline[0].name : null
}

output "bucket_name" {
  description = "Name of the S3 bucket (includes random suffix)"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key (null if SSE-S3)"
  value       = var.kms_encryption ? aws_kms_key.bucket[0].arn : null
}

output "logs_bucket_name" {
  description = "Name of the access logs bucket (null if logging disabled)"
  value       = var.access_logging ? aws_s3_bucket.logs[0].id : null
}

output "website_endpoint" {
  description = "Static website endpoint URL (null if website disabled)"
  value       = var.website_enabled ? aws_s3_bucket_website_configuration.main[0].website_endpoint : null
}

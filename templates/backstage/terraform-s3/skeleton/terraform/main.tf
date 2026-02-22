terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment to use S3 backend for state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "${{ values.name }}/terraform.tfstate"
  #   region         = "${{ values.region }}"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Name        = var.bucket_name
      ManagedBy   = "Terraform"
      CreatedFrom = "Backstage"
      Project     = "${{ values.name }}"
      Repository  = "${{ values.remoteUrl }}"
    }
  }
}

# Random suffix ensures globally unique bucket name and prevents name collision on re-deploy
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_id = "${var.bucket_name}-${random_id.suffix.hex}"
}

# ─── S3 Bucket ──────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "main" {
  bucket        = local.bucket_id
  force_destroy = var.force_destroy

  tags = { Name = local.bucket_id }
}

# Block all public access — always enabled for security
resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACLs — recommended since April 2023 (BucketOwnerEnforced)
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ─── Versioning ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

# ─── Encryption ─────────────────────────────────────────────────────────────

resource "aws_kms_key" "bucket" {
  count               = var.kms_encryption ? 1 : 0
  description         = "KMS key for S3 bucket ${local.bucket_id}"
  enable_key_rotation = true

  tags = { Name = "${local.bucket_id}-kms-key" }
}

resource "aws_kms_alias" "bucket" {
  count         = var.kms_encryption ? 1 : 0
  name          = "alias/${local.bucket_id}-key"
  target_key_id = aws_kms_key.bucket[0].key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_encryption ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_encryption ? aws_kms_key.bucket[0].arn : null
    }
    bucket_key_enabled = var.kms_encryption
  }
}

# ─── Lifecycle Rules ─────────────────────────────────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = var.lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "lifecycle-rule"
    status = "Enabled"

    dynamic "transition" {
      for_each = var.lifecycle_ia_days > 0 ? [1] : []
      content {
        days          = var.lifecycle_ia_days
        storage_class = "STANDARD_IA"
      }
    }

    dynamic "transition" {
      for_each = var.lifecycle_glacier_days > 0 ? [1] : []
      content {
        days          = var.lifecycle_glacier_days
        storage_class = "GLACIER"
      }
    }

    dynamic "expiration" {
      for_each = var.lifecycle_expire_days > 0 ? [1] : []
      content {
        days = var.lifecycle_expire_days
      }
    }

    # Clean up incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ─── Access Logging ──────────────────────────────────────────────────────────

resource "aws_s3_bucket" "logs" {
  count         = var.access_logging ? 1 : 0
  bucket        = "${local.bucket_id}-logs"
  force_destroy = var.force_destroy

  tags = { Name = "${local.bucket_id}-logs" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = var.access_logging ? 1 : 0
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.access_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  count      = var.access_logging ? 1 : 0
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs[0].id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.access_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "main" {
  count         = var.access_logging ? 1 : 0
  bucket        = aws_s3_bucket.main.id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "access-logs/"
}

# ─── Static Website Hosting ──────────────────────────────────────────────────

resource "aws_s3_bucket_website_configuration" "main" {
  count  = var.website_enabled ? 1 : 0
  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

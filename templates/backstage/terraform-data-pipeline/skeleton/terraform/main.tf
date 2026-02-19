terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
      Name        = var.pipeline_name
      ManagedBy   = "Terraform"
      CreatedFrom = "Backstage"
      Project     = "${{ values.name }}"
      Repository  = "${{ values.remoteUrl }}"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  use_glue = var.pipeline_type == "glue" || var.pipeline_type == "both"
  use_emr  = var.pipeline_type == "emr" || var.pipeline_type == "both"
  account_id = data.aws_caller_identity.current.account_id
}

# ─── S3 Data Lake ──────────────────────────────────────────────────────────

resource "aws_s3_bucket" "datalake" {
  bucket = "${var.pipeline_name}-${var.s3_bucket_suffix}"

  tags = { Name = "${var.pipeline_name}-datalake" }
}

resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_encryption ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_encryption ? aws_kms_key.pipeline[0].arn : null
    }
    bucket_key_enabled = var.kms_encryption
  }
}

resource "aws_s3_bucket_public_access_block" "datalake" {
  bucket                  = aws_s3_bucket.datalake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 prefixes (folders)
resource "aws_s3_object" "raw_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "${var.s3_prefix}"
  content = ""
}

resource "aws_s3_object" "processed_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "processed/"
  content = ""
}

resource "aws_s3_object" "scripts_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "scripts/"
  content = ""
}

resource "aws_s3_object" "logs_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "logs/"
  content = ""
}

# ─── KMS Key ───────────────────────────────────────────────────────────────

resource "aws_kms_key" "pipeline" {
  count               = var.kms_encryption ? 1 : 0
  description         = "KMS key for ${var.pipeline_name} data pipeline"
  enable_key_rotation = true

  tags = { Name = "${var.pipeline_name}-kms-key" }
}

resource "aws_kms_alias" "pipeline" {
  count         = var.kms_encryption ? 1 : 0
  name          = "alias/${var.pipeline_name}-pipeline-key"
  target_key_id = aws_kms_key.pipeline[0].key_id
}

# ─── CloudWatch Log Group ──────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "pipeline" {
  count             = var.cloudwatch_logs ? 1 : 0
  name              = "/aws/datapipeline/${var.pipeline_name}"
  retention_in_days = 14

  tags = { Name = "${var.pipeline_name}-logs" }
}

# ─── IAM Role for Glue ─────────────────────────────────────────────────────

resource "aws_iam_role" "glue" {
  count = local.use_glue ? 1 : 0
  name  = "${var.pipeline_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.pipeline_name}-glue-role" }
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  count      = local.use_glue ? 1 : 0
  role       = aws_iam_role.glue[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  count = local.use_glue ? 1 : 0
  name  = "${var.pipeline_name}-glue-s3-policy"
  role  = aws_iam_role.glue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.datalake.arn, "${aws_s3_bucket.datalake.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = var.cloudwatch_logs ? ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"] : []
        Resource = var.cloudwatch_logs ? ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/datapipeline/${var.pipeline_name}:*"] : []
      }
    ]
  })
}

# ─── Glue Data Catalog ─────────────────────────────────────────────────────

resource "aws_glue_catalog_database" "main" {
  count = local.use_glue ? 1 : 0
  name  = replace(var.pipeline_name, "-", "_")

  description = "Glue Data Catalog database for ${var.pipeline_name}"
}

resource "aws_glue_crawler" "main" {
  count         = local.use_glue ? 1 : 0
  name          = "${var.pipeline_name}-crawler"
  role          = aws_iam_role.glue[0].arn
  database_name = aws_glue_catalog_database.main[0].name
  description   = "Crawler for ${var.pipeline_name} raw data"

  s3_target {
    path = "s3://${aws_s3_bucket.datalake.bucket}/${var.s3_prefix}"
  }

  schedule = var.crawler_schedule != "disabled" ? var.crawler_schedule : null

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = { Name = "${var.pipeline_name}-crawler" }
}

resource "aws_glue_job" "main" {
  count    = local.use_glue ? 1 : 0
  name     = "${var.pipeline_name}-job"
  role_arn = aws_iam_role.glue[0].arn

  command {
    name            = var.glue_job_type
    script_location = "s3://${aws_s3_bucket.datalake.bucket}/scripts/main.py"
    python_version  = "3"
  }

  default_arguments = merge(
    {
      "--job-bookmark-option"    = "job-bookmark-enable"
      "--SOURCE_BUCKET"          = aws_s3_bucket.datalake.bucket
      "--SOURCE_PREFIX"          = var.s3_prefix
      "--OUTPUT_PREFIX"          = "processed/"
      "--enable-metrics"         = ""
      "--enable-spark-ui"        = "true"
      "--spark-event-logs-path"  = "s3://${aws_s3_bucket.datalake.bucket}/logs/spark-ui/"
    },
    var.cloudwatch_logs ? {
      "--enable-continuous-cloudwatch-log" = "true"
      "--enable-continuous-log-filter"     = "true"
      "--continuous-log-logGroup"          = "/aws/datapipeline/${var.pipeline_name}"
    } : {}
  )

  worker_type       = var.glue_job_type == "glueetl" ? var.glue_worker_type : null
  number_of_workers = var.glue_job_type == "glueetl" ? var.glue_worker_count : null
  max_capacity      = var.glue_job_type == "pythonshell" ? 0.0625 : null

  glue_version = "4.0"
  timeout      = 60

  tags = { Name = "${var.pipeline_name}-job" }
}

# ─── IAM Role for EMR ──────────────────────────────────────────────────────

resource "aws_iam_role" "emr_service" {
  count = local.use_emr ? 1 : 0
  name  = "${var.pipeline_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.pipeline_name}-emr-service-role" }
}

resource "aws_iam_role_policy_attachment" "emr_service" {
  count      = local.use_emr ? 1 : 0
  role       = aws_iam_role.emr_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role" "emr_ec2" {
  count = local.use_emr ? 1 : 0
  name  = "${var.pipeline_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.pipeline_name}-emr-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "emr_ec2" {
  count      = local.use_emr ? 1 : 0
  role       = aws_iam_role.emr_ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_ec2" {
  count = local.use_emr ? 1 : 0
  name  = "${var.pipeline_name}-emr-ec2-profile"
  role  = aws_iam_role.emr_ec2[0].name
}

# ─── EMR Cluster ───────────────────────────────────────────────────────────

resource "aws_emr_cluster" "main" {
  count        = local.use_emr ? 1 : 0
  name         = var.pipeline_name
  release_label = var.emr_release_label
  applications = ["Spark", "Hadoop"]

  service_role = aws_iam_role.emr_service[0].arn

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.emr_ec2[0].arn
  }

  master_instance_group {
    instance_type = var.emr_master_instance_type
  }

  core_instance_group {
    instance_type  = var.emr_core_instance_type
    instance_count = var.emr_core_count
  }

  log_uri = "s3://${aws_s3_bucket.datalake.bucket}/logs/emr/"

  configurations_json = jsonencode([
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.eventLog.enabled" = "true"
        "spark.eventLog.dir"     = "s3://${aws_s3_bucket.datalake.bucket}/logs/spark-history/"
      }
    }
  ])

  dynamic "bootstrap_action" {
    for_each = []
    content {
      path = bootstrap_action.value.path
      name = bootstrap_action.value.name
    }
  }

  tags = { Name = var.pipeline_name }

  # EMR clusters terminate after work is done; use step execution for job runs
  auto_termination_policy {
    idle_timeout = 3600
  }
}

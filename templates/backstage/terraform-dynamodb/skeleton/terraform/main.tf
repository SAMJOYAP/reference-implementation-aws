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
      Name        = var.table_name
      ManagedBy   = "Terraform"
      CreatedFrom = "Backstage"
      Project     = "${{ values.name }}"
      Repository  = "${{ values.remoteUrl }}"
    }
  }
}

locals {
  has_range_key  = var.range_key != ""
  is_provisioned = var.billing_mode == "PROVISIONED"
}

# ─── DynamoDB Table ─────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = var.billing_mode
  table_class  = var.table_class

  # Provisioned capacity (ignored for PAY_PER_REQUEST)
  read_capacity  = local.is_provisioned ? var.read_capacity : null
  write_capacity = local.is_provisioned ? var.write_capacity : null

  hash_key  = var.hash_key
  range_key = local.has_range_key ? var.range_key : null

  # Primary key attributes
  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  dynamic "attribute" {
    for_each = local.has_range_key ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # GSI attribute (only if different from existing attributes)
  dynamic "attribute" {
    for_each = var.gsi_enabled && var.gsi_hash_key != var.hash_key && var.gsi_hash_key != var.range_key ? [1] : []
    content {
      name = var.gsi_hash_key
      type = var.gsi_hash_key_type
    }
  }

  # TTL
  ttl {
    enabled        = var.ttl_enabled
    attribute_name = var.ttl_enabled ? var.ttl_attribute : ""
  }

  # Point-in-Time Recovery
  point_in_time_recovery {
    enabled = var.pitr_enabled
  }

  # DynamoDB Streams
  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  # KMS Encryption
  dynamic "server_side_encryption" {
    for_each = var.kms_encryption ? [1] : []
    content {
      enabled = true
    }
  }

  # Global Secondary Index
  dynamic "global_secondary_index" {
    for_each = var.gsi_enabled ? [1] : []
    content {
      name            = var.gsi_name
      hash_key        = var.gsi_hash_key
      projection_type = "ALL"

      read_capacity  = local.is_provisioned ? var.read_capacity : null
      write_capacity = local.is_provisioned ? var.write_capacity : null
    }
  }

  tags = { Name = var.table_name }
}

# ─── Auto Scaling (Provisioned billing only) ────────────────────────────────

resource "aws_appautoscaling_target" "read" {
  count = local.is_provisioned && var.auto_scaling ? 1 : 0

  max_capacity       = var.read_capacity * 10
  min_capacity       = var.read_capacity
  resource_id        = "table/${aws_dynamodb_table.main.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "read" {
  count = local.is_provisioned && var.auto_scaling ? 1 : 0

  name               = "${var.table_name}-read-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_target" "write" {
  count = local.is_provisioned && var.auto_scaling ? 1 : 0

  max_capacity       = var.write_capacity * 10
  min_capacity       = var.write_capacity
  resource_id        = "table/${aws_dynamodb_table.main.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write" {
  count = local.is_provisioned && var.auto_scaling ? 1 : 0

  name               = "${var.table_name}-write-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}

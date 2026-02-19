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
      Name        = var.cluster_id
      ManagedBy   = "Terraform"
      CreatedFrom = "Backstage"
      Project     = "${{ values.name }}"
      Repository  = "${{ values.remoteUrl }}"
    }
  }
}

# Random suffix prevents resource name collisions on re-deploy
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  is_cluster_mode = var.cluster_mode == "enabled"

  # [FIX] Unique prefix prevents parameter group / secret name collisions
  resource_prefix = "${var.cluster_id}-${random_id.suffix.hex}"
}

# [FIX] Use the EKS VPC (contains private subnets in multiple AZs)
# ElastiCache subnet groups require subnets in at least 2 AZs.
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name_filter]
  }
}

# Private subnets (map-public-ip-on-launch=false) ensures multi-AZ coverage
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

# AUTH token (only when auth is enabled)
resource "random_password" "auth_token" {
  count   = var.auth_enabled ? 1 : 0
  length  = 32
  special = false
}

# Subnet Group — uses private subnets spanning multiple AZs
resource "aws_elasticache_subnet_group" "main" {
  name        = "${local.resource_prefix}-subnet-group"
  subnet_ids  = data.aws_subnets.private.ids
  description = "Subnet group for ${var.cluster_id}"

  tags = { Name = "${local.resource_prefix}-subnet-group" }
}

# Security Group
resource "aws_security_group" "redis" {
  name_prefix = "${var.cluster_id}-"
  vpc_id      = data.aws_vpc.selected.id
  description = "Security group for ${var.cluster_id} ElastiCache"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Redis access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Parameter Group — random suffix prevents collision on re-deploy
resource "aws_elasticache_parameter_group" "main" {
  name   = "${local.resource_prefix}-params"
  family = "redis${split(".", var.engine_version)[0]}"

  tags = { Name = "${local.resource_prefix}-params" }
}

# ─── Cluster Mode Disabled (Replication Group) ──────────────────────────────

resource "aws_elasticache_replication_group" "main" {
  count = local.is_cluster_mode ? 0 : 1

  replication_group_id = var.cluster_id
  description          = "ElastiCache Redis for ${var.cluster_id}"

  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.auto_failover && var.num_cache_clusters > 1
  multi_az_enabled           = var.multi_az && var.auto_failover && var.num_cache_clusters > 1

  transit_encryption_enabled = var.transit_encryption
  at_rest_encryption_enabled = var.at_rest_encryption
  auth_token                 = var.auth_enabled ? random_password.auth_token[0].result : null

  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "mon:06:00-mon:07:00"

  parameter_group_name = aws_elasticache_parameter_group.main.name

  apply_immediately = true

  tags = { Name = var.cluster_id }
}

# ─── Cluster Mode Enabled ───────────────────────────────────────────────────

resource "aws_elasticache_replication_group" "cluster" {
  count = local.is_cluster_mode ? 1 : 0

  replication_group_id = var.cluster_id
  description          = "ElastiCache Redis Cluster for ${var.cluster_id}"

  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  num_node_groups         = var.num_shards
  replicas_per_node_group = var.replicas_per_shard

  automatic_failover_enabled = true
  multi_az_enabled           = var.multi_az

  transit_encryption_enabled = var.transit_encryption
  at_rest_encryption_enabled = var.at_rest_encryption
  auth_token                 = var.auth_enabled ? random_password.auth_token[0].result : null

  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "mon:06:00-mon:07:00"

  parameter_group_name = aws_elasticache_parameter_group.main.name

  apply_immediately = true

  tags = { Name = var.cluster_id }
}

# ─── CloudWatch Alarms ──────────────────────────────────────────────────────

locals {
  rg_id = local.is_cluster_mode ? aws_elasticache_replication_group.cluster[0].id : aws_elasticache_replication_group.main[0].id
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_id}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "EngineCPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    ReplicationGroupId = local.rg_id
  }

  alarm_description = "Redis CPU utilization is too high"
  alarm_actions     = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions        = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  count = var.cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_id}-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 104857600 # 100 MB in bytes

  dimensions = {
    ReplicationGroupId = local.rg_id
  }

  alarm_description = "Redis freeable memory is below 100 MB"
  alarm_actions     = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions        = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
}

# [FIX] Secrets Manager — random suffix prevents 7-day deletion window collision
resource "aws_secretsmanager_secret" "auth_token" {
  count       = var.auth_enabled ? 1 : 0
  name        = "${local.resource_prefix}/redis-auth-token"
  description = "Redis AUTH token for ${var.cluster_id}"

  tags = { Name = "${local.resource_prefix}-redis-auth-token" }
}

resource "aws_secretsmanager_secret_version" "auth_token" {
  count     = var.auth_enabled ? 1 : 0
  secret_id = aws_secretsmanager_secret.auth_token[0].id

  secret_string = jsonencode({
    auth_token = random_password.auth_token[0].result
    endpoint   = local.is_cluster_mode ? aws_elasticache_replication_group.cluster[0].configuration_endpoint_address : aws_elasticache_replication_group.main[0].primary_endpoint_address
    port       = 6379
  })
}

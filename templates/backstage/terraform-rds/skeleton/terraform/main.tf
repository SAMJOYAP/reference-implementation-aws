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
      Name        = var.identifier
      ManagedBy   = "Terraform"
      CreatedFrom = "Backstage"
      Project     = "${{ values.name }}"
      Repository  = "${{ values.remoteUrl }}"
    }
  }
}

locals {
  is_aurora = startswith(var.db_engine, "aurora")

  engine_config = {
    "postgres" = {
      version = "15.4"
      family  = "postgres15"
      port    = 5432
      logs    = ["postgresql", "upgrade"]
    }
    "mysql" = {
      version = "8.0.35"
      family  = "mysql8.0"
      port    = 3306
      logs    = ["audit", "error", "general", "slowquery"]
    }
    "aurora-postgresql" = {
      version = "15.4"
      family  = "aurora-postgresql15"
      port    = 5432
      logs    = ["postgresql"]
    }
    "aurora-mysql" = {
      version = "8.0.mysql_aurora.3.04.0"
      family  = "aurora-mysql8.0"
      port    = 3306
      logs    = ["audit", "error", "general", "slowquery"]
    }
  }

  db_engine_version   = local.engine_config[var.db_engine].version
  db_family           = local.engine_config[var.db_engine].family
  db_port             = local.engine_config[var.db_engine].port
  cloudwatch_exports  = local.engine_config[var.db_engine].logs
}

# Default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Random DB password
resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.identifier}-subnet-group"
  subnet_ids  = data.aws_subnets.default.ids
  description = "Subnet group for ${var.identifier}"

  tags = { Name = "${var.identifier}-subnet-group" }
}

# Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.identifier}-"
  vpc_id      = data.aws_vpc.default.id
  description = "Security group for ${var.identifier} RDS"

  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Database access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "${var.identifier}-params"
  family = local.db_family

  tags = { Name = "${var.identifier}-params" }
}

# ─── Standard RDS (postgres / mysql) ───────────────────────────────────────

resource "aws_db_instance" "main" {
  count = local.is_aurora ? 0 : 1

  identifier        = var.identifier
  engine            = var.db_engine
  engine_version    = local.db_engine_version
  instance_class    = var.instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = local.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled    = var.performance_insights
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs ? local.cloudwatch_exports : []

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = var.identifier }
}

# ─── Aurora Cluster (aurora-postgresql / aurora-mysql) ─────────────────────

resource "aws_rds_cluster_parameter_group" "aurora" {
  count  = local.is_aurora ? 1 : 0
  name   = "${var.identifier}-cluster-params"
  family = local.db_family

  tags = { Name = "${var.identifier}-cluster-params" }
}

resource "aws_rds_cluster" "main" {
  count = local.is_aurora ? 1 : 0

  cluster_identifier      = var.identifier
  engine                  = var.db_engine
  engine_version          = local.db_engine_version
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = random_password.db.result
  port                    = local.db_port

  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora[0].name

  backup_retention_period = var.backup_retention_days
  preferred_backup_window = "03:00-04:00"
  storage_encrypted       = true

  enabled_cloudwatch_logs_exports = var.cloudwatch_logs ? local.cloudwatch_exports : []

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = var.identifier }
}

# Aurora writer instance
resource "aws_rds_cluster_instance" "writer" {
  count = local.is_aurora ? 1 : 0

  identifier         = "${var.identifier}-writer"
  cluster_identifier = aws_rds_cluster.main[0].id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main[0].engine
  engine_version     = aws_rds_cluster.main[0].engine_version

  db_parameter_group_name      = aws_db_parameter_group.main.name
  performance_insights_enabled = var.performance_insights

  tags = { Name = "${var.identifier}-writer" }
}

# Aurora reader instance (Multi-AZ)
resource "aws_rds_cluster_instance" "reader" {
  count = local.is_aurora && var.multi_az ? 1 : 0

  identifier         = "${var.identifier}-reader"
  cluster_identifier = aws_rds_cluster.main[0].id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main[0].engine
  engine_version     = aws_rds_cluster.main[0].engine_version

  db_parameter_group_name      = aws_db_parameter_group.main.name
  performance_insights_enabled = var.performance_insights

  tags = { Name = "${var.identifier}-reader" }
}

# ─── Secrets Manager ───────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_credentials" {
  count       = var.secrets_manager ? 1 : 0
  name        = "${var.identifier}/db-credentials"
  description = "Database credentials for ${var.identifier}"

  tags = { Name = "${var.identifier}-db-credentials" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = var.db_engine
    host     = local.is_aurora ? aws_rds_cluster.main[0].endpoint : aws_db_instance.main[0].address
    port     = local.db_port
    dbname   = var.db_name
  })
}

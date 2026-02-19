variable "identifier" {
  description = "Unique identifier for the RDS instance/cluster"
  type        = string
  default     = "${{ values.name }}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.region }}"
}

variable "db_engine" {
  description = "Database engine (postgres, mysql, aurora-postgresql, aurora-mysql)"
  type        = string
  default     = "${{ values.engine }}"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "${{ values.instanceClass }}"
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
  default     = "dbadmin"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment (standby replica for RDS, reader instance for Aurora)"
  type        = bool
  default     = ${{ values.multiAz }}
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = ${{ values.backupRetentionDays }}
}

variable "performance_insights" {
  description = "Enable Performance Insights (not supported on db.t3.micro)"
  type        = bool
  default     = ${{ values.performanceInsights }}
}

variable "cloudwatch_logs" {
  description = "Export database logs to CloudWatch"
  type        = bool
  default     = ${{ values.cloudwatchLogs }}
}

variable "secrets_manager" {
  description = "Store DB credentials in AWS Secrets Manager"
  type        = bool
  default     = ${{ values.secretsManager }}
}

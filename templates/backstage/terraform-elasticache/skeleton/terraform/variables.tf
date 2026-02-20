variable "cluster_id" {
  description = "Unique identifier for the ElastiCache cluster"
  type        = string
  default     = "${{ values.name }}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.region }}"
}

variable "cluster_mode" {
  description = "Cluster mode: disabled (single shard) or enabled (multiple shards)"
  type        = string
  default     = "${{ values.clusterMode }}"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "${{ values.engineVersion }}"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "${{ values.nodeType }}"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes in Cluster Mode Disabled (1 = no replication)"
  type        = number
  default     = ${{ values.numCacheClusters }}
}

variable "num_shards" {
  description = "Number of shards in Cluster Mode Enabled"
  type        = number
  default     = ${{ values.numShards }}
}

variable "replicas_per_shard" {
  description = "Number of replicas per shard in Cluster Mode Enabled"
  type        = number
  default     = ${{ values.replicasPerShard }}
}

variable "auto_failover" {
  description = "Enable automatic failover (requires at least 1 replica)"
  type        = bool
  default     = ${{ values.autoFailover }}
}

variable "multi_az" {
  description = "Enable Multi-AZ (requires auto failover)"
  type        = bool
  default     = ${{ values.multiAz }}
}

variable "transit_encryption" {
  description = "Enable TLS in-transit encryption"
  type        = bool
  default     = ${{ values.transitEncryption }}
}

variable "at_rest_encryption" {
  description = "Enable encryption at rest"
  type        = bool
  default     = ${{ values.atRestEncryption }}
}

variable "auth_enabled" {
  description = "Enable Redis AUTH token (requires TLS)"
  type        = bool
  default     = ${{ values.authEnabled }}
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots (0 = disabled)"
  type        = number
  default     = ${{ values.snapshotRetentionDays }}
}

variable "cloudwatch_alarms" {
  description = "Create CloudWatch alarms for CPU and memory"
  type        = bool
  default     = ${{ values.cloudwatchAlarms }}
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications (optional)"
  type        = string
  default     = ""
}

variable "vpc_name_filter" {
  description = "Name tag of the VPC where ElastiCache will be deployed. Must contain private subnets in at least 2 AZs."
  type        = string
  default     = "${{ values.vpcNameFilter }}"
}

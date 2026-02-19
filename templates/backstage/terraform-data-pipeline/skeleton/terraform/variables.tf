variable "pipeline_name" {
  description = "Name of the data pipeline"
  type        = string
  default     = "${{ values.name }}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.region }}"
}

variable "pipeline_type" {
  description = "Pipeline type: glue, emr, or both"
  type        = string
  default     = "${{ values.pipelineType }}"
}

variable "s3_bucket_suffix" {
  description = "Suffix appended to the S3 bucket name: {name}-{suffix}"
  type        = string
  default     = "${{ values.s3BucketSuffix }}"
}

variable "s3_prefix" {
  description = "S3 key prefix for raw input data"
  type        = string
  default     = "${{ values.s3Prefix }}"
}

variable "glue_job_type" {
  description = "Glue job type: glueetl or pythonshell"
  type        = string
  default     = "${{ values.glueJobType }}"
}

variable "glue_worker_type" {
  description = "Glue ETL worker type: G.025X, G.1X, G.2X"
  type        = string
  default     = "${{ values.glueWorkerType }}"
}

variable "glue_worker_count" {
  description = "Number of Glue workers for ETL jobs"
  type        = number
  default     = ${{ values.glueWorkerCount }}
}

variable "crawler_schedule" {
  description = "Cron schedule for Glue Crawler. Use 'disabled' for manual trigger only."
  type        = string
  default     = "${{ values.crawlerSchedule }}"
}

variable "emr_release_label" {
  description = "EMR release label (e.g. emr-7.0.0)"
  type        = string
  default     = "${{ values.emrReleaseLabel }}"
}

variable "emr_master_instance_type" {
  description = "EC2 instance type for EMR master node"
  type        = string
  default     = "${{ values.emrMasterInstanceType }}"
}

variable "emr_core_instance_type" {
  description = "EC2 instance type for EMR core nodes"
  type        = string
  default     = "${{ values.emrCoreInstanceType }}"
}

variable "emr_core_count" {
  description = "Number of EMR core nodes"
  type        = number
  default     = ${{ values.emrCoreCount }}
}

variable "kms_encryption" {
  description = "Enable KMS encryption for S3, Glue, and EMR"
  type        = bool
  default     = ${{ values.kmsEncryption }}
}

variable "cloudwatch_logs" {
  description = "Export Glue job and EMR logs to CloudWatch Logs"
  type        = bool
  default     = ${{ values.cloudwatchLogs }}
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.region }}"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "${{ values.name }}"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "${{ values.clusterVersion }}"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "${{ values.environment }}"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "${{ values.vpcCidr }}"
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["${{ values.nodeInstanceType }}"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = ${{ values.nodeDesiredSize }}
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = ${{ values.nodeMinSize }}
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = ${{ values.nodeMaxSize }}
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "${{ values.name }}"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "${{ values.instanceType }}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.region }}"
}

variable "eks_cluster_name" {
  description = "Default EKS cluster name from GitHub Actions vars.EKS_CLUSTER_NAME (TF_VAR_eks_cluster_name)"
  type        = string
}

variable "eks_cluster_name_override" {
  description = "Optional EKS cluster name entered in Backstage. If empty, eks_cluster_name is used."
  type        = string
  default     = "${{ values.eksClusterName }}"
}

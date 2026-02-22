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

variable "vpc_name" {
  description = "Name tag of the VPC to deploy the EC2 instance into"
  type        = string
  default     = "${{ values.vpcName }}"
}

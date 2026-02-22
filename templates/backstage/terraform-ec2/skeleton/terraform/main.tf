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
      Name        = var.instance_name
      ManagedBy   = "Terraform"
      CreatedFrom = "Backstage"
      Project     = "${{ values.name }}"
      Repository  = "${{ values.remoteUrl }}"
    }
  }
}

# Use user-provided cluster name if set, otherwise fall back to the default
# set via TF_VAR_eks_cluster_name GitHub Actions variable (vars.EKS_CLUSTER_NAME)
locals {
  effective_cluster_name = var.eks_cluster_name_override != "" ? var.eks_cluster_name_override : var.eks_cluster_name
}

data "aws_eks_cluster" "main" {
  name = local.effective_cluster_name
}

data "aws_vpc" "selected" {
  id = data.aws_eks_cluster.main.vpc_config[0].vpc_id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*Public*", "*public*", "*Private*", "*private*"]
  }
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group - Allow SSH (22) and HTTP (80)
resource "aws_security_group" "main" {
  name_prefix = "${{ values.name }}-"
  description = "Security group for ${{ values.name }} EC2 instance"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CAUTION: Restrict this in production!
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.selected.ids[0]
  vpc_security_group_ids = [aws_security_group.main.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from ${{ values.name }}!</h1>" > /var/www/html/index.html
              echo "<p>Instance Type: ${var.instance_type}</p>" >> /var/www/html/index.html
              echo "<p>Region: ${var.aws_region}</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}

terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    tls     = { source = "hashicorp/tls", version = "~> 4.0" }
    local   = { source = "hashicorp/local", version = "~> 2.4" }
    template = { source = "hashicorp/template", version = "~> 2.2" }
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR (NAT/Bastion lives here)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (Kubernetes nodes live here)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "allowed_ssh_cidr" {
  description = "Your public IP/CIDR allowed to SSH to Bastion"
  type        = string
  default     = "90.251.112.0/24"
}

variable "assign_app2_eip" {
  description = "If true, assign a dedicated EIP to APP2 (lowest-latency egress)"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for SNS alarm notifications (confirm the AWS email!)"
  type        = string
  default     = "a@example.com"
}

variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "kubeadm-dev"
}

variable "ami_id_al2023_arm" {
  description = "Amazon Linux 2023 ARM64 AMI ID (ap-northeast-1)"
  type        = string
  default     = "ami-00af5e7d41b60553e"
}



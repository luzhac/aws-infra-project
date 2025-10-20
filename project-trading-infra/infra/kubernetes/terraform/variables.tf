############################################################
# Basic Configuration
############################################################

variable "region" {
  description = "AWS region to deploy the cluster in"
  type        = string
  default     = "ap-northeast-1" # Change to eu-west-2 (London) if needed
}

variable "cluster_name" {
  description = "Prefix name used to identify all related resources"
  type        = string
  default     = "k8s"
}

############################################################
# Network Configuration
############################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}


############################################################
# Other Settings
############################################################

variable "assign_app2_eip" {
  description = "Whether to assign a separate Elastic IP to app2 (optional)"
  type        = bool
  default     = false
}

############################################################
# Output Variables
############################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.efs.id
}

output "nat_gateway_ip" {
  description = "Public IP address of the NAT gateway instance"
  value       = aws_eip.nat_eip.public_ip
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

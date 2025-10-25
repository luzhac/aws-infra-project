############################################################
# Basic Configuration
############################################################

variable "region" {
  description = "AWS region to deploy the cluster in"
  type        = string
  default     = "eu-west-2" # London
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

variable "enable_alb" {
  description = "Whether to create ALB resources"
  type        = bool
  default     = false
}

variable "assign_app2_eip" {
  description = "Whether to assign a separate Elastic IP to app node"
  type        = bool
  default     = true
}

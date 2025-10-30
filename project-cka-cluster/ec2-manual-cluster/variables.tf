############################################################
# Basic Configuration
############################################################

variable "region" {
  description = "AWS region to deploy the cluster in"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Prefix name used to identify all related resources"
  type        = string
  default     = "cka"
}

############################################################
# Network Configuration
############################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}



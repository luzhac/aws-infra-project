variable "region" {
  description = "AWS region to deploy."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging and resource names."
  type        = string
  default     = "tf-full-demo"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "public_key_path" {
  description = "Path to your local SSH public key."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

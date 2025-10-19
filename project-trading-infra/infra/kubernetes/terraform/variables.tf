############################################################
# 基础配置
############################################################

variable "region" {
  description = "AWS 区域"
  type        = string
  default     = "ap-northeast-1" # 你也可以改成 eu-west-2 (伦敦)
}

variable "cluster_name" {
  description = "集群名称前缀，用于标识资源"
  type        = string
  default     = "k8s-demo"
}

############################################################
# 网络配置
############################################################

variable "vpc_cidr" {
  description = "VPC 网段"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "公网子网 CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "私网子网 CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

############################################################
# 镜像配置 (Amazon Linux 2023 ARM)
############################################################

variable "ami_id_al2023_arm" {
  description = "Amazon Linux 2023 ARM64 AMI ID"
  type        = string
  # 例如：ap-northeast-1 (东京) 的 AMI
  default     = "ami-00af5e7d41b60553e"
  # 你可以使用命令查找：
  # aws ec2 describe-images --owners amazon \
  #   --filters "Name=name,Values=al2023-ami-2023*" \
  #   --query "Images[*].[ImageId,Name]" --output table
}



############################################################
# 其他设置
############################################################

variable "assign_app2_eip" {
  description = "是否为 app2 分配独立 EIP（暂未使用）"
  type        = bool
  default     = false
}

############################################################
# 输出选项
############################################################

output "alb_dns_name" {
  description = "ALB 访问地址"
  value       = aws_lb.alb.dns_name
}

output "efs_id" {
  description = "EFS 文件系统 ID"
  value       = aws_efs_file_system.efs.id
}

output "nat_gateway_ip" {
  description = "NAT Gateway 公网 IP"
  value       = aws_eip.nat_eip.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}





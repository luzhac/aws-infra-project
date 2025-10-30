############################################################
# Provider
############################################################
provider "aws" {
  region = var.region
}

############################################################
# SSH Key Pair
############################################################
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "${var.cluster_name}-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content              = tls_private_key.key.private_key_pem
  filename             = "${path.module}/${var.cluster_name}.pem"
  file_permission      = "0400"
  directory_permission = "0700"
}

############################################################
# IAM Role for SSM
############################################################
resource "aws_iam_role" "ssm_role" {
  name = "${var.cluster_name}-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [ {
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    } ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.cluster_name}-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

############################################################
# Networking (VPC + Route via IGW)
############################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.cluster_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-igw" }
}

# Public and Private Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.cluster_name}-public-a" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.cluster_name}-private-a" }
}

# Shared route table (no NAT Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.public.id
}

############################################################
# Security Group
############################################################
resource "aws_security_group" "cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow internal and SSH traffic"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################################
# EC2 Instances (Master   + Worker )
############################################################
data "aws_ami" "ubuntu_2204_arm64" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
}

locals {
  ami_id_arm = data.aws_ami.ubuntu_2204_arm64.id
}

# Master =  Kubernetes master
resource "aws_instance" "master" {
  ami                         = local.ami_id_arm
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address  = true
  vpc_security_group_ids      = [aws_security_group.cluster_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  key_name                    = aws_key_pair.kp.key_name
  source_dest_check           = false
  user_data = <<-EOF
              #!/bin/bash
              sysctl -w net.ipv4.ip_forward=1
              iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              EOF
  tags = { Name = "${var.cluster_name}-master" }
}



# Worker node with public IP
resource "aws_instance" "app" {
  ami                         = local.ami_id_arm
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address  = true
  vpc_security_group_ids      = [aws_security_group.cluster_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  key_name                    = aws_key_pair.kp.key_name
  depends_on                  = [aws_instance.master]
  tags = { Name = "${var.cluster_name}-app" }
}




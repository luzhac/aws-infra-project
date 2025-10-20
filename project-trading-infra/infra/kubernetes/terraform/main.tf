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
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
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
# Networking (VPC, Subnets, Routing)
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

# Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.cluster_name}-public-a" }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.cluster_name}-public-c" }
}

# Private Subnets
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.cluster_name}-private-a" }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.region}c"
  tags              = { Name = "${var.cluster_name}-private-c" }
}

# Route Tables
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

resource "aws_route_table_association" "public_assoc_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for Private Subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "${var.cluster_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.cluster_name}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-private-rt" }
}

resource "aws_route" "private_default_via_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

############################################################
# Security Groups
############################################################
resource "aws_security_group" "cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Allow internal Kubernetes traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  ingress {
    description = "Allow SSH from anywhere"
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

  tags = { Name = "${var.cluster_name}-cluster-sg" }
}

resource "aws_security_group" "efs_sg" {
  name        = "${var.cluster_name}-efs-sg"
  description = "EFS access"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-efs-sg" }
}

resource "aws_security_group_rule" "efs_from_cluster" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster_sg.id
  security_group_id        = aws_security_group.efs_sg.id
}

############################################################
# EFS
############################################################
resource "aws_efs_file_system" "efs" {
  creation_token   = "${var.cluster_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags             = { Name = "${var.cluster_name}-efs" }
}

resource "aws_efs_mount_target" "mt_private_a" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "mt_private_c" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.private_c.id
  security_groups = [aws_security_group.efs_sg.id]
}

############################################################
# ALB
############################################################
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Allow inbound HTTP"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-alb-sg" }
}

resource "aws_lb" "alb" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  security_groups    = [aws_security_group.alb_sg.id]
  tags               = { Name = "${var.cluster_name}-alb" }
}

resource "aws_lb_target_group" "tg" {
  name        = "${var.cluster_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

############################################################
# AMI - Ubuntu 22.04 ARM64
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

############################################################
# EC2 Instances (Manual Setup, Master Has Public IP)
############################################################
resource "aws_instance" "master" {
  ami                         = local.ami_id_arm
  instance_type               = "t4g.small"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.cluster_sg.id]
  iam_instance_profile         = aws_iam_instance_profile.ssm_profile.name
  key_name                     = aws_key_pair.kp.key_name
  source_dest_check            = false
  depends_on                   = [aws_internet_gateway.igw]
  tags                         = { Name = "${var.cluster_name}-master" }
}

resource "aws_instance" "app" {
  ami                    = local.ami_id_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private_c.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = aws_key_pair.kp.key_name
  depends_on             = [aws_instance.master]
  tags                   = { Name = "${var.cluster_name}-app" }
}

resource "aws_instance" "monitor" {
  ami                    = local.ami_id_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = aws_key_pair.kp.key_name
  depends_on             = [aws_instance.master]
  tags                   = { Name = "${var.cluster_name}-monitor" }
}

############################################################
# Register Nodes to ALB
############################################################
resource "aws_lb_target_group_attachment" "master_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.master.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "monitor_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.monitor.id
  port             = 80
}

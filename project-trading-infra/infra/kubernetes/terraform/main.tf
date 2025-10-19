provider "aws" {
  region = var.region
}

# -------------------------------------------------------------------
# SSH Key Pair
# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
# Networking (VPC / Subnets / Routing)
# -------------------------------------------------------------------
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

# Two public subnets in different AZs
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

# Two private subnets in different AZs
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.cluster_name}-private-a" }
}

resource "aws_subnet" "private_c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.cluster_name}-private-c" }
}

# Public route table
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

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-private-rt" }
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

# -------------------------------------------------------------------
# NAT Gateway
# -------------------------------------------------------------------
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

resource "aws_route" "private_default_via_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# -------------------------------------------------------------------
# Security Groups
# -------------------------------------------------------------------
resource "aws_security_group" "cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Kubernetes nodes internal traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
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
  description = "EFS security group"
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

# -------------------------------------------------------------------
# EFS
# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
# ALB
# -------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Allow inbound HTTP traffic"
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
  idle_timeout       = 60
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

# -------------------------------------------------------------------
# Common Cloud-init Template
# -------------------------------------------------------------------
locals {
  efs_dns = "${aws_efs_file_system.efs.id}.efs.${var.region}.amazonaws.com"
}

data "template_cloudinit_config" "node_common" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = <<-SH
#!/bin/bash
set -eux
dnf -y update
dnf -y install amazon-efs-utils curl tar containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl enable --now containerd
sed -i.bak '/ swap / s/^/#/' /etc/fstab || true
swapoff -a || true
cat >/etc/yum.repos.d/kubernetes.repo <<'REPO'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repomd.xml.key
REPO
dnf -y install kubelet kubeadm kubectl
systemctl enable --now kubelet
mkdir -p /mnt/efs
echo "${local.efs_dns}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab
mount -a || true
SH
  }
}

# -------------------------------------------------------------------
# Master Node (control plane)
# -------------------------------------------------------------------
data "template_cloudinit_config" "master" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = data.template_cloudinit_config.node_common.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<-SH
#!/bin/bash
set -eux
kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubeadm token create --print-join-command > /mnt/efs/join.sh
chmod +x /mnt/efs/join.sh
SH
  }
}

# -------------------------------------------------------------------
# Worker Node Template
# -------------------------------------------------------------------
data "template_cloudinit_config" "joiner" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = data.template_cloudinit_config.node_common.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<-SH
#!/bin/bash
set -eux
for i in {1..180}; do
  if [ -f /mnt/efs/join.sh ]; then
    bash /mnt/efs/join.sh
    exit 0
  fi
  sleep 5
done
echo "join.sh not found after 15 minutes" >&2
exit 1
SH
  }
}

# -------------------------------------------------------------------
# EC2 Instances
# -------------------------------------------------------------------
resource "aws_instance" "master" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  key_name               = aws_key_pair.kp.key_name
  user_data              = data.template_cloudinit_config.master.rendered
  depends_on             = [aws_efs_mount_target.mt_private_a]
  tags                   = { Name = "${var.cluster_name}-master" }
}

resource "aws_instance" "app" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private_c.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  key_name               = aws_key_pair.kp.key_name
  user_data              = data.template_cloudinit_config.joiner.rendered
  depends_on             = [aws_instance.master]
  tags                   = { Name = "${var.cluster_name}-app" }
}

resource "aws_instance" "monitor" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  key_name               = aws_key_pair.kp.key_name
  user_data              = data.template_cloudinit_config.joiner.rendered
  depends_on             = [aws_instance.master]
  tags                   = { Name = "${var.cluster_name}-monitor" }
}

# -------------------------------------------------------------------
# Register nodes to ALB
# -------------------------------------------------------------------
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

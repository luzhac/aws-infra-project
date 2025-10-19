provider "aws" {
  region = var.region
}

# -------------------------------------------------------------------
# SSH key pair
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

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.cluster_name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.cluster_name}-private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# -------------------------------------------------------------------
# Security Groups
# -------------------------------------------------------------------
resource "aws_security_group" "nat_sg" {
  name        = "${var.cluster_name}-nat-sg"
  description = "NAT/Bastion"
  vpc_id      = aws_vpc.this.id

  # 允许你的公网 SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # 允许来自私网的所有入站流量
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  # 出网
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-nat-sg" }
}

resource "aws_security_group" "cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Kubernetes nodes intra-traffic"
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

resource "aws_security_group_rule" "allow_ssh_from_nat" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nat_sg.id
  security_group_id        = aws_security_group.cluster_sg.id
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

resource "aws_efs_mount_target" "mt_private" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.efs_sg.id]
}

# -------------------------------------------------------------------
# NAT / Bastion (with full working SNAT)
# -------------------------------------------------------------------
resource "aws_instance" "nat" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  key_name               = aws_key_pair.kp.key_name
  source_dest_check      = false

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

dnf -y update

# 永久启用 IPv4 转发
cat >/etc/sysctl.d/99-nat.conf <<'SYSCTL'
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system

# 安装并启用 iptables-services
dnf install -y iptables-services
systemctl enable --now iptables

# SNAT 转发规则
PRIV_CIDR="${aws_subnet.private.cidr_block}"
PUB_IF="$(ip -4 route ls default | awk '{print $5}')"

iptables -t nat -A POSTROUTING -s "$PRIV_CIDR" -o "$PUB_IF" -j MASQUERADE
iptables -A FORWARD -s "$PRIV_CIDR" -j ACCEPT
iptables -A FORWARD -d "$PRIV_CIDR" -m state --state ESTABLISHED,RELATED -j ACCEPT
service iptables save
EOF

  tags = { Name = "${var.cluster_name}-nat" }
}

resource "aws_eip" "nat_eip" {
  instance = aws_instance.nat.id
  domain   = "vpc"
  tags     = { Name = "${var.cluster_name}-nat-eip" }
}

resource "aws_route" "private_default_via_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat.id
  depends_on             = [aws_instance.nat]
}

# -------------------------------------------------------------------
# Node initialization scripts (common, master, joiners)
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
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
helm install nginx-gateway-fabric oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric --namespace gateway-system --create-namespace --kubeconfig /etc/kubernetes/admin.conf
cat >/root/gateway.yaml <<EOF2
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: gateway-system
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
EOF2
kubectl apply -f /root/gateway.yaml --kubeconfig /etc/kubernetes/admin.conf
SH
  }
}

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
# EC2 nodes
# -------------------------------------------------------------------
resource "aws_instance" "master" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  key_name               = aws_key_pair.kp.key_name
  user_data              = data.template_cloudinit_config.master.rendered
  depends_on             = [aws_efs_mount_target.mt_private]
  tags                   = { Name = "${var.cluster_name}-master" }
}

resource "aws_instance" "worker" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  key_name               = aws_key_pair.kp.key_name
  user_data              = data.template_cloudinit_config.joiner.rendered
  depends_on             = [aws_instance.master]
  tags                   = { Name = "${var.cluster_name}-worker" }
}

resource "aws_instance" "app2" {
  ami                    = var.ami_id_al2023_arm
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]
  key_name               = aws_key_pair.kp.key_name
  user_data              = data.template_cloudinit_config.joiner.rendered
  depends_on             = [aws_instance.master]
  tags                   = { Name = "${var.cluster_name}-app2" }
}

resource "aws_eip" "app2_eip" {
  count    = var.assign_app2_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.app2.id
  tags     = { Name = "${var.cluster_name}-app2-eip" }
}

#   VPC
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

# Data Source：  Amazon Linux 2 AMI
data "aws_ami" "amazon_linux2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}



#   22/80
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# EC2 User Data  NGINX
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -eux
    yum update -y
    amazon-linux-extras install -y nginx1
    systemctl enable nginx
    systemctl start nginx
    echo "Hello from Terraform at $(hostname) !" > /usr/share/nginx/html/index.html
  EOT
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux2.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_id

  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data     = local.user_data

  #   lifecycle
  lifecycle {
    prevent_destroy = false  #   true
  }

  #
  depends_on = [module.vpc, aws_security_group.web_sg]

  tags = {
    Name = "${var.project_name}-web"
  }
}

terraform {
  required_version = "~> 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = "Test-edge"
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "edge_sg" {
  name_prefix = "hardened-edge-test-"
  description = "Security group for hardened edge instance"
  vpc_id      = var.vpc_id

  ingress {
    description  = "Allow HTTPS (443) from anywhere"
    from_port    = 443
    to_port      = 443
    protocol     = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  ingress {
    description  = "Allow SSH (22) from admin CIDRs"
    from_port    = 22
    to_port      = 22
    protocol     = "tcp"
    cidr_blocks  = var.admin_cidrs
  }

  ingress {
    description  = "Allow WireGuard (UDP) from admin CIDRs"
    from_port    = var.wireguard_port
    to_port      = var.wireguard_port
    protocol     = "udp"
    cidr_blocks  = var.admin_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # This means "all protocols"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hardened-edge-sg"
  }
}

# IAM Role & Profile
resource "aws_iam_role" "edge_role" {
  name_prefix = "hardened-edge-test-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "edge_profile" {
  name_prefix = "hardened-edge-test-"
  role        = aws_iam_role.edge_role.name
}

# Cloud-init configuration
# EC2 instance
resource "aws_instance" "edge" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.edge_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.edge_profile.name
  monitoring             = true
  ebs_optimized          = true

  # This is the new, direct way to render the script
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    admin_user        = var.admin_user
    admin_ssh_keys    = var.admin_ssh_keys
    admin_cidrs       = var.admin_cidrs
    wireguard_port    = var.wireguard_port
    wireguard_network = var.wireguard_network
    domain_name       = var.domain_name
    backend_servers   = var.backend_servers

  })

  user_data_replace_on_change = true

  metadata_options {
    http_tokens               = "required"
    http_endpoint             = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "hardened-edge-test"
  }
}

# Elastic IP
resource "aws_eip" "edge_eip" {
  instance = aws_instance.edge.id
  domain   = "vpc"

  tags = {
    Name = "hardened-edge-eip"
  }
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "edge"
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

# Render Caddyfile from template
locals {
  caddyfile_rendered = templatefile("${path.module}/cloud-init/Caddyfile.tpl", {
    domain         = var.domain
    app_private_ip = var.app_private_ip
    app_port       = var.app_port
  })
}

# Cloud-init configuration
data "cloudinit_config" "edge" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "edge-base.yaml"
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-init/edge-base.yaml")
  }

  part {
    filename     = "edge-wg.yaml"
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-init/edge-wg.yaml")
  }

  part {
    filename     = "edge-nat.yaml"
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-init/edge-nat.yaml")
  }

  part {
    filename     = "edge-caddy.yaml"
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-init/edge-caddy.yaml")
  }

  part {
    filename     = "edge-wg-admin.yaml"
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-init/edge-wg-admin.yaml")
  }

  part {
    filename     = "edge-caddy-proxy.yaml"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/cloud-init/edge-caddy-proxy.yaml", {
      caddyfile_content = local.caddyfile_rendered
    })
  }
}

# Security Group for edge instance
resource "aws_security_group" "edge_sg" {
  name        = "edge-sg"
  description = "Edge instance security group"
  vpc_id      = data.aws_vpc.default.id

  # SSH from admin CIDRs
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  # WireGuard UDP
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = var.admin_cidrs
  }

  # HTTP/HTTPS open
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "edge-sg" }
}

# EC2 instance
resource "aws_instance" "edge" {
  ami               = var.ami
  instance_type     = var.instance_type
  user_data_base64  = data.cloudinit_config.edge.rendered
  key_name          = var.key_pair_name
  security_groups   = [aws_security_group.edge_sg.name]
  tags = { Name = "edge-node" }
}




terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type        = string
  description = "AWS region"
}

locals {
  name = "edge-external-client"
}

# Minimal VPC with public subnet
resource "aws_vpc" "vpc" {
  cidr_block           = "10.200.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = local.name }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = { Name = local.name }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.200.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = { Name = local.name }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = local.name }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "client" {
  name        = "${local.name}-sg"
  description = "External client SG"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.client.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  security_group_id = aws_security_group.client.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Key pair for this client (separate from edge)
resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "client" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.client.public_key_openssh
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "client" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.client.id]
  key_name                    = aws_key_pair.client.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #cloud-config
              package_update: true
              packages:
                - docker.io
              runcmd:
                - [ bash, -lc, "usermod -aG docker ubuntu || true" ]
                - [ bash, -lc, "systemctl enable --now docker" ]
              EOF

  tags = { Name = local.name }
}

output "public_ip" {
  value = aws_instance.client.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.client.private_key_pem
  sensitive = true
}

# Also write the key to disk for the test runner
resource "local_file" "client_private_key" {
  content         = tls_private_key.client.private_key_pem
  filename        = abspath("${path.module}/external_client_key.pem")
  file_permission = "0600"
}

output "private_key_path" {
  value = local_file.client_private_key.filename
}
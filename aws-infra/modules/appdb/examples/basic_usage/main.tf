# =============================================================================
# examples/basic_usage/main.tf
# Standalone test configuration for appdb module with Edge NAT
# =============================================================================

provider "aws" {
  region = "eu-central-1"
}

# -----------------------------
# Get first available AZ
# -----------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------
# Locals
# -----------------------------
locals {
  project_name  = "layered-infra"
  environment   = "testing"
  instance_type = "t3.micro"
  vpc_cidr      = "10.0.0.0/16"

  common_tags = {
    Project     = local.project_name
    ManagedBy   = "Terraform"
    Environment = local.environment
    Team        = "D"
    Module      = "AppDB Basic Usage"
  }

  arch            = can(regex(".*g\\.", local.instance_type)) ? "arm64" : "amd64"
  ubuntu_version  = "22.04"
  ubuntu_ssm_path = "/aws/service/canonical/ubuntu/server/${local.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"
}

# -----------------------------
# TLS/SSH Key for testing
# -----------------------------
resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "this" {
  key_name   = "${local.project_name}-test-key"
  public_key = tls_private_key.test_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.test_key.private_key_pem
  filename        = abspath("${path.module}/appdb_test_key.pem")
  file_permission = "0600"
}

# -----------------------------
# VPC + Subnets
# -----------------------------
resource "aws_vpc" "test_vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "${local.project_name}-vpc" })
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${local.project_name}-public-subnet" })
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(local.common_tags, { Name = "${local.project_name}-private-subnet" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.test_vpc.id
  tags   = merge(local.common_tags, { Name = "${local.project_name}-igw" })
}

# -----------------------------
# Route Tables
# -----------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, { Name = "${local.project_name}-public-rt" })
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.test_vpc.id
  tags   = merge(local.common_tags, { Name = "${local.project_name}-private-rt" })
}

# -----------------------------
# Security Groups
# -----------------------------
resource "aws_security_group" "sg_edge" {
  name        = "${local.project_name}-sg-edge"
  description = "Edge NAT SG"
  vpc_id      = aws_vpc.test_vpc.id

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

  tags = local.common_tags
}

resource "aws_security_group" "sg_appdb" {
  name        = "${local.project_name}-sg-appdb"
  description = "AppDB instance SG"
  vpc_id      = aws_vpc.test_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# -----------------------------
# Ubuntu AMI
# -----------------------------
data "aws_ssm_parameter" "ubuntu" {
  name = local.ubuntu_ssm_path
}

# -----------------------------
# Edge NAT Instance
# -----------------------------
resource "aws_instance" "edge" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = local.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_edge.id]
  key_name               = aws_key_pair.this.key_name
  source_dest_check      = false

  user_data = templatefile("${path.module}/templates/edge_init.sh.tftpl", {
    vpc_cidr = local.vpc_cidr
  })

  tags = merge(local.common_tags, { Name = "${local.project_name}-edge" })
}

# -----------------------------
# AppDB Module
# -----------------------------
module "appdb" {
  source                 = "../.." # Path to appdb module
  project_name           = local.project_name
  environment            = local.environment
  common_tags            = local.common_tags
  private_subnet_id      = aws_subnet.private_subnet.id
  sg_app_id              = aws_security_group.sg_appdb.id
  instance_type          = local.instance_type
  iam_instance_profile   = null
  app_image              = "nginx:latest" # Placeholder for testing
}

# -----------------------------
# Route private subnet traffic via Edge NAT
# -----------------------------
resource "aws_route" "private_to_edge" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.edge.primary_network_interface_id
}

# Allow SSH from Edge to AppDB for testing
resource "aws_security_group_rule" "appdb_ssh_from_edge" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_appdb.id
  source_security_group_id = aws_security_group.sg_edge.id
}

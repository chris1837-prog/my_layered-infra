provider "aws" {
  region  = "eu-central-1"
  profile = "AdministratorAccess-694816839566"
}

# Locals for edge module
locals {
  instance_type  = "t3.micro"
  ubuntu_version = "20.04"
}

# VPC
resource "aws_vpc" "test_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.test_vpc.id
  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = var.public_subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
  tags = {
    Name        = "${var.environment}-public-subnet"
    Environment = var.environment
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = var.private_subnet_cidr_block
  map_public_ip_on_launch = false
  availability_zone       = "eu-central-1a"
  tags = {
    Name        = "${var.environment}-private-subnet"
    Environment = var.environment
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }
  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = var.environment
  }
}

# Private Route Table (routes to edge instance)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = module.edge.primary_network_interface_id
  }
  tags = {
    Name        = "${var.environment}-private-route-table"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

# Security Group for App
resource "aws_security_group" "app" {
  vpc_id = aws_vpc.test_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  tags = {
    Name        = "${var.environment}-app-sg"
    Environment = var.environment
  }
}

# Security Group for Edge
resource "aws_security_group" "edge" {
  vpc_id = aws_vpc.test_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.2.0/24"]
  }
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
  tags = {
    Name        = "${var.environment}-edge-sg"
    Environment = var.environment
  }
}

# Key Pair for App
resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "this" {
  key_name   = "appdb_test_key"
  public_key = tls_private_key.test_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.test_key.private_key_pem
  filename        = "appdb_test_key.pem"
  file_permission = "0600"
}

# IAM Role and Instance Profile for Edge
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Elastic IP for Edge
resource "aws_eip" "edge" {
  domain = "vpc"
  tags = {
    Name        = "${var.environment}-edge-eip"
    Environment = var.environment
  }
}

# EC2 Instance Connect Endpoint
resource "aws_ec2_instance_connect_endpoint" "eic_endpoint" {
  subnet_id          = aws_subnet.private_subnet.id
  security_group_ids = [aws_security_group.app.id]
  tags = {
    Name        = "${var.environment}-eic-endpoint"
    Environment = var.environment
  }
}

# Edge Module
module "edge" {
  source = "../../../edge"

  project_name              = "layered-infra"
  environment               = var.environment
  vpc_id                    = aws_vpc.test_vpc.id
  edge_private_ip           = "10.0.1.130"
  registry_user             = "registry"
  registry_password         = "registry"
  registry_external_url     = "https://registry.dev.uselayered.com"
  registry_internal_url     = "https://registry.internal.dev.uselayered.com"
  instance_type             = local.instance_type
  sg_edge_id                = aws_security_group.edge.id
  ubuntu_version            = local.ubuntu_version
  key_name                  = aws_key_pair.this.key_name
  admin_ssh_keys            = [tls_private_key.test_key.public_key_openssh]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  public_subnet_id          = aws_subnet.public_subnet.id
  admin_cidrs               = ["0.0.0.0/0"]
  domain_name               = "edge.dev.uselayered.com"
  backend_servers           = ["10.0.2.10:3000", "10.0.2.11:3000"]
  enable_domain_tls         = true
  enable_domain_acme        = true
  enable_eip_association    = true
  eip_allocation_id         = aws_eip.edge.id
}

# AppDB Module
module "appdb" {
  source                         = "../../"
  environment                    = var.environment
  docker_compose_content         = var.docker_compose_content
  db_volume_id                   = var.db_volume_id
  ssm_registry_password_path     = "/app/registry/password"
  ssm_postgres_user_path         = "/app/db/user"
  ssm_app_image_tag_path         = "/app/image/tag"
  ssm_registry_user_path         = "/app/registry/user"
  ssm_internal_registry_url_path = "/app/registry/url"
  ssm_postgres_db_path           = "/app/db/name"
  private_subnet_id              = aws_subnet.private_subnet.id
  ssm_postgres_password_path     = "/app/db/password"
  ssm_app_image_name_path        = "/app/image/name"
  sg_app_id                      = aws_security_group.app.id
  key_pair_name                  = aws_key_pair.this.key_name
}
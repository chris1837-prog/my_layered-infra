provider "aws" {
  region  = "eu-central-1"
  profile = "AdministratorAccess-694816839566"
}

resource "aws_vpc" "test_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.test_vpc.id
  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

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

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name        = "${var.environment}-nat-gateway"
    Environment = var.environment
  }
  depends_on = [aws_internet_gateway.public]
}

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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name        = "${var.environment}-private-route-table"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

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

resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "this" {
  key_name   = "appdb_test_key.pem"
  public_key = tls_private_key.test_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.test_key.private_key_pem
  filename        = "appdb_test_key.pem"
  file_permission = "0600"
}

resource "aws_ec2_instance_connect_endpoint" "eic_endpoint" {
  subnet_id          = aws_subnet.private_subnet.id
  security_group_ids = [aws_security_group.app.id]
  tags = {
    Name        = "${var.environment}-eic-endpoint"
    Environment = var.environment
  }
}

module "appdb" {
  source                        = "../../"
  environment                   = var.environment
  ssm_registry_password_path    = "/app/registry/password"
  ssm_postgres_user_path        = "/app/db/user"
  ssm_app_image_tag_path        = "/app/image/tag"
  ssm_registry_user_path        = "/app/registry/user"
  ssm_internal_registry_url_path = "/app/registry/url"
  ssm_postgres_db_path          = "/app/db/name"
  private_subnet_id             = aws_subnet.private_subnet.id
  ssm_postgres_password_path    = "/app/db/password"
  ssm_app_image_name_path       = "/app/image/name"
  sg_app_id                     = aws_security_group.app.id
  key_pair_name                 = aws_key_pair.this.key_name
}
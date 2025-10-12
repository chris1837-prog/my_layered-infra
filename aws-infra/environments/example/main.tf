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

resource "aws_subnet" "test_subnet" {
  vpc_id     = aws_vpc.test_vpc.id
  cidr_block = var.subnet_cidr_block
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-subnet"
    Environment = var.environment
  }
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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.test_subnet.id
  route_table_id = aws_route_table.public.id
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
}


module "appdb" {
  source = "../../modules/appdb"

  environment  = var.environment

  ssm_registry_password_path    = "/app/registry/password"
  ssm_postgres_user_path       = "/app/db/user"
  ssm_app_image_tag_path       = "/app/image/tag"
  ssm_registry_user_path       = "/app/registry/user"
  ssm_internal_registry_url_path = "/app/registry/url"
  ssm_postgres_db_path         = "/app/db/name"
  private_subnet_id            = aws_subnet.test_subnet.id
  ssm_postgres_password_path   = "/app/db/password"
  ssm_app_image_name_path      = "/app/image/name"
  sg_app_id                    = aws_security_group.app.id
  key_pair_name                = "jtest"
}

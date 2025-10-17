provider "aws" {
  region  = "eu-central-1"
  profile = "AdministratorAccess-694816839566"
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Locals for consistent values and dynamic AMI selection
locals {
  instance_type       = "t3.micro"
  vpc_cidr            = "10.0.0.0/16"
  allowed_admin_cidrs = ["0.0.0.0/0"]
  project_name        = "layered-infra"
  ubuntu_version      = "22.04"
  arch                = can(regex(".*g\\.", local.instance_type)) ? "arm64" : "amd64"
  ubuntu_ssm_path     = "/aws/service/canonical/ubuntu/server/${local.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"
  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = var.environment
    Team        = "A"
    Module      = "Private-Egress-via-Edge"
  }
}

# Generate SSH key pair
resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "this" {
  key_name   = "${local.project_name}-${var.environment}-key"
  public_key = tls_private_key.test_key.public_key_openssh
}

# Save private key locally
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.test_key.private_key_pem
  filename        = "${path.module}/${local.project_name}-${var.environment}-key.pem"
  file_permission = "0600"
}

# IAM Role and Instance Profile for Edge
resource "aws_iam_role" "ec2_role" {
  name = "${local.project_name}-${var.environment}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
  tags = local.common_tags
}


# EC2 Instance Connect Endpoint
resource "aws_ec2_instance_connect_endpoint" "eic_endpoint" {
  subnet_id          = module.network.private_subnet_ids[0]
  security_group_ids = [module.network.sg_app_id]
  tags               = merge(local.common_tags, { Name = "${local.project_name}-${var.environment}-eic-endpoint" })
}

# Allow SSH from Edge SG for testing over ssh
resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_edge" {
  security_group_id            = module.network.sg_app_id
  description                  = "Allow SSH from Edge SG"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = module.network.sg_edge_id
}

resource "aws_security_group_rule" "app_ssh_from_local" {
  type              = "ingress"
  security_group_id = module.network.sg_app_id
  description       = "Allow SSH from local IP for EC2 Instance Connect"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Elastic IP for Edge
resource "aws_eip" "edge" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${local.project_name}-${var.environment}-edge-eip" })
}

# Get Ubuntu AMI
data "aws_ssm_parameter" "ubuntu" {
  name = local.ubuntu_ssm_path
}


# Route to Edge instance for NAT
resource "aws_route" "private_to_nat" {
  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.edge.primary_network_interface_id
}

# Network Module
module "network" {
  source = "../../../network"

  project_name = local.project_name
  common_tags  = local.common_tags

  vpc_cidr            = local.vpc_cidr
  allowed_admin_cidrs = local.allowed_admin_cidrs

  # Single AZ configuration
  az_configurations = {
    (data.aws_availability_zones.available.names[0]) = {
      public_subnet_cidr  = "10.0.1.0/24"
      private_subnet_cidr = "10.0.2.0/24"
    }
  }

  enable_dns_support            = true
  enable_dns_hostnames          = true
  allow_map_public_ip_on_launch = true
  application_port              = 3000
  open_internet_cidr            = "0.0.0.0/0"
  tcp_protocol                  = "tcp"
  udp_protocol                  = "udp"
  all_protocols                 = "-1"
  https_port                    = 443
  http_port                     = 80
  ssh_port                      = 22
  wireguard_port                = 51820
}


resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.project_name}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}


# Edge Module
module "edge" {
  source = "../../../edge"

  project_name              = local.project_name
  environment               = var.environment
  vpc_id                    = module.network.vpc_id
  edge_private_ip           = "10.0.1.130"
  registry_user             = "registry"
  registry_password         = "registry"
  registry_external_url     = "https://registry.dev.uselayered.com"
  registry_internal_url     = "https://registry.internal.dev.uselayered.com"
  instance_type             = local.instance_type
  sg_edge_id                = module.network.sg_edge_id
  ubuntu_version            = local.ubuntu_version
  key_name                  = aws_key_pair.this.key_name
  admin_ssh_keys            = [tls_private_key.test_key.public_key_openssh]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  public_subnet_id          = module.network.public_subnet_ids[0]
  admin_cidrs               = local.allowed_admin_cidrs
  domain_name               = "edge.dev.uselayered.com"
  backend_servers           = ["10.0.2.10:3000", "10.0.2.11:3000"]
  enable_domain_tls         = true
  enable_domain_acme        = true
  enable_eip_association    = true
  eip_allocation_id         = aws_eip.edge.id
}

# AppDB Module
module "appdb" {
  source                         = "../../../appdb"
  project_name                   = local.project_name
  environment                    = var.environment
  docker_compose_content         = var.docker_compose_content
  db_volume_id                   = var.db_volume_id
  ssm_registry_password_path     = "/app/registry/password"
  ssm_postgres_user_path         = "/app/db/user"
  ssm_app_image_tag_path         = "/app/image/tag"
  ssm_registry_user_path         = "/app/registry/user"
  ssm_internal_registry_url_path = "/app/registry/url"
  ssm_postgres_db_path           = "/app/db/name"
  private_subnet_id              = module.network.private_subnet_ids[0]
  ssm_postgres_password_path     = "/app/db/password"
  ssm_app_image_name_path        = "/app/image/name"
  sg_app_id                      = module.network.sg_app_id
  key_pair_name                  = aws_key_pair.this.key_name
}
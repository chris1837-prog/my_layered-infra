provider "aws" {
  region  = "eu-central-1"
  profile = "AdministratorAccess-694816839566"
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
  environment   = "dev"
  instance_type = "t3.micro"
  vpc_cidr      = "10.0.0.0/16"

  common_tags = {
    Project     = local.project_name
    ManagedBy   = "Terraform"
    Environment = local.environment
    Team        = "B"
    Module      = "Edge Basic Usage"
  }

  arch            = can(regex(".*g\\.", local.instance_type)) ? "arm64" : "amd64"
  ubuntu_version  = "22.04"
  ubuntu_ssm_path = "/aws/service/canonical/ubuntu/server/${local.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"
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

# Security Group for the public Edge VM
resource "aws_security_group" "edge" {
  name        = "${local.project_name}-edge-sg"
  description = "Controls traffic for the public Edge VM (Caddy & WireGuard)."
  vpc_id      = aws_vpc.test_vpc.id

  tags = merge(
    { Name = "${local.project_name}-edge-sg" },
    local.common_tags
  )
}

# =============================================================================
# INGRESS RULES for Edge SG
# =============================================================================

# Allow HTTPS from the public internet to Caddy
resource "aws_vpc_security_group_ingress_rule" "edge_https" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow HTTPS from the internet to Caddy"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow HTTP from the public internet to Caddy (for redirects)
resource "aws_vpc_security_group_ingress_rule" "edge_http" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow HTTP from the internet to Caddy (for redirects)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow WireGuard VPN traffic from admin devices
resource "aws_vpc_security_group_ingress_rule" "edge_wireguard" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow WireGuard UDP traffic from admin devices"
  ip_protocol       = "udp"
  from_port         = 51820
  to_port           = 51820
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow SSH access for management
resource "aws_vpc_security_group_ingress_rule" "edge_ssh" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow SSH from admin devices for management"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# EGRESS RULES
# =============================================================================

# Allow all outbound traffic from the Edge VM
resource "aws_vpc_security_group_egress_rule" "edge_egress" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow all outbound traffic from Edge VM"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -------------------------
# IAM Role for EC2
# -------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${local.project_name}-${local.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ec2-role"
  })
}

# -------------------------
# IAM Instance Profile for Edge EC2
# -------------------------
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.project_name}-${local.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ec2-instance-profile"
  })
}

# -------------------------
# Attach SSM Policy
# -------------------------
resource "aws_iam_role_policy_attachment" "ec_ssm_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

##################################
# Route53 Hosted Zone (per environment)
##################################

resource "aws_route53_zone" "environment" {
  name = "${local.environment}.${"uselayered.com"}"

}

##################################
# Elastic IP for edge host (public)
##################################

resource "aws_eip" "edge" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-edge-eip"
  })
}

##################################
# PUBLIC record for GitHub Actions to push images
##################################

# resource "aws_route53_record" "registry_public" {
#   zone_id = aws_route53_zone.environment.zone_id
#   name    = "registry.${aws_route53_zone.environment.name}" # registry.dev.uselayered.com
#   type    = "A"
#   ttl     = 300
#   records = [aws_eip.edge.public_ip]

# }
# ##################################
# # Primary edge record / edge host public record (for reverse proxy & ACME)
# ##################################

# resource "aws_route53_record" "edge_primary" {
#   zone_id = aws_route53_zone.environment.zone_id
#   name    = "edge.${aws_route53_zone.environment.name}" # edge.dev.uselayered.com
#   type    = "A"
#   ttl     = 300
#   records = [aws_eip.edge.public_ip]
# }

# ##################################
# # PRIVATE record for internal VPC services to pull images
# ##################################

# resource "aws_route53_record" "registry_private" {
#   zone_id = aws_route53_zone.environment.zone_id
#   name    = "registry.internal.${aws_route53_zone.environment.name}" # registry.internal.dev.uselayered.com
#   type    = "A"
#   ttl     = 300
#   records = ["10.0.1.130"]
# }

# --- Dynamic SSH Key Generation ---
resource "tls_private_key" "edge" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "edge" {
  key_name   = "${local.project_name}-${local.environment}-edge-key"
  public_key = tls_private_key.edge.public_key_openssh
}

# Save private key locally for admin use
resource "local_file" "edge_private_key" {
  content         = tls_private_key.edge.private_key_pem
  filename        = abspath("${path.module}/edge_private_key.pem")
  file_permission = "0600"
}

module "edge" {
  source = "../../"

  project_name      = "layered-infra"
  environment       = "dev"
  vpc_id            = aws_vpc.test_vpc.id
  edge_private_ip   = "10.0.1.130"
  registry_user     = "registry"
  registry_password = "registry"
  # Explicitly override registry URLs to avoid relying on SSM in examples/tests.
  # Supply full URLs (module variables now require https:// scheme)
  # Route 53 records are created in bootstrap and must exist before applying this module
  registry_external_url     = "https://registry.dev.uselayered.com"
  registry_internal_url     = "https://registry.internal.dev.uselayered.com"
  registry_zone_name        = "dev.uselayered.com"
  instance_type             = local.instance_type
  sg_edge_id                = aws_security_group.edge.id
  ubuntu_version            = local.ubuntu_version
  key_name                  = aws_key_pair.edge.key_name
  admin_ssh_keys            = [tls_private_key.edge.public_key_openssh]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  public_subnet_id          = aws_subnet.public_subnet.id
  admin_cidrs               = ["0.0.0.0/0"]
  # Use a hostname within the delegated subdomain for automatic HTTPS instead of the parent apex
  domain_name               = "edge.dev.uselayered.com"
  backend_servers           = ["10.0.2.10:3000", "10.0.2.11:3000"]
  # Ensure the Edge instance gets a public IP via the created Elastic IP
  enable_eip_association    = true
  eip_allocation_id         = aws_eip.edge.id
}

# Note: In this self-contained example we avoid creating SSM parameters.
# Real environments should use the bootstrap module to write these to SSM.

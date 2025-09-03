# =============================================================================
# examples/private_egress_via_edge/main.tf
# Test configuration for private egress via Edge NAT instance
# =============================================================================

# Provider config without a specific profile to use default auth chain
provider "aws" {
  region = "eu-central-1"
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Locals for consistent values and dynamic AMI selection
locals {
  instance_type = "t3.micro"
  vpc_cidr      = "10.0.0.0/16" # Define once, use everywhere
  project_name  = "layered-infra"
  # Define common_tags in one place
  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = "Testing"
    Team        = "A"
    Module      = "Private-Egress-via-Edge-Test"
  }

  # Detect architecture from instance type
  arch            = can(regex(".*g\\.", local.instance_type)) ? "arm64" : "amd64"
  ubuntu_version  = "22.04"
  ubuntu_ssm_path = "/aws/service/canonical/ubuntu/server/${local.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"
}

# Generate SSH key pair inside Terraform
resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "this" {
  key_name   = "${local.project_name}-nat-test-key"
  public_key = tls_private_key.test_key.public_key_openssh
}

# Save private key locally for Terratest
resource "local_file" "ssh_private_key" {
  content        = tls_private_key.test_key.private_key_pem
  filename       = abspath("${path.module}/network_test_key.pem")
  file_permission = "0600"
}

variable "allowed_admin_cidr" {
  description = "Admin CIDR allowed for SSH / WG (used by the network module)."
  type        = string
  default     = "0.0.0.0/0" # safe default for quick tests - change for production
}

module "network" {
  source = "../.." # Points to the root network module directory

  project_name = local.project_name
  common_tags  = local.common_tags


  vpc_cidr           = local.vpc_cidr
  allowed_admin_cidr = var.allowed_admin_cidr

  # Single AZ configuration
  az_configurations = {
    (data.aws_availability_zones.available.names[0]) = {
      public_subnet_cidr  = "10.0.1.0/24"
      private_subnet_cidr = "10.0.2.0/24"
    }
  }

  # Set other variables with their defaults for clarity
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

data "aws_ssm_parameter" "ubuntu" {
  name = local.ubuntu_ssm_path
}

# --- Create the Edge Instance that will act as NAT ---
resource "aws_instance" "test_edge_instance" {
  ami           = data.aws_ssm_parameter.ubuntu.value
  instance_type = local.instance_type
  subnet_id     = module.network.public_subnet_ids[0]

  # CRITICAL: Disable source/dest check for NAT functionality
  source_dest_check = false

  # Security group that allows SSH for setup
  vpc_security_group_ids = [module.network.sg_edge_id]

  # SSH key for access
  key_name = aws_key_pair.this.key_name

  # Cloud-init script embedded directly
    user_data = <<-EOT
    #!/bin/bash
    set -eux

    echo "[edge-init] Start user_data script" | tee /var/log/edge-init.log

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

    # Install required packages
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y iptables-persistent curl

    # Detect primary interface
    PRIMARY_IFACE=$(ip route show default | awk '{print $5}' | head -n1)

    echo "[edge-init] Primary interface: $PRIMARY_IFACE" | tee -a /var/log/edge-init.log

    # Create persistent NAT rules file
    cat > /etc/iptables/rules.v4 <<EOF
  *nat
  :PREROUTING ACCEPT [0:0]
  :INPUT ACCEPT [0:0]
  :OUTPUT ACCEPT [0:0]
  :POSTROUTING ACCEPT [0:0]
  -A POSTROUTING -s ${local.vpc_cidr} -o $PRIMARY_IFACE -j MASQUERADE
  COMMIT
EOF

  # Load rules immediately
  iptables-restore < /etc/iptables/rules.v4

  echo "[edge-init] Final NAT table:" | tee -a /var/log/edge-init.log
  iptables -t nat -S | tee -a /var/log/edge-init.log

  echo "[edge-init] Completed successfully" | tee -a /var/log/edge-init.log
EOT

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-test-edge-instance"
  })

}

# --- Create a test instance in private subnet to validate NAT ---
resource "aws_instance" "test_appdb_instance" {
  ami           = data.aws_ssm_parameter.ubuntu.value
  instance_type = local.instance_type
  subnet_id     = module.network.private_subnet_ids[0]

  # Security group that allows outbound traffic
  vpc_security_group_ids = [module.network.sg_app_id]

  # SSH key for access
  key_name = aws_key_pair.this.key_name

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-test-appdb-instance"
  })

}

# --- Create route in private route table to Edge NAT instance ---
resource "aws_route" "private_to_nat" {
  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.test_edge_instance.primary_network_interface_id
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
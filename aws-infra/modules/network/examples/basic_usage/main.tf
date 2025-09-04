# =============================================================================
# examples/basic_usage/main.tf
# Minimal test configuration for the network module (for terraform validate/plan)
# =============================================================================

# Provider config without a specific profile to use default auth chain
provider "aws" {
  region = "eu-central-1"
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "../.." # Points to the root network module directory

  project_name = "layered-infra-test"
  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = "Testing"
    Team        = "A"
    Module      = "Network"
  }

  vpc_cidr           = "10.0.0.0/16"
  allowed_admin_cidr = "10.0.0.0/8" # Example: wider range for testing

  # Single AZ configuration matching the architecture diagram
  az_configurations = {
    # Use the first available AZ
    (data.aws_availability_zones.available.names[0]) = {
      public_subnet_cidr  = "10.0.1.0/24" # For Edge VM (10.0.1.10)
      private_subnet_cidr = "10.0.2.0/24" # For App VM (10.0.2.10)
    }
  }
  # Optional: Set other variables with their defaults for clarity
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
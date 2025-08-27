# =============================================================================
# examples/basic_usage/main.tf
# Test configuration for the network module
# =============================================================================

terraform {
  required_version = "1.12.2

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  profile = "layered-qa-694816839566"
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
    Environment = "Development"
    Team        =  "A"
    Module = "Network"
  }

  # Network configuration
  #cidr_block = "10.0.0.0/16"

  # # Single AZ configuration matching the architecture diagram
  #  az_configurations = {
  #    # Use the first available AZ
  #    (data.aws_availability_zones.available.names[0]) = {
  #      public_subnet_cidr  = "10.0.1.0/24"  # For Edge VM (10.0.1.10)
  #      private_subnet_cidr = "10.0.2.0/24"  # For App VM (10.0.2.10)
  #    }
  #  }

  # Security configuration (override defaults for testing)
  wireguard_admin_cidr = "192.168.1.0/24" # Example: restrict to test network
  ssh_admin_cidr       = "10.0.0.0/8"     # Example: wider range for testing


}
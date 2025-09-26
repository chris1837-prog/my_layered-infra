# =============================================================================
# examples/basic_usage/main.tf
# Minimal test configuration for the remote_backend module (for terraform validate/plan)
# =============================================================================

# Provider config without a specific profile to use default auth chain
provider "aws" {
  region = "eu-central-1"
}

module "remote_backend" {
  source = "../.."

  project_name = "layered-infra-test"
  environment  = "dev"

  common_tags = {
    Environment = "Testing"
    Team        = "A"
    Module      = "remote_backend"
  }
}

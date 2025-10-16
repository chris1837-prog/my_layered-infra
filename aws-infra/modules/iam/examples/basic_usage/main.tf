# =============================================================================
# examples/basic_usage/main.tf
# Minimal test configuration for the IAM module (for terraform validate/plan)
# =============================================================================

provider "aws" {
  region = "eu-central-1"
}

module "iam" {
  source = "../.." # Points to the root IAM module directory
  # Remote state backend IAM role
  tf_state_bucket    = "example-terraform-state-bucket"
  lock_table         = "example-terraform-lock-table"
  engineer_role_name = "example-engineer-role"
  # EC2 IAM role + instance profile
  project_name = "layered-infra-test"
  environment  = "Testing"

  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = "Testing"
    Team        = "A/D"
    Module      = "iam"
  }
}
# =============================================================================
# examples/basic_usage/main.tf
# Minimal test configuration for the IAM module (for terraform validate/plan)
# =============================================================================

provider "aws" {
  region  = "eu-central-1"
  profile = "AdministratorAccess-694816839566"
}

# Example values for remote state resources
locals {
  tf_state_bucket = "example-terraform-state-bucket"
  lock_table      = "example-terraform-lock-table"
}

module "iam" {
  source             = "../.." # Points to the root IAM module directory
  tf_state_bucket    = local.tf_state_bucket
  lock_table         = local.lock_table
  engineer_role_name = "test-engineer-role"
}
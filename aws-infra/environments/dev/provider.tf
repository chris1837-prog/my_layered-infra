########################################
# Provider (DEV)
########################################

provider "aws" {
  region = local.bootstrap_outputs.aws_region
}
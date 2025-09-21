# This file is necessary for running 'terraform init' and 'terraform validate'
# in the examples/basic/ directory.
terraform {
  required_version = "~> 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.5.0"
    }
  }
}
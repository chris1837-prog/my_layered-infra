# This file is necessary for running 'terraform init' and 'terraform validate'
# in the examples/private_egress_via_edge/ directory.
terraform {
  required_version = "~> 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0" # Add TLS provider requirement
    }
  }
}
provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}


module "edge" {
  source = "../../"

  project_name      = "mvp"
  environment       = "qa"
  vpc_id            = var.vpc_id
  instance_type     = var.instance_type
  public_subnet_id  = var.public_subnet_id
  admin_cidrs       = var.admin_cidrs
  admin_ssh_keys    = var.admin_ssh_keys
  domain_name       = var.domain_name
  backend_servers   = var.backend_servers
}
locals {
  # Detect architecture from instance type
  # ARM = Graviton families (t4g, m6g, c7g, etc.), otherwise AMD64
  arch = can(regex(".*g\\.", var.instance_type)) ? "arm64" : "amd64"

  # Build SSM parameter path dynamically
  ubuntu_ssm_path = "/aws/service/canonical/ubuntu/server/${var.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"
}

locals {
  enforced_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  merged_tags = merge(var.common_tags, local.enforced_tags)
}

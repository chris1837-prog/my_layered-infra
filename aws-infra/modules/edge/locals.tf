locals {
  # Detect architecture from instance type
  # ARM = Graviton families (t4g, m6g, c7g, etc.), otherwise AMD64
  arch = can(regex(".*g\\.", var.instance_type)) ? "arm64" : "amd64"

  # Build SSM parameter path dynamically
  ubuntu_ssm_path = "/aws/service/canonical/ubuntu/server/${var.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"

  # Build SSM parameter names for registry credentials dynamically
  registry_password_ssm_path = "/edge/registry/${var.environment}/password"  # maybe not
  registry_user_ssm_path     = "/edge/registry/${var.environment}/username"

  # Build final registry password
  registry_password_final = var.registry_password != null ? var.registry_password : random_password.registry.result

  # bcrypt hash of the final registry password
  bcrypt_hash = bcrypt(local.registry_password_final)
}
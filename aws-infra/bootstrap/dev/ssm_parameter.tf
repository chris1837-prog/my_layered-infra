# Generate random passwords for sensitive data
resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "registry_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# Store sensitive data in SSM Parameter Store with SecureString
resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${var.project_name}/${var.environment}/postgres_password"
  type        = "SecureString"
  value       = random_password.postgres_password.result
  description = "PostgreSQL password"
}

resource "aws_ssm_parameter" "registry_password" {
  name        = "/${var.project_name}/${var.environment}/registry_password"
  type        = "SecureString"
  value       = random_password.registry_password.result
  description = "Private Docker registry password"
}

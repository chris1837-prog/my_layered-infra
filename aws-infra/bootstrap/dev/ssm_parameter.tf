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

# Store non-sensitive configuration as String parameters
resource "aws_ssm_parameter" "registry_url" {
  name        = "/${var.project_name}/${var.environment}/registry_url"
  type        = "String"
  value       = var.registry_url
  description = "Private Docker registry URL"
}

resource "aws_ssm_parameter" "registry_user" {
  name        = "/${var.project_name}/${var.environment}/registry_user"
  type        = "String"
  value       = var.registry_user
  description = "Private Docker registry username"
}

resource "aws_ssm_parameter" "app_image_tag" {
  name        = "/${var.project_name}/${var.environment}/app_image_tag"
  type        = "String"
  value       = var.app_image_tag
  description = "Docker image tag for the application"
}

resource "aws_ssm_parameter" "postgres_db" {
  name        = "/${var.project_name}/${var.environment}/postgres_db"
  type        = "String"
  value       = var.postgres_db
  description = "PostgreSQL database name"
}

resource "aws_ssm_parameter" "postgres_user" {
  name        = "/${var.project_name}/${var.environment}/postgres_user"
  type        = "String"
  value       = var.postgres_user
  description = "PostgreSQL username"
}

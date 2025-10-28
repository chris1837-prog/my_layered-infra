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

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "registry_password" {
  name        = "/${var.project_name}/${var.environment}/registry_password"
  type        = "SecureString"
  value       = random_password.registry_password.result
  description = "Private Docker registry password"

  tags = local.merged_tags
}

# Store non-sensitive configuration as String parameters
resource "aws_ssm_parameter" "external_registry_url" {
  name        = "/${var.project_name}/${var.environment}/external_registry_url"
  type        = "String"
  value       = aws_route53_record.registry_public.fqdn # Use the FQDN of the public record
  description = "Private Docker external registry URL"

  tags = local.merged_tags
}

# Store non-sensitive configuration as String parameters
resource "aws_ssm_parameter" "internal_registry_url" {
  name        = "/${var.project_name}/${var.environment}/internal_registry_url"
  type        = "String"
  value       = aws_route53_record.registry_private.fqdn # Use the FQDN of the public record
  description = "Private Docker internal registry URL"

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "edge_primary_url" {
  name        = "/${var.project_name}/${var.environment}/edge_primary_url"
  type        = "String"
  value       = aws_route53_record.edge_primary.fqdn # Use the FQDN of the public record
  description = "Primary URL for the Edge VM"

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "registry_user" {
  name        = "/${var.project_name}/${var.environment}/registry_user"
  type        = "String"
  value       = var.registry_user
  description = "Private Docker registry username"

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "app_image_name" {
  name        = "/${var.project_name}/${var.environment}/app_image_name"
  type        = "String"
  value       = var.app_image_name
  description = "Docker image name for the application"
}

resource "aws_ssm_parameter" "app_image_tag" {
  name        = "/${var.project_name}/${var.environment}/app_image_tag"
  type        = "String"
  value       = var.app_image_tag
  description = "Docker image tag for the application"

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "postgres_db" {
  name        = "/${var.project_name}/${var.environment}/postgres_db"
  type        = "String"
  value       = var.postgres_db
  description = "PostgreSQL database name"

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "postgres_user" {
  name        = "/${var.project_name}/${var.environment}/postgres_user"
  type        = "String"
  value       = var.postgres_user
  description = "PostgreSQL username"

  tags = local.merged_tags
}

resource "aws_ssm_parameter" "grafana_url" {
  name  = "/layered-infra/${var.environment}/grafana_url"
  type  = "String"
  value = "https://grafana.${var.environment}.${var.domain_name}"
  tags  = local.merged_tags
}

resource "aws_ssm_parameter" "prometheus_url" {
  name  = "/layered-infra/${var.environment}/prometheus_url"
  type  = "String"
  value = "https://prometheus.${var.environment}.${var.domain_name}"
  tags  = local.merged_tags
}

resource "aws_ssm_parameter" "loki_url" {
  name  = "/layered-infra/${var.environment}/loki_url"
  type  = "String"
  value = "https://loki.${var.environment}.${var.domain_name}"
  tags  = local.merged_tags
}

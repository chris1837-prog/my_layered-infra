# Generate backend.tf
resource "local_file" "backend_config" {
  filename = "${path.module}/../../environments/${var.environment}/backend.tf"
  content  = <<EOT
terraform {
  backend "s3" {
    bucket         = "${module.remote_backend.tf_state_bucket_name}"
    dynamodb_table = "${module.remote_backend.tf_state_lock_table}"
    key            = "terraform.tfstate"
    region         = "${var.aws_region}"
  }
}
EOT
}

# Generate bootstrap_outputs.json
resource "local_file" "bootstrap_outputs" {
  filename = "${path.module}/../../environments/${var.environment}/bootstrap_outputs.json"
  content = jsonencode({
    tf_state_bucket_name    = module.remote_backend.tf_state_bucket_name
    tf_state_lock_table     = module.remote_backend.tf_state_lock_table
    github_actions_role_arn = aws_iam_role.github_actions.arn
  })
}

# Generate JSON output file with parameter paths
resource "local_file" "ssm_parameters_json" {
  filename = "${path.module}/../../environments/${var.environment}/ssm_parameters.json"
  content = jsonencode({
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region
    parameter_paths = {
      postgres_password = aws_ssm_parameter.postgres_password.name
      registry_password = aws_ssm_parameter.registry_password.name
      registry_url      = aws_ssm_parameter.registry_url.name
      registry_user     = aws_ssm_parameter.registry_user.name
      app_image_tag     = aws_ssm_parameter.app_image_tag.name
      postgres_db       = aws_ssm_parameter.postgres_db.name
      postgres_user     = aws_ssm_parameter.postgres_user.name
    }
    parameter_values = {
      registry_url  = var.registry_url
      registry_user = var.registry_user
      postgres_db   = var.postgres_db
      postgres_user = var.postgres_user
      app_image_tag = var.app_image_tag
    }
  })
}

# Generate instructions for DNS delegation setup
resource "local_file" "delegation_instructions" {
  filename = "${path.module}/../../environments/${var.environment}/namecheap_setup_${var.environment}.txt"
  content  = <<-EOT
DNS DELEGATION SETUP FOR ${upper(var.environment)}
=================================================
Please log in to the registrar for '${var.domain_name}' (e.g., Namecheap) and navigate to the Advanced DNS settings.

Create FOUR (4) new NS records with the following details:

Type: NS
Host: ${var.environment}
Value: Use one of the four values below (include the trailing dot).
TTL: Automatic / 1 hour

REQUIRED VALUES:
- ${aws_route53_zone.environment.name_servers[0]}.
- ${aws_route53_zone.environment.name_servers[1]}.
- ${aws_route53_zone.environment.name_servers[2]}.
- ${aws_route53_zone.environment.name_servers[3]}.

After saving these records, DNS delegation for *.${var.environment}.${var.domain_name} will be managed by AWS.
  EOT
}
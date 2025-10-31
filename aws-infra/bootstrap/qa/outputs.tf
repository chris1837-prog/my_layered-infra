# bootstrap/dev/outputs.tf

output "github_actions_role_arn" {
  description = "The ARN of the GitHub Actions OIDC role created for Terraform CI/CD"
  value       = aws_iam_role.github_actions.arn
}

output "tf_state_bucket_name" {
  description = "The name of the S3 bucket used for Terraform remote state"
  value       = module.remote_backend.tf_state_bucket_name
}

output "tf_state_lock_table" {
  description = "The name of the DynamoDB table used for Terraform state locking"
  value       = module.remote_backend.tf_state_lock_table
}

output "tf_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state"
  value       = module.remote_backend.tf_state_bucket_arn
}

output "tf_state_lock_table_arn" {
  description = "ARN of the DynamoDB table used for Terraform state locking"
  value       = module.remote_backend.tf_state_lock_table_arn

}

output "environment_subdomain_nameservers" {
  description = "The authoritative name servers for the environment subdomain hosted zone. These MUST be set as NS records in the parent DNS zone."
  value       = aws_route53_zone.environment.name_servers
  sensitive   = false
}

output "edge_eip_allocation_id" {
  description = "The allocation ID of the Elastic IP for the edge instance"
  value       = aws_eip.edge.id
}

output "edge_private_ip" {
  description = "The private IP assigned for the edge instance (used in registry.internal DNS record)"
  value       = var.edge_private_ip
}

output "project_name" {
  value = var.project_name
}

output "environment" {
  value = var.environment
}

output "aws_region" {
  value = var.aws_region
}


# bootstrap/dev/outputs.tf

# GitHub Actions role ARN (created inside bootstrapper)
output "github_actions_role_arn" {
  description = "The ARN of the GitHub Actions OIDC role created for Terraform CI/CD"
  value       = aws_iam_role.github_actions_role.arn
}

# Remote backend S3 bucket name (from remote_backend module)
output "tf_state_bucket_name" {
  description = "The name of the S3 bucket used for Terraform remote state"
  value       = module.remote_backend.tf_state_bucket_name
}

# Remote backend DynamoDB table name (from remote_backend module)
output "tf_state_lock_table" {
  description = "The name of the DynamoDB table used for Terraform state locking"
  value       = module.remote_backend.tf_state_lock_table
}

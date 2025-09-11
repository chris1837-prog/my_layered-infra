output "tf_state_bucket_name" {
  value       = module.remote_backend.tf_state_bucket_name
  description = "The name of the S3 bucket used for Terraform state"
}

output "tf_state_lock_table" {
  value       = module.remote_backend.tf_state_lock_table
  description = "The name of the DynamoDB table used for Terraform state locking"
}

output "tf_state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "tf_state_lock_table" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "tf_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "tf_state_lock_table_arn" {
  description = "ARN of the DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}
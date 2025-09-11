variable "tf_state_bucket" {
  description = "Name of the S3 bucket for Terraform remote state."
  type        = string
}

variable "lock_table" {
  description = "Name of the DynamoDB table for Terraform state locking."
  type        = string
}

variable "engineer_role_name" {
  description = "Name for the engineer IAM role."
  type        = string
  default     = "engineer-role"
}

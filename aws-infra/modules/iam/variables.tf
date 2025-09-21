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

variable "project_name" {
  description = "Project name (used for naming IAM resources)"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, etc.)"
  type        = string
}

variable "common_tags" {
  description = "A map of tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
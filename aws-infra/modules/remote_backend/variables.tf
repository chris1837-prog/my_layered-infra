variable "environment" {
  description = "The environment for which to create resources (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "admin_role_arn" {
  description = "ARN of the IAM role for admin access"
  type        = string
}

variable "developer_role_arn" {
  description = "ARN of the IAM role for developer access"
  type        = string
}
variable "lambda_function_name" {
  type        = string
  description = "Name of the Lambda function to trigger"
}

variable "lambda_function_arn" {
  type        = string
  description = "ARN of the Lambda function to trigger"
}

variable "rule_name" {
  type        = string
  default     = "daily-orphaned-cleanup"
}
variable "name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda handler (e.g. stop_instances.lambda_handler)"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime (e.g. python3.12)"
  type        = string
}

variable "env_vars" {
  description = "Environment variables to pass to Lambda"
  type        = map(string)
  default     = {}
}

variable "policy_json" {
  description = "IAM policy for Lambda as raw JSON"
  type        = string
}

variable "schedule" {
  description = "EventBridge schedule expression"
  type        = string
}

variable "enabled" {
  description = "Whether the rule is enabled"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "source_dir" {
  description = "Path to the Lambda function source code"
  type        = string
}

variable "description" {
  description = "Description for the Lambda function"
  type        = string
  default     = ""
}

variable "environment_variables" {
  description = "Environment variables to pass to the Lambda function"
  type        = map(string)
  default     = {}
}
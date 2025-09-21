variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "start_schedule_expression" {
  description = "Cron expression to start instances"
  type        = string
}

variable "stop_schedule_expression" {
  description = "Cron expression to stop instances"
  type        = string
}

variable "tag_key" {
  description = "Tag key to match instances"
  type        = string
  default     = "Environment"
}

variable "tag_value" {
  description = "Tag value to match instances"
  type        = string
  default     = "QA"
}

variable "region" {
  description = "AWS region to operate in"
  type        = string
}
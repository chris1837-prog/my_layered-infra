########################################
# Variables (QA)
########################################

# --- AWS Provider Vars ---
variable "aws_region" {
  description = "AWS region for QA"
  type        = string
  default     = "eu-central-1"
}

# --- Budget Vars ---
variable "qa_budget_amount_usd" {
  description = "Monthly budget amount for QA (USD)"
  type        = number
  default     = 500
}

variable "qa_alert_emails" {
  description = "Recipients for budget alerts (QA)"
  type        = list(string)
  default     = ["siebert.acer@googlemail.com"]
}

# --- Office Hours Scheduler Vars ---
variable "function_name" {
  description = "Name of the Lambda function for office hours"
  type        = string
  default     = "qa-office-hours-scheduler"
}

variable "start_schedule_expression" {
  description = "Start schedule in cron expression (UTC)"
  type        = string
  default     = "cron(0 7 ? * MON-FRI *)"
}

variable "stop_schedule_expression" {
  description = "Stop schedule in cron expression (UTC)"
  type        = string
  default     = "cron(0 19 ? * MON-FRI *)"
}

variable "tag_key" {
  description = "EC2 tag key to match instances"
  type        = string
  default     = "Environment"
}

variable "tag_value" {
  description = "EC2 tag value to match instances"
  type        = string
  default     = "QA"
}
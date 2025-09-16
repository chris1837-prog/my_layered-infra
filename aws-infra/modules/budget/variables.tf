########################################
# Variables for Budget Module
########################################

variable "name" {
  description = "Budget name (must be unique in the AWS account)"
  type        = string
}

variable "amount_usd" {
  description = "Budget limit in USD"
  type        = number
}

variable "time_unit" {
  description = "Time unit for the budget"
  type        = string
  default     = "MONTHLY" # DAILY | MONTHLY | QUARTERLY | ANNUALLY
}

variable "thresholds" {
  description = "List of thresholds (percentages) for notifications"
  type        = list(number)
  default     = [50, 75, 90]
}

variable "notification_type" {
  description = "Type of notification: ACTUAL or FORECASTED"
  type        = string
  default     = "FORECASTED"
}

variable "emails" {
  description = "List of email recipients for budget alerts"
  type        = list(string)
  default     = []
}

variable "topic_name" {
  description = "SNS topic name for budget notifications"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "cost_filters" {
  description = "Optional Budgets cost filters"
  type        = map(list(string))
  default     = {}
}
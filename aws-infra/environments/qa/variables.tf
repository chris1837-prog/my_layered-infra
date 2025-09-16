########################################
# Variables (QA)
########################################

# --- AWS Provider Vars ---
variable "aws_region" {
  description = "AWS region for QA"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI/SSO profile for QA"
  type        = string
  default     = "qa-sso-profile" # anpassen!
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
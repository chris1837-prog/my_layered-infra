########################################
# Variables (DEV)
########################################

# --- AWS Provider Vars ---
variable "aws_region" {
  description = "AWS region for DEV"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI/SSO profile for DEV"
  type        = string
  default     = "your-sso-profile" # anpassen!
}

# --- Budget Vars ---
variable "dev_budget_amount_usd" {
  description = "Monthly budget amount for DEV (USD)"
  type        = number
  default     = 5
}

variable "dev_alert_emails" {
  description = "Recipients for budget alerts (DEV)"
  type        = list(string)
  default     = ["siebert.acer@googlemail.com"]
}
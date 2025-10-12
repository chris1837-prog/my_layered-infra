########################################
# Variables (DEV)
########################################
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

# --- AppDB Vars ---

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  description = "The CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "environment" {
  description = "The environment for the resources (e.g., dev, prod)"
  type        = string
  default     = "dev"
}
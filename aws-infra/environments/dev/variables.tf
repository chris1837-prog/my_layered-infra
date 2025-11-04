########################################
# Variables (DEV Environment)
########################################

# --- Core Project Vars ---
variable "project_name" {
  description = "Name of the overall project"
  type        = string
  # No default - must be set in terraform.tfvars
}

variable "environment" {
  description = "Name of the deployment environment (e.g., qa, dev)"
  type        = string
  # No default - must be set in terraform.tfvars
}

# --- AWS Provider Vars ---
variable "aws_region" {
  description = "AWS region for DEV"
  type        = string
  default     = "eu-central-1"
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

# --- Office Hours Scheduler Vars ---
variable "function_name" {
  description = "Name of the Lambda function for office hours"
  type        = string
  default     = "dev-office-hours-scheduler"
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
  description = "EC2 tag key to match instances for scheduler"
  type        = string
  default     = "Environment"
}

variable "tag_value" {
  description = "EC2 tag value to match instances for scheduler"
  type        = string
  default     = "dev"
}

# --- EC2 Key Pair ---
variable "ec2_key_pair_name" {
  description = "Name of the EC2 Key Pair to use for SSH access"
  type        = string
  # No default - must be set in terraform.tfvars
}

# --- Networking Vars ---
variable "edge_private_ip" {
  description = "Private IP address for the Edge instance"
  type        = string
}

variable "allowed_admin_cidrs" {
  description = "List of CIDR blocks allowed SSH/Admin access to Edge"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Insecure default - Override in terraform.tfvars
}

variable "PROMTAIL_VERSION" {
  description = "The version of Promtail to install."
  type        = string
}
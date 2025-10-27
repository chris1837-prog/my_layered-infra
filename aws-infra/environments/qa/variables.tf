########################################
# Variables (QA Environment)
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
  default     = ["siebert.acer@googlemail.com"] # Replace with appropriate QA alert emails
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
  description = "EC2 tag key to match instances for scheduler"
  type        = string
  default     = "Environment"
}

variable "tag_value" {
  description = "EC2 tag value to match instances for scheduler"
  type        = string
  default     = "qa" # Changed default to 'qa'
}

# --- EC2 Key Pair ---
variable "ec2_key_pair_name" {
  description = "Name of the EC2 Key Pair to use for SSH access"
  type        = string
  # No default - must be set in terraform.tfvars
}

# Note: docker_compose_content variable was removed.
# It's now read directly in main.tf using file().

variable "edge_private_ip" {
  description = "Private IP address for the Edge instance"
  type        = string
  # Value comes from terraform.tfvars
}

variable "allowed_admin_cidrs" {
  description = "List of CIDR blocks allowed SSH/Admin access to Edge"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Insecure default
}
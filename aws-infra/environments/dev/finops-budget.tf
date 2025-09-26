########################################
# FinOps Budget (DEV)
########################################

module "budget_dev" {
  source = "../../modules/budget"

  name       = "qa-monthly-budget-dev"
  amount_usd = var.dev_budget_amount_usd
  emails     = var.dev_alert_emails
  topic_name = "qa-budget-alerts-dev"

  thresholds        = [50, 75, 90]
  notification_type = "FORECASTED"

  # Optional Filter nach Environment-Tag
  cost_filters = {
    TagKeyValue = ["Environment$Dev"]
  }

  tags = {
    Project     = "layered-infra"
    Environment = "Dev"
    ManagedBy   = "Terraform"
    Module      = "FinOps-Budget"
  }
}
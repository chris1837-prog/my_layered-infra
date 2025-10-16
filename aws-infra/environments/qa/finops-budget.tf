########################################
# FinOps Budget (QA)
########################################

module "budget_qa" {
  source = "../../modules/budget"

  name       = "qa-monthly-budget"
  amount_usd = var.qa_budget_amount_usd
  emails     = var.qa_alert_emails
  topic_name = "qa-budget-alerts"

  thresholds        = [50, 75, 90]
  notification_type = "FORECASTED"

  # Optional Filter nach Environment-Tag
  cost_filters = {
    TagKeyValue = ["Environment$QA"]
  }

  tags = {
    Project     = "layered-infra"
    Environment = "QA"
    ManagedBy   = "Terraform"
    Module      = "FinOps-Budget"
  }
}
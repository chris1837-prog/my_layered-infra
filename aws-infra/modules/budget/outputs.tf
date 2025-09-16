########################################
# Outputs
########################################

output "budget_name" {
  description = "AWS Budget name"
  value       = aws_budgets_budget.this.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN used by the budget"
  value       = aws_sns_topic.budget_alerts.arn
}
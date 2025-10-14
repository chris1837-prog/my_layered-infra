########################################
# Outputs (DEV)
########################################

output "budget_dev_name" {
  description = "Budget name in DEV"
  value       = module.budget_dev.budget_name
}

output "budget_dev_topic_arn" {
  description = "SNS Topic ARN for DEV budget alerts"
  value       = module.budget_dev.sns_topic_arn
}
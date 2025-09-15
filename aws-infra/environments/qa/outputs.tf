########################################
# Outputs (QA)
########################################

output "budget_qa_name" {
  description = "Budget name in QA"
  value       = module.budget_qa.budget_name
}

output "budget_qa_topic_arn" {
  description = "SNS Topic ARN for QA budget alerts"
  value       = module.budget_qa.sns_topic_arn
}
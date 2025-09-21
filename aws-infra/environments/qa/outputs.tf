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

output "office_hours_lambda_function_name" {
  description = "Lambda function name for office hours scheduler"
  value       = module.office_hours_scheduler.lambda_function_name
}

output "office_hours_start_rule_name" {
  description = "EventBridge rule name to start instances"
  value       = module.office_hours_scheduler.start_eventbridge_rule_name
}

output "office_hours_stop_rule_name" {
  description = "EventBridge rule name to stop instances"
  value       = module.office_hours_scheduler.stop_eventbridge_rule_name
}

output "office_hours_lambda_role_arn" {
  description = "IAM Role ARN used by the office hours Lambda"
  value       = module.office_hours_scheduler.lambda_role_arn
}
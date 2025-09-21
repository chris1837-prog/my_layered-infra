output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.office_hours_scheduler.lambda_function_name
}

output "start_eventbridge_rule_name" {
  description = "Name of the EventBridge rule for starting instances"
  value       = module.office_hours_scheduler.start_eventbridge_rule_name
}

output "stop_eventbridge_rule_name" {
  description = "Name of the EventBridge rule for stopping instances"
  value       = module.office_hours_scheduler.stop_eventbridge_rule_name
}

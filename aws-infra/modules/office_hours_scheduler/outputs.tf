# modules/office_hours_scheduler/outputs.tf

output "lambda_function_name" {
  value = aws_lambda_function.scheduler.function_name
}

output "start_eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.start_rule.name
}

output "stop_eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.stop_rule.name
}

output "lambda_role_arn" {
  value = aws_iam_role.office_hours_lambda_role.arn
}
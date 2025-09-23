output "lambda_name" {
  value = aws_lambda_function.scheduled.function_name
}

output "lambda_arn" {
  value = aws_lambda_function.scheduled.arn
}

output "rule_name" {
  value = aws_cloudwatch_event_rule.schedule.name
}
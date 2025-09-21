resource "aws_cloudwatch_event_rule" "daily_cleanup" {
  name        = var.rule_name
  description = "Triggers orphaned resource cleanup Lambda daily"
  schedule_expression = "cron(0 3 * * ? *)" # jeden Tag um 03:00 Uhr UTC
  state = "ENABLED"
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "cleanup-lambda"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}
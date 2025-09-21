resource "aws_cloudwatch_event_rule" "start_rule" {
  name                = "${var.function_name}-start"
  schedule_expression = "cron(0 7 ? * MON-FRI *)" # 9 AM CET = 7 AM UTC
}

resource "aws_cloudwatch_event_rule" "stop_rule" {
  name                = "${var.function_name}-stop"
  schedule_expression = "cron(0 19 ? * MON-FRI *)" # 9 PM CET = 7 PM UTC
}

resource "aws_lambda_function" "scheduler" {
  function_name = var.function_name
  filename      = "${path.module}/lambda.zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.office_hours_lambda_role.arn
  environment {
    variables = {
      TAG_KEY   = var.tag_key
      TAG_VALUE = var.tag_value
    }
  }
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_rule.name
  target_id = "startLambda"
  arn       = aws_lambda_function.scheduler.arn
  input     = jsonencode({ action = "start" })
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  target_id = "stopLambda"
  arn       = aws_lambda_function.scheduler.arn
  input     = jsonencode({ action = "stop" })
}

resource "aws_lambda_permission" "allow_start_event" {
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_rule.arn
}

resource "aws_lambda_permission" "allow_stop_event" {
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_rule.arn
}
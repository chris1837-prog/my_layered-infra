resource "aws_lambda_function" "cleanup" {
  function_name = var.function_name
  role          = aws_iam_role.cleanup_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  timeout     = 60
  memory_size = 128
}
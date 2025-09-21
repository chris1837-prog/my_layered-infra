module "orphaned_cleanup_lambda" {
  source        = "../../modules/orphaned_cleanup"
  function_name = "qa-orphaned-resource-cleanup"
}

module "orphaned_cleanup_scheduler" {
  source = "../../modules/orphaned_cleanup/scheduler"

  lambda_function_name = module.orphaned_cleanup_lambda.lambda_function_name
  lambda_function_arn  = module.orphaned_cleanup_lambda.lambda_function_arn
  rule_name            = "qa-daily-orphaned-cleanup"
}
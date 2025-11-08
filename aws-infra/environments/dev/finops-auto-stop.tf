# module "e1_auto_stop_lambda" {
#   source = "../../modules/scheduled_lambda"
#
#   name        = "e1-auto-stop"
#   handler     = "stop_instances.lambda_handler"
#   runtime     = "python3.12"
#   schedule    = "rate(5 minutes)" # Use "rate(2 hours)" in production
#   source_dir  = "../../functions/e1-auto-stop"
#   description = "Stops QA EC2 instances that exceed run threshold"
#
#   environment_variables = {
#     ENV_TAG_KEY       = "Environment"
#     ENV_TAG_VALUE     = "QA"
#     THRESHOLD_MINUTES = "5"    # For test. Use 120 for prod.
#     DRY_RUN           = "true" # Start in safe mode
#   }
#
#   policy_json = file("${path.module}/../../functions/e1-auto-stop/policy.json")
#   enabled     = true
#
#   tags = {
#     Name        = "e1-auto-stop"
#     Environment = "dev"
#     Module      = "scheduled_lambda"
#   }
# }
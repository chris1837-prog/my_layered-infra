module "office_hours_scheduler" {
  source = "../../modules/office_hours_scheduler"

  function_name             = "qa-office-hours-scheduler"
  start_schedule_expression = "cron(0 7 ? * MON-FRI *)"  # 9 AM CET = 07:00 UTC
  stop_schedule_expression  = "cron(0 19 ? * MON-FRI *)" # 9 PM CET = 19:00 UTC
  tag_key                   = "Environment"
  tag_value                 = "QA"
  region                    = var.aws_region
}
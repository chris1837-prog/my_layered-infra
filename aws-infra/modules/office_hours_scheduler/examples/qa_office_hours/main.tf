module "office_hours_scheduler" {
  source = "../.."

  function_name             = "qa-office-hours"
  start_schedule_expression = "cron(0 7 ? * MON-FRI *)"   # 09:00 CET = 07:00 UTC
  stop_schedule_expression  = "cron(0 19 ? * MON-FRI *)"  # 21:00 CET = 19:00 UTC
  tag_key                   = "Environment"
  tag_value                 = "QA"
  region                    = "eu-central-1"
}
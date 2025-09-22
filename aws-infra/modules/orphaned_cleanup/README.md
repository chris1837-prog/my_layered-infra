

# Orphaned Resource Cleanup Scheduler

This module sets up a scheduled trigger for the orphaned resource cleanup Lambda function using AWS CloudWatch Event Rules.

## Resources Created

- `aws_cloudwatch_event_rule` — Defines the schedule for running the Lambda.
- `aws_cloudwatch_event_target` — Connects the rule to the Lambda function.
- `aws_lambda_permission` — Allows CloudWatch Events to invoke the Lambda.

## Input Variables

| Name                  | Description                                               | Type   | Required |
|-----------------------|-----------------------------------------------------------|--------|----------|
| `lambda_function_name`| The name of the Lambda function to invoke.                | string | yes      |
| `schedule_expression` | A valid CloudWatch schedule expression (e.g. `cron(...)`).| string | yes      |
| `tags`                | Tags to apply to resources.                               | map    | no       |
| `prefix`              | Name prefix to distinguish environment/module.            | string | yes      |

## Example Usage

```hcl
module "orphaned_cleanup_scheduler" {
  source              = "../../modules/orphaned_cleanup/scheduler"
  lambda_function_name = "qa-orphaned-resource-cleanup"
  schedule_expression = "cron(0 3 * * ? *)"
  prefix              = "qa"
  tags = {
    Environment = "QA"
    ManagedBy   = "Terraform"
  }
}
```
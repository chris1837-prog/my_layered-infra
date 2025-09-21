

## Orphaned Cleanup Scheduler Module

This module defines a CloudWatch Events rule that triggers a Lambda function on a daily schedule to clean up orphaned AWS resources (e.g., EBS volumes, snapshots).

### Resources

- `aws_cloudwatch_event_rule`: Triggers the daily Lambda execution.
- `aws_cloudwatch_event_target`: Connects the rule to the Lambda function.
- `aws_lambda_permission`: Grants CloudWatch Events permission to invoke the Lambda.

### Variables

- `rule_name`: Name of the CloudWatch Event Rule (default: `daily-orphaned-cleanup`)
- `schedule_expression`: Cron expression for the rule (default: `cron(0 3 * * ? *)`)

### Example

```hcl
module "orphaned_cleanup_scheduler" {
  source              = "../../modules/orphaned_cleanup/scheduler"
  rule_name           = "qa-daily-orphaned-cleanup"
  schedule_expression = "cron(0 3 * * ? *)"
}
```
# modules/office_hours_scheduler/README.md

# Office Hours Scheduler (Terraform Module)

This module sets up a scheduled Lambda function to **stop** and **start** EC2 instances during off-hours in non-production environments such as QA.

## 🧠 Motivation
FinOps initiative to reduce cloud costs by stopping resources automatically during off-hours.

## ⚙️ What It Deploys
- IAM role for Lambda with EC2 + CloudWatch permissions
- Lambda function (Python) zipped and deployed
- EventBridge rule with configurable cron
- Target: EC2 instances with tag `Environment = QA`

## 📥 Inputs
| Name                | Type   | Description                            |
|---------------------|--------|----------------------------------------|
| `lambda_role_name`  | string | IAM role name for the Lambda           |
| `cron_expression`   | string | Schedule expression (e.g. stop/start)  |
| `action`            | string | Either `stop` or `start`               |
| `target_tag_key`    | string | EC2 tag key to filter (e.g. `Environment`) |
| `target_tag_value`  | string | EC2 tag value (e.g. `QA`)              |

## 📤 Outputs
- Lambda function name
- EventBridge rule name
- IAM role ARN

## 🔍 Example
See [`examples/qa_office_hours`](./examples/qa_office_hours) for a full usage example.

## ✅ Tested With

- Terraform v1.8.0+
- AWS Provider v5.47.0+

## 📦 Packaging

Before deployment, ensure you have zipped the Lambda correctly:

```bash
cd modules/office_hours_scheduler
zip lambda.zip lambda_function.py
```

This zip file must be available before `terraform apply`.

## 🛂 Permissions

The module creates a scoped IAM role with the following actions:

- `ec2:DescribeInstances`
- `ec2:StartInstances`
- `ec2:StopInstances`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

## ⏱️ Scheduling

Use standard AWS cron expressions:

- `cron(0 7 ? * MON-FRI *)` → Start every weekday at 07:00 UTC
- `cron(0 19 ? * MON-FRI *)` → Stop every weekday at 19:00 UTC

## 🧪 QA

This module was tested in the `qa` environment and verified with both `terraform apply` and `terraform destroy` via automation script.

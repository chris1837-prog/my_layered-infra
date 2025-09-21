# scheduled_lambda Module

Reusable Terraform module to create scheduled AWS Lambda functions triggered by EventBridge rules.

---

## 📦 What It Does

This module creates:
- A Lambda function (from an existing `lambda.zip` in the module folder)
- An IAM role and inline policy
- An EventBridge schedule rule
- A target connecting the rule to the Lambda
- The necessary Lambda invoke permissions

---

## 📁 Files

```text
scheduled_lambda/
├── main.tf          # Infra setup (Lambda, IAM, EventBridge)
├── variables.tf     # Inputs for customization
├── outputs.tf       # Outputs (lambda_name, lambda_arn, rule_name)
└── README.md        # This file
```

---

## 🛠️ Inputs

| Name           | Type        | Required | Description |
|----------------|-------------|----------|-------------|
| `name`         | `string`    | ✅       | Lambda function name |
| `handler`      | `string`    | ✅       | Lambda handler (e.g. `stop_instances.lambda_handler`) |
| `runtime`      | `string`    | ✅       | Lambda runtime (e.g. `python3.12`) |
| `env_vars`     | `map(string)` | optional | Env vars passed to the function |
| `policy_json`  | `string`    | ✅       | IAM policy JSON (inline) |
| `schedule`     | `string`    | ✅       | EventBridge schedule expression |
| `enabled`      | `bool`      | optional | Enable/disable rule (default: true) |
| `tags`         | `map(string)` | optional | Common tags |

---

## 📤 Outputs

| Name          | Description                        |
|---------------|------------------------------------|
| `lambda_name` | Name of the created Lambda function |
| `lambda_arn`  | ARN of the Lambda function          |
| `rule_name`   | Name of the EventBridge rule        |

---

## 📌 Notes

- The Lambda zip (`lambda.zip`) must be placed in this module folder before `terraform apply`.
- Environment variables like `ENV_TAG_KEY`, `THRESHOLD_MINUTES`, etc., can be passed via `env_vars`.
- Use `enabled = false` to disable the rule without removing the Lambda.

---

## ✅ Example

```hcl
module "auto_stop_lambda" {
  source      = "../../modules/scheduled_lambda"
  name        = "qa-auto-stop"
  handler     = "stop_instances.lambda_handler"
  runtime     = "python3.12"
  schedule    = "rate(5 minutes)"
  enabled     = true
  env_vars = {
    ENV_TAG_KEY     = "Environment"
    ENV_TAG_VALUE   = "QA"
    THRESHOLD_MINUTES = "5"
    DRY_RUN         = "true"
  }
  policy_json = file("${path.module}/../../functions/e1-auto-stop/policy.json")

  tags = {
    Environment = "Dev"
    Module      = "auto-stop"
  }
}
```

# Auto-Stop QA Instances (E1 Lambda)

This Lambda function stops EC2 instances that are tagged with `Environment=QA` if they have been running longer than a configurable time threshold.

---

## 📁 Path

```
aws-infra/functions/e1-auto-stop/
```

---

## 🧠 How It Works

1. A scheduled EventBridge rule triggers the Lambda periodically.
2. Lambda checks for EC2 instances tagged with `Environment=QA`.
3. If any instance has a launch time older than the specified threshold (e.g., 2 hours), it is stopped.
4. The function supports dry-run mode for safe testing.

---

## 🔧 Environment Variables

| Variable           | Description                                | Example       |
|-------------------|--------------------------------------------|---------------|
| `ENV_TAG_KEY`     | Tag key to filter instances                | `Environment` |
| `ENV_TAG_VALUE`   | Tag value to filter (e.g., QA)             | `QA`          |
| `THRESHOLD_MINUTES` | Max allowed uptime in minutes              | `120`         |
| `DRY_RUN`         | If `true`, logs what would happen          | `true`        |

---

## 🔐 IAM Permissions

See `policy.json`. Required permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeInstances",
    "ec2:StopInstances"
  ],
  "Resource": "*"
}
```

This policy should be attached to the Lambda's execution role, scoped to resources with the correct tag conditions.

---

## 🧪 Testing

Run unit tests using:

```bash
pytest tests/
```

---

## 📜 Files

- `stop_instances.py` – Lambda handler function
- `policy.json` – IAM policy for the function
- `requirements.txt` – (optional)
- `tests/test_handler.py` – Unit tests

---

## 🚀 Deployment

Use the Terraform module `scheduled_lambda` and point it to this directory as `source_dir`. Example:

```hcl
module "auto_stop" {
  source        = "../../modules/scheduled_lambda"
  name          = "qa-auto-stop"
  schedule      = "rate(5 minutes)"
  source_dir    = "../../functions/e1-auto-stop"

  environment_variables = {
    ENV_TAG_KEY      = "Environment"
    ENV_TAG_VALUE    = "QA"
    THRESHOLD_MINUTES = "120"
    DRY_RUN          = "true"
  }

  policy_json = file("../../functions/e1-auto-stop/policy.json")
  enabled     = true
}
```

---

## 🧼 Cleanup

To remove:

```bash
terraform destroy -target=module.auto_stop
```
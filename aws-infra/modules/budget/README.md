# Budget Module

This module provisions an **AWS Cost Budget** with notifications through **SNS** and email.

## Features
- Creates a COST budget with a fixed USD limit.
- Triggers alerts at configurable thresholds (default: 50%, 75%, 90%).
- Supports ACTUAL or FORECASTED spend alerts.
- Creates an SNS topic + email subscriptions for notifications.
- Allows optional Budgets cost filters (e.g., TagKeyValue).

## Example

```hcl
module "budget" {
  source      = "../../modules/budget"
  name        = "qa-monthly-budget"
  amount_usd  = 100
  emails      = ["alerts@example.com"]
  topic_name  = "qa-budget-alerts"
  thresholds  = [50, 75, 90]
  notification_type = "FORECASTED"

  cost_filters = {
    TagKeyValue = ["Environment$QA"]
  }

  tags = {
    Project     = "layered-infra"
    Environment = "QA"
    ManagedBy   = "Terraform"
    Module      = "FinOps-Budget"
  }
}

## Usage in Environments

Each environment (such as `dev`, `qa`, `prod`) should instantiate this module directly in their own `finops-budget.tf` files. This approach keeps the module generic and reusable, while environment-specific files supply context-specific values like the budget amount and notification recipients.

For example, in `environments/dev/finops-budget.tf`:

```hcl
module "budget" {
  source      = "../../modules/budget"
  name        = var.budget_name
  amount_usd  = var.budget_amount_usd
  emails      = var.budget_emails
  topic_name  = var.budget_topic_name
  thresholds  = var.budget_thresholds
  notification_type = var.budget_notification_type
  cost_filters = var.budget_cost_filters
  tags        = var.tags
}
```

Here, variables like `budget_name`, `budget_amount_usd`, and `budget_emails` are defined in the environment's `variables.tf` file, allowing each environment to provide its own values as needed.
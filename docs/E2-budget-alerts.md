# E2 – Proactive Budget Alerts (QA)

## Goal
Receive early warnings when QA spend is forecast to exceed the monthly budget.

## What this creates
- AWS Budgets **COST** budget (monthly, USD)
- SNS topic for alerts + email subscriptions
- Notifications at **50%**, **75%**, **90%** thresholds (FORECASTED by default)

## Dev rollout
1. Apply in `aws-infra/environments/dev`:
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply -auto-approve
   ```
2. Confirm SNS subscriptions:
   - Each recipient receives a confirmation email. Click Confirm subscription.
3. Verify in AWS Budgets console:
   - Budget appears with three notifications.
4. (Fast test) Set a tiny amount_usd (e.g., 2) to provoke a forecast alert quickly.
5. Restore a sensible amount after validation.

## Rollback
- `terraform destroy -auto-approve` in the same folder removes the budget, SNS topic, and subscriptions.

## Notes
- Notifications trigger on FORECASTED spend by default; switch to ACTUAL if required.
- Optional cost filtering can scope alerts (e.g., by tag Environment=QA using TagKeyValue = ["Environment$QA"]).
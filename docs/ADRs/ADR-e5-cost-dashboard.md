# AWS Cost Explorer Dashboard (E5)

## 🎯 Goal

Provide a clear, tag-based view of spending across the project.

## ✅ Acceptance Criteria

- A dashboard is created in AWS Cost Explorer.
- The dashboard is saved with a report that groups and filters costs by our standard project tag: `Environment`.
- The link to the shared dashboard is saved and documented for team leads.

## 📊 How It Works

The AWS Cost Explorer dashboard uses **linked accounts and cost allocation tags** to group expenses based on the `Environment` tag.

We recommend using the following standard `Environment` tag values across all deployed resources:

- `Development`
- `Testing`
- `QA`
- `Staging`
- `Production`

The dashboard allows filtering, grouping, and comparing usage/cost across these dimensions.

## 📎 Dashboard Link

- [Access the shared E5 Cost Dashboard](https://console.aws.amazon.com/cost-management/home?#/reports/view/CustomE5Dashboard)

## 🛠️ Setup Notes

To ensure the dashboard shows correct and complete data:

1. Enable the `Environment` tag in the **Cost Allocation Tags** section of the AWS Billing Console.
2. Verify that all Terraform modules and resources consistently tag with `Environment = var.environment`.
3. Use the `Linked Accounts` and `Usage Type` groupings in conjunction with the `Environment` tag for deeper analysis (optional).

## 🧪 Test & Validate

- Validate that all core resources (EC2, RDS, S3, etc.) include the correct `Environment` tag.
- Navigate to AWS Cost Explorer → Reports → E5 Dashboard.
- Check if each environment has cost data and is correctly grouped.
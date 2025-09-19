


---

## 🧠 Architectural Decision (ADR-e4-office-hours)

### Context

To reduce cloud costs in non-production environments, we introduced an automated mechanism to stop and start EC2 instances outside of business hours. This is especially useful for QA workloads that do not require 24/7 uptime.

### Decision

We implemented an **Office Hours Scheduler** as a reusable Terraform module that:
- Creates a Python-based AWS Lambda function.
- Adds two CloudWatch Event Rules using cron schedules.
- Assigns a scoped IAM role with only the permissions required.
- Selects instances based on tag filters (`Environment = QA`).

This module was tested in the `qa` environment using our standard automation wrapper (`aws-auth.sh`), which applies and destroys infrastructure in a controlled way.

### Consequences

- ✅ Cost savings: instances no longer run 24/7 in QA.
- ✅ Reusability: the module can be reused across other environments.
- ⚠️ Responsibility: all target instances must be correctly tagged.
- ⚠️ Requires re-packaging `lambda.zip` for any function change.
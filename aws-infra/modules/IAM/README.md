# IAM Module for Terraform Remote State Access

This module provisions secure AWS IAM roles and policies for accessing Terraform remote state in S3 and DynamoDB. It is designed for use by human engineers in test environments, granting only the necessary permissions.

## Features
- Creates an IAM role for engineers to access Terraform remote state.
- Attaches a policy with least-privilege permissions for S3 and DynamoDB.
- Outputs the IAM role ARN for use in workflows.
- Accepts remote state resource names as input variables, making it reusable across environments.

## Usage

```
module "iam" {
	source             = "../../modules/IAM"
	tf_state_bucket    = local.bootstrap.tf_state_bucket_name   # from bootstrap_outputs.json
	lock_table         = local.bootstrap.tf_state_lock_table    # from bootstrap_outputs.json
	engineer_role_name = "engineer-terraform-remote-state"      # optional override
}
```

## Variables

| Name               | Description                                         | Type   | Default                        |
|--------------------|-----------------------------------------------------|--------|--------------------------------|
| tf_state_bucket    | Name of the S3 bucket for Terraform remote state.   | string | n/a                            |
| lock_table         | Name of the DynamoDB table for state locking.       | string | n/a                            |
| engineer_role_name | Name for the engineer IAM role.                     | string | "engineer-terraform-remote-state" |

## Outputs

| Name              | Description                                         |
|-------------------|-----------------------------------------------------|
| engineer_role_arn | ARN of the engineer IAM role for remote state access|

## IAM Policy JSON

The policy attached to the engineer role grants only the following permissions:

```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"s3:GetObject",
				"s3:PutObject",
				"s3:DeleteObject",
				"s3:ListBucket"
			],
			"Resource": [
				"arn:aws:s3:::<tf_state_bucket>",
				"arn:aws:s3:::<tf_state_bucket>/*"
			]
		},
		{
			"Effect": "Allow",
			"Action": [
				"dynamodb:GetItem",
				"dynamodb:PutItem",
				"dynamodb:DeleteItem",
				"dynamodb:UpdateItem"
			],
			"Resource": [
				"arn:aws:dynamodb:<region>:<account_id>:table/<lock_table>"
			]
		}
	]
}
```

Variables `<tf_state_bucket>`, `<lock_table>`, `<region>`, and `<account_id>` will be passed with the actual values.

## Notes
- The engineer role trust policy must be provided in `engineer_assume_role_policy.json`.
- This module does **not** create the GitHub Actions role; that is handled in bootstrap.
- For production, hardening permissions further is a must. Will be done in further steps of the project.

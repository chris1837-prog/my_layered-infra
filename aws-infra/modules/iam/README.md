# IAM Module for Terraform Remote State & AppDB Access

This module provisions secure AWS IAM roles and policies for:

1. **Terraform remote state access** (engineer role for S3 + DynamoDB).

   - Creates an IAM role for engineers to access Terraform remote state.
   - Attaches a policy with least-privilege permissions for S3 and DynamoDB.
   - Outputs the IAM role ARN for use in workflows.
   
2. **AppDB EC2 instance** (role + instance profile for accessing SSM Parameter Store).

   - Creates an IAM role + instance profile for AppDB EC2 instances.
   - Attaches least-privilege policies (read only) for SSM Parameter Store.
   - Outputs the instance profile name for AppDB.
   - Accepts project/environment inputs and tags for consistency.

It is designed to be reusable across environments and allows attaching additional policies as needed.
Absolutely! Here’s a clean **IAM module structure skeleton** suitable for your README, showing a beginner-friendly, well-organized layout. You can paste it into your README or use it as guidance for module development.

---

## IAM Module Directory Structure

```
modules/
└── iam/
    ├── main.tf                  # Main resources (IAM roles, instance profiles, policies)
    ├── variables.tf             # Input variables for module
    ├── outputs.tf               # Outputs exported from the module
    ├── versions.tf              # Terraform version and provider requirements
    ├── README.md                # Module-specific README
    ├── examples/                # Runnable examples for testing/documentation
    │   └── basic_usage/
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── versions.tf
    └── test/                    # Automated tests using Terratest
        └── basic_usage_test.go
```

### Folder/Files Description

| Folder/File    | Purpose                                                                               |
|----------------|---------------------------------------------------------------------------------------|
| `main.tf`      | Defines IAM roles, instance profiles, and policies.                                   |
| `variables.tf` | Declares module inputs (role names, project, environment, optional flags).            |
| `outputs.tf`   | Declares outputs such as engineer role ARN, AppDB instance profile name.              |
| `versions.tf`  | Defines Terraform required version and provider versions.                             |
| `examples/`    | Contains runnable example configurations to validate the module or demonstrate usage. |
| `test/`        | Contains Terratest scripts for automated validation of the module.                    |
| `README.md`    | Module-specific documentation with usage instructions, variables, outputs, examples.  |

### Notes

* **Examples** should be minimal and standalone, allowing easy validation with `terraform init`, `terraform validate`, and `terraform plan`.
* **Test** folder uses Terratest to ensure resources are provisioned and destroyed correctly without manual cleanup.
* **Policies folder** is optional but recommended for separating IAM JSON policy logic from Terraform HCL, improving readability and maintainability.
* Always tag resources consistently with `project_name`, `environment`, and `module` tags for clarity in AWS.

---

## Usage

```hcl
module "iam" {
  source             = "../../modules/IAM"

  # Remote state IAM
  tf_state_bucket    = local.bootstrap.tf_state_bucket_name   # from bootstrap_outputs.json
  lock_table         = local.bootstrap.tf_state_lock_table    # from bootstrap_outputs.json
  engineer_role_name = "engineer-terraform-remote-state"      # optional override

  # AppDB IAM
  project_name = "layered-infra-test"
  environment  = "Testing"

  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = "Testing"
    Team        = "A/D"
    Module      = "IAM"
  }
}
```

### Variables

| Name               | Description                                       | Type   | Default         |
|--------------------|---------------------------------------------------|--------|-----------------|
| tf_state_bucket    | Name of the S3 bucket for Terraform remote state. | string | n/a             |
| lock_table         | Name of the DynamoDB table for state locking.     | string | n/a             |
| engineer_role_name | Name for the engineer IAM role.                   | string | "engineer-role" |
| project_name       | Project name used in AppDB IAM role and tags      | string | n/a             |
| environment        | Environment name used in AppDB IAM role and tags  | string | n/a             |
| common_tags        | Map of common tags applied to all IAM resources   | map    | {}              |

### Outputs

| Name                        | Description                                   |
|-----------------------------|-----------------------------------------------|
| engineer_role_arn           | ARN of the engineer IAM role for remote state |
| appdb_instance_profile_name | Instance profile name to attach to AppDB EC2  |

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


## Trust Policy Generation

This module automatically generates the trust policy for the engineer role in memory using a Terraform `data "aws_iam_policy_document"` block. No local file is created or required.

The default trust policy allows a specific AWS principal to assume the role (for testing):

```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"AWS": "arn:aws:iam::694816839566:root"
			},
			"Action": "sts:AssumeRole"
		}
	]
}
```
#
## Trust Policy for EC2

The default trust policy allows a EC2 to assume the role:

```
{
	Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
```

**Important:** For production, you must restrict the trust policy to only trusted AWS principals (replace `694816839566:root` with specific account/user/role ARNs).

## Notes
- The engineer role trust policy is generated automatically in memory; you do not need to provide it manually.
- This module does **not** create the GitHub Actions role; that is handled in bootstrap.
- For production, hardening permissions further is a must. Will be done in further steps of the project.

### Notes

* The **AppDB IAM role** is required if the EC2 instance needs to access **SSM Parameter Store**, Docker registries, or other AWS services securely.
* If no AppDB instance profile is specified in the module, the EC2 can still launch but won’t have any IAM permissions.
* You can extend the AppDB IAM role later with additional policies (e.g., S3, Secrets Manager) without modifying the module interface.

## Examples Directory

The `examples/` folder contains runnable configurations demonstrating module usage.

### `basic_usage/`

* Minimal working example provisioning:

  * Engineer IAM role for Terraform remote state access.
  * AppDB IAM role + instance profile (ready for SSM secrets usage).
* Serves as both **validation test** and **documentation**.
*You can copy and adapt this configuration as a starting point for your own infrastructure.
* 
#### Manual Testing

```bash
cd examples/basic_usage/
terraform init
terraform validate   # Should pass with zero errors
terraform plan       # Should show only IAM resources
```

#### Automated Testing with Terratest

Terratest is used to validate the module by building resources, checking outputs, and destroying them after the test.

### Prerequisites
- Go installed (v1.20+ recommended)
- go mod initialized in test/ folder

### Running the Terratest

```bash
cd test/
go mod init basic_usage_test
go mod tidy
go test -v -timeout 30m -run TestIAMModule .
```

**Terratest Logic:**

* Applies the `examples/basic_usage/` configuration.
* Verifies `engineer_role_arn` is present and not empty.
* Verifies `appdb_instance_profile_name` is present and not empty.
* Destroys all resources after the test.

**Sample Terratest Output:**

```
=== RUN   TestIAMModule
    basic_usage_test.go:20: Applying IAM test resources...
    basic_usage_test.go:24: IAM test resources applied.
    basic_usage_test.go:28: Destroying IAM test resources...
    basic_usage_test.go:30: IAM test resources destroyed.
--- PASS: TestIAMModule (N.NNs)
        --- PASS: TestIAMModule/Engineer_role_ARN_output_exists (N.NNs)
        --- PASS: TestIAMModule/AppDB_instance_profile_output_exists (N.NNs)
PASS
ok      iam_module_test   N.NNs
```

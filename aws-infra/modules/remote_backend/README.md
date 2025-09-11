# AWS Remote Backend Module

This Terraform module provisions a **remote backend** for Terraform state management in AWS.
It creates an S3 bucket (with encryption, versioning, and public access blocks) and a DynamoDB table for state locking.
This ensures **safe, consistent, and collaborative infrastructure deployments**.

It is designed for reusability across environments and is consumed by the [bootstrapper](../../bootstrap) to establish consistent state management.

## File Structure

### Directory Tree

```
aws-infra/modules/remote_backend/
├── main.tf
├── outputs.tf
├── README.md
├── variables.tf
├── versions.tf
└── examples/               # Usage examples and module testing
    └── basic_usage/
        ├── main.tf
        ├── outputs.tf
        └── versions.tf
```

* `main.tf`: Provisions an S3 bucket and a DynamoDB table for Terraform state.

  * S3 bucket: Versioning, server-side encryption (AES256), and public access blocking.
  * DynamoDB table: PAY\_PER\_REQUEST billing mode, used for state locking.
* `variables.tf`: Declares required input variables (`project_name`, `environment`, `common_tags`).
* `outputs.tf`: Exposes the S3 bucket name and DynamoDB table name.
* `versions.tf`: Specifies required Terraform and provider versions.
* `examples/`: Runnable configuration showing minimal usage of the module.
* `examples/basic_usage`: Demonstrates how to consume the module and serves as a working test harness.

## Usage

### Basic Usage

```hcl
# Provider config without a specific profile to use default auth chain
provider "aws" {
  region = "eu-central-1"
}

module "remote_backend" {
  source = "./modules/remote_backend"

  project_name = "layered-infra-test"
  environment  = "dev"

  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = "Testing"
    Team        = "A"
    Module      = "remote_backend"
  }
}
```
### Variables

```hcl
variable "environment" {
  description = "The environment for which to create resources (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```
### Outputs

```hcl
output "tf_state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "tf_state_lock_table" {
  value = aws_dynamodb_table.terraform_locks.name
}
```

## Examples Directory

The `examples/` folder contains runnable configurations that demonstrate how to use this module.

### `basic_usage/`

* A **minimal working example** of the module.
* Provisions:

  * S3 bucket for Terraform state (random suffix, versioning, encryption, public access block).
  * DynamoDB table for state locking.
  
* Serves both as:

  * A **validation test** (`terraform init/validate/plan`)
  * **Documentation**, showing expected inputs and outputs.
  
* You can copy and adapt this configuration as a starting point for your own infrastructure.

## Testing

### Manual Validation

```bash
cd modules/remote_backend/examples/basic_usage/
terraform init
terraform validate  # Should pass with zero errors
terraform plan      # Should show S3 bucket and DynamoDB resources
```

---

## Integration with Bootstrapper

This module is primarily consumed by the [bootstrapper](../../bootstrap).
The bootstrapper calls `remote_backend` to provision backend resources and then generates:

* `backend.tf` (configures Terraform to use the S3 + DynamoDB backend).
* `bootstrap_outputs.json` (exposes bucket + table names for later modules).

🔑 **Note**

* This module is **environment-agnostic**.
* Backend generation happens via **per-environment bootstrap directories** (e.g., `bootstrap/dev/`).
* After bootstrap, the generated `backend.tf` is committed into the environment folder (`environments/dev/`).
* We use **explicit environment directories** (not Terraform workspaces) to enforce clear separation and IAM best practices.


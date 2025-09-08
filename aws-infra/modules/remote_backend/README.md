
---

# AWS Remote Backend Module

This Terraform module provisions the resources required for a **remote Terraform state backend** using **Amazon S3** and **DynamoDB**.
It ensures **state versioning, encryption, and locking**, preventing corruption during concurrent applies.
The module is designed to be reusable across environments and wired into your infrastructure via a **one-time bootstrap process**.

## File Structure

### Directory Tree

```
aws-infra/modules/remote_backend/
├── main.tf
├── outputs.tf
├── README.md
├── variables.tf
├── versions.tf
├── test/                   # Terratest skeleton for automated testing
│   └── remote_backend_test.go
└──examples/               # Usage examples and module testing
    └── basic_usage/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

* `main.tf`: Provisions an S3 bucket (with versioning + AES256 encryption), a DynamoDB table for state locking, and IAM **policies** for controlling backend access.
* `variables.tf`: Declares input variables such as `project_name`, `environment`, optional role ARNs, and common tags.
* `outputs.tf`: Exposes key attributes, including bucket name, DynamoDB table name, and IAM policy ARNs for later attachment to roles.
* `versions.tf`: Specifies required Terraform and AWS provider versions.
* `test/`: Placeholder Terratest skeleton for automated validation.
* `examples/basic_usage`: Demonstrates how to consume the module and serves as a working test harness.

---

## Usage

---

### Bootstrapper (Per-Environment)

The module is intended to be used via a **bootstrap process** in a separate per-environment folder, for example:

```
aws-infra/bootstrap/dev/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
 ```

**Workflow:**

1. Run `terraform apply` inside `bootstrap/dev/`

   * Provisions the remote backend infrastructure (S3 + DynamoDB + IAM policies).
   * **Automatically generates** the `backend.tf` file and places it directly into the corresponding environment folder (`environments/dev/`).
2. From `environments/dev/`, run Terraform as usual to provision your infrastructure.

This ensures:

* **Automatic placement** of `backend.tf` in the correct environment.
* **Local bootstrap state** → no unnecessary remote state for bootstrap resources.
* **Clear separation of concerns** → infrastructure code doesn’t mix with backend provisioning.
* **Environment-specific backend** → each environment has its own bucket, lock table, and IAM policies.

---

### Basic Usage (Module Example)

```hcl
module "remote_backend" {
  source = "./modules/remote_backend"

  project_name   = "layered-infra-test"
  environment    = "dev"
  aws_region     = "us-east-1"

  # Optional: attach policies to existing IAM roles
  rw_role_arns = [
    "arn:aws:iam::123456789012:role/platform-engineer",
    "arn:aws:iam::123456789012:role/ci-cd-role"
  ]

  ro_role_arns = [
    "arn:aws:iam::123456789012:role/developer"
  ]

  common_tags = {
    Project     = "layered-infra-test"
    Environment = "dev"
  }
}
```

The module provisions:

* **S3 bucket** `${project_name}-${environment}-tfstate`

  * Versioning enabled
  * AES256 server-side encryption
* **DynamoDB table** `${project_name}-${environment}-tf-lock`

  * Used to lock state during `terraform apply`
* **IAM policies**

  * **Always created** to control access to S3 bucket
  * Optional: attach to provided role ARNs for read/write (CI/CD + platform engineers) and read-only (developers)
* **Outputs**

  * Bucket name, DynamoDB table name, IAM policy ARNs

---

## Examples Directory

The `examples/` folder contains runnable configurations that demonstrate how to use this module.

### `basic_usage/`

* Minimal working example of the module.
* Serves as both:

  * **Validation test** (`terraform init/validate/plan`)
  * **Documentation**, showing expected inputs and outputs.

---

## Testing

### Manual Testing with Examples

```bash
cd modules/remote_backend/examples/basic_usage/
terraform init
terraform validate  # Should pass with zero errors
terraform plan      # Should show S3 + DynamoDB + IAM policies
```

### Terratest Skeleton

```bash
cd test/
go mod init remote-backend-test
go mod tidy
go test -v -timeout 30m .
```

The Terratest skeleton can be extended to validate:

* S3 bucket exists with versioning + encryption enabled
* DynamoDB table exists with proper schema
* IAM policies are created and match expected ARNs
* Tags are applied consistently

---

🔑 **Note**

* This module is **environment-agnostic**.
* Backend generation happens via **per-environment bootstrap directories** (e.g., `bootstrap/dev/`).
* After bootstrap, the generated `backend.tf` is committed into the environment folder (`environments/dev/`).
* We use **explicit environment directories** (not Terraform workspaces) to enforce clear separation and IAM best practices.

---


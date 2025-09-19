# Bootstrapper

## Description

The bootstrapper is a one-time setup for each environment (e.g., `dev`, `prod`).  
It provisions the **Terraform remote backend infrastructure** (S3 + DynamoDB) and creates a **GitHub Actions IAM role** with OIDC trust so Terraform can run securely from CI/CD pipelines.  

The bootstrapper also generates **artifacts** inside the environment folder (`environments/dev/`):  
- `backend.tf` → backend configuration for Terraform state.  
- `bootstrap_outputs.json` → JSON wiring values (bucket, lock table, GitHub Actions role).  

This ensures that every environment is hardwired to the correct state backend and CI/CD is immediately ready.

---

## Structure

```hcl
bootstrap/dev/
 ├── provider.tf              # AWS provider + caller identity
 ├── remote_backend.tf        # Remote backend module
 ├── github_oidc.tf           # GitHub Actions IAM role, policies, boundaries
 ├── artifacts.tf             # backend.tf + bootstrap_outputs.json
 ├── ssm_parameter.tf         # (new) SSM parameter resources
 ├── variables.tf             # Defines project_name, environment, aws_region, common_tags, github_org/repo/branch, restrict_by_tags
 ├── outputs.tf               # Outputs GitHub Actions role ARN
 ├── versions.tf              # Defines required Terraform and provider versions
 └── terraform.tfvars.example # Example variables file

````

---
## How It Works

* Runs **with local backend** (so it can create the remote backend on its own).  
* Calls the [`remote_backend` module](../../modules/remote_backend) with inputs:
  - `project_name`
  - `environment`
  - `common_tags`

    This module provisions the **remote backend infrastructure**:
    - S3 bucket (with versioning + encryption) for Terraform state.  
    - DynamoDB table for state locking.  

* Creates only **two additional components** directly in the bootstrapper:
  1. **GitHub Actions IAM role** (with trust, permissions, and boundary policies).
     
     * OIDC trust restricted to a **specific GitHub organization, repository, and branch**.
     * Permissions initially **full Terraform access** (`Action="*"`, `Resource="*"`), optionally restricted by `Project` and `Environment` tags.
     * Role name: `${project_name}-${environment}-terraform-github-actions-role`
     * Policy name: `${project_name}-${environment}-terraform-github-actions-policy`
     * Attached permission boundary to prevent privilege escalation.
  
  2. **Artifacts inside the target environment folder**:
     - `backend.tf` → backend configuration using the S3 bucket + DynamoDB. 
     ```hcl
     terraform {
       backend "s3" {
         bucket         = "layered-infra-test-dev-tfstate-1234"
         dynamodb_table = "layered-infra-test-dev-locks"
         key            = "terraform.tfstate"
         region         = "eu-central-1"
       }
     }
     ```
     - `bootstrap_outputs.json` → JSON file with bucket, table, and GitHub Actions role ARN. 
     ```json
     {
       "tf_state_bucket_name": "layered-infra-test-dev-tfstate-1234",
       "tf_state_lock_table": "layered-infra-test-dev-locks",
       "github_actions_role_arn": "arn:aws:iam::123456789012:role/layered-infra-test-dev-terraform-github-actions-role"
     }
     ```
---

## IAM Policies

### 1. Trust Policy (OIDC Federation)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account_id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<github_org>/<github_repo>:ref:refs/heads/<github_branch>"
        }
      }
    }
  ]
}
```

This ensures only the specified **GitHub repository + branch** can assume the role.

---

### 2. Permissions Policy (broad by default, tag-restricted if enabled)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestTag/Project": "<project_name>",
          "aws:RequestTag/Environment": "<environment>"
        }
      }
    }
  ]
}
```

* Default: unrestricted (`Action="*"`, `Resource="*"`).
* If `restrict_by_tags = true`, requests must include matching `Project` + `Environment` tags.

---

### 3. Permissions Boundary (prevents privilege escalation)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:AttachUserPolicy",
        "iam:PutUserPolicy",
        "iam:CreateAccessKey"
      ],
      "Resource": "*"
    }
  ]
}
```

This boundary prevents the role from creating IAM users, keys, or policies — blocking privilege escalation while still allowing Terraform to manage infrastructure.

---

## Artifacts Written to Environment

After `terraform apply`, the following files are created in `environments/dev/`:

### `backend.tf`

Ensures Terraform uses the correct backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "layered-infra-test-dev-tfstate-1234"
    dynamodb_table = "layered-infra-test-dev-locks"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
  }
}
```

### `bootstrap_outputs.json`

Provides wiring values for future modules:

```json
{
  "tf_state_bucket_name": "layered-infra-test-dev-tfstate-1234",
  "tf_state_lock_table": "layered-infra-test-dev-locks",
  "github_actions_role_arn": "arn:aws:iam::123456789012:role/layered-infra-test-dev-terraform-github-actions-role"
}
```

Example usage in environment:

```hcl
locals {
  bootstrap = jsondecode(file("${path.module}/bootstrap_outputs.json"))
}

module "iam" {
  source = "../../modules/iam"

  tf_state_bucket_name = local.bootstrap.tf_state_bucket_name
  tf_state_lock_table  = local.bootstrap.tf_state_lock_table
}
```

---

## Workflow

1. **Run bootstrap (one-time per environment)**

```bash
cd bootstrap/dev/
terraform init
terraform apply
```

* Creates S3 bucket + DynamoDB table.
* Creates GitHub Actions role with OIDC trust + optional tag restrictions.
* Writes `backend.tf` + `bootstrap_outputs.json` to `environments/dev/`.

2. **Use the environment**

```bash
cd environments/dev/
terraform init   # uses remote backend from backend.tf
terraform apply  # provisions environment resources
```

---

## Benefits

* **Separation of concerns**

  * Bootstrapper = backend + CI/CD role.
  * Environment modules = infrastructure.

* **Safety**

  * `backend.tf` locks Terraform to the correct backend.
  * `bootstrap_outputs.json` provides wiring without duplicating names or hardcoding.

* **CI/CD ready**

  * GitHub Actions role exists after bootstrap.
  * OIDC trust restricted to GitHub org/repo/branch.
  * Optional tag-based restrictions for least privilege.

* **Future-proof**

  * IAM and other modules can read backend details dynamically.
  * Policies can evolve from full access → least privilege.

---

## Compliance with Requirements

* ✅ S3 backend with DynamoDB lock
* ✅ Versioning + encryption on state bucket
* ✅ Documented workflow for bootstrap → environment
* ✅ GitHub Actions OIDC role created automatically
* ✅ `backend.tf` + JSON wiring written into environment
* ✅ Optional tag-based permission restrictions for future tightening
* ✅ Explicit IAM trust, permissions, and boundary policies documented

---




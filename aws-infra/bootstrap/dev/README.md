# Bootstrapper (dev)

## Description
This bootstrapper is responsible for setting up the foundational AWS resources required before any actual environment infrastructure can be deployed.
The bootstrapper is a one-time setup for each environment (e.g., `dev`, `prod`).
It provisions the **Terraform remote backend infrastructure** (S3 + DynamoDB) and creates a **GitHub Actions IAM role** with OIDC trust so Terraform can run securely from CI/CD pipelines.

The bootstrapper also generates **artifacts** inside the environment folder (`environments/dev/`):

* `backend.tf` → backend configuration for Terraform state.
* `bootstrap_outputs.json` → JSON wiring values (bucket, lock table, GitHub Actions role).
* `ssm_parameters.json` → JSON mapping SSM parameter paths (for sensitive values) and non-sensitive values.

This ensures that every environment is hardwired to the correct state backend and CI/CD is immediately ready.

---

## Components

The bootstrapper provisions:

* **Remote Backend** (via `modules/remote_backend`).
* **IAM Role for GitHub Actions** (trust restricted to a GitHub repo + branch).
* **SSM Parameters** for registry + database credentials and config.
* **Artifacts**: `backend.tf`, `bootstrap_outputs.json`, and `ssm_parameters.json`.

---

## How It Works

1. **Bootstrap runs with a local backend**
   This allows Terraform to create the remote backend infrastructure before switching to it.

2. **Remote backend provisioning**
   The bootstrapper calls the `remote_backend` module with these inputs:

   * `project_name`
   * `environment`
   * `common_tags`

   The module provisions the remote backend:

   * S3 bucket for Terraform state (with versioning + encryption)
   * DynamoDB table for state locking

3. **GitHub Actions IAM role for CI/CD**
   The bootstrapper creates a role with:

   * OIDC trust restricted to a specific GitHub organization, repository, and branch
   * Full Terraform access by default (`Action="*"`, `Resource="*"`), optionally restricted by `Project` and `Environment` tags
   * Attached permission boundary to prevent privilege escalation
   * Role name: `${project_name}-${environment}-terraform-github-actions-role`
   * Policy name: `${project_name}-${environment}-terraform-github-actions-policy`

4. **SSM Parameter Store for configuration**
   The bootstrapper stores both sensitive and non-sensitive data as parameters:

   **Sensitive values** (`SecureString`, generated via `random_password`):

   * `/project/environment/postgres_password`
   * `/project/environment/registry_password`

   **Non-sensitive configuration** (`String`):

   * `/project/environment/registry_url`
   * `/project/environment/registry_user`
   * `/project/environment/app_image_tag`
   * `/project/environment/postgres_db`
   * `/project/environment/postgres_user`

5. **Artifacts written to the environment folder**
   These JSON/HCL files make the environment immediately usable:

   * `backend.tf` → configures Terraform to use the remote backend
   * `bootstrap_outputs.json` → wiring for backend + GitHub Actions role
   * `ssm_parameters.json` → paths and non-sensitive values for SSM parameters

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

---

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

---

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

### `ssm_parameters.json`

Provides the SSM parameter paths (for sensitive values) and non-sensitive config values directly for environment consumption.
Sensitive values (like passwords) are **not included**, only their SSM paths.

```json
{
  "project_name": "layered-infra-test",
  "environment": "dev",
  "aws_region": "eu-central-1",
  "parameter_paths": {
    "postgres_password": "/layered-infra-test/dev/postgres_password",
    "registry_password": "/layered-infra-test/dev/registry_password",
    "registry_url": "/layered-infra-test/dev/registry_url",
    "registry_user": "/layered-infra-test/dev/registry_user",
    "app_image_tag": "/layered-infra-test/dev/app_image_tag",
    "postgres_db": "/layered-infra-test/dev/postgres_db",
    "postgres_user": "/layered-infra-test/dev/postgres_user"
  },
  "parameter_values": {
    "registry_url": "registry.example.com",
    "registry_user": "admin",
    "postgres_db": "myapp",
    "postgres_user": "myuser",
    "app_image_tag": "latest"
  }
}

```

Example usage in environment:

```hcl
locals {
  ssm_params = jsondecode(file("${path.module}/ssm_parameters.json"))
}

data "aws_ssm_parameter" "postgres_password" {
  name = local.ssm_params.postgres_password_path
}

resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    name  = "app"
    image = "${local.ssm_params.registry_url}:${local.ssm_params.app_image_tag}"
    environment = [
      { name = "DB_NAME",  value = local.ssm_params.postgres_db },
      { name = "DB_USER",  value = local.ssm_params.postgres_user },
      { name = "DB_PASS",  value = data.aws_ssm_parameter.postgres_password.value }
    ]
  }])
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
* Creates GitHub Actions role.
* Generates and stores credentials + config in SSM Parameter Store.
* Writes `backend.tf`, `bootstrap_outputs.json`, `ssm_parameters.json`.

2. **Use the environment**

```bash
cd environments/dev/
terraform init   # uses backend.tf
terraform apply  # provisions environment resources
```


---

## Benefits

* **Separation of concerns**

  * Bootstrapper = backend + CI/CD role + SSM wiring.
  * Environment modules = infrastructure and application wiring.
* **Safety**

  * `backend.tf` locks Terraform to the correct backend.
  * SSM SecureString stores sensitive values.
* **CI/CD ready**

  * GitHub Actions role exists after bootstrap.
  * OIDC trust restricted to GitHub org/repo/branch.
  * Optional tag-based restrictions for least privilege.
* **Future-proof**

  * IAM and other modules can read backend details dynamically.
  * Policies can evolve from full access → least privilege.
  * New bootstrap files (Route53, KMS) plug in cleanly.

---

## Compliance with Requirements

* ✅ S3 backend with DynamoDB lock
* ✅ Versioning + encryption on state bucket
* ✅ Documented workflow for bootstrap → environment
* ✅ GitHub Actions OIDC role created automatically
* ✅ `backend.tf` + JSON wiring written into environment
* ✅ Sensitive data stored securely in SSM Parameter Store
* ✅ `ssm_parameters.json` created with paths + non-sensitive values
* ✅ Optional tag-based permission restrictions for future tightening
* ✅ Explicit IAM trust, permissions, and boundary policies documented

---
---

Perfect! Here’s the **fully updated README.md** for your bootstrapper. It keeps **all your original sections**, IAM policies, artifacts, workflow, benefits, and now includes **correct SSM parameter examples** with both the JSON structure and Terraform usage. You can copy-paste it directly.

---

# Bootstrapper

## Description

The bootstrapper is a one-time setup for each environment (e.g., `dev`, `prod`).
It provisions the **Terraform remote backend infrastructure** (S3 + DynamoDB) and creates a **GitHub Actions IAM role** with OIDC trust so Terraform can run securely from CI/CD pipelines.

The bootstrapper also generates **artifacts** inside the environment folder (`environments/dev/`):

* `backend.tf` → backend configuration for Terraform state.
* `bootstrap_outputs.json` → JSON wiring values (bucket, lock table, GitHub Actions role).
* `ssm_parameters.json` → JSON mapping SSM parameter paths (for sensitive values) and non-sensitive values.

This ensures that every environment is hardwired to the correct state backend and CI/CD is immediately ready.

---

## Structure

```hcl
bootstrap/dev/
 ├── provider.tf            # AWS provider + caller identity
 ├── remote_backend.tf      # Calls remote_backend module
 ├── github_oidc.tf         # GitHub Actions role + policies + permissions boundary
 ├── ssm_parameter.tf       # Stores sensitive + non-sensitive config in SSM Parameter Store
 ├── artifacts.tf           # Writes backend.tf, bootstrap_outputs.json, ssm_parameters.json
 ├── route53.tf             # (reserved) Route53 setup for DNS/bootstrap wiring
 ├── variables.tf           # Defines project_name, environment, aws_region, common_tags, github_org/repo/branch, restrict_by_tags, registry/postgres values
 ├── outputs.tf             # Outputs GitHub Actions role ARN
 ├── versions.tf            # Defines required Terraform and provider versions
 └── terraform.tfvars.example # Example variables file
```

---

## How It Works

* Runs **with local backend** (so it can create the remote backend on its own).

* Calls the [`remote_backend` module](../../modules/remote_backend) with inputs:




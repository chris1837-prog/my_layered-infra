
# Remote Backend & Bootstrapper – Concept Summary

## Goal

As a platform engineer, I want a documented, locked remote state so that concurrent applies don’t corrupt state, and a clean way to pass backend resource names into future IAM modules.

---

## Core Design

1. **Remote Backend Module (`modules/remote_backend/`)**

   * Provisions:

     * S3 bucket for Terraform state
       * Versioning enabled
       * AES256 encryption (SSE-S3)
     * DynamoDB table for state locking

   * Outputs:
     * `tf_state_bucket_name`
     * `tf_state_lock_table`

2. **Bootstrapper (`bootstrap/dev/`)**
   * Structure:
   ```hcl
   bootstrap/dev/
    ├── main.tf                  # Calls remote_backend module, creates GitHub Actions role, generates backend.tf + bootstrap_outputs.json
    ├── variables.tf             # Defines project_name, environment, aws_region, common_tags, github_org/repo/branch, restrict_by_tags
    ├── outputs.tf               # Optional: outputs if needed, e.g., GitHub Actions role ARN
    ├── versions.tf              # Defines required Terraform and provider versions
    ├── terraform.tfvars.example # Example variables file
    ```

* Runs **with local backend**.
* Calls the `remote_backend` module with inputs: `project_name`, `environment`, `common_tags`.
* Creates only two things:

  1. Remote backend infra (bucket + lock table).
  2. **GitHub Actions role for Terraform CI/CD**:

     * OIDC trust restricted to a **specific GitHub organization, repository, and branch**.
     * Permissions initially **full Terraform access** (`Action="*"`, `Resource="*"`), optionally restricted by `Project` and `Environment` tags.
     * Role name: `${project_name}-${environment}-terraform-github-actions-role`
     * Policy name: `${project_name}-${environment}-terraform-github-actions-policy`
     
* Creates **two artifacts inside the target environment directory (`environments/dev/`)**:

  1. **`backend.tf`** → Configures remote backend with correct S3 + DynamoDB.
  2. **`bootstrap_outputs.json`** → JSON file containing bucket and table names, and GitHub Actions role arn

     ```json
     {
       "tf_state_bucket_name": "layered-infra-test-dev-tfstate-1234",
       "tf_state_lock_table": "layered-infra-test-dev-locks",
       "github_actions_role_arn": "arn:aws:iam::123456789012:role/layered-infra-test-dev-terraform-github-actions-role"
     }
     ```

3. **Environment (`environments/dev/`)**

   * `backend.tf` ensures Terraform uses the correct S3 bucket + DynamoDB table for state.
   * `bootstrap_outputs.json` provides values for wiring future modules (like IAM).
   * Example inside `main.tf`:

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

1. **Bootstrap (one-time per environment)**

```bash
   cd bootstrap/dev/
   terraform init
   terraform apply
```

* Creates backend infra (S3 + DynamoDB).
* Creates GitHub Actions OIDC role with optional tag-based restriction.
* Generates `backend.tf` + `bootstrap_outputs.json` in `environments/dev/`.

2. **Environment Infra**

```bash
   cd environments/dev/
   terraform init   # now uses remote backend
   terraform apply  # provisions environment resources
```

---

## Benefits

* **Separation of concerns**

  * Bootstrapper: remote backend + CI/CD role.
  * IAM module (later): policies for developers/engineers.
* **Safety**

  * `backend.tf` ensures every environment is hardwired to the right backend.
  * JSON file provides wiring without duplicating names or hardcoding.
* **CI/CD ready**

  * GitHub Actions role exists after bootstrap, enabling pipeline-driven deployments.
  * OIDC trust restricted to specific GitHub repo/branch.
  * Optional tag-based restrictions enforce least privilege.
* **Future-proof**

  * IAM and other modules can consume backend info from JSON.

---

✅ This design matches the task requirements *exactly*:

* S3 backend with DynamoDB lock.
* Versioning + encryption on state bucket.
* Documented workflow.
* Clear wiring for IAM best practices later.
* GitHub Actions role for Terraform CI/CD with OIDC trust and optional tag-based permissions.





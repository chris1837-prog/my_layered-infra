## Description

This bootstrapper sets up the foundational AWS resources required before any environment infrastructure can be deployed.
It is a **one-time setup per environment** (e.g., `dev`, `prod`) and fully prepares the environment for automated provisioning and CI/CD.

The bootstrapper provisions:

* **Terraform remote backend infrastructure** (S3 bucket + DynamoDB table for state locking).
* **GitHub Actions IAM role** with OIDC trust, restricted to a specific GitHub repository and branch, allowing Terraform to run securely from CI/CD pipelines.
* **SSM Parameters** for both sensitive (SecureString) and non-sensitive (String) values. All non-sensitive parameters include enforced tags for easy identification and automation.
* **Elastic IP (EIP)** allocation for the edge instance to provide a stable public IP.
* **Route53 hosted zone** for the environment subdomain, with two A records:

  1. `registry.${environment}.${domain_name}` → points to the edge instance public IP (EIP)
  2. `registry.internal.${environment}.${domain_name}` → points to the edge instance private IP

Additionally, the bootstrapper generates **artifacts** in `environments/dev/artifacts/`:

* `backend.tf` → Terraform backend configuration
* `bootstrap_outputs.json` → wiring values including remote backend info, GitHub Actions role ARN, edge EIP allocation ID, and private IP
* `ssm_parameters.json` → paths and values for sensitive and non-sensitive parameters
* `namecheap_setup_dev.txt` → human-readable instructions for DNS delegation using the hosted zone nameservers

This ensures that every environment is **immediately usable**, **correctly wired**, and **CI/CD-ready**, with all infrastructure wiring, secrets, and stable IP addressing prepared for environment modules.

---

## Structure

```hcl
bootstrap/dev/
 ├── provider.tf            # AWS provider + caller identity
 ├── remote_backend.tf      # Calls remote_backend module
 ├── github_oidc.tf         # GitHub Actions role + policies + permissions boundary
 ├── ssm_parameter.tf       # Stores sensitive + non-sensitive config in SSM Parameter Store (with tags)
 ├── artifacts.tf           # Writes backend.tf, bootstrap_outputs.json, ssm_parameters.json
 ├── route53.tf             # Public + private registry A records
 ├── locals.tf              # Tags: enforced + merged      
 ├── variables.tf           # Defines project_name, environment, aws_region, common_tags, github_org/repo/branch, restrict_by_tags, registry/postgres values
 ├── outputs.tf             # Outputs GitHub Actions role ARN + edge info
 ├── versions.tf            # Defines required Terraform and provider versions
 └── terraform.tfvars.example # Example variables file
```

---

## Components

The bootstrapper provisions:

* **Remote Backend** (via `modules/remote_backend`).
* **IAM Role for GitHub Actions** (trust restricted to a GitHub repo + branch).
* **SSM Parameters** for registry + database credentials and config, now including `tags = local.merged_tags`.
* **Elastic IP (EIP)** allocation for the edge instance to provide a stable public IP for the registry.
* **Route53 Hosted Zone (per environment)** with **public + private A records** for registry access:

  1. `registry.${environment}.${domain_name}` → points to the edge instance public IP (EIP)
  2. `registry.internal.${environment}.${domain_name}` → points to the edge instance private IP
  
* **Artifacts**: `backend.tf`, `bootstrap_outputs.json`, and `ssm_parameters.json` in `environments/dev/artifacts/`.

---

## How It Works

1. **Bootstrap runs with a local backend**
   This allows Terraform to create the remote backend infrastructure before switching to it.

2. **Remote backend provisioning**

   * Calls the [`remote_backend` module](../../modules/remote_backend) with inputs:

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
   
4. **Route53 Hosted Zone + Records**

   The bootstrapper creates a public hosted zone and two A records:
   1. An Elastic IP (EIP) for the edge instance to ensure a stable public IP.
   2. Public registry: `registry.${environment}.${domain_name}` → points to `aws_eip.edge.public_ip`
   3. Private registry: `registry.internal.${environment}.${domain_name}` → points to `edge_private_ip` from bootstrap outputs
    
5. **SSM Parameter Store for configuration**
   The bootstrapper stores both sensitive and non-sensitive data as parameters:

   **Sensitive values** (`SecureString`, generated via `random_password`):

   * `/project/environment/postgres_password`
   * `/project/environment/registry_password`

   **Non-sensitive configuration** (`String`, with enforced tags):

   * `/project/environment/registry_url` → points to the new public registry A record FQDN
   * `/project/environment/registry_user`
   * `/project/environment/app_image_tag`
   * `/project/environment/postgres_db`
   * `/project/environment/postgres_user`

6. **Artifacts written to the environment**

   After `terraform apply`, the following files are created in `environments/dev/artifacts/`:

   ### `backend.tf`

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

   ```json
   {
     "tf_state_bucket_name": "layered-infra-test-dev-tfstate-1234",
     "tf_state_lock_table": "layered-infra-test-dev-locks",
     "github_actions_role_arn": "arn:aws:iam::123456789012:role/layered-infra-test-dev-terraform-github-actions-role",
     "edge_eip_allocation_id": "eipalloc-12345678",
     "edge_private_ip": "10.0.0.10"
   }
   ```
   ### `ssm_parameters.json`)**

   Provides paths for sensitive values and non-sensitive values (with tags):

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
       "registry_url": "registry.dev.uselayered.com",
       "registry_user": "admin",
       "postgres_db": "myapp",
       "postgres_user": "myuser",
       "app_image_tag": "latest"
     }
   }
   ```

   ### `namecheap_setup_dev.txt`

   Provides human-readable DNS delegation instructions for your registrar (e.g., Namecheap) with the four NS records that Route53 assigned to the environment hosted zone.

   Example contents (dev):

   ```txt
   DNS DELEGATION SETUP FOR DEV
   =================================================
   Please log in to the registrar for 'uselayered.com' (e.g., Namecheap) and navigate to the Advanced DNS settings.

   Create FOUR (4) new NS records with the following details:

   Type: NS
   Host: dev
   Value: Use one of the four values below (include the trailing dot).
   TTL: Automatic / 1 hour

   REQUIRED VALUES:
   - ns-1234.awsdns-11.org.
   - ns-5678.awsdns-22.com.
   - ns-90.awsdns-33.net.
   - ns-12.awsdns-44.co.uk.

   After saving these records, DNS delegation for *.dev.uselayered.com will be managed by AWS.
   ```

   The real values will match the Terraform output `environment_subdomain_nameservers`.

7. **Example usage in environment**

```hcl
locals {
  bootstrap_outputs = jsondecode(file("${path.module}/artifacts/bootstrap_outputs.json"))
  ssm_parameters    = jsondecode(file("${path.module}/artifacts/ssm_parameters.json"))

  edge_config = {
    eip_allocation_id   = local.bootstrap_outputs.edge_eip_allocation_id
    private_ip          = local.bootstrap_outputs.edge_private_ip
    ssm_parameter_paths = local.ssm_parameters.parameter_paths
  }

  appdb_config = {
    ssm_parameter_paths = {
      postgres_password = local.ssm_parameters.parameter_paths.postgres_password
      registry_password = local.ssm_parameters.parameter_paths.registry_password
      app_image_tag     = local.ssm_parameters.parameter_paths.app_image_tag
    }
    parameter_values = {
      registry_url  = local.ssm_parameters.parameter_values.registry_url
      registry_user = local.ssm_parameters.parameter_values.registry_user
      postgres_db   = local.ssm_parameters.parameter_values.postgres_db
      postgres_user = local.ssm_parameters.parameter_values.postgres_user
      app_image_tag = local.ssm_parameters.parameter_values.app_image_tag
    }
  }
}

module "iam" {
     source = "../../modules/iam"

     tf_state_bucket_name = local.bootstrap.tf_state_bucket_name
     tf_state_lock_table  = local.bootstrap.tf_state_lock_table
   }

data "aws_ssm_parameter" "postgres_password" {
     name = local.ssm_params.parameter_paths.postgres_password
   }

resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    name  = "app"
    image = "${local.ssm_params.parameter_values.registry_url}:${local.ssm_params.parameter_values.app_image_tag}"
    environment = [
      { name = "DB_NAME",  value = local.ssm_params.parameter_values.postgres_db },
      { name = "DB_USER",  value = local.ssm_params.parameter_values.postgres_user },
      { name = "DB_PASS",  value = data.aws_ssm_parameter.postgres_password.value }
    ]
  }])
}
# Example: using edge_config and appdb_config in a module
module "edge" {
  source = "../../modules/edge"

  eip_allocation_id   = local.edge_config.eip_allocation_id
  private_ip          = local.edge_config.private_ip
  ssm_parameter_paths = local.edge_config.ssm_parameter_paths

  appdb_parameter_paths  = local.appdb_config.ssm_parameter_paths
  appdb_parameter_values = local.appdb_config.parameter_values
}

```

---

## Outputs

After `terraform apply`, the bootstrapper exposes these outputs:

* `github_actions_role_arn` — ARN of the GitHub Actions OIDC role.
* `tf_state_bucket_name` — Name of the S3 bucket for Terraform state.
* `tf_state_lock_table` — Name of the DynamoDB table for state locking.
* `environment_subdomain_nameservers` — Array of four NS records for `${environment}.${domain_name}`.
* `edge_private_ip` — Private IP for edge instance.
* `edge_eip_allocation_id` — Elastic IP allocation ID for edge instance.

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

---

## Workflow

1. **Run bootstrap (one-time per environment)**

```bash
cd bootstrap/dev/
terraform init
terraform apply
```

* Creates **S3 bucket + DynamoDB table** for Terraform backend.
* Creates **GitHub Actions OIDC role**.
* Stores credentials + config in **SSM Parameter Store** (with tags).
* Allocates **Elastic IP (EIP)** for edge instance.
* Creates **Route53 hosted zone** with public & private registry A records.
* Writes **artifacts** into `environments/dev/artifacts/`: `backend.tf`, `bootstrap_outputs.json`, `ssm_parameters.json`, and `namecheap_setup_dev.txt`.

2. **Use the environment**

```bash
cd environments/dev/
terraform init   # uses backend.tf
terraform apply  # provisions environment resources
```

---

## Benefits

* **Separation of concerns**

  * Bootstrapper = backend, CI/CD role, SSM wiring, Elastic IP, Route53 hosted zone + registry records.
  * Environment modules = actual infrastructure and application wiring, consuming bootstrap artifacts.

* **Safety**

  * `backend.tf` locks Terraform to the correct remote backend.
  * SSM SecureString stores sensitive values securely.
  * SSM parameters include **enforced tags** for governance.

* **CI/CD ready**

  * GitHub Actions OIDC role exists after bootstrap.
  * OIDC trust restricted to specific GitHub org/repo/branch.
  * Optional tag-based restrictions ensure least privilege.

* **Future-proof**

  * Environment modules can read backend details, edge IP, and SSM parameters dynamically from artifacts.
  * Policies can evolve from full access → least privilege.
  * New bootstrap files (Route53, EIP, SSM updates) plug in cleanly.
  * DNS delegation is documented and reproducible via generated `namecheap_setup_<env>.txt`.

---

## Compliance with Requirements

* ✅ S3 backend with DynamoDB lock
* ✅ Versioning + encryption on state bucket
* ✅ Documented workflow for bootstrap → environment
* ✅ GitHub Actions OIDC role created automatically
* ✅ `backend.tf` + JSON wiring written into environment
* ✅ Sensitive data stored securely in SSM Parameter Store
* ✅ `ssm_parameters.json` created with paths + non-sensitive values (with tags)
* ✅ Optional tag-based permission restrictions for future tightening
* ✅ Explicit IAM trust, permissions, and boundary policies documented
* ✅ Route53 hosted zone per environment with public + private A records
* ✅ Registrar delegation instructions generated as an artifact
* ✅ `edge_private_ip` + `edge_eip_allocation_id` exposed in outputs for environment locals

---





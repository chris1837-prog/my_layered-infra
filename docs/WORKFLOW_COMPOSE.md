# WORKFLOW_COMPOSE.md

## Folder structure overview

- `app/`  
  Contains the Node.js application code written by Hao.

- `pgbouncer/`  
  Holds PgBouncer configuration files maintained by Felix.

- `init-db/`  
  Contains database bootstrap scripts executed on first Postgres startup.

- `mvp-compose/`  
  Docker Compose setup for the MVP stack including `docker-compose.yml`, environment files, and scripts.

---

## layered-infra/mvp-compose/
- `app/` — Node.js application source code.  
  - Includes graceful shutdown handling and PgBouncer-safe queries.
- `docker-compose.yml` — Compose file defining services and volumes.
- `Dockerfile.migrate` / `migrator` service — runs `npm run migrate:up` before the app starts.
- `init-db/` — SQL scripts to initialize the Postgres database.
- `pgbouncer/` — Configuration files for PgBouncer connection pooler.  
  - `pgbouncer.ini` — corrected `log_disconnections` key.  
  - `userlist.txt` — mounted writable to allow non-interactive auth updates.
- `test-stack.sh` — Script to build, test, and verify the stack.  
  - Supports **smoke** mode (fast connectivity checks).  
  - Supports **graceful** mode (verifies app shutdown closes HTTP + DB pool cleanly).

## layered-infra/modules/orphaned_cleanup/
- `lambda_function.py` — Python Lambda to detect and delete unattached EBS volumes and stale snapshots.
- `lambda.zip` — Packaged deployment artifact for the Lambda.
- `main.tf` — Declares IAM role, policy, Lambda resource, and permissions.
- `outputs.tf` — Exports Lambda function ARN.
- `variables.tf` — Input variables for name prefix and region.
- `versions.tf` — Terraform and AWS provider version constraints.
- `README.md` — Usage and setup guide for the orphaned cleanup module.

## layered-infra/modules/orphaned_cleanup_scheduler/
- `main.tf` — CloudWatch event rule + Lambda invocation permissions.
- `variables.tf` — Accepts Lambda function ARN and naming prefix.
- `versions.tf` — Terraform and AWS provider version constraints.
- `README.md` — Scheduler module to trigger orphaned cleanup daily at 03:00 UTC.

---

## Backup & Restore (local)

We provide a script `backup-restore.sh` inside `mvp-compose/` to manage database snapshots and restoration safely and reliably. This script leverages Postgres tools inside the `postgres:16.10` container, so no local installation of `psql` or `pg_dump` is required.

**Folder & format**  
- Database dumps are stored in `mvp-compose/backups/`, which is git-ignored to avoid committing sensitive data.  
- Dumps use the **custom** format via `pg_dump -Fc`, allowing flexible restore options.

**Commands & workflows**

1. **Snapshot**  
   Creates a timestamped backup of the current database. Before dumping, it ensures the `postgres`, `pgbouncer`, and `app` services are running and that the app’s `/health` endpoint returns HTTP 200. After creation, it prints the dump’s table of contents for inspection.

2. **Smoke-restore**  
   Restores the latest snapshot into a side database named like `myapp_restore_<timestamp>`. It then verifies that expected tables exist and that row counts appear reasonable, ensuring the dump is usable without affecting the live database.

3. **Full restore**  
   Performs a full replacement of the live database:  
   - Restores the dump into a temporary database.  
   - Terminates all active sessions on the live database.  
   - Drops the live database.  
   - Renames the restored database to the live database name.  
   - Finally, re-checks the app’s `/health` endpoint via PgBouncer to confirm successful recovery.

**Notes**  
- The script retries health checks for up to about one minute to handle slow startups.  
- To start fresh and re-run initialization scripts, use:  
  ```bash
  docker compose down -v
  docker compose up -d
  ```  
- Always keep real dumps out of version control; the backups folder is already excluded via `.gitignore`.

---

## Migration flow (local)

- The Compose stack now includes a `migrator` container that runs once, applies pending migrations (`npm run migrate:up`), and must exit successfully before the app starts.
- Create migrations from `mvp-compose/app`: `npm run migrate:create feature-name`. Implement the `up`/`down` blocks and validate locally with `npm run migrate:up` / `npm run migrate:down`.
- To inspect state, run `npm run migrate:status` while inside `mvp-compose/app`.
- The initial cutover requires a clean data directory. Run `docker compose down -v` and delete (or point `POSTGRES_DATA_SOURCE` at) the existing bind-mounted path before starting the stack so the first migration runs against an empty database.
- After cutover, all schema changes must go through migrations; keep the legacy `init-db` scripts limited to bootstrap tasks (database + role creation).

---

## Lambda: Auto-Stop QA Instances (E1)

This folder contains a Lambda function that stops EC2 instances tagged with `Environment=QA` after a configurable time limit.

### 📁 Path
```
aws-infra/functions/e1AutoStop/
```

### 🔧 Environment Variables

| Variable           | Description                                | Example       |
|-------------------|--------------------------------------------|---------------|
| `ENV_TAG_KEY`     | Tag key to filter instances                | `Environment` |
| `ENV_TAG_VALUE`   | Tag value to filter (e.g., QA)             | `QA`          |
| `THRESHOLD_MINUTES` | Max allowed uptime in minutes              | `120`         |
| `DRY_RUN`         | If `true`, logs what would happen          | `true`        |

### 🧪 Testen

```bash
pytest functions/e1AutoStop/tests/
```

- Vollständige Abdeckung:
  ```bash
  coverage run -m pytest && coverage report -m
  ```

- `.coveragerc`:
  ```ini
  [run]
  branch = True
  source = functions/e1AutoStop

  [report]
  show_missing = True
  skip_covered = True
  ```

### 📦 requirements.txt (lokal)

```txt
boto3==1.40.35
boto3-stubs==1.40.35
botocore==1.40.35
coverage==7.10.7
iniconfig==2.1.0
jmespath==1.0.1
packaging==25.0
pluggy==1.6.0
Pygments==2.19.2
pytest==8.4.2
python-dateutil==2.9.0.post0
s3transfer==0.14.0
six==1.17.0
urllib3==2.5.0
```

### 🧼 Cleanup

```bash
terraform destroy -target=module.auto_stop
```
=======
## QA Office Hours (Cloud)

The `qa` environment supports an **automated Office Hours Scheduler** that stops and starts tagged EC2 instances using a Lambda function and EventBridge rules.

### Deployment

This is managed via the `office_hours_scheduler` Terraform module. Key resources include:

- **Lambda function**: `qa-office-hours-scheduler`
- **CloudWatch rules**: 
  - `qa-office-hours-scheduler-start` → `cron(0 7 ? * MON-FRI *)`
  - `qa-office-hours-scheduler-stop` → `cron(0 19 ? * MON-FRI *)`
- **IAM role** with permissions for EC2 and CloudWatch Logs
- **Input tags**: 
  - `TAG_KEY=Environment`
  - `TAG_VALUE=QA`

To deploy the scheduler in `qa`:

```bash
~/bin/aws-auth.sh --account qa --tf-apply-then-destroy --tf-chdir aws-infra/environments/qa --auto-approve
```

> 💡 This triggers a `terraform apply` followed by `destroy`, useful for verifying provisioning in ephemeral environments.

### Notes

- The Lambda zip file (`lambda.zip`) must exist in the module path before applying Terraform.
- All cloud infra changes for this module are documented in `ADR-e4-office-hours.md`.

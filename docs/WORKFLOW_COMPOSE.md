# FILE_STRUCTURE.md

## Folder structure overview

- `app/`  
  Contains the Node.js application code written by Hao.

- `pgbouncer/`  
  Holds PgBouncer configuration files maintained by Felix.

- `init-db/`  
  Contains database bootstrap scripts executed on first Postgres startup.

- `mvp-compose/`  
  Docker Compose setup for the MVP stack including `docker-compose.yml`, environment files, and scripts.

## layered-infra/mvp-compose/
- `app/` — Node.js application source code.  
  - Includes graceful shutdown handling and PgBouncer-safe queries.
- `docker-compose.yml` — Compose file defining services and volumes.
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

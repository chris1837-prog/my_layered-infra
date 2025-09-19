# Layered Infrastructure

Monorepo for the MVP platform. This repo hosts:
- **mvp-compose/** – local single-host Docker Compose stack (App → PgBouncer → Postgres)
- **tests/k6/** – load testing setup (k6 + xk6-sql against PgBouncer/Postgres)
- **infra/** (future) – Terraform / cloud infra
- **docs/** – contribution guides and workflows
- **.github/** – CI workflows

---

## Getting started
- Local Compose stack: see **mvp-compose/** and **docs/WORKFLOW_COMPOSE.md**
- Contribution & PR flow: see **docs/BRANCHING.md**
- Load testing: see **tests/k6/README.md**

---

## Backup & Restore (local)

This repo ships a helper script that performs consistent backups and safe restores **via PgBouncer**. It also validates app health before/after.

> **Run all commands from the repo root** (where `backup-restore.sh` lives).
>
> Make sure the stack is up: `cd mvp-compose && docker compose up -d && cd ..`

### Commands

- **Snapshot (backup)**
  ```bash
  ./backup-restore.sh snapshot
  ```
  Creates a versioned dump under `backups/` (format: `YYYY-MM-DD_HHMMSS-myapp.dump`).

- **Smoke restore (side DB)**
  ```bash
  ./backup-restore.sh smoke-restore
  ```
  Restores the last snapshot into a temporary database (e.g., `myapp_restore_<timestamp>`), then verifies tables and counts. Does **not** touch the live DB.

- **Full restore (seed → snapshot → verify → swap)**
  ```bash
  ./backup-restore.sh full
  ```
  End-to-end flow used locally: ensures stack is up, (re)seeds demo data idempotently, takes a snapshot, verifies via smoke-restore, then performs a **swap-restore** (restore into temp DB, terminate sessions, atomically rename to `myapp`) and re-checks app `/health` through PgBouncer.

### Important notes on PgBouncer and queries

PgBouncer runs in **transaction pooling mode**, which means **prepared statements** (`PREPARE`/`EXECUTE` or `name:` parameter in node-postgres) **must not be used**, as they are incompatible with this mode. However, plain **parameterized queries without prepared statements are safe** and recommended.

### Where files go
- Backups are written to `backups/` and are **.gitignored**.
- The script uses the Compose services defined in `mvp-compose/docker-compose.yml` and relies on environment from `.env` / `.env.example`.

### Troubleshooting
- `zsh: no such file or directory: ./mvp-compose/backup-restore.sh` → Run from repo root: `./backup-restore.sh ...` (the script is **not** inside `mvp-compose/`).
- `permission denied` → `chmod +x ./backup-restore.sh`.
- App not healthy initially → the script waits for `http://localhost:3000/health` to return 200; if it keeps failing, check `docker compose logs app`.

### Validation of restores

Restores are validated by checking both the presence and correctness of database objects and by confirming the application health endpoint responds successfully.

### Notes
- All pg operations go **through PgBouncer** to mirror production access patterns.
- Dumps are created with `pg_dump` (custom format) and include schema + data of the `myapp` DB.

---

## Contributing
- Keep PRs **small and focused** (one concern per PR).
- Pin external images/dependencies to **stable versions**.
- Add/keep **smoke tests** for critical flows.
- For database performance testing, use the **load tests** in `tests/k6/`.

---


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


## AWS Cost Explorer Dashboard (E5)

### 🎯 Goal

Provide a clear, tag-based view of spending across the project.

### ✅ Acceptance Criteria

- A dashboard is created in AWS Cost Explorer.
- The dashboard is saved with a report that groups and filters costs by our standard project tag: `Environment`.
- The link to the shared dashboard is saved and documented for team leads.

### 📊 How It Works

The AWS Cost Explorer dashboard uses **linked accounts and cost allocation tags** to group expenses based on the `Environment` tag.

We recommend using the following standard `Environment` tag values across all deployed resources:

- `Development`
- `Testing`
- `QA`
- `Staging`
- `Production`

The dashboard allows filtering, grouping, and comparing usage/cost across these dimensions.

### 📎 Dashboard Link

- [Access the shared E5 Cost Dashboard](https://console.aws.amazon.com/cost-management/home?#/reports/view/CustomE5Dashboard)

### 🛠️ Setup Notes

To ensure the dashboard shows correct and complete data:

1. Enable the `Environment` tag in the **Cost Allocation Tags** section of the AWS Billing Console.
2. Verify that all Terraform modules and resources consistently tag with `Environment = var.environment`.
3. Use the `Linked Accounts` and `Usage Type` groupings in conjunction with the `Environment` tag for deeper analysis (optional).

### 🧪 Test & Validate

- Validate that all core resources (EC2, RDS, S3, etc.) include the correct `Environment` tag.
- Navigate to AWS Cost Explorer → Reports → E5 Dashboard.
- Check if each environment has cost data and is correctly grouped.
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

- Auto-stop Lambda (FinOps): see **functions/e1AutoStop/README.md**

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

## QA Auto-Stop Lambda

The repo includes a Lambda function that automatically stops long-running QA-tagged EC2 instances to save cost.

### ✅ Highlights
- Stops instances with `Environment=QA` after a threshold (e.g. 2h).
- Uses environment variables for flexibility.
- Includes unit tests with full coverage (100%) using `pytest` and `coverage`.

### 📁 Location
- `functions/e1AutoStop/`

### 🧪 Testing
- Tests are located in `tests/test_handler.py`.
- Run tests using:
  ```bash
  coverage run -m pytest
  coverage report -m
  ```
  Coverage config in `.coveragerc`.

### 📦 Dependencies
Dependencies are pinned in `requirements.txt`:
- `boto3`, `pytest`, `coverage`, etc.

See `README.md` inside `functions/e1AutoStop/` for detailed IAM, Terraform module, and config examples.

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


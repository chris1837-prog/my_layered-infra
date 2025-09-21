# Branching & PR Workflow

## Branch naming
- **Team branches** (longer-lived): `feat/<scope>`  
  e.g. `feat/database`, `feat/infra`, `feat/app`, `feat/tests`, `feat/docs`
- **Local sub-branches** (short-lived, experimental): `_feat/<desc>`  
  e.g. `_feat/add-auth`, `_feat/try-new-healthcheck`

### Common scopes
- `feat/infra` – Terraform / cloud infra
- `feat/app` – app container changes
- `feat/compose` – local stack & Docker Compose
- `feat/tests` – k6 load tests, smoke tests
- `feat/docs` – documentation, guides & workflows

## Workflow
1. Branch off `main`.
2. Implement changes in a **local sub-branch** (`_feat/...`).
3. Open a PR into your **team branch** (`feat/...`), not directly into `main`.
4. Team branch → reviewed + merged into `main` via PR.

### Rules
- ❌ No direct commits to `main`.
- ✅ Every PR must pass smoke tests (`./test-stack.sh smoke`) **and** CI checks.
- Keep PRs **small and focused** (one concern per PR).

## Commit style (Conventional Commits)
- `feat: add /health endpoint`
- `fix: correct PgBouncer healthcheck`
- `docs: add workflow guide`
- `chore: update dependencies`
- `refactor: simplify connection handling`

⚠️ Avoid mixing multiple types in one commit. Split into separate commits if needed.

## Ownership
- **Compose + Docs + CI** – infra maintainers
- **App container** – app team
- **PgBouncer + DB init** – DB/infra maintainers
- **Infra (Terraform, future `infra/`)** – infra team
- **Load Testing (k6 / tests/k6/)** – QA/perf team
- **Monitoring (Grafana, Prometheus, etc.)** – observability team
- **EBS Cleanup (orphaned volumes/snapshots)** – FinOps team
- **Cleanup Scheduler (CloudWatch + Lambda binding)** – Infra team

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

Because PgBouncer runs in **transaction pooling mode**, **prepared statements** (using `PREPARE`/`EXECUTE` or named prepared statements in node-postgres) **must not be used**, as they are incompatible with this mode. However, **plain parameterized queries are safe** and recommended to use.

### Where files go
- Backups are written to `backups/` and are **.gitignored**.
- The script uses the Compose services defined in `mvp-compose/docker-compose.yml` and relies on environment from `.env` / `.env.example`.

### Troubleshooting
- `zsh: no such file or directory: ./mvp-compose/backup-restore.sh` → Run from repo root: `./backup-restore.sh ...` (the script is **not** inside `mvp-compose/`).
- `permission denied` → `chmod +x ./backup-restore.sh`.
- App not healthy initially → the script waits for `http://localhost:3000/health` to return 200; if it keeps failing, check `docker compose logs app`.

### Notes
- All pg operations go **through PgBouncer** to mirror production access patterns.
- Dumps are created with `pg_dump` (custom format) and include schema + data of the `myapp` DB.
- Restores are validated by checking both database objects (tables and counts) and app health to ensure consistency and correctness.

This structure ensures:  
- Clear ownership and accountability.  
- Easy navigation of team responsibilities.  
- Smooth PR review and integration process.

---

## Office Hours Scheduler (QA cloud workflow)

The `qa` environment includes a scheduled **EC2 auto-stop/start module** powered by AWS Lambda and CloudWatch Events. Instances tagged with:

```hcl
TAG_KEY   = "Environment"
TAG_VALUE = "QA"
```

are automatically:
- **Started** at `07:00 UTC` every weekday  
- **Stopped** at `19:00 UTC` every weekday

This behavior is controlled by a reusable module defined under `aws-infra/modules/office_hours_scheduler/`. The function is written in Python and packaged into `lambda.zip` before deployment.

### Deployment (for QA)
Use our wrapper script:
```bash
~/bin/aws-auth.sh --account qa --tf-apply-then-destroy --tf-chdir aws-infra/environments/qa --auto-approve
```

This will perform a full apply and teardown for ephemeral QA testing.

📄 For more, see:
- [Module README](../modules/office_hours_scheduler/README.md)
- [ADR](../../../docs/ADRs/ADR-e4-office-hours.md)

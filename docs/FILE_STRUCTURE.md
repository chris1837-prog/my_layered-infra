# 📂 Repository File Structure

## Root
- `layered-infra/` — Infrastructure code organized by layers and projects.
- `README.md` — Project overview and top-level guidance.
- `BRANCHING.md` — Branching and PR workflow.
- `FILE_STRUCTURE.md` — Repository structure (this file).

## layered-infra/mvp-compose/
- `docker-compose.yml` — Main Docker Compose stack configuration for production and development.
- `docker-compose.annotated.yml` — Annotated Docker Compose file for learning and reference.
- `.env.example` — Template file for environment variables; copy to `.env` and customize.
- `test-stack.sh` — Script to build, test, and verify the stack.  
  - Supports **smoke** mode (fast connectivity checks).  
  - Supports **graceful** mode (verifies app shutdown closes HTTP + DB pool cleanly).
- `app/` — Source code for the Node.js application.
  - Includes graceful shutdown handling and PgBouncer-safe queries.
- `pgbouncer/` — Configuration files for PgBouncer connection pooler.  
  - `pgbouncer.ini` — corrected `log_disconnections` key.  
  - `userlist.txt` — mounted writable to allow non-interactive auth updates.
- `init-db/` — SQL scripts and other files for initializing the database.
- `tests/k6/` — Load and smoke testing stack:
  - `Dockerfile` — Builds a k6 image with xk6-sql extension.
  - `build-and-run.sh` — Helper script to build and run load tests.
  - `pgbouncer_pooling.js` — k6 test targeting PgBouncer (transaction pooling).
  - `open_smoke.js` — Lightweight smoke test with k6.
  - `README.md` — Guide for running load tests.

> For environment variable handling (`.env`) and day-to-day run instructions, see **docs/WORKFLOW_COMPOSE.md**.
> This keeps operational guidance in one place and avoids duplication with other docs.

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
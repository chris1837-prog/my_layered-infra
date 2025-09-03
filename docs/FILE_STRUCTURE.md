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
- `test-stack.sh` — Script to build, test, and perform smoke checks on the stack.
- `app/` — Source code for the Node.js application.
- `pgbouncer/` — Configuration files for PgBouncer connection pooler, including `userlist.txt`.
- `init-db/` — SQL scripts and other files for initializing the database.
- `tests/k6/` — Load and smoke testing stack:
  - `Dockerfile` — Builds a k6 image with xk6-sql extension.
  - `build-and-run.sh` — Helper script to build and run load tests.
  - `pgbouncer_pooling.js` — k6 test targeting PgBouncer (transaction pooling).
  - `open_smoke.js` — Lightweight smoke test with k6.
  - `README.md` — Guide for running load tests.

> Note: The `.env` file is untracked and intended for local environment-specific settings only.

## Backup & Restore (local)
The `mvp-compose/backup-restore.sh` script provides snapshot and restore functionality for the local development database. It uses Postgres tools inside the container to perform backups and restores.

- Backups are stored in the `backups/` folder.
- Backups use the custom dump format (`pg_dump -Fc`), which supports selective restores.
- You can list dump contents with `pg_restore -l`.

### Commands
- `snapshot`: Takes a snapshot of the current database state.
- `smoke-restore`: Restores from the latest snapshot and performs basic smoke tests.
- `full`: Performs a full restore from a specified dump file.

### Notes
- The restore process retries `/health` endpoint before proceeding to ensure the database is ready.
- To start fresh, use `docker compose down -v` to remove volumes.
- Keep dumps out of git to avoid committing large binary files.
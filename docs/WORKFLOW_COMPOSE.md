
# WORKFLOW_COMPOSE.md

Single-host Docker Compose workflow for the MVP stack: App → PgBouncer → Postgres.
This guide shows how to run, verify health, simulate failures, and recover.

⸻

1. Prerequisites
	•	Docker Desktop (Compose v2 enabled).
	•	macOS (M-series OK).
	•	Git (to pull the repo).
	•	No local Postgres required (we use the Postgres image as a client).

Compose file uses version: “2.4” so that local CPU/memory limits are enforced.

⸻

2. Branch & folders

Work on the Compose MVP under:

layered-infra/
└─ mvp-compose/
   ├─ docker-compose.yml
   ├─ .env.example  → copy to .env (local only)
   ├─ test-stack.sh
   ├─ app/          → Node app (Hao)
   ├─ pgbouncer/    → PgBouncer config (Felix)
   └─ init-db/      → DB bootstrap scripts (Felix)


⸻

3. First-time setup

From repo root:

cd mvp-compose
cp .env.example .env            # create your local env file
# (Optional) edit .env to change db name/user/pass/ports

Do not commit .env. It’s ignored via .gitignore.

⸻

4. Bring the stack up

docker compose up -d --build
docker compose ps

You should see the three services. Postgres and PgBouncer may show as “starting” briefly while health checks pass.

⸻

5. Verify health (happy path)

App health endpoint

curl -i http://localhost:3000/health
Expect output similar to:
```
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 15
ETag: W/"f-VaSQ4oDUiZblZNAEkkN+sX+q3Sg"
Date: Fri, 29 Aug 2025 08:39:12 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"status":"ok"}
```
This is the expected result when DB connectivity is healthy.

PgBouncer reachable (Postgres protocol, not HTTP)

Use the Postgres image as a client so you don’t need psql installed:

# Inside the compose network, target pgbouncer:6432
docker compose run --rm -T postgres \\
  psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@pgbouncer:6432/${POSTGRES_DB}" \\
  -c "select 1;"

If that returns 1, PgBouncer is forwarding to Postgres correctly.

⸻

6. Simulate DB failure → verify backoff & recovery

Stop Postgres:

docker compose stop postgres

The app’s health should drop to 503 shortly:

curl -i http://localhost:3000/health
# Expect: HTTP/1.1 503 ... {"status":"db_unavailable", ...}

Start Postgres again:

docker compose start postgres

App recovers to 200:

curl -i http://localhost:3000/health
# Expect: 200

This satisfies the acceptance criteria that app health reflects DB availability and recovers without manual restarts.

⸻

7. Resource limits (local enforcement)

We use Compose v2.4 keys:

mem_limit: "1g"     # postgres
cpus: "1.0"

mem_limit: "256m"   # pgbouncer
cpus: "0.2"

mem_limit: "512m"   # app
cpus: "0.5"

Check live usage:

docker stats

On macOS, 100% in docker stats ≈ one full CPU core.

⸻

8. Port bindings & connectivity
	•	App: host localhost:3000 → container :3000
	•	PgBouncer: host 127.0.0.1:6432 → container :6432
	•	Only accessible from your machine (not the LAN) because we bind to 127.0.0.1.

From your host you can connect using any Postgres client to:

postgresql://<user>:<pass>@127.0.0.1:6432/<db>


⸻

9. Auth modes (dev vs prod)

Current default for fast local dev:

# pgbouncer environment
AUTH_TYPE=md5

PgBouncer requires a userlist.txt file for MD5 authentication.

Postgres passwords are forced to MD5 encryption at initialization via the script `02-force-md5-password.sh` located in init-db/.

If PgBouncer logs show "wrong password type", you can recover by re-running the ALTER ROLE command inside Postgres and restarting PgBouncer:

```bash
docker compose exec postgres \\
  psql -U <your_user> -d <your_db> -c "SET password_encryption='md5'; ALTER ROLE <your_user> PASSWORD '<your_password>';"
docker compose restart pgbouncer
```

This ensures PgBouncer and Postgres are aligned on password encryption.

⸻

10. Database initialization

Anything placed under init-db/ is executed once on the very first Postgres boot (empty data volume):
	•	*.sql files → executed in alphabetical order.
	•	*.sh scripts → run as shell scripts.

To force Postgres to run init scripts again (destroys data):

docker compose down -v   # removes volumes
docker compose up -d


⸻

11. Test script (automates the above)

We provide test-stack.sh which:
	•	brings the stack up,
	•	waits for the app to report healthy (200),
	•	checks psql through PgBouncer,
	•	stops Postgres (expects /health → 503),
	•	restarts Postgres (expects /health → 200).

Run:

./test-stack.sh

⸻

11b. Optional: Load & stress tests with k6

For deeper benchmarking of PgBouncer and Postgres under load, we provide k6-based tests in **tests/k6/**.

- The Docker image `local/xk6-sql` includes the `xk6-sql` extension for Postgres.
- You can run parameterized load tests with:

```bash
cd mvp-compose
export CONN_STR='postgres://myuser:mypassword@pgbouncer:6432/myapp?sslmode=disable'
VUS=50 DURATION=120s RPS=500 tests/k6/build-and-run.sh
```

- Results include latency (`db_latency`), error rates (`db_error_rate`), and operation throughput (`db_ops`).  
- See [tests/k6/README.md](../tests/k6/README.md) for detailed usage.

⸻

12. Backup & Restore Runbook (local)

We provide `mvp-compose/backup-restore.sh` to **snapshot** the DB and **restore** it safely. It uses the Postgres tools inside the `postgres:16.10` container — no local psql needed — and waits for the app `/health` where appropriate.

**Folder & format**
- Dumps are written to `mvp-compose/backups/` (git-ignored).
- Format: **custom** (`pg_dump -Fc`). You can list contents with:
  ```bash
  docker compose exec -T postgres pg_restore -l < /path/to/your.dump | head -40
  ```

**Commands**

1) Snapshot the current DB (verifies dump)
```bash
./mvp-compose/backup-restore.sh snapshot
```
What it does:
- Ensures `postgres`, `pgbouncer`, `app` are up and `/health` = 200.
- Creates a timestamped dump under `mvp-compose/backups/`.
- Prints the dump TOC (table of contents) so you can see what’s included.

2) Smoke-restore into a side database (non-destructive)
```bash
./mvp-compose/backup-restore.sh smoke-restore
```
What it does:
- Restores the latest dump into a new DB named like `myapp_restore_<timestamp>`.
- Verifies tables exist and row counts look sane.

3) Full swap-restore (replace the live DB safely)
```bash
./mvp-compose/backup-restore.sh full
```
What it does:
- (Re)seeds tiny demo data (idempotent) for testing, snapshots, smoke-restores.
- Restores into a temporary DB, **terminates sessions** on `myapp`, **drops** old `myapp`,
  **renames** the restored DB to `myapp`, then re-checks the app `/health` via PgBouncer.

**Notes**
- If `/health` is slow on your machine, the script retries for up to ~1 minute.
- To start fresh and re-run init scripts, use:
  ```bash
  docker compose down -v
  docker compose up -d
  ```
- Keep real dumps out of git — `mvp-compose/backups/` is already in `.gitignore`.

⸻

... (remaining content unchanged) ...

WORKFLOW_COMPOSE.md

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
docker compose run --rm -T postgres \
  psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@pgbouncer:6432/${POSTGRES_DB}" \
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
docker compose exec postgres \
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

13. Volume persistence verification

By default, Postgres data is persisted to a dedicated Docker volume named `mvp-compose_postgres_data`.

You can confirm this with:

```bash
docker volume ls | grep postgres_data
# expect: local     mvp-compose_postgres_data

docker compose exec postgres ls -lh /var/lib/postgresql/data
# expect to see cluster files: base/, pg_wal/, postgresql.conf, etc.
```

This ensures that database state survives container restarts and aligns with the acceptance criteria for a dedicated data volume.

✅ Acceptance Criteria #3 (part A): DB data on dedicated volume is confirmed.

```bash
docker compose exec postgres \
  psql -U myuser -d myapp -c "CREATE TABLE foo(id serial primary key, val text); INSERT INTO foo(val) VALUES('bar');"
CREATE TABLE
INSERT 0 1

docker compose down
docker compose up -d

docker compose exec postgres \
  psql -U myuser -d myapp -c "SELECT * FROM foo;"
 id | val 
----+-----
  1 | bar
(1 row)
```

If you run docker compose down -v, the volume is destroyed and data will not persist.

⸻

14. Troubleshooting

App health stays unhealthy
	•	Ensure the app actually exposes GET /health on port 3000.
	•	Confirm the app env points to PgBouncer:
	•	DB_HOST=pgbouncer, DB_PORT=6432.

PgBouncer healthcheck failing
	•	Check mapping is 127.0.0.1:6432:6432 (not :5432).
	•	View logs:

docker compose logs -f pgbouncer


Postgres stuck “starting”
	•	Inspect logs:

docker compose logs -f postgres


	•	If you changed POSTGRES_DB/USER/PASSWORD after the first boot, remember they don’t retroactively apply to an existing data volume. Recreate with docker compose down -v.

Ports already in use
	•	Something else is using 3000 or 6432 on your host. Change the host port mapping in docker-compose.yml or stop the conflicting process.

PgBouncer login failed: wrong password type
	•	Cause: Postgres user stored as SCRAM.
	•	Fix:  
	  ```bash
	  docker compose exec postgres \
	    psql -U myuser -d myapp -c "SET password_encryption='md5'; ALTER ROLE myuser PASSWORD 'mypassword';"
	  docker compose restart pgbouncer
	  ```
	•	Note that this is handled automatically on first init by `02-force-md5-password.sh`, but old volumes may need manual fix.


⸻

15. Acceptance criteria checklist (copy into PRs)
	•	docker compose up -d brings up app, postgres:16.10, pgbouncer.
	•	DB data on dedicated volume confirmed (persistence across restarts).
	•	Snapshot/restore runbook proven via backup-restore.sh (snapshot, smoke-restore, full).
	•	Resource limits set and effective (mem_limit, cpus), restart: unless-stopped.
	•	Health checks present:
	•	Postgres: `pg_isready` on DB.
	•	PgBouncer: `pg_isready` on 127.0.0.1:6432.
	•	App: HTTP GET /health returns 200 when DB ok, 503 when down.
	•	.env used (no secrets hardcoded in Compose).
	•	App connects to PgBouncer (not directly to Postgres).
	•	Failure drill passes: stop DB → /health=503 → start DB → /health=200.
	•	PgBouncer bound to 127.0.0.1:6432 (or agreed WG IP).

✅ Acceptance Criteria #4: PgBouncer transaction pooling enabled and node-postgres driver reviewed (compatible).

⸻

16. Upgrade notes
	•	Postgres version is controlled by POSTGRES_VERSION in .env.
	•	We standardize on 16.10. To start fresh after changing major versions:

docker compose down -v
docker compose up -d



⸻

17. Clean up

# stop and remove containers (keep data)
docker compose down

# stop and remove containers + volumes (wipe DB)
docker compose down -v


⸻

18. FAQ

Q: Why version: "2.4" in Compose?
A: So mem_limit and cpus are enforced locally. v3’s deploy.resources only works in Swarm.

Q: Why PgBouncer at all?
A: It pools connections so Postgres handles a small, stable number of backends even if the app opens many clients.

Q: Can I connect from my host tools (DBeaver/psql)?
A: Yes: 127.0.0.1:6432 goes to PgBouncer, localhost:3000 goes to the app.


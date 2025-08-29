Absolutely. Here’s a complete, paste-ready docs/WORKFLOW_COMPOSE.md you can drop into the repo.

⸻

WORKFLOW_COMPOSE.md

Single-host Docker Compose workflow for the MVP stack: App → PgBouncer → Postgres.
This guide shows how to run, verify health, simulate failures, and recover.

⸻

0) Prerequisites
	•	Docker Desktop (Compose v2 enabled).
	•	macOS (M-series OK).
	•	Git (to pull the repo).
	•	No local Postgres required (we use the Postgres image as a client).

Compose file uses version: “2.4” so that local CPU/memory limits are enforced.

⸻

1) Branch & folders

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

2) First-time setup

From repo root:

cd mvp-compose
cp .env.example .env            # create your local env file
# (Optional) edit .env to change db name/user/pass/ports

Do not commit .env. It’s ignored via .gitignore.

⸻

3) Bring the stack up

docker compose up -d --build
docker compose ps

You should see the three services. Postgres and PgBouncer may show as “starting” briefly while healthchecks pass.

⸻

4) Verify health (happy path)

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

5) Simulate DB failure → verify backoff & recovery

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

6) Resource limits (local enforcement)

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

7) Port bindings & connectivity
	•	App: host localhost:3000 → container :3000
	•	PgBouncer: host 127.0.0.1:6432 → container :6432
	•	Only accessible from your machine (not the LAN) because we bind to 127.0.0.1.

From your host you can connect using any Postgres client to:

postgresql://<user>:<pass>@127.0.0.1:6432/<db>


⸻

8) Auth modes (dev vs prod)

Current default for fast local dev:

# pgbouncer environment
AUTH_TYPE=trust

For a secured setup (recommended beyond smoke tests):
	1.	Generate userlist.txt (macOS):

USER="${POSTGRES_USER}"; PASS="${POSTGRES_PASSWORD}"
HASH=$(printf '%s' "${PASS}${USER}" | md5 -q)
printf '"%s" "md5%s"\n' "$USER" "$HASH" > pgbouncer/userlist.txt

	2.	Update PgBouncer service:

environment:
  - AUTH_TYPE=md5
  - AUTH_FILE=/etc/pgbouncer/userlist.txt
volumes:
  - ./pgbouncer/userlist.txt:/etc/pgbouncer/userlist.txt:ro

	3.	Ensure Postgres stores md5 hashes (already configured):

command: ["postgres", "-c", "password_encryption=md5"]

Restart:

docker compose up -d


⸻

9) Database initialization

Anything placed under init-db/ is executed once on the very first Postgres boot (empty data volume):
	•	*.sql files → executed in alphabetical order.
	•	*.sh scripts → run as shell scripts.

To force Postgres to run init scripts again (destroys data):

docker compose down -v   # removes volumes
docker compose up -d


⸻

10) Test script (automates the above)

We provide test-stack.sh which:
	•	brings the stack up,
	•	waits for the app to report healthy (200),
	•	checks psql through PgBouncer,
	•	stops Postgres (expects /health → 503),
	•	restarts Postgres (expects /health → 200).

Run:

./test-stack.sh


⸻

11) Troubleshooting

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

⸻

12) Acceptance criteria checklist (copy into PRs)
	•	docker compose up -d brings up app, postgres:16.10, pgbouncer.
	•	Resource limits set and effective (mem_limit, cpus), restart: unless-stopped.
	•	Healthchecks present:
	•	Postgres: pg_isready on DB.
	•	PgBouncer: pg_isready on 127.0.0.1:6432.
	•	App: HTTP GET /health returns 200 when DB ok, 503 when down.
	•	.env used (no secrets hardcoded in Compose).
	•	App connects to PgBouncer (not directly to Postgres).
	•	Failure drill passes: stop DB → /health=503 → start DB → /health=200.
	•	PgBouncer bound to 127.0.0.1:6432 (or agreed WG IP).

⸻

13) Upgrade notes
	•	Postgres version is controlled by POSTGRES_VERSION in .env.
	•	We standardize on 16.10. To start fresh after changing major versions:

docker compose down -v
docker compose up -d



⸻

14) Clean up

# stop and remove containers (keep data)
docker compose down

# stop and remove containers + volumes (wipe DB)
docker compose down -v


⸻

15) FAQ

Q: Why version: "2.4" in Compose?
A: So mem_limit and cpus are enforced locally. v3’s deploy.resources only works in Swarm.

Q: Why PgBouncer at all?
A: It pools connections so Postgres handles a small, stable number of backends even if the app opens many clients.

Q: Can I connect from my host tools (DBeaver/psql)?
A: Yes: 127.0.0.1:6432 goes to PgBouncer, localhost:3000 goes to the app.

⸻

That’s it. If the steps above pass, the MVP meets the Compose acceptance criteria.
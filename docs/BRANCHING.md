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

- **Smoke restore (side DB)**
  ```bash
  ./backup-restore.sh smoke-restore
  ```

- **Full restore (seed → snapshot → verify → swap)**
  ```bash
  ./backup-restore.sh full
  ```

### Important notes on PgBouncer and queries

Because PgBouncer runs in **transaction pooling mode**, **prepared statements** must not be used. Use plain parameterized queries.

### Where files go
- Backups are written to `backups/` (in `.gitignore`).
- Script uses Compose config from `mvp-compose/docker-compose.yml`.

### Troubleshooting
- `zsh: no such file or directory: ./mvp-compose/backup-restore.sh` → run from repo root.
- `permission denied` → `chmod +x ./backup-restore.sh`.
- App not healthy → verify `localhost:3000/health` and container logs.

---

## ✅ Infra Lambda Development (e.g. e1AutoStop)

### Branch usage
- Dev branch: `_feat/e1AutoStop`
- Team branch: `feat/infra`

### Testing
```bash
cd aws-infra
coverage run -m pytest
coverage report -m
```

### Requirements
```text
boto3==1.40.35
coverage==7.10.7
pytest==8.4.2
# usw.
```

### .coveragerc config
```ini
[run]
branch = True
source = functions/e1AutoStop

[report]
show_missing = True
skip_covered = True
```

### 100% Coverage Output (Example)
```
Name                                     Stmts   Miss Branch BrPart  Cover
--------------------------------------------------------------------------
functions/e1AutoStop/stop_instances.py      34      0     10      0   100%
--------------------------------------------------------------------------
TOTAL                                       81      0     10      0   100%
```

### Directory Layout
```bash
functions/
└── e1AutoStop/
    ├── stop_instances.py
    ├── test_handler.py
    ├── requirements.txt
    └── .coveragerc
```

### Conventional Commits
- `feat: add e1AutoStop Lambda`
- `test: full test coverage`
- `docs: add Lambda usage guide`

# Database Migration System Implementation (K2)

## Summary
Introduce a version-controlled, repeatable migration workflow using `node-pg-migrate`. Migrations run from a dedicated migrator container before the app starts; schema ownership stays with the existing `myuser` account.

**Current Status**: This PR implements the complete migration infrastructure as outlined in the acceptance criteria below.

**Key Changes**
- 🔄 Add `node-pg-migrate` as a dev dependency
- 🔄 Add migration helper scripts to `package.json`
- 🔄 Create first migration covering the schema previously in `init-db/01-init.sql`
- 🔄 Add `pg-migrate-config.js` and ensure all migration scripts share the app's DB env settings
- 🔄 Replace the init SQL's table creation with the new migration, leaving only DB/user bootstrap
- 🔄 Add a `Dockerfile.migrate` and migrator service in `docker-compose.yml` that blocks app startup until migrations succeed
- 🔄 Document the migration workflow and fresh-start expectation

## How to Test
```bash
# Current state
cd mvp-compose
cp .env.example .env
docker compose up -d --build
curl -i http://localhost:3000/health

# After migration infrastructure lands
cd mvp-compose/app
npm run migrate:status
npm run migrate:create test-migration
docker compose down -v   # fresh DB for first migration (also remove or override POSTGRES_DATA_SOURCE bind mount)
docker compose up -d --build
curl -i http://localhost:3000/health
```

> **Note:** Postgres stores its data in the host path referenced by `POSTGRES_DATA_SOURCE`. Remove that directory (or point the env var at a new empty location) before rerunning the stack; `docker compose down -v` alone will not wipe bind-mounted data.

## Acceptance Criteria

### Phase 1: Dependency Setup 🔄
- [x] `node-pg-migrate` in devDependencies
- [x] `migrate:create`, `migrate:up`, `migrate:down`, `migrate:status`, `migrate` scripts in `package.json`

### Phase 2: Migration Infrastructure 🔄
- [x] Add `migrations/` directory with initial migration that recreates the original schema
- [x] Create `pg-migrate-config.js` that reads shared DB env vars
- [x] Update `init-db/01-init.sql` so it only handles DB/user bootstrap
- [x] Ensure `init-db/02-force-md5-password.sh` and PgBouncer configs still function unchanged

### Phase 3: Docker Integration 🔄
- [x] Add `Dockerfile.migrate`
- [x] Add `migrator` one-shot service to `docker-compose.yml`
- [x] Make `app` depend on successful migrator completion and healthy PgBouncer/Postgres

> Suggested flow:
> 1. Scaffold `Dockerfile.migrate` that installs dev deps (full `npm ci`), copies `package*.json`, `pg-migrate-config.js`, and `migrations/`, with default CMD `npm run migrate:up`.
> 2. Extend `docker-compose.yml`:
>    - introduce `migrator` service using the new Dockerfile, reusing the app env vars and mounting `./app` where needed;
>    - set `depends_on` so `migrator` waits for healthy `postgres`, and `app` waits for `migrator` success plus `pgbouncer` health.
> 3. Ensure logs are visible (no tty) and the service exits on completion (no restart).
> 4. Update local helper scripts (`test-stack.sh`, etc.) to wait on migrator before health checks.
> 5. Validate with `docker compose down -v && docker compose up -d --build`, confirm migrator runs once and app reaches 200 /health.

### Phase 4: Documentation & Process 🔄
- [x] Document migration creation/execution/rollback workflow and the fresh-DB expectation for the cutover
- [x] Update README / docs / `.env.example`
- [x] Update helper scripts (e.g., `test-stack.sh`) to reflect the migration-first flow

## Migration Workflow

### Creating a migration
1. Ensure you are inside `mvp-compose/app`.
2. Run `npm run migrate:create <name>` to scaffold a timestamped migration file under `mvp-compose/app/migrations/`.
3. Implement the `up`/`down` functions; keep DDL idempotent wherever possible.

### Applying migrations locally
1. Bring the stack up once to ensure dependencies are built: `cd mvp-compose && docker compose up -d --build`.
2. Run pending migrations via the migrator service (preferred) or directly:  
   - Docker Compose handles this automatically when `docker compose up` starts and the `migrator` container exits successfully.  
   - For manual execution without Compose, use `npm run migrate:up` inside `mvp-compose/app`.
3. Confirm status with `npm run migrate:status`.

### Rolling back
- To undo the latest migration, run `npm run migrate:down`.  
- For iterative testing, pair `npm run migrate:down` with targeted `npm run migrate:up` commands.  
- Rollbacks should be immediately followed by `npm run migrate:status` to verify the stack state.

### Fresh database expectation for cutover
- The first migration run assumes an empty database: drop bind-mounted data before enabling the migrator.
- Use `docker compose down -v` and remove (or point to a new) `POSTGRES_DATA_SOURCE` directory to guarantee a clean slate.  
- Communicate the cutover window so no writes happen between wiping old data and running the first migration.
- After cutover, all schema changes must go through migrations; the legacy `init-db` SQL should only contain bootstrap logic (users/roles).

## Technical Notes
- First migration assumes a clean database; devs should run `docker compose down -v` and clear or override the host directory bound to `POSTGRES_DATA_SOURCE` when switching over.
- `pg-migrate-config.js` lives in `mvp-compose/app/` and builds its connection string from `DB_HOST`, `DB_USER`, `DB_PASSWORD`, etc.
- `node-pg-migrate` commands are run via `npm run migrate` (plus `:up/:down/:status/:create`).

## Testing Strategy
- CLI: `npm run migrate:status`, `npm run migrate:create add-table`, `npm run migrate:up`, `npm run migrate:down`
- Compose: `docker compose down -v`, `docker compose up -d --build`, confirm migrator exits 0 and app health is 200.
- Optional: Validate that backup/restore scripts still operate after migrations run.

## Risks & Mitigations
- **Migration failure** → surface logs via migrator service; document rollback steps.
- **Fresh DB assumption** → call out `docker compose down -v` in docs; coordinate cutover timing.
- **PgBouncer compatibility** → continue using `myuser`; no role-split in this phase.

## Follow-Up Ideas
- Add migration validation in CI/CD
- Automate rollback playbooks
- Introduce separate DB roles in a future PR when scope allows

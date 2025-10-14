# Database Migration System Implementation

## Summary
Introduce a version-controlled, repeatable migration workflow using `node-pg-migrate`. Migrations run from a dedicated migrator container before the app starts; schema ownership stays with the existing `myuser` account.

**Key Changes**
- ✅ `node-pg-migrate` already added as a dev dependency
- ✅ Migration helper scripts already added to `package.json`
- 🔄 Create first migration covering the schema previously in `init-db/01-init.sql`
- 🔄 Add `pg-migrate-config.js` and ensure all migration scripts share the app’s DB env settings
- 🔄 Replace the init SQL’s table creation with the new migration, leaving only DB/user bootstrap
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
npm run migrate:list
npm run migrate:create test-migration
docker compose down -v   # fresh DB for first migration
docker compose up -d --build
curl -i http://localhost:3000/health
```

## Acceptance Criteria

### Phase 1: Dependency Setup ✅
- [x] `node-pg-migrate` in devDependencies
- [x] `migrate:create`, `migrate:up`, `migrate:down`, `migrate:list`, `migrate` scripts in `package.json`

### Phase 2: Migration Infrastructure 🔄
- [ ] Add `migrations/` directory with initial migration that recreates the original schema
- [ ] Create `pg-migrate-config.js` that reads shared DB env vars
- [ ] Update `init-db/01-init.sql` so it only handles DB/user bootstrap
- [ ] Ensure `init-db/02-force-md5-password.sh` and PgBouncer configs still function unchanged

### Phase 3: Docker Integration 🔄
- [ ] Add `Dockerfile.migrate`
- [ ] Add `migrator` one-shot service to `docker-compose.yml`
- [ ] Make `app` depend on successful migrator completion and healthy PgBouncer/Postgres

### Phase 4: Documentation & Process 🔄
- [ ] Document migration creation/execution/rollback workflow and the fresh-DB expectation for the cutover
- [ ] Update README / docs / `.env.example`
- [ ] Update helper scripts (e.g., `test-stack.sh`) to reflect the migration-first flow

## Technical Notes
- First migration assumes a clean database; devs should run `docker compose down -v` when switching over.
- `pg-migrate-config.js` lives in `mvp-compose/app/` and builds its connection string from `DB_HOST`, `DB_USER`, `DB_PASSWORD`, etc.
- `node-pg-migrate` commands are run via `npm run migrate` (plus `:up/:down/:list/:create`).

## Testing Strategy
- CLI: `npm run migrate:list`, `npm run migrate:create add-table`, `npm run migrate:up`, `npm run migrate:down`
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

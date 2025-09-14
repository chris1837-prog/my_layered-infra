## Summary
<!-- What does this PR change? -->

## How to test
```bash
cd mvp-compose
cp .env.example .env
docker compose up -d --build
curl -i http://localhost:3000/health
```

## Acceptance Criteria
- [ ] Services: app, postgres:16.10, pgbouncer
- [ ] Resource limits + restart policies set
- [ ] Healthchecks:
  - [ ] Postgres: `pg_isready`
  - [ ] PgBouncer: `pg_isready -h 127.0.0.1 -p 6432`
  - [ ] App: `/health` → 200 when DB OK, 503 when DB down
- [ ] App connects through PgBouncer (not Postgres directly)
- [ ] `.env` used (no secrets hardcoded)
- [ ] Failure drill passes (stop DB → 503, start DB → 200)

## Notes
<!-- Risks, follow-ups, config changes -->
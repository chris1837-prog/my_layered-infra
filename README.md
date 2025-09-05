# Layered Infrastructure

Monorepo for the MVP platform. This repo hosts:
- **mvp-compose/** – local single-host Docker Compose stack (App → PgBouncer → Postgres)
- **infra/** (future) – Terraform / cloud infra
- **docs/** – contribution guides and workflows
- **.github/** – CI workflows

## Getting started
- Local Compose stack: see **mvp-compose/** and **docs/WORKFLOW_COMPOSE.md**
- Contribution & PR flow: see **docs/BRANCHING.md**

## Backup & Restore (local)

### Backup

To create a backup of the local Postgres database:

1. Run the backup command in the `mvp-compose` directory:

   ```
   docker-compose exec postgres pg_dumpall -U postgres > backup.sql
   ```

2. Save the `backup.sql` file to a safe location outside the container.

### Restore

To restore the backup to the local Postgres database:

1. Copy the backup file into the `mvp-compose` directory if it is not already there.

2. Run the restore command:

   ```
   cat backup.sql | docker-compose exec -T postgres psql -U postgres
   ```

3. Verify the database has been restored correctly by connecting to Postgres and checking the data.

---

## Contributing
- Keep PRs **small and focused** (one concern per PR).
- Pin external images/dependencies to **stable versions**.
- Add/keep **smoke tests** for critical flows.

## Repository structure
```
layered-infra/
├─ mvp-compose/
├─ docs/
└─ .github/
```
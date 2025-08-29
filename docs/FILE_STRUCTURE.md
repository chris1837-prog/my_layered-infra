# 📂 Repository File Structure

## Root
- `layered-infra/` — Infrastructure code organized by layers and projects.

## layered-infra/mvp-compose/
- `docker-compose.yml` — Main Docker Compose stack configuration for production and development.
- `docker-compose.annotated.yml` — Annotated Docker Compose file for learning and reference.
- `.env.example` — Template file for environment variables; copy to `.env` and customize.
- `test-stack.sh` — Script to build, test, and perform smoke checks on the stack.
- `app/` — Source code for the Node.js application.
- `pgbouncer/` — Configuration files for PgBouncer connection pooler, including `userlist.txt`.
- `init-db/` — SQL scripts and other files for initializing the database.

Note: The `.env` file is untracked and intended for local environment-specific settings only.

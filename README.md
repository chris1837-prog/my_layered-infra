# Layered Infrastructure

Monorepo for the MVP platform. This repo hosts:
- **mvp-compose/** – local single-host Docker Compose stack (App → PgBouncer → Postgres)
- **infra/** (future) – Terraform / cloud infra
- **docs/** – contribution guides and workflows
- **.github/** – CI workflows

## Getting started
- Local Compose stack: see **mvp-compose/** and **docs/WORKFLOW_COMPOSE.md**
- Contribution & PR flow: see **docs/BRANCHING.md**

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
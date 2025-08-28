# Layered Infrastructure

## Our goal for our MVP
- Keep costs as low as possible
- Use open source
- Avoid vendor lock-in
- Not use managed resources
- Be able to deploy anywhere

---

## Overview
This repository contains the MVP stack for **App → PgBouncer → Postgres** (via Docker Compose) and AWS Terraform infrastructure.

## Structure
- **mvp-compose/** — local single-host stack
- **aws-infra/** — Terraform IaC for AWS
- **docs/** — runbooks & workflows
- **.github/** — CI/CD workflows + PR template

## Quickstart (local MVP)
```bash
cd mvp-compose
cp .env.example .env
docker compose up -d --build
curl -i http://localhost:3000/health
```

## Branching

See [docs/BRANCHING.md](docs/BRANCHING.md) for feature branch rules.

Example:
- Team branch: `feat/app_and_db`
- Sub-branch: `_feat/app_and_branch_hao`

## Ownership
- **Daniel** — Compose, Docs, CI, Terraform glue
- **Hao** — App container + health logic
- **Felix** — PgBouncer config + DB init

## Docs
- [WORKFLOW_COMPOSE](docs/WORKFLOW_COMPOSE.md)
- [WORKFLOW_TERRAFORM](docs/WORKFLOW_TERRAFORM.md)
- [BRANCHING](docs/BRANCHING.md)
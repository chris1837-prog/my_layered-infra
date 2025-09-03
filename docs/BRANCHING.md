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

---

This structure ensures:  
- Clear ownership and accountability.  
- Easy navigation of team responsibilities.  
- Smooth PR review and integration process.

# Branching & PR Workflow

## Branch naming
- **Team branches**: `feat/<scope>`  
  e.g. `feat/database`
- **Local sub-branches**: `_feat/<desc>`  
  e.g. `_feat/add-auth`

## Workflow
1. Branch off `main`.
2. Implement changes.
3. Open a PR into your **team branch**, not directly into `main`.
4. Team branch → reviewed + merged into `main`.

## Commit style (Conventional Commits)
- `feat: add /health endpoint`
- `fix: correct PgBouncer healthcheck`
- `docs: add workflow guide`

## Ownership
- Compose + Docs + CI  
- App container  
- PgBouncer + DB init
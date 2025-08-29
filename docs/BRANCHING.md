# Branching & PR Workflow

## Branch naming
- **Team branches**: `feat/<team-scope>`  
  e.g. `feat/app_and_db`
- **Local sub-branches**: `_feat/<owner>-<desc>`  
  e.g. `_feat/app_and_branch_hao`

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
- Daniel: Compose + Docs + CI  
- Hao: App container  
- Felix: PgBouncer + DB init
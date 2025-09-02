#!/usr/bin/env bash
set -euo pipefail

# Run from repo root OR mvp-compose; we try to cd if needed
if [ -f "mvp-compose/docker-compose.yml" ]; then
  cd mvp-compose
elif [ ! -f "docker-compose.yml" ]; then
  echo "Run from repo root or mvp-compose directory." >&2
  exit 1
fi

ts() { date +%F_%H%M%S; }

require_up() {
  echo "▶️  Ensuring postgres/pgbouncer/app are up..."
  docker compose up -d --build postgres pgbouncer app
  # After bringing services up, wait for the app to actually be healthy
  wait_for_app_health
}

seed_demo() {
  echo "🌱 Seeding small demo schema/data (idempotent)..."
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-myuser}" -d "${POSTGRES_DB:-myapp}" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
INSERT INTO users(name) VALUES ('Alice'), ('Bob')
ON CONFLICT DO NOTHING; -- harmless if unique rules exist later
SQL
}

snapshot() {
  mkdir -p backups
  local dump="backups/$(ts)-${POSTGRES_DB:-myapp}.dump"
  echo "🧾 Creating snapshot → $dump"
  docker compose exec -T postgres \
    pg_dump -U "${POSTGRES_USER:-myuser}" -d "${POSTGRES_DB:-myapp}" -Fc > "$dump"
  # Basic checks
  [ -s "$dump" ] || { echo "❌ Dump file is empty: $dump"; exit 1; }
  echo "🔎 Inspect dump TOC:"
  docker compose exec -T postgres pg_restore -l -U "${POSTGRES_USER:-myuser}" -d "${POSTGRES_DB:-myapp}" < "$dump" | head -20
  echo "✅ Snapshot OK"
}

# Wait until the app's /health endpoint returns HTTP 200
wait_for_app_health() {
  local url="http://localhost:${PORT:-3000}${HEALTH_PATH:-/health}"
  local max_retries="${APP_HEALTH_MAX_RETRIES:-20}"
  local sleep_secs="${APP_HEALTH_RETRY_SLEEP:-3}"

  echo "⏳ Waiting for app health at $url ..."
  for i in $(seq 1 "$max_retries"); do
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)
    if [ "$status" = "200" ]; then
      echo "✅ App is healthy (HTTP 200)"
      return 0
    fi
    echo "   Try $i/$max_retries: not healthy yet (got ${status:-curl-fail}). Retrying in ${sleep_secs}s..."
    sleep "$sleep_secs"
  done

  echo "❌ App never became healthy at $url"
  return 1
}

app_health_ok() {
  curl -sf "http://localhost:${PORT:-3000}${HEALTH_PATH:-/health}" >/dev/null
}

check_health() {
  echo "🩺 Checking app /health..."
  if wait_for_app_health; then
    : # already echoed success inside wait_for_app_health
  else
    exit 1
  fi
}

smoke_restore_side() {
  local dump_latest
  dump_latest="$(ls -1t backups/*.dump | head -1)"
  [ -f "$dump_latest" ] || { echo "❌ No dump found in backups/"; exit 1; }

  local side="myapp_restore_$(ts)"
  echo "🧪 Smoke-restore into side DB: $side"
  docker compose exec -T postgres createdb -U "${POSTGRES_USER:-myuser}" "$side"
  docker compose exec -T postgres pg_restore -U "${POSTGRES_USER:-myuser}" -d "$side" < "$dump_latest"

  echo "🔎 Verify tables in $side"
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-myuser}" -d "$side" -c "\dt"
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-myuser}" -d "$side" -c "SELECT count(*) FROM users;" || true
  echo "✅ Smoke-restore (side DB) done"
}

swap_restore_overwrite() {
  local dump_latest
  dump_latest="$(ls -1t backups/*.dump | head -1)"
  [ -f "$dump_latest" ] || { echo "❌ No dump found in backups/"; exit 1; }

  local side="myapp_swap_$(ts)"
  local db="${POSTGRES_DB:-myapp}"

  echo "🔁 Swap-restore: restore into temp DB, then atomar tauschen"
  docker compose exec -T postgres createdb -U "${POSTGRES_USER:-myuser}" "$side"
  docker compose exec -T postgres pg_restore -U "${POSTGRES_USER:-myuser}" -d "$side" < "$dump_latest"

  echo "🔒 Terminate sessions on $db"
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-myuser}" -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db';"

  echo "🗑️ Drop $db"
  docker compose exec -T postgres dropdb -U "${POSTGRES_USER:-myuser}" "$db"

  echo "✏️  Rename $side → $db"
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-myuser}" -d postgres -c \
    "ALTER DATABASE \"$side\" RENAME TO \"$db\";"

  echo "🩺 Re-check app health (PgBouncer path)"
  check_health
  echo "✅ Swap-restore completed"
}

case "${1:-}" in
  seed)         require_up; seed_demo ;;
  snapshot)     require_up; check_health; snapshot ;;
  smoke-restore) require_up; smoke_restore_side ;;
  swap-restore) require_up; swap_restore_overwrite ;;
  full)
    require_up
    seed_demo
    check_health
    snapshot
    smoke_restore_side
    swap_restore_overwrite
    ;;
  *)
    cat <<USAGE
Usage: $0 {seed|snapshot|smoke-restore|swap-restore|full}

Targets:
  seed           Create a tiny demo schema/data (users) in ${POSTGRES_DB:-myapp}
  snapshot       Create backups/<timestamp>-myapp.dump and validate it
  smoke-restore  Restore latest dump into side DB and verify contents
  swap-restore   Overwrite the main DB via temp DB + rename; re-check app /health
  full           Run all steps in order (seed → snapshot → smoke-restore → swap-restore)
USAGE
    exit 1;;
esac
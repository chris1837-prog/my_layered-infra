#!/usr/bin/env bash
set -euo pipefail

# Resolve paths so the script works from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/mvp-compose"

if [[ ! -d "$COMPOSE_DIR" ]]; then
  echo "❌ Can't find mvp-compose directory at: $COMPOSE_DIR"
  exit 1
fi

cd "$COMPOSE_DIR"

echo "🚀 Compose MVP smoke test"

# 0) Bring up (or refresh) the stack
echo "▶️  Starting (or rebuilding) containers..."
docker compose up -d --build

# --- Quick SMOKE target (opt-in) -----------------------------------------
# Usage: ./test-stack.sh smoke
# Does a minimal check:
#   1) wait for PgBouncer to become healthy,
#   2) run SELECT 1 via PgBouncer,
#   3) ensure /health returns 200.
if [[ "${1:-}" == "smoke" ]]; then
  echo "🧪 Running lightweight smoke test..."

  # 1) Wait until PgBouncer container health is 'healthy'
  echo "⏳ Waiting for PgBouncer (container: layered-pgbouncer) to be healthy..."
  for i in {1..30}; do
    status="$(docker inspect -f '{{.State.Health.Status}}' layered-pgbouncer 2>/dev/null || echo 'starting')"
    if [[ "$status" == "healthy" ]]; then
      echo "✅ PgBouncer is healthy"
      break
    fi
    sleep 2
    if [[ "$i" -eq 30 ]]; then
      echo "❌ PgBouncer did not become healthy in time"
      exit 1
    fi
  done

  # 2) Run SELECT 1 via PgBouncer using a one-off postgres client container
  PG_URL="postgresql://${POSTGRES_USER:-myuser}:${POSTGRES_PASSWORD:-mypassword}@pgbouncer:6432/${POSTGRES_DB:-myapp}"
  echo "🔍 Checking DB via PgBouncer (SELECT 1)..."
  docker compose run --rm -T postgres psql "$PG_URL" -c "SELECT 1;" 1>/dev/null
  echo "✅ PgBouncer responded to SQL"

  # 3) Ensure app /health returns 200
  APP_URL="http://localhost:${PORT:-3000}${HEALTH_PATH:-/health}"
  echo "🩺 Checking app health at ${APP_URL} ..."
  for i in {1..30}; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL" || true)"
    if [[ "$code" == "200" ]]; then
      echo "✅ App /health is 200"
      break
    fi
    sleep 2
    if [[ "$i" -eq 30 ]]; then
      echo "❌ App /health did not return 200 in time"
      exit 1
    fi
  done

  echo "🎉 Smoke test passed."
  exit 0
fi
# -------------------------------------------------------------------------

# 1) Wait/poll until the app reports healthy (200 on /health)
APP_URL="http://localhost:${PORT:-3000}${HEALTH_PATH:-/health}"
echo "⏳ Waiting for app health at ${APP_URL} ..."
for i in {1..30}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || true)
  if [[ "$code" == "200" ]]; then
    echo "✅ App is healthy (HTTP 200)"
    break
  fi
  sleep 2
  if [[ "$i" -eq 30 ]]; then
    echo "❌ App did not become healthy in time"
    exit 1
  fi
done

# 2) Verify DB connectivity THROUGH PgBouncer using psql (no local install required)
# We run a one-off postgres container INSIDE the compose network, so service DNS works.
PG_URL="postgresql://${POSTGRES_USER:-myuser}:${POSTGRES_PASSWORD:-mypassword}@pgbouncer:6432/${POSTGRES_DB:-myapp}"
echo "🔍 Checking DB via PgBouncer with psql..."
docker compose run --rm -T postgres psql "$PG_URL" -c "SELECT 'PgBouncer OK' AS status;" 1>/dev/null
echo "✅ PgBouncer responds to SQL (SELECT 1) via psql"

# 3) Simulate DB failure → app /health should go 503
echo "🛑 Stopping Postgres to simulate DB outage..."
docker compose stop postgres
sleep 5

echo "🔁 Poll /health for 503 while DB is down..."
got_503="no"
for i in {1..15}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || true)
  if [[ "$code" == "503" ]]; then
    got_503="yes"
    echo "✅ App reports 503 while DB is down (as expected)"
    break
  fi
  sleep 2
done
if [[ "$got_503" != "yes" ]]; then
  echo "❌ Expected /health to return 503 when DB is down"
  exit 1
fi

# 4) Bring DB back → app should recover to 200
echo "▶️  Restarting Postgres..."
docker compose start postgres

echo "⏳ Waiting for app to recover to 200..."
for i in {1..30}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || true)
  if [[ "$code" == "200" ]]; then
    echo "✅ App recovered to 200 after DB came back"
    break
  fi
  sleep 2
  if [[ "$i" -eq 30 ]]; then
    echo "❌ App did not recover to 200"
    exit 1
  fi
done

# 5) Optional: direct Postgres check (inside network)
DB_URL="postgresql://${POSTGRES_USER:-myuser}:${POSTGRES_PASSWORD:-mypassword}@postgres:5432/${POSTGRES_DB:-myapp}"
echo "🔎 Optional: direct DB check (inside network)..."
docker compose run --rm -T postgres psql "$DB_URL" -c "SELECT version();" 1>/dev/null && \
  echo "✅ Postgres direct check OK"

echo "🎉 Smoke test completed successfully."
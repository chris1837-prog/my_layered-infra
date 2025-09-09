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

# Helpers
APP_URL="http://localhost:${PORT:-3000}${HEALTH_PATH:-/health}"
PG_URL="postgresql://${POSTGRES_USER:-myuser}:${POSTGRES_PASSWORD:-mypassword}@pgbouncer:6432/${POSTGRES_DB:-myapp}"
DB_URL="postgresql://${POSTGRES_USER:-myuser}:${POSTGRES_PASSWORD:-mypassword}@postgres:5432/${POSTGRES_DB:-myapp}"

wait_for_pgbouncer() {
  echo "⏳ Waiting for PgBouncer (container: layered-pgbouncer) to be healthy..."
  for i in {1..30}; do
    status="$(docker inspect -f '{{.State.Health.Status}}' layered-pgbouncer 2>/dev/null || echo 'starting')"
    if [[ "$status" == "healthy" ]]; then
      echo "✅ PgBouncer is healthy"
      return 0
    fi
    sleep 2
  done
  echo "❌ PgBouncer did not become healthy in time"
  return 1
}

wait_for_app_200() {
  local url="${1:-$APP_URL}"
  echo "⏳ Waiting for app health at ${url} ..."
  for i in {1..30}; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"
    if [[ "$code" == "200" ]]; then
      echo "✅ App is healthy (HTTP 200)"
      return 0
    fi
    sleep 2
  done
  echo "❌ App did not become healthy in time"
  return 1
}

pgb_admin() {
  # Runs a PgBouncer admin command via the pgbouncer database
  docker compose exec -T \
    -e PGPASSWORD="${POSTGRES_PASSWORD:-mypassword}" \
    pgbouncer \
    psql -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -p 6432 \
      -U "${POSTGRES_USER:-myuser}" \
      -d pgbouncer \
      -c "$1"
}

# --- Graceful shutdown target (opt-in) -----------------------------------
# Usage: ./test-stack.sh graceful
# Sends SIGTERM to the app, expects a clean shutdown (server + pool closed),
# then brings it back and verifies /health is 200 again.
if [[ "${1:-}" == "graceful" ]]; then
  echo "🧪 Running graceful shutdown test..."
  wait_for_app_200 "$@"

  echo "🧹 Clearing recent app logs window (for clean assertions)..."
  docker compose logs --since=0 app >/dev/null 2>&1 || true

  echo "🛑 Sending SIGTERM to app..."
  docker compose kill -s SIGTERM app

  echo "⏳ Waiting for container to exit..."
  for i in {1..20}; do
    state="$(docker inspect -f '{{.State.Status}}' layered-app 2>/dev/null || echo 'exited')"
    if [[ "$state" == "exited" ]]; then
      echo "✅ App container exited on SIGTERM"
      break
    fi
    sleep 1
    if [[ "$i" -eq 20 ]]; then
      echo "❌ App did not exit after SIGTERM"
      exit 1
    fi
  done

  echo "▶️  Starting app again..."
  docker compose up -d app

  wait_for_app_200 "$@"

  echo "🔎 Checking logs for graceful shutdown markers..."
  logs="$(docker compose logs --since=2m app | tail -n 200 || true)"
  echo "$logs" | grep -q "Received shutdown signal" || { echo "❌ Missing 'Received shutdown signal' log"; exit 1; }
  echo "$logs" | grep -q "HTTP server closed" || { echo "❌ Missing 'HTTP server closed' log"; exit 1; }
  echo "$logs" | grep -q "Database pool closed" || { echo "❌ Missing 'Database pool closed' log"; exit 1; }

  echo "🎉 Graceful shutdown test passed."
  exit 0
fi
# -------------------------------------------------------------------------

echo "🚀 Compose MVP smoke test"

# 0) Bring up (or refresh) the stack
echo "▶️  Starting (or rebuilding) containers..."
docker compose up -d --build

# --- Quick SMOKE target (opt-in) -----------------------------------------
# Usage: ./test-stack.sh smoke
# Does a minimal check:
#   1) wait for PgBouncer to become healthy,
#   2) run SELECT 1 via PgBouncer,
#   3) ensure /health returns 200,
#   4) verify PgBouncer pools/stats can be queried.
if [[ "${1:-}" == "smoke" ]]; then
  echo "🧪 Running lightweight smoke test..."

  # 1) Wait until PgBouncer container health is 'healthy'
  wait_for_pgbouncer

  # 2) Run SELECT 1 via PgBouncer using a one-off postgres client container
  echo "🔍 Checking DB via PgBouncer (SELECT 1)..."
  docker compose run --rm -T postgres psql "$PG_URL" -c "SELECT 1;" 1>/dev/null
  echo "✅ PgBouncer responded to SQL"

  # 3) Ensure app /health returns 200
  echo "🩺 Checking app health..."
  wait_for_app_200 "$@"

  echo "🧾 PgBouncer admin visibility (SHOW POOLS; SHOW STATS;)..."
  pgb_admin "SHOW POOLS;" 1>/dev/null
  pgb_admin "SHOW STATS;" 1>/dev/null
  echo "✅ PgBouncer admin commands accessible"

  echo "🎉 Smoke test passed."
  exit 0
fi
# -------------------------------------------------------------------------

# 1) Wait/poll until the app reports healthy (200 on /health)
wait_for_app_200 "$@"

# 2) Verify DB connectivity THROUGH PgBouncer using psql (no local install required)
# We run a one-off postgres container INSIDE the compose network, so service DNS works.
echo "🔍 Checking DB via PgBouncer with psql..."
docker compose run --rm -T postgres psql "$PG_URL" -c "SELECT 'PgBouncer OK' AS status;" 1>/dev/null
echo "✅ PgBouncer responds to SQL (SELECT 1) via psql"

echo "🧾 PgBouncer admin visibility (SHOW POOLS; SHOW STATS;)..."
pgb_admin "SHOW POOLS;" 1>/dev/null
pgb_admin "SHOW STATS;" 1>/dev/null
echo "✅ PgBouncer admin commands accessible"

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
echo "🔎 Optional: direct DB check (inside network)..."
docker compose run --rm -T postgres psql "$DB_URL" -c "SELECT version();" 1>/dev/null && \
  echo "✅ Postgres direct check OK"

echo "🎉 Smoke test completed successfully."
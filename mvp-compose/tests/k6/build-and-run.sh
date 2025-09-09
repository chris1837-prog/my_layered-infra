#!/usr/bin/env bash
set -euo pipefail

# --- Where this script lives (so it works from anywhere) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Versions you can override via env ---
: "${K6_VER:=v0.51.0}"
: "${XK6_SQL_REF:=v1.0.5}"
: "${XK6_SQL_PG_REF:=v0.1.1}"     # NOTE: driver tag is 0.1.x, not 1.0.x

# --- Image/tag (override if you want) ---
: "${K6_IMAGE_NAME:=local/xk6-sql:${K6_VER}-${XK6_SQL_REF}}"

# --- Test params (override via env) ---
: "${VUS:=10}"
: "${DURATION:=30s}"
: "${RPS:=0}"
: "${MAX_LATENCY_P90_MS:=200}"
: "${ERROR_RATE_MAX:=0.01}"
: "${K6_LOG_LEVEL:=info}"
: "${SCRIPT:=/scripts/pgbouncer_pooling.js}"  # or /scripts/open_smoke.js

# --- Required: connection string ---
if [[ -z "${CONN_STR:-}" ]]; then
  echo "Error: CONN_STR is not set."
  echo "Example:"
  echo "  CONN_STR='postgres://myuser:mypassword@pgbouncer:6432/myapp?sslmode=disable' \\"
  echo "    $0"
  exit 1
fi

echo "🔨 Building k6 image '${K6_IMAGE_NAME}' (k6=${K6_VER}, xk6-sql=${XK6_SQL_REF}, pg-driver=${XK6_SQL_PG_REF})..."
docker build \
  --build-arg K6_VER="${K6_VER}" \
  --build-arg XK6_SQL_REF="${XK6_SQL_REF}" \
  --build-arg XK6_SQL_PG_REF="${XK6_SQL_PG_REF}" \
  -t "${K6_IMAGE_NAME}" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  "${SCRIPT_DIR}"

echo "🔎 Selecting network if available…"
NETWORK_ARG=()
if docker network inspect mvp-compose_app-network >/dev/null 2>&1; then
  NETWORK_ARG=(--network mvp-compose_app-network)
  echo "   ✔ using --network mvp-compose_app-network"
else
  echo "   ⚠ no 'mvp-compose_app-network'; running without a custom Docker network"
fi

echo "🏃 Running '${SCRIPT}' with VUS=${VUS}, DURATION=${DURATION}, RPS=${RPS}…"
docker run --rm -it \
  "${NETWORK_ARG[@]}" \
  -v "${SCRIPT_DIR}:/scripts" \
  -e CONN_STR="${CONN_STR}" \
  -e VUS="${VUS}" \
  -e DURATION="${DURATION}" \
  -e RPS="${RPS}" \
  -e MAX_LATENCY_P90_MS="${MAX_LATENCY_P90_MS}" \
  -e ERROR_RATE_MAX="${ERROR_RATE_MAX}" \
  -e K6_LOG_LEVEL="${K6_LOG_LEVEL}" \
  "${K6_IMAGE_NAME}" run "${SCRIPT}"
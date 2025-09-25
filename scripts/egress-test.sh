#!/bin/bash
#
# Egress connectivity smoke test
# - DNS resolution (dig)
# - HTTPS reachability (curl)
# - Package repo reachability (curl)
#
# Environment overrides:
#   DNS_HOST=example.com
#   HTTPS_URL=https://example.com
#   PACKAGE_REPO_URL=http://deb.debian.org/debian/dists/stable/Release
#
set -euo pipefail

# -------- Defaults (can be overridden by env) --------
DNS_HOST="${DNS_HOST:-google.com}"
HTTPS_URL="${HTTPS_URL:-https://www.google.com}"
PACKAGE_REPO_URL="${PACKAGE_REPO_URL:-http://deb.debian.org/debian/dists/stable/Release}"

# Curl / dig timeouts (seconds)
CURL_MAX_TIME="${CURL_MAX_TIME:-10}"
DIG_TIMEOUT="${DIG_TIMEOUT:-5}"

# -------- Dependency checks --------
need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 127
  }
}
need curl
need jq
need dig

results_json="{}"
exit_code=0

# -------- DNS Test --------
dns_ip="$(dig +short +time="${DIG_TIMEOUT}" "${DNS_HOST}" 2>/dev/null | head -n1 || true)"
if [[ -n "${dns_ip}" ]]; then
  dns_status="success"
  results_json=$(echo "${results_json}" \
    | jq --arg status "${dns_status}" --arg ip "${dns_ip}" '.dns = { "status": $status, "ip": $ip }')
else
  dns_status="failure"
  exit_code=1
  results_json=$(echo "${results_json}" \
    | jq --arg status "${dns_status}" '.dns = { "status": $status }')
fi

# -------- HTTPS Test --------
if curl --silent --location --head --fail --max-time "${CURL_MAX_TIME}" "${HTTPS_URL}" >/dev/null 2>&1; then
  https_status="success"
else
  https_status="failure"
  exit_code=1
fi
results_json=$(echo "${results_json}" \
  | jq --arg status "${https_status}" --arg url "${HTTPS_URL}" '.https = { "status": $status, "url": $url }')

# -------- Package Repo Test --------
if curl --silent --location --fail --max-time "${CURL_MAX_TIME}" "${PACKAGE_REPO_URL}" >/dev/null 2>&1; then
  package_status="success"
else
  package_status="failure"
  exit_code=1
fi
results_json=$(echo "${results_json}" \
  | jq --arg status "${package_status}" --arg url "${PACKAGE_REPO_URL}" '.package_repo = { "status": $status, "url": $url }')

# -------- Output --------
echo "${results_json}" | jq .
exit "${exit_code}"

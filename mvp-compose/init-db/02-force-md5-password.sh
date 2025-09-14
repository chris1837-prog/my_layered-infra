#!/usr/bin/env bash
set -euo pipefail

# This runs only on first init of the Postgres data directory.
# It forces the app user password to be stored as MD5 (compatible with PgBouncer md5 auth).
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-SQL
  SET password_encryption = 'md5';
  ALTER ROLE "${POSTGRES_USER}" PASSWORD '${POSTGRES_PASSWORD}';
SQL

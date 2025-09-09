# Database Load Testing (k6 + xk6-sql)

This folder provides smoke tests and load tests for the local stack (App → PgBouncer → Postgres) using [k6](https://k6.io) with the [xk6-sql](https://github.com/grafana/xk6-sql) extension.

## Contents
- **Dockerfile** – builds a custom k6 binary with the SQL extension and Postgres driver
- **build-and-run.sh** – helper script to build the image and run a test in one step
- **open_smoke.js** – quick connection test against PgBouncer
- **pgbouncer_pooling.js** – main pooling and throughput test

## Getting started

1. Make sure the local Compose stack is running:

   ```bash
   cd mvp-compose
   docker-compose up -d
   ```

2. Export the Postgres connection string (must point to PgBouncer):

   ```bash
   export CONN_STR='postgres://myuser:mypassword@pgbouncer:6432/myapp?sslmode=disable'
   ```

3. Run a smoke test:

   ```bash
   tests/k6/build-and-run.sh SCRIPT=/scripts/open_smoke.js
   ```

   This checks if the connection works.

4. Run a baseline pooling test:

   ```bash
   tests/k6/build-and-run.sh
   ```

   By default this runs **10 VUs for 30s**.

## Parameters

You can override defaults with environment variables:

- `CONN_STR` (**required**) – Postgres DSN (via PgBouncer)
- `VUS` – number of virtual users (default: `10`)
- `DURATION` – test duration (default: `30s`)
- `RPS` – requests per second (default: `0` = unlimited)
- `SCRIPT` – test script to run (default: `/scripts/pgbouncer_pooling.js`)
- `K6_SUMMARY_EXPORT` – optional path inside container for JSON summary (e.g. `/scripts/out.json`)

## Example runs

- **Smoke test (1 query):**

  ```bash
  tests/k6/build-and-run.sh SCRIPT=/scripts/open_smoke.js
  ```

- **Stress test (50 VUs, 120s, 500 RPS):**

  ```bash
  VUS=50 DURATION=120s RPS=500 tests/k6/build-and-run.sh
  ```

- **High load (200 VUs, 2m, 500 RPS):**

  ```bash
  VUS=200 DURATION=120s RPS=500 tests/k6/build-and-run.sh
  ```

## Results

Each run prints a summary of:
- `db_error_rate` – should stay below `1%`
- `db_latency{step:query}` – p90 target `<200ms`
- Throughput (`db_ops`, iterations/sec)

Optionally export results to JSON:

```bash
K6_SUMMARY_EXPORT=/scripts/out.json tests/k6/build-and-run.sh
```

---

📌 For project-level setup and workflows, see the [root README.md](../../README.md).

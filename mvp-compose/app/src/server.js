// Minimal app with health endpoints and DB readiness (PgBouncer later)

const express = require('express');
const { Pool } = require('pg');

const app = express();

const PORT = Number(process.env.PORT || 3000);
const MAX_RETRIES = Number(process.env.DB_CONNECT_MAX_RETRIES || 20);
const BASE_DELAY_MS = Number(process.env.DB_CONNECT_BASE_DELAY_MS || 500);

// Build DATABASE_URL from either DATABASE_URL or DB_* parts (Compose-friendly)
const DB_HOST = process.env.DB_HOST;
const DB_PORT = process.env.DB_PORT || '6432';
const DB_NAME = process.env.DB_NAME || 'myapp';
const DB_USER = process.env.DB_USER || 'myuser';
const DB_PASSWORD = process.env.DB_PASSWORD || 'mypassword';

const DATABASE_URL =
  process.env.DATABASE_URL ||
  (DB_HOST
    ? `postgresql://${encodeURIComponent(DB_USER)}:${encodeURIComponent(DB_PASSWORD)}@${DB_HOST}:${DB_PORT}/${encodeURIComponent(DB_NAME)}`
    : null);

// IMPORTANT: create a pool ONLY if DB config exists
let pool = null;
if (DATABASE_URL) {
  pool = new Pool({
    connectionString: DATABASE_URL,
    max: 5,
    idleTimeoutMillis: 30000,
  });
} else {
  console.warn('[app] No DB config (DATABASE_URL nor DB_*). /health and /readyz will return 503.');
}

let dbReady = false;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
function backoffDelay(i) {
  // exponential backoff with a cap ~30s
  return Math.min(BASE_DELAY_MS * Math.pow(2, i), 30000);
}

// Background readiness probing (only when pool exists)
(async function primeDbConnectivity() {
  if (!pool) return;

  // Initial retries to establish connectivity
  let attempt = 0;
  while (attempt < MAX_RETRIES) {
    try {
      const client = await pool.connect();
      await client.query('SELECT 1');
      client.release();
      dbReady = true;
      console.log('[app] Initial DB connectivity established.');
      break;
    } catch (err) {
      dbReady = false;
      const delay = backoffDelay(attempt);
      console.warn(
        `[app] DB connect failed (try ${attempt + 1}/${MAX_RETRIES}): ${err.message}. Retrying in ${delay}ms`
      );
      await sleep(delay);
      attempt++;
    }
  }

  // Periodic probe to keep readiness fresh (does not exit on failure)
  while (true) {
    try {
      await pool.query('SELECT 1');
      dbReady = true;
    } catch (err) {
      dbReady = false;
      console.warn(`[app] Periodic DB probe failed: ${err.message}`);
    }
    await sleep(10000); // every 10s
  }
})().catch((e) => console.error('[app] Unexpected DB init error:', e));

// Routes

// Proof the app runs (no DB required)
app.get('/', (_req, res) => res.status(200).send('ok'));

// Liveness: process up = 200 (no DB required)
app.get('/healthz', (_req, res) => res.status(200).json({ ok: true }));

// Readiness: 200 only if DB SELECT 1 succeeds; 503 without DB config
app.get('/readyz', async (_req, res) => {
  if (!pool) return res.status(503).json({ ready: false, reason: 'NO_DB_CONFIG' });
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ ready: true });
  } catch {
    return res.status(503).json({ ready: false });
  }
});

// DB-based health for Compose healthcheck
app.get('/health', async (_req, res) => {
  if (!pool) return res.status(503).json({ status: 'unhealthy', reason: 'NO_DB_CONFIG' });
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ status: 'ok' });
  } catch {
    return res.status(503).json({ status: 'unhealthy' });
  }
});

// Graceful shutdown: close DB pool when the container receives a stop signal
process.on('SIGTERM', async () => {
  try { await pool?.end(); }
  finally { process.exit(0); }
});
process.on('SIGINT', async () => {
  try { await pool?.end(); }
  finally { process.exit(0); }
});

// Start server
app.listen(PORT, () => {
  console.log(`[app] Listening on ${PORT}`);
});

// Minimal app with health endpoints and DB readiness (PgBouncer later)

const express = require('express');
const { Pool } = require('pg');

const app = express();

const PORT = Number(process.env.PORT || 3000);
const DATABASE_URL = process.env.DATABASE_URL; // will later point to PgBouncer:6432
const MAX_RETRIES = Number(process.env.DB_CONNECT_MAX_RETRIES || 20);
const BASE_DELAY_MS = Number(process.env.DB_CONNECT_BASE_DELAY_MS || 500);

// IMPORTANT: create a pool ONLY if DATABASE_URL is provided
let pool = null;
if (DATABASE_URL) {
  pool = new Pool({
    connectionString: DATABASE_URL,
    max: 5,
    idleTimeoutMillis: 30000,
  });
} else {
  console.warn('[app] DATABASE_URL is not set. /readyz will return 503 until set.');
}

let dbReady = false;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
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
app.get('/', (_req, res) => {
  // Proof the app runs (no DB required)
  res.status(200).send('ok');
});

// Liveness: process up = 200 (no DB required)
app.get('/healthz', (_req, res) => {
  res.status(200).json({ ok: true });
});

// Readiness: 200 only if a SELECT 1 via DB succeeds; 503 when missing or failing
app.get('/readyz', async (_req, res) => {
  if (!pool) {
    return res.status(503).json({ ready: false, reason: 'NO_DATABASE_URL' });
  }
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ ready: true });
  } catch (_err) {
    return res.status(503).json({ ready: false });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`[app] Listening on ${PORT}`);
});
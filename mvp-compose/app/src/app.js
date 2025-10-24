
const client = require('prom-client');
client.collectDefaultMetrics();
const express = require('express');
const logger = require('./logger');
const { Pool } = require('pg');

const app = express();

const MAX_RETRIES = Number(process.env.DB_CONNECT_MAX_RETRIES || 20);
const BASE_DELAY_MS = Number(process.env.DB_CONNECT_BASE_DELAY_MS || 500);

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

let pool = null;
if (DATABASE_URL) {
  pool = new Pool({
    connectionString: DATABASE_URL,
    max: Number(process.env.PGPOOL_MAX || 5),
    idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT || 30000),
    connectionTimeoutMillis: Number(process.env.PG_CONNECT_TIMEOUT || 5000),
  });
  pool.on('connect', async (client) => {
    const st = Number(process.env.PG_STATEMENT_TIMEOUT || 0);
    if (st > 0) {
      try {
        await client.query('SET statement_timeout TO $1', [st]);
      } catch (e) {

        logger.warn({ err: e.message }, 'Failed to SET statement_timeout on connect');

      }
    }
  });
} else {
  logger.warn('No DB config. /health and /readyz will return 503.');
}

function backoffDelay(i) {
  return Math.min(BASE_DELAY_MS * Math.pow(2, i), 30000);
}
if (process.env.JEST_WORKER_ID === undefined) {

  (async function primeDbConnectivity() {
    if (!pool) return;
    let attempt = 0;
    while (attempt < MAX_RETRIES) {
      try {
        const client = await pool.connect();
        await client.query('SELECT 1');
        client.release();
        logger.info('Initial DB connectivity established.');
        break;
      } catch (err) {
        const delay = backoffDelay(attempt);
        logger.warn({ err: err.message, attempt: attempt + 1, max: MAX_RETRIES, delay }, 'DB connect failed, retrying');
        await new Promise((res) => setTimeout(res, delay));
        attempt++;
      }
    }
    // periodic probe
    while (true) {
      try {
        await pool.query('SELECT 1');
      } catch (err) {
        logger.warn({ err: err.message }, 'Periodic DB probe failed');
      }
      await new Promise((res) => setTimeout(res, 10000));
    }
  })().catch((e) => logger.error({ err: e.message }, 'Unexpected DB init error'));

}

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
app.get('/', (_req, res) => res.status(200).send('ok'));
app.get('/healthz', (_req, res) => res.status(200).json({ ok: true }));
app.get('/readyz', async (_req, res) => {
  if (!pool) return res.status(503).json({ ready: false, reason: 'NO_DB_CONFIG' });
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ ready: true });
  } catch (err) {
    logger.error({ err }, 'Readiness check database query failed');
    return res.status(503).json({ ready: false });
  }
});
app.get('/health', async (_req, res) => {
  if (!pool) return res.status(503).json({ status: 'unhealthy', reason: 'NO_DB_CONFIG' });
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ status: 'ok' });
  } catch (err) {
    logger.error({ err }, 'Health check database query failed');
    return res.status(503).json({ status: 'unhealthy' });
  }
});

module.exports = { app, pool, backoffDelay };
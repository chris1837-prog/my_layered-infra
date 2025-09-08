// k6 + xk6-sql (postgres driver) workload that targets PgBouncer (transaction pooling).
//
// ENV VARS:
//   CONN_STR="postgres://myuser:mypassword@pgbouncer:6432/myapp?sslmode=disable"
//   QUERY="SELECT 1;"                         (optional)
//   TX_SLEEP_MS="0"                           (optional artificial delay inside tx)
//   VUS="20" DURATION="60s" RPS="0"
//   MAX_LATENCY_P90_MS="200" ERROR_RATE_MAX="0.01"

import { sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import sql from 'k6/x/sql';
import pg from 'k6/x/sql/driver/postgres';

const CONN_STR = __ENV.CONN_STR || 'postgres://myuser:mypassword@pgbouncer:6432/myapp?sslmode=disable';
const QUERY = __ENV.QUERY || 'SELECT 1;';
const TX_SLEEP_MS = Number(__ENV.TX_SLEEP_MS || '0');

const VUS = Number(__ENV.VUS || '20');
const DURATION = __ENV.DURATION || '60s';
const RPS = Number(__ENV.RPS || '0');

const MAX_LAT_P90 = Number(__ENV.MAX_LATENCY_P90_MS || '200');
const ERROR_RATE_MAX = Number(__ENV.ERROR_RATE_MAX || '0.01');

export const options = RPS > 0
  ? {
      scenarios: {
        rate_based: {
          executor: 'ramping-arrival-rate',
          startRate: Math.max(1, Math.floor(RPS / 2)),
          timeUnit: '1s',
          preAllocatedVUs: Math.max(10, VUS),
          maxVUs: Math.max(50, VUS * 2),
          stages: [
            { target: RPS, duration: '30s' },
            { target: RPS, duration: DURATION },
            { target: 0,   duration: '10s' },
          ],
        },
      },
      thresholds: {
        'db_latency{step:query}': [`p(90)<${MAX_LAT_P90}`],
        'db_error_rate': [`rate<${ERROR_RATE_MAX}`],
      },
    }
  : {
      vus: VUS,
      duration: DURATION,
      thresholds: {
        'db_latency{step:query}': [`p(90)<${MAX_LAT_P90}`],
        'db_error_rate': [`rate<${ERROR_RATE_MAX}`],
      },
    };

const dbLatency = new Trend('db_latency', true);
const dbErrors  = new Rate('db_error_rate');
const dbOps     = new Counter('db_ops');

// Open once, per VU (k6 will clone this for each VU)
const db = sql.open(pg, CONN_STR);

export default function () {
  try {
    timeIt('query', () => {
      db.exec('BEGIN'); // explicit short transaction for pool_mode=transaction
      if (TX_SLEEP_MS > 0) {
        db.exec(`SELECT pg_sleep(${TX_SLEEP_MS}/1000.0)`);
      }
      db.exec(QUERY);
      db.exec('COMMIT');
    });
    dbOps.add(1);
  } catch (e) {
    dbErrors.add(1);
    dbLatency.add(10_000, { step: 'query' }); // big datapoint for visibility
    throw e;
  }
  sleep(0.01);
}

export function teardown() {
  try { db.close(); } catch (_) {}
}

function timeIt(step, fn) {
  const t0 = Date.now();
  const res = fn();
  const t1 = Date.now();
  dbLatency.add(t1 - t0, { step });
  return res;
}
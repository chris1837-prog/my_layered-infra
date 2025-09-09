import sql from 'k6/x/sql';
// IMPORTANT: import the Postgres driver object and pass it to sql.open()
import pg from 'k6/x/sql/driver/postgres';

const CONN_STR = __ENV.CONN_STR || 'postgres://myuser:mypassword@pgbouncer:6432/myapp?sslmode=disable';

export default function () {
  // driver object first, then the DSN
  const db = sql.open(pg, CONN_STR);
  try {
    // trivial query just to prove the pipeline works end-to-end
    db.exec('SELECT 1;');
  } finally {
    db.close();
  }
}
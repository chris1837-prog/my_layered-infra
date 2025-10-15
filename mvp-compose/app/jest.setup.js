const { pool } = require('./src/app');


afterAll(async () => {
  if (pool) {
    await pool.end();
  }
});
const { app, pool } = require('./app');

const PORT = Number(process.env.PORT || 3000);

const server = app.listen(PORT, () => {
  console.log(`[app] Listening on ${PORT}`);
});

function gracefulShutdown() {
  console.log('[app] Received shutdown signal, closing server gracefully.');
  server.close(async () => {
    console.log('[app] HTTP server closed.');
    if (pool) {
      try {
        await pool.end();
        console.log('[app] Database pool closed.');
      } catch (e) {
        console.error('[app] Error closing database pool:', e.message);
      }
    }
    process.exit(0);
  });

  setTimeout(() => {
    console.error('[app] Could not close connections in time, forcing shutdown.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);
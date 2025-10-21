const { app, pool} = require('./app');
const logger = require('./logger');

const PORT = Number(process.env.PORT || 3000);

const server = app.listen(PORT, () => {
  logger.info({ port: PORT }, 'App listening');
});

function gracefulShutdown() {
  logger.info('Received shutdown signal, closing server gracefully.');
  server.close(async () => {
    logger.info('HTTP server closed.');
    if (pool) {
      try {
        await pool.end();
        logger.info('Database pool closed.');
      } catch (e) {
        logger.error({ err: e.message }, 'Error closing database pool');
      }
    }
    process.exit(0);
  });

  setTimeout(() => {
    logger.error('Could not close connections in time, forcing shutdown.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);


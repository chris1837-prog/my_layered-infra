const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: { service_name: 'layered-infra' },
  formatters: {
    level(label) {
      return { log_level: label };
    },
  },
  timestamp: () => `,"timestamp":"${new Date().toISOString()}"`,
});

module.exports = logger;


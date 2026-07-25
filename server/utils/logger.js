// server/utils/logger.js
// ─────────────────────────────────────────────────
// Winston structured logger.
// - Logs to console (always)
// - Logs to logs/error.log (errors only)
// - Logs to logs/combined.log (all levels)
// ─────────────────────────────────────────────────
const { createLogger, format, transports } = require('winston');
const { NODE_ENV } = require('../config/env');

const { combine, timestamp, printf, colorize, errors } = format;

// Custom log format for console output
const consoleFormat = printf(({ level, message, timestamp, stack }) => {
  return `${timestamp} [${level}]: ${stack || message}`;
});

const logger = createLogger({
  level: NODE_ENV === 'production' ? 'info' : 'debug',
  format: combine(
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    errors({ stack: true }),
    format.json()
  ),
  transports: [
    // Console transport with colors in development
    new transports.Console({
      format: combine(
        colorize(),
        timestamp({ format: 'HH:mm:ss' }),
        consoleFormat
      ),
    }),
  ],
});

// In production, also write to log files
if (NODE_ENV === 'production') {
  logger.add(new transports.File({ filename: 'logs/error.log', level: 'error' }));
  logger.add(new transports.File({ filename: 'logs/combined.log' }));
}

module.exports = logger;

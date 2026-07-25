// server/middleware/error.middleware.js
// ─────────────────────────────────────────────────
// Global Error Handler
//
// Must be registered LAST in the Express middleware
// chain (after all routes).
//
// Catches:
//   - Unhandled route errors (thrown inside controllers)
//   - 404 Not Found for unknown routes
// ─────────────────────────────────────────────────
const logger = require('../utils/logger');
const { NODE_ENV } = require('../config/env');

/**
 * 404 Not Found handler — catches requests to unknown routes.
 * Register BEFORE the error handler.
 */
const notFound = (req, res, next) => {
  const error = new Error(`Route not found: ${req.method} ${req.originalUrl}`);
  error.statusCode = 404;
  next(error);
};

/**
 * Global error handler — catches all errors passed via next(err).
 * Returns structured JSON error response.
 * Must be registered LAST (4 arguments signature required by Express).
 */
// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  const statusCode = err.statusCode || err.status || 500;
  const isProduction = NODE_ENV === 'production';

  // Log all 5xx errors as errors, 4xx as warnings
  if (statusCode >= 500) {
    logger.error(`[ERROR] ${statusCode} ${req.method} ${req.path}`, {
      message: err.message,
      stack: err.stack,
    });
  } else {
    logger.warn(`[WARN] ${statusCode} ${req.method} ${req.path}: ${err.message}`);
  }

  return res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal server error',
    // Only expose stack trace in development
    ...(isProduction ? {} : { stack: err.stack }),
  });
};

module.exports = { notFound, errorHandler };

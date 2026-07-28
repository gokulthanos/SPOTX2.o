// server/index.js
// ─────────────────────────────────────────────────
// SpotX 5.0 — Entry Point
// Urban Transit MVP
// ─────────────────────────────────────────────────
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { PORT, CORS_ORIGIN, NODE_ENV } = require('./config/env');
const { initDB, createTables } = require('./db');
const logger = require('./utils/logger');
const { notFound, errorHandler } = require('./middleware/error.middleware');

// Routes
const authRouter = require('./routes/auth.routes');
const busRouter = require('./routes/bus.routes');
const ticketRouter = require('./routes/ticket.routes');
const paymentRouter = require('./routes/payment.routes');
const conductorRouter = require('./routes/conductor.routes');

// Seed
const { seed } = require('./seed-demo');

const app = express();

// Security Middleware
const {
  sanitizeInput,
  requestSizeLimiter,
  sqlInjectionGuard,
  securityHeaders,
  bruteForceProtection,
} = require('./middleware/security.middleware');

// Global Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: false,
}));
app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    const allowed = CORS_ORIGIN.some(o => {
      if (o.includes('*')) {
        const pattern = o.replace(/\*/g, '.*');
        return new RegExp(`^${pattern}$`).test(origin);
      }
      return o === origin;
    });
    if (NODE_ENV !== 'production' || allowed) {
      return callback(null, true);
    }
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined', { stream: { write: (message) => logger.info(message.trim()) } }));

// Security layers
app.use(securityHeaders);
app.use(sanitizeInput);
app.use(sqlInjectionGuard);
app.use(requestSizeLimiter(1024));
app.use(bruteForceProtection);

// Health Check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '5.0.0',
    environment: NODE_ENV,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// API v1 Routes
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/buses', busRouter);
app.use('/api/v1/tickets', ticketRouter);
app.use('/api/v1/payments', paymentRouter);
app.use('/api/v1/conductor', conductorRouter);

// Global Error Handlers
app.use(notFound);
app.use(errorHandler);

// Start Server
async function start() {
  try {
    await initDB();
    await createTables();
    await seed();

    app.listen(PORT, () => {
      logger.info(`\n  ╔══════════════════════════════════════════╗`);
      logger.info(`  ║   SPOTX 5.0 Server — Urban Transit MVP  ║`);
      logger.info(`  ╠══════════════════════════════════════════╣`);
      logger.info(`  ║  HTTP:  http://localhost:${PORT}            ║`);
      logger.info(`  ║  API:   http://localhost:${PORT}/api/v1     ║`);
      logger.info(`  ║  Health: http://localhost:${PORT}/health    ║`);
      logger.info(`  ╠══════════════════════════════════════════╣`);
      logger.info(`  ║  Demo conductors:                        ║`);
      logger.info(`  ║  conductor1 / pass123                    ║`);
      logger.info(`  ║  conductor2 / pass123                    ║`);
      logger.info(`  ╚══════════════════════════════════════════╝\n`);
    });
  } catch (err) {
    logger.error('Failed to start server:', err);
    process.exit(1);
  }
}

start();

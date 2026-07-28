// server/index.js
// ─────────────────────────────────────────────────
// SpotX 4.0 — Entry Point
// Production-ready with Real-Time GPS, Driver App,
// Analytics, SMS, FCM, and more
// ─────────────────────────────────────────────────
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const { PORT, CORS_ORIGIN, NODE_ENV } = require('./config/env');
const { initDB, createTables } = require('./db');
const logger = require('./utils/logger');
const { notFound, errorHandler } = require('./middleware/error.middleware');

// Routes
const authRouter = require('./routes/auth.routes');
const busRouter = require('./routes/bus.routes');
const ticketRouter = require('./routes/ticket.routes');
const paymentRouter = require('./routes/payment.routes');
const adminRouter = require('./routes/admin.routes');
const smartRouter = require('./routes/smart.routes');
const driverRouter = require('./routes/driver.routes');
const analyticsRouter = require('./routes/analytics.routes');

// Controllers for compatibility redirects
const authController = require('./controllers/auth.controller');
const busController = require('./controllers/bus.controller');
const ticketController = require('./controllers/ticket.controller');

// Services
const { initFCM } = require('./services/fcm.service');

const app = express();
const httpServer = http.createServer(app);

// Security Middleware
const {
  sanitizeInput,
  requestSizeLimiter,
  auditLogger,
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
    // Allow requests with no origin (mobile apps, curl, server-to-server)
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
app.use(requestSizeLimiter(1024)); // 1MB max
app.use(auditLogger);
app.use(bruteForceProtection);

// Performance: Cache headers + in-memory response cache for public endpoints
const { responseCache, etagSupport } = require('./middleware/cache.middleware');
app.use(etagSupport());
app.use('/api/v1/buses', responseCache(30000));    // 30s cache for bus listings
app.use('/api/v1/smart', responseCache(15000));    // 15s cache for smart features
app.use('/api/v1/admin/stops', responseCache(60000)); // 60s cache for static data
app.use('/api/v1/admin/cities', responseCache(60000));

// Rate limiting headers
app.use((req, res, next) => {
  res.setHeader('X-Powered-By', 'SpotX-4.0');
  next();
});

// Health Check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '4.0.0',
    environment: NODE_ENV,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// API Info
app.get('/api', (req, res) => {
  res.json({
    name: 'SpotX Transit API',
    version: '4.0.0',
    docs: '/api/docs',
    endpoints: {
      auth: '/api/v1/auth',
      buses: '/api/v1/buses',
      tickets: '/api/v1/tickets',
      payments: '/api/v1/payments',
      admin: '/api/v1/admin',
      smart: '/api/v1/smart',
      driver: '/api/v1/driver',
      analytics: '/api/v1/analytics',
    },
  });
});

// ─── Modern API Version 1 ────────────────────────
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/buses', busRouter);
app.use('/api/v1/tickets', ticketRouter);
app.use('/api/v1/payments', paymentRouter);
app.use('/api/v1/admin', adminRouter);
app.use('/api/v1/smart', smartRouter);
app.use('/api/v1/driver', driverRouter);
app.use('/api/v1/analytics', analyticsRouter);

// ─── Backward Compatibility Layer (SpotX 2.0 Client support) ───
// These ensure existing, un-upgraded client apps continue functioning
app.post('/api/passenger/request-otp', authController.requestOtp);
app.post('/api/passenger/verify-otp', authController.verifyOtp);
app.post('/api/passenger/set-password', authController.setPassword);
app.post('/api/passenger/login', authController.passengerLogin);
app.post('/api/users/login', authController.officerLogin);
app.post('/api/users/register', authController.registerOfficer);
app.post('/api/v1/officer/login', authController.officerLogin);

app.get('/api/buses', busController.getBuses);
app.get('/api/buses/:id', busController.getBusById);

app.post('/api/tickets', ticketController.bookTicket);
app.get('/api/tickets/:ticketNumber', ticketController.getTicket);

// Seed database on startup
async function seedDatabase() {
  const { getOne, run } = require('./db');
  const count = await getOne('SELECT COUNT(*) as c FROM buses');
  if (count && count.c > 0) {
    logger.info(`[SEED] Database already has ${count.c} buses — skipping basic seed`);
    return;
  }

  logger.info('[SEED] Seeding database with initial cities, stops, routes, and buses...');

  // Seed Cities
  await run("INSERT IGNORE INTO cities (id, name, state, lat, lon) VALUES (1, 'Chennai', 'Tamil Nadu', 13.0827, 80.2707)");
  await run("INSERT IGNORE INTO cities (id, name, state, lat, lon) VALUES (2, 'Madurai', 'Tamil Nadu', 9.9252, 78.1198)");

  // Seed Stops
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (1, 'Chennai CMBT', 1, 13.0674, 80.2078, 'terminus')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (2, 'Villupuram Bus Stand', 1, 11.9401, 79.4975, 'stop')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (3, 'Trichy Central Bus Stand', 1, 10.7905, 78.7047, 'stop')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (4, 'Madurai Mattuthavani', 2, 9.9252, 78.1198, 'terminus')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (5, 'Mahabalipuram Stop', 1, 12.6269, 80.1927, 'stop')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (6, 'Pondicherry Bus Stand', 1, 11.9416, 79.8083, 'terminus')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (7, 'Kanchipuram Stop', 1, 12.8387, 79.7016, 'stop')");
  await run("INSERT IGNORE INTO stops (id, name, city_id, lat, lon, stop_type) VALUES (8, 'Vellore Bus Stand', 1, 12.9165, 79.1325, 'terminus')");

  // Seed Routes
  await run("INSERT IGNORE INTO routes (id, route_number, name, from_stop_id, to_stop_id, distance_km, base_fare) VALUES (1, 'R-101', 'Chennai - Madurai Express', 1, 4, 460, 120)");
  await run("INSERT IGNORE INTO routes (id, route_number, name, from_stop_id, to_stop_id, distance_km, base_fare) VALUES (2, 'R-102', 'Chennai - Pondicherry Coastal', 1, 6, 151, 85)");
  await run("INSERT IGNORE INTO routes (id, route_number, name, from_stop_id, to_stop_id, distance_km, base_fare) VALUES (3, 'R-103', 'Chennai - Vellore Local', 1, 8, 135, 60)");

  // Seed Buses
  const stops1 = JSON.stringify([
    { name: 'Chennai CMBT', arrival: '06:00 AM', departure: '06:00 AM', distance: 0 },
    { name: 'Villupuram Bus Stand', arrival: '08:30 AM', departure: '08:35 AM', distance: 158 },
    { name: 'Trichy Central Bus Stand', arrival: '10:45 AM', departure: '10:50 AM', distance: 330 },
    { name: 'Madurai Mattuthavani', arrival: '12:30 PM', departure: '12:30 PM', distance: 460 },
  ]);
  const stops2 = JSON.stringify([
    { name: 'Chennai CMBT', arrival: '07:30 AM', departure: '07:30 AM', distance: 0 },
    { name: 'Mahabalipuram Stop', arrival: '08:15 AM', departure: '08:20 AM', distance: 58 },
    { name: 'Pondicherry Bus Stand', arrival: '09:30 AM', departure: '09:30 AM', distance: 151 },
  ]);
  const stops3 = JSON.stringify([
    { name: 'Chennai CMBT', arrival: '08:00 AM', departure: '08:00 AM', distance: 0 },
    { name: 'Kanchipuram Stop', arrival: '08:45 AM', departure: '08:50 AM', distance: 75 },
    { name: 'Vellore Bus Stand', arrival: '09:45 AM', departure: '09:45 AM', distance: 135 },
  ]);

  await run(`INSERT IGNORE INTO buses (id, bus_number, route_id, bus_type, capacity, current_occupancy, travel_status, delay_minutes, city, stops, from_stop, to_stop, arrival_time, fare)
       VALUES (1, 'TN01N1234', 1, 'Deluxe', 45, 12, 'Running', 0, 'Chennai', ?, 'Chennai CMBT', 'Madurai Mattuthavani', '06:00 AM', 120)`, [stops1]);
  await run(`INSERT IGNORE INTO buses (id, bus_number, route_id, bus_type, capacity, current_occupancy, travel_status, delay_minutes, city, stops, from_stop, to_stop, arrival_time, fare)
       VALUES (2, 'TN01N5678', 2, 'Express', 45, 0, 'Not Started', 0, 'Chennai', ?, 'Chennai CMBT', 'Pondicherry Bus Stand', '07:30 AM', 85)`, [stops2]);
  await run(`INSERT IGNORE INTO buses (id, bus_number, route_id, bus_type, capacity, current_occupancy, travel_status, delay_minutes, city, stops, from_stop, to_stop, arrival_time, fare)
       VALUES (3, 'TN01N9012', 3, 'Normal', 45, 45, 'Arrived', 5, 'Chennai', ?, 'Chennai CMBT', 'Vellore Bus Stand', '08:00 AM', 60)`, [stops3]);

  // Seed Schedules
  await run("INSERT IGNORE INTO schedules (bus_id, stop_id, stop_sequence, scheduled_arrival, scheduled_departure, distance_from_origin) VALUES (1, 1, 1, '06:00 AM', '06:00 AM', 0)");
  await run("INSERT IGNORE INTO schedules (bus_id, stop_id, stop_sequence, scheduled_arrival, scheduled_departure, distance_from_origin) VALUES (1, 2, 2, '08:30 AM', '08:35 AM', 158)");
  await run("INSERT IGNORE INTO schedules (bus_id, stop_id, stop_sequence, scheduled_arrival, scheduled_departure, distance_from_origin) VALUES (1, 3, 3, '10:45 AM', '10:50 AM', 330)");
  await run("INSERT IGNORE INTO schedules (bus_id, stop_id, stop_sequence, scheduled_arrival, scheduled_departure, distance_from_origin) VALUES (1, 4, 4, '12:30 PM', '12:30 PM', 460)");

  // Seed Demo Users
  const bcrypt = require('bcryptjs');
  const hashedAdmin = bcrypt.hashSync('admin123', 12);
  const hashedStaff = bcrypt.hashSync('staff123', 12);

  await run("INSERT IGNORE INTO users (name, email, password_hash, role) VALUES ('Admin Officer', 'ADMIN@GOV.IN', ?, 'ADMIN')", [hashedAdmin]);
  await run("INSERT IGNORE INTO users (name, email, password_hash, role) VALUES ('Staff Raj', 'RAJ@GOV.IN', ?, 'STAFF')", [hashedStaff]);

  logger.info('[SEED] Database seeded successfully.');
}

// Global Error Handlers
app.use(notFound);
app.use(errorHandler);

// Start Server
async function start() {
  await initDB();
  await createTables();
  await seedDatabase();

  // Initialize real-time WebSocket
  const { initRealtime } = require('./services/realtime.service');
  initRealtime(httpServer);

  // Initialize Firebase Cloud Messaging
  initFCM();

  // Use httpServer for WebSocket support
  httpServer.listen(PORT, () => {
    logger.info(`\n  ╔══════════════════════════════════════════╗`);
    logger.info(`  ║   SPOTX 4.0 Server — Production Ready   ║`);
    logger.info(`  ╠══════════════════════════════════════════╣`);
    logger.info(`  ║  HTTP:  http://localhost:${PORT}            ║`);
    logger.info(`  ║  WS:    ws://localhost:${PORT}              ║`);
    logger.info(`  ║  API:   http://localhost:${PORT}/api        ║`);
    logger.info(`  ║  Health: http://localhost:${PORT}/health    ║`);
    logger.info(`  ╠══════════════════════════════════════════╣`);
    logger.info(`  ║  Admin:  ADMIN@GOV.IN / admin123         ║`);
    logger.info(`  ║  Staff:  RAJ@GOV.IN   / staff123         ║`);
    logger.info(`  ╚══════════════════════════════════════════╝\n`);

    // Optionally seed demo data via --demo flag
    if (process.argv.includes('--demo')) {
      const { seed } = require('./seed-demo');
      seed().catch(err => logger.error('[SEED-DEMO] Error:', err.message));
    }
  });
}

start().catch((err) => {
  logger.error('Failed to start server:', err);
});

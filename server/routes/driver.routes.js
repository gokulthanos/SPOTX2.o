// server/routes/driver.routes.js
// ─────────────────────────────────────────────────
// Driver App Routes
// ─────────────────────────────────────────────────
const router = require('express').Router();
const driverController = require('../controllers/driver.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');

// POST /api/v1/driver/login
router.post('/login', driverController.driverLogin);

// All routes below require STAFF or ADMIN role
router.use(authenticate, requireRole('STAFF', 'ADMIN'));

// GET /api/v1/driver/profile
router.get('/profile', driverController.getProfile);

// GET /api/v1/driver/my-bus
router.get('/my-bus', driverController.getMyBus);

// Trip management
router.put('/trip/start', driverController.startTrip);
router.put('/trip/pause', driverController.pauseTrip);
router.put('/trip/resume', driverController.resumeTrip);
router.put('/trip/end', driverController.endTrip);

// GPS sharing
router.put('/location', driverController.shareLocation);

// Delay reporting
router.put('/delay', driverController.reportDelay);

// Emergency alert
router.post('/emergency', driverController.emergencyAlert);

// Driver stats
router.get('/stats', driverController.getDriverStats);

module.exports = router;

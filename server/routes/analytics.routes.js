// server/routes/analytics.routes.js
// ─────────────────────────────────────────────────
// Analytics Routes — Charts, Reports, Metrics
// ─────────────────────────────────────────────────
const router = require('express').Router();
const analyticsController = require('../controllers/analytics.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');

// All analytics routes require ADMIN or GOV role
router.use(authenticate, requireRole('ADMIN', 'GOV'));

// GET /api/v1/analytics/overview
router.get('/overview', analyticsController.getOverview);

// GET /api/v1/analytics/revenue
router.get('/revenue', analyticsController.getRevenueAnalytics);

// GET /api/v1/analytics/routes
router.get('/routes', analyticsController.getRouteAnalytics);

// GET /api/v1/analytics/occupancy
router.get('/occupancy', analyticsController.getOccupancyAnalytics);

module.exports = router;

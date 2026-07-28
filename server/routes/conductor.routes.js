// server/routes/conductor.routes.js
// ─────────────────────────────────────────────────
const { Router } = require('express');
const { authenticate } = require('../middleware/auth.middleware');
const {
  selectBusRoute,
  verifyTicket,
  todayStats,
} = require('../controllers/conductor.controller');
const { sendError } = require('../utils/response');

const router = Router();

function requireConductor(req, res, next) {
  if (!req.user || req.user.role !== 'conductor') {
    return sendError(res, 'Access denied. Conductor role required.', 403);
  }
  next();
}

router.post('/select-bus', authenticate, requireConductor, selectBusRoute);
router.post('/verify-ticket', authenticate, requireConductor, verifyTicket);
router.get('/today-stats', authenticate, requireConductor, todayStats);

module.exports = router;

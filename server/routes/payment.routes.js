// server/routes/payment.routes.js
// ─────────────────────────────────────────────────
const { Router } = require('express');
const { authenticate } = require('../middleware/auth.middleware');
const {
  initiatePayment,
  verifyPayment,
} = require('../controllers/payment.controller');

const router = Router();

router.post('/initiate', authenticate, initiatePayment);
router.post('/verify', authenticate, verifyPayment);

module.exports = router;

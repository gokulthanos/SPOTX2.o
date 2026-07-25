// server/routes/payment.routes.js
const router = require('express').Router();
const paymentController = require('../controllers/payment.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { validateInitiatePayment, validateVerifyPayment } = require('../middleware/validate.middleware');

// All payment routes require authentication
router.use(authenticate);

// POST /api/v1/payments/initiate
router.post('/initiate', validateInitiatePayment, paymentController.initiatePayment);

// POST /api/v1/payments/verify
router.post('/verify', validateVerifyPayment, paymentController.verifyPayment);

// GET /api/v1/payments/wallet
router.get('/wallet', paymentController.getWallet);

// GET /api/v1/payments/history
router.get('/history', paymentController.getPaymentHistory);

module.exports = router;

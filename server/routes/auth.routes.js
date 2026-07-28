// server/routes/auth.routes.js
// ─────────────────────────────────────────────────
const { Router } = require('express');
const { authenticate } = require('../middleware/auth.middleware');
const {
  passengerRegister,
  passengerLogin,
  requestOtp,
  verifyOtp,
  forgotPassword,
  getProfile,
  updateProfile,
  conductorLogin,
} = require('../controllers/auth.controller');

const router = Router();

router.post('/register', passengerRegister);
router.post('/login', passengerLogin);
router.post('/request-otp', requestOtp);
router.post('/verify-otp', verifyOtp);
router.post('/forgot-password', forgotPassword);
router.get('/profile', authenticate, getProfile);
router.put('/profile', authenticate, updateProfile);
router.post('/conductor/login', conductorLogin);

module.exports = router;

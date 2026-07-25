// server/routes/auth.routes.js
// ─────────────────────────────────────────────────
// Authentication Routes — /api/v1/auth and /api/v1/officer
// ─────────────────────────────────────────────────
const router = require('express').Router();
const authController = require('../controllers/auth.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const {
  validateRequestOtp,
  validateVerifyOtp,
  validateSetPassword,
  validatePassengerLogin,
  validateOfficerLogin,
  validateRegisterStaff,
  validateRefreshToken,
} = require('../middleware/validate.middleware');
const { otpRateLimiter, loginRateLimiter } = require('../middleware/rateLimiter');

// ── Passenger Auth ────────────────────────────────

// POST /api/v1/auth/request-otp
router.post('/request-otp',
  otpRateLimiter,
  validateRequestOtp,
  authController.requestOtp
);

// POST /api/v1/auth/verify-otp
router.post('/verify-otp',
  validateVerifyOtp,
  authController.verifyOtp
);

// POST /api/v1/auth/set-password
router.post('/set-password',
  validateSetPassword,
  authController.setPassword
);

// POST /api/v1/auth/login
router.post('/login',
  loginRateLimiter,
  validatePassengerLogin,
  authController.passengerLogin
);

// POST /api/v1/auth/refresh
router.post('/refresh',
  validateRefreshToken,
  authController.refreshToken
);

// POST /api/v1/auth/logout (requires auth)
router.post('/logout',
  authenticate,
  authController.logout
);

// POST /api/v1/auth/fcm-token — Save/update device FCM token (requires auth)
router.post('/fcm-token',
  authenticate,
  authController.updateFcmToken
);

// ── Officer Auth ──────────────────────────────────

// POST /api/v1/officer/login
router.post('/officer/login',
  loginRateLimiter,
  validateOfficerLogin,
  authController.officerLogin
);

// POST /api/v1/officer/register (Admin only)
router.post('/officer/register',
  authenticate,
  requireRole('ADMIN'),
  validateRegisterStaff,
  authController.registerOfficer
);

// ── Driver Auth (alias) ───────────────────────────
// Driver login goes through the same officer auth path
// but is handled by driver.routes.js for the full flow

module.exports = router;

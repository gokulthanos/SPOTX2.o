// server/controllers/auth.controller.js
// ─────────────────────────────────────────────────
// Auth Controller — handles all authentication HTTP requests.
// Delegates business logic to auth.service.js.
// ─────────────────────────────────────────────────
const authService = require('../services/auth.service');
const { getOne, run } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const { hashPassword } = require('../services/auth.service');
const { sendOTP } = require('../services/sms.service');
const logger = require('../utils/logger');

// ── Passenger Auth ────────────────────────────────

/**
 * POST /api/v1/auth/request-otp
 * Generate and send OTP to a mobile number via SMS.
 */
const requestOtp = async (req, res, next) => {
  try {
    const { contact } = req.body;
    const { otp, expiresAt } = await authService.requestOtp(contact);

    // Send OTP via SMS (provider configured via SMS_PROVIDER env var)
    const smsResult = await sendOTP(contact, otp);
    if (!smsResult.success) {
      logger.warn(`[AUTH] OTP SMS failed for ${contact}: ${smsResult.error || 'unknown'}`);
    }

    const response = { expiresAt };
    // Only expose OTP in development mode for testing convenience
    if (process.env.NODE_ENV !== 'production') {
      response.devOtp = otp;
    }

    return sendSuccess(res, 'OTP sent successfully', response);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/auth/verify-otp
 * Verify OTP and create passenger account if new user.
 */
const verifyOtp = async (req, res, next) => {
  try {
    const { contact, otp } = req.body;
    const result = await authService.verifyOtp(contact, otp);

    if (!result.success) {
      return sendError(res, result.message, 400);
    }

    // Create passenger record if first-time user
    const existing = await getOne('SELECT id FROM passengers WHERE contact = ?', [contact]);
    if (!existing) {
      await run('INSERT INTO passengers (contact, full_name, password_hash) VALUES (?, ?, ?)', [
        contact, '', '',
      ]);
    }

    return sendSuccess(res, 'OTP verified successfully', { contact });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/auth/set-password
 * Set (or reset) password for a passenger after OTP verification.
 */
const setPassword = async (req, res, next) => {
  try {
    const { contact, password, fullName } = req.body;

    // Ensure OTP was verified for this contact
    const otpRecord = await getOne(
      'SELECT * FROM otps WHERE contact = ? AND verified = 1 ORDER BY id DESC LIMIT 1',
      [contact]
    );
    if (!otpRecord) {
      return sendError(res, 'OTP not verified. Please verify your number first.', 400);
    }

    const passwordHash = await hashPassword(password);

    const existing = await getOne('SELECT id FROM passengers WHERE contact = ?', [contact]);
    if (existing) {
      await run(
        'UPDATE passengers SET password_hash = ?, full_name = COALESCE(NULLIF(?, \'\'), full_name) WHERE contact = ?',
        [passwordHash, fullName || '', contact]
      );
    } else {
      await run(
        'INSERT INTO passengers (contact, full_name, password_hash) VALUES (?, ?, ?)',
        [contact, fullName || '', passwordHash]
      );
    }

    // Auto-login after setting password
    const { passenger, accessToken, refreshToken } = await authService.passengerLogin(contact, password);

    return sendSuccess(res, 'Password set successfully', {
      ...passenger,
      accessToken,
      refreshToken,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/auth/login
 * Passenger login with contact + password.
 */
const passengerLogin = async (req, res, next) => {
  try {
    const { contact, password } = req.body;
    const result = await authService.passengerLogin(contact, password);

    logger.info(`[AUTH] Passenger logged in: ${contact}`);
    return sendSuccess(res, 'Login successful', result);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/auth/refresh
 * Issue new access + refresh tokens using a valid refresh token.
 */
const refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    const tokens = await authService.refreshAccessToken(refreshToken);
    return sendSuccess(res, 'Tokens refreshed', tokens);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/auth/logout
 * Revoke refresh token (requires authentication).
 */
const logout = async (req, res, next) => {
  try {
    const { id, role } = req.user;
    await authService.logout(id, role);
    return sendSuccess(res, 'Logged out successfully');
  } catch (err) {
    next(err);
  }
};

// ── Officer Auth ──────────────────────────────────

/**
 * POST /api/v1/officer/login
 * Officer login with email + password.
 */
const officerLogin = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.officerLogin(email, password);

    logger.info(`[AUTH] Officer logged in: ${email} (${result.user.role})`);
    return sendSuccess(res, 'Login successful', result);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/officer/register
 * Register a new staff/admin account (Admin only).
 */
const registerOfficer = async (req, res, next) => {
  try {
    const { name, email, password, role = 'STAFF' } = req.body;

    const existing = await getOne('SELECT id FROM users WHERE email = ?', [email.toUpperCase()]);
    if (existing) {
      return sendError(res, 'An account with this email already exists', 409);
    }

    const passwordHash = await hashPassword(password);
    await run(
      'INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [name, email.toUpperCase(), passwordHash, role.toUpperCase()]
    );

    logger.info(`[AUTH] New officer registered: ${email} (${role})`);
    return sendSuccess(res, 'Staff registered successfully', { name, email, role }, 201);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/auth/fcm-token
 * Save or update the device FCM token for push notifications.
 * Requires authentication (passenger or officer).
 */
const updateFcmToken = async (req, res, next) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken || typeof fcmToken !== 'string') {
      return sendError(res, 'fcmToken is required', 400);
    }

    const { id, role } = req.user;

    if (role === 'PASSENGER') {
      // Update passenger FCM token
      await run('UPDATE passengers SET fcm_token = ? WHERE id = ?', [fcmToken, id]);
      logger.info(`[AUTH] FCM token updated for passenger ${id}`);
    } else {
      // Update officer FCM token
      await run('UPDATE users SET fcm_token = ? WHERE id = ?', [fcmToken, id]);
      logger.info(`[AUTH] FCM token updated for officer ${id}`);
    }

    return sendSuccess(res, 'FCM token updated');
  } catch (err) {
    next(err);
  }
};

module.exports = {
  requestOtp,
  verifyOtp,
  setPassword,
  passengerLogin,
  refreshToken,
  logout,
  officerLogin,
  registerOfficer,
  updateFcmToken,
};

// server/services/auth.service.js
// ─────────────────────────────────────────────────
// Authentication Business Logic
//
// Handles:
//   - bcrypt password hashing & comparison
//   - JWT access token generation
//   - JWT refresh token generation
//   - OTP generation and verification
//   - Token refresh flow
// ─────────────────────────────────────────────────
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const {
  JWT_SECRET,
  JWT_REFRESH_SECRET,
  JWT_EXPIRES_IN,
  JWT_REFRESH_EXPIRES_IN,
} = require('../config/env');
const { getOne, run } = require('../db');
const logger = require('../utils/logger');

const BCRYPT_ROUNDS = 12; // Good balance of security vs CPU time

// ── Password Utilities ────────────────────────────

/**
 * Hash a plaintext password with bcrypt.
 * @param {string} password
 * @returns {Promise<string>} bcrypt hash
 */
const hashPassword = async (password) => {
  return await bcrypt.hash(password, BCRYPT_ROUNDS);
};

/**
 * Compare a plaintext password against a bcrypt hash.
 * @param {string} password
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
const comparePassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

// ── Token Generation ──────────────────────────────

/**
 * Generate a signed JWT access token.
 * @param {Object} payload - { id, role, contact? email? }
 * @returns {string} JWT token
 */
const generateAccessToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
};

/**
 * Generate a signed JWT refresh token (longer lived).
 * @param {Object} payload - { id, role }
 * @returns {string} JWT refresh token
 */
const generateRefreshToken = (payload) => {
  return jwt.sign(payload, JWT_REFRESH_SECRET, {
    expiresIn: JWT_REFRESH_EXPIRES_IN,
  });
};

/**
 * Verify a refresh token and return its payload.
 * @param {string} token
 * @returns {Object} decoded payload
 * @throws {Error} if invalid or expired
 */
const verifyRefreshToken = (token) => {
  return jwt.verify(token, JWT_REFRESH_SECRET);
};

// ── OTP Utilities ─────────────────────────────────

/**
 * Generate a 6-digit numeric OTP.
 * @returns {string}
 */
const generateOtp = () => {
  // Use crypto.randomInt for cryptographically secure OTP
  return String(crypto.randomInt(100000, 999999));
};

// ── Auth Flows ────────────────────────────────────

/**
 * Request OTP for a contact number.
 * Deletes any existing OTP for the contact and inserts a new one.
 * Returns the OTP (for dev mode logging; in production, send via SMS).
 *
 * @param {string} contact - Mobile phone number
 * @returns {{ otp: string, expiresAt: string }}
 */
const requestOtp = async (contact) => {
  const otp = generateOtp();

  await run('DELETE FROM otps WHERE contact = ?', [contact]);
  await run(
    'INSERT INTO otps (contact, otp, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))',
    [contact, otp]
  );

  // Compute expiry for the response (10 minutes from now)
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000)
    .toISOString().replace('T', ' ').substring(0, 19);

  // In production: send via SMS gateway (Twilio / MSG91 / Fast2SMS)
  logger.info(`[OTP] Generated for ${contact} (dev mode — do not log in production)`);

  return { otp, expiresAt };
};

/**
 * Verify an OTP for a contact number.
 * @param {string} contact
 * @param {string} otp
 * @returns {{ success: boolean, message: string }}
 */
const verifyOtp = async (contact, otp) => {
  const record = await getOne(
    'SELECT * FROM otps WHERE contact = ? AND expires_at > NOW() ORDER BY id DESC LIMIT 1',
    [contact]
  );

  if (!record) {
    return { success: false, message: 'OTP has expired or not found. Please request a new one.' };
  }
  if (record.otp !== otp) {
    return { success: false, message: 'Invalid OTP. Please try again.' };
  }

  await run('UPDATE otps SET verified = 1 WHERE id = ?', [record.id]);
  return { success: true, message: 'OTP verified' };
};

/**
 * Passenger Login — validate credentials and return tokens.
 * @param {string} contact
 * @param {string} password
 * @returns {{ passenger, accessToken, refreshToken }}
 * @throws {Error} if credentials invalid
 */
const passengerLogin = async (contact, password) => {
  const passenger = await getOne(
    'SELECT * FROM passengers WHERE contact = ? AND is_active = 1',
    [contact]
  );

  if (!passenger) {
    throw Object.assign(new Error('Account not found. Please sign up first.'), { statusCode: 404 });
  }

  // Support old plaintext passwords during transition period
  let passwordValid = false;
  if (passenger.password_hash && passenger.password_hash.startsWith('$2')) {
    // bcrypt hash
    passwordValid = await comparePassword(password, passenger.password_hash);
  } else if (passenger.password_hash === password) {
    // Legacy plaintext — migrate to bcrypt on successful login
    const newHash = await hashPassword(password);
    await run('UPDATE passengers SET password_hash = ? WHERE id = ?', [newHash, passenger.id]);
    passwordValid = true;
    logger.info(`[AUTH] Migrated plaintext password to bcrypt for passenger ${passenger.id}`);
  }

  if (!passwordValid) {
    throw Object.assign(new Error('Invalid password'), { statusCode: 401 });
  }

  const payload = { id: passenger.id, role: 'PASSENGER', contact: passenger.contact };
  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken({ id: passenger.id, role: 'PASSENGER' });

  await run('UPDATE passengers SET refresh_token = ? WHERE id = ?', [refreshToken, passenger.id]);

  return {
    passenger: {
      id: passenger.id,
      fullName: passenger.full_name,
      contact: passenger.contact,
      walletBalance: passenger.wallet_balance,
    },
    accessToken,
    refreshToken,
  };
};

/**
 * Officer Login — validate credentials and return tokens.
 * @param {string} email
 * @param {string} password
 * @returns {{ user, accessToken, refreshToken }}
 * @throws {Error} if credentials invalid
 */
const officerLogin = async (email, password) => {
  const user = await getOne(
    'SELECT * FROM users WHERE email = ? AND is_active = 1',
    [email.toUpperCase()]
  );

  if (!user) {
    throw Object.assign(new Error('Officer account not found'), { statusCode: 404 });
  }

  let passwordValid = false;
  if (user.password_hash && user.password_hash.startsWith('$2')) {
    passwordValid = await comparePassword(password, user.password_hash);
  } else if (user.password_hash === password) {
    // Legacy plaintext migration
    const newHash = await hashPassword(password);
    await run('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, user.id]);
    passwordValid = true;
    logger.info(`[AUTH] Migrated plaintext password to bcrypt for officer ${user.id}`);
  }

  if (!passwordValid) {
    throw Object.assign(new Error('Invalid password'), { statusCode: 401 });
  }

  const payload = { id: user.id, role: user.role, email: user.email };
  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken({ id: user.id, role: user.role });

  await run('UPDATE users SET refresh_token = ? WHERE id = ?', [refreshToken, user.id]);

  return {
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    },
    accessToken,
    refreshToken,
  };
};

/**
 * Refresh access token using a valid refresh token.
 * Checks the token against the stored value in DB (rotation).
 *
 * @param {string} refreshToken
 * @returns {{ accessToken, refreshToken }}
 * @throws {Error} if token invalid or revoked
 */
const refreshAccessToken = async (refreshToken) => {
  let decoded;
  try {
    decoded = verifyRefreshToken(refreshToken);
  } catch {
    throw Object.assign(new Error('Invalid or expired refresh token'), { statusCode: 401 });
  }

  // Check if refresh token matches what's stored (prevents reuse of old tokens)
  let storedToken = null;
  if (decoded.role === 'PASSENGER') {
    const passenger = await getOne('SELECT refresh_token FROM passengers WHERE id = ?', [decoded.id]);
    storedToken = passenger?.refresh_token;
  } else {
    const user = await getOne('SELECT refresh_token FROM users WHERE id = ?', [decoded.id]);
    storedToken = user?.refresh_token;
  }

  if (!storedToken || storedToken !== refreshToken) {
    throw Object.assign(new Error('Refresh token has been revoked'), { statusCode: 401 });
  }

  // Rotate: issue new access + refresh tokens
  const newPayload = { id: decoded.id, role: decoded.role, contact: decoded.contact, email: decoded.email };
  const newAccessToken = generateAccessToken(newPayload);
  const newRefreshToken = generateRefreshToken({ id: decoded.id, role: decoded.role });

  // Store new refresh token
  if (decoded.role === 'PASSENGER') {
    await run('UPDATE passengers SET refresh_token = ? WHERE id = ?', [newRefreshToken, decoded.id]);
  } else {
    await run('UPDATE users SET refresh_token = ? WHERE id = ?', [newRefreshToken, decoded.id]);
  }

  return { accessToken: newAccessToken, refreshToken: newRefreshToken };
};

/**
 * Logout — invalidate refresh token in DB.
 * @param {string} id - User or passenger ID
 * @param {string} role
 */
const logout = async (id, role) => {
  if (role === 'PASSENGER') {
    await run('UPDATE passengers SET refresh_token = NULL WHERE id = ?', [id]);
  } else {
    await run('UPDATE users SET refresh_token = NULL WHERE id = ?', [id]);
  }
};

module.exports = {
  hashPassword,
  comparePassword,
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  generateOtp,
  requestOtp,
  verifyOtp,
  passengerLogin,
  officerLogin,
  refreshAccessToken,
  logout,
};

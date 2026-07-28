// server/controllers/auth.controller.js
// ─────────────────────────────────────────────────
// Passenger & Conductor Authentication
// ─────────────────────────────────────────────────
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/env');
const { getOne, run, lastInsertId } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

function generatePnr() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let pnr = '';
  for (let i = 0; i < 10; i++) {
    pnr += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return pnr;
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

const passengerRegister = async (req, res) => {
  try {
    const { name, mobile, password } = req.body;

    if (!name || !mobile || !password) {
      return sendError(res, 'Name, mobile, and password are required');
    }

    if (password.length < 6) {
      return sendError(res, 'Password must be at least 6 characters');
    }

    const existing = await getOne('SELECT id FROM passengers WHERE mobile = ?', [mobile]);
    if (existing) {
      return sendError(res, 'Mobile number already registered', 409);
    }

    const password_hash = await bcrypt.hash(password, 12);

    await run(
      'INSERT INTO passengers (full_name, mobile, password_hash) VALUES (?, ?, ?)',
      [name, mobile, password_hash]
    );

    const passengerId = await lastInsertId();

    const token = jwt.sign(
      { id: passengerId, role: 'passenger', mobile },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    logger.info(`[AUTH] Passenger registered: ${name} (${mobile})`);

    return sendSuccess(res, 'Registration successful', {
      token,
      passenger: { id: passengerId, full_name: name, mobile },
    });
  } catch (err) {
    logger.error(`[AUTH] Register error: ${err.message}`);
    return sendError(res, 'Registration failed', 500);
  }
};

const passengerLogin = async (req, res) => {
  try {
    const { mobile, password } = req.body;

    if (!mobile || !password) {
      return sendError(res, 'Mobile and password are required');
    }

    const passenger = await getOne('SELECT * FROM passengers WHERE mobile = ?', [mobile]);
    if (!passenger) {
      return sendError(res, 'Invalid credentials', 401);
    }

    if (!passenger.is_active) {
      return sendError(res, 'Account is deactivated', 403);
    }

    const valid = await bcrypt.compare(password, passenger.password_hash);
    if (!valid) {
      return sendError(res, 'Invalid credentials', 401);
    }

    const token = jwt.sign(
      { id: passenger.id, role: 'passenger', mobile: passenger.mobile },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    return sendSuccess(res, 'Login successful', {
      token,
      passenger: {
        id: passenger.id,
        full_name: passenger.full_name,
        mobile: passenger.mobile,
        email: passenger.email,
        wallet_balance: passenger.wallet_balance,
      },
    });
  } catch (err) {
    logger.error(`[AUTH] Login error: ${err.message}`);
    return sendError(res, 'Login failed', 500);
  }
};

const requestOtp = async (req, res) => {
  try {
    const { mobile } = req.body;

    if (!mobile) {
      return sendError(res, 'Mobile number is required');
    }

    const otp = generateOtp();
    const expires_at = new Date(Date.now() + 5 * 60 * 1000);

    await run(
      'INSERT INTO otps (contact, otp, expires_at) VALUES (?, ?, ?)',
      [mobile, otp, expires_at]
    );

    logger.info(`[AUTH] OTP for ${mobile}: ${otp}`);

    return sendSuccess(res, 'OTP sent successfully', { mobile });
  } catch (err) {
    logger.error(`[AUTH] OTP request error: ${err.message}`);
    return sendError(res, 'Failed to send OTP', 500);
  }
};

const verifyOtp = async (req, res) => {
  try {
    const { mobile, otp } = req.body;

    if (!mobile || !otp) {
      return sendError(res, 'Mobile and OTP are required');
    }

    const record = await getOne(
      'SELECT * FROM otps WHERE contact = ? AND otp = ? AND verified = 0 ORDER BY id DESC LIMIT 1',
      [mobile, otp]
    );

    if (!record) {
      return sendError(res, 'Invalid OTP', 400);
    }

    if (new Date(record.expires_at) < new Date()) {
      return sendError(res, 'OTP has expired', 400);
    }

    await run('UPDATE otps SET verified = 1 WHERE id = ?', [record.id]);

    return sendSuccess(res, 'OTP verified successfully');
  } catch (err) {
    logger.error(`[AUTH] OTP verify error: ${err.message}`);
    return sendError(res, 'OTP verification failed', 500);
  }
};

const forgotPassword = async (req, res) => {
  try {
    const { mobile, otp, newPassword } = req.body;

    if (!mobile || !otp || !newPassword) {
      return sendError(res, 'Mobile, OTP, and new password are required');
    }

    if (newPassword.length < 6) {
      return sendError(res, 'Password must be at least 6 characters');
    }

    const record = await getOne(
      'SELECT * FROM otps WHERE contact = ? AND otp = ? AND verified = 1 ORDER BY id DESC LIMIT 1',
      [mobile, otp]
    );

    if (!record) {
      return sendError(res, 'OTP not verified. Please verify OTP first.', 400);
    }

    const passenger = await getOne('SELECT id FROM passengers WHERE mobile = ?', [mobile]);
    if (!passenger) {
      return sendError(res, 'No account found with this mobile number', 404);
    }

    const password_hash = await bcrypt.hash(newPassword, 12);
    await run('UPDATE passengers SET password_hash = ? WHERE id = ?', [password_hash, passenger.id]);

    return sendSuccess(res, 'Password reset successful');
  } catch (err) {
    logger.error(`[AUTH] Forgot password error: ${err.message}`);
    return sendError(res, 'Password reset failed', 500);
  }
};

const getProfile = async (req, res) => {
  try {
    const passenger = await getOne(
      'SELECT id, full_name, dob, gender, mobile, email, emergency_contact, wallet_balance, is_active, created_at FROM passengers WHERE id = ?',
      [req.user.id]
    );

    if (!passenger) {
      return sendError(res, 'Passenger not found', 404);
    }

    return sendSuccess(res, 'Profile fetched', passenger);
  } catch (err) {
    logger.error(`[AUTH] Get profile error: ${err.message}`);
    return sendError(res, 'Failed to fetch profile', 500);
  }
};

const updateProfile = async (req, res) => {
  try {
    const { name, dob, gender, email, emergency_contact } = req.body;
    const fields = [];
    const values = [];

    if (name !== undefined) { fields.push('full_name = ?'); values.push(name); }
    if (dob !== undefined) { fields.push('dob = ?'); values.push(dob); }
    if (gender !== undefined) { fields.push('gender = ?'); values.push(gender); }
    if (email !== undefined) { fields.push('email = ?'); values.push(email); }
    if (emergency_contact !== undefined) { fields.push('emergency_contact = ?'); values.push(emergency_contact); }

    if (fields.length === 0) {
      return sendError(res, 'No fields to update');
    }

    values.push(req.user.id);
    await run(`UPDATE passengers SET ${fields.join(', ')} WHERE id = ?`, values);

    const updated = await getOne(
      'SELECT id, full_name, dob, gender, mobile, email, emergency_contact, wallet_balance FROM passengers WHERE id = ?',
      [req.user.id]
    );

    return sendSuccess(res, 'Profile updated', updated);
  } catch (err) {
    logger.error(`[AUTH] Update profile error: ${err.message}`);
    return sendError(res, 'Failed to update profile', 500);
  }
};

const conductorLogin = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return sendError(res, 'Username and password are required');
    }

    const conductor = await getOne('SELECT * FROM conductors WHERE username = ?', [username]);
    if (!conductor) {
      return sendError(res, 'Invalid credentials', 401);
    }

    if (!conductor.is_active) {
      return sendError(res, 'Conductor account is deactivated', 403);
    }

    const valid = await bcrypt.compare(password, conductor.password_hash);
    if (!valid) {
      return sendError(res, 'Invalid credentials', 401);
    }

    const token = jwt.sign(
      { id: conductor.id, role: 'conductor', username: conductor.username },
      JWT_SECRET,
      { expiresIn: '12h' }
    );

    return sendSuccess(res, 'Login successful', {
      token,
      conductor: { id: conductor.id, name: conductor.name, username: conductor.username },
    });
  } catch (err) {
    logger.error(`[AUTH] Conductor login error: ${err.message}`);
    return sendError(res, 'Login failed', 500);
  }
};

module.exports = {
  passengerRegister,
  passengerLogin,
  requestOtp,
  verifyOtp,
  forgotPassword,
  getProfile,
  updateProfile,
  conductorLogin,
  generatePnr,
};

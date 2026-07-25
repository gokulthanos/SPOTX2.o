// server/middleware/auth.middleware.js
// ─────────────────────────────────────────────────
// JWT Authentication Middleware
//
// Usage:
//   router.get('/protected', authenticate, handler)
//   router.get('/admin-only', authenticate, requireRole('ADMIN'), handler)
//
// On success: attaches req.user = { id, role, contact/email }
// On failure: returns 401 Unauthorized
// ─────────────────────────────────────────────────
const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/env');
const { sendError } = require('../utils/response');

/**
 * Verify JWT access token from Authorization: Bearer <token> header.
 * Attaches decoded payload to req.user.
 */
const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return sendError(res, 'Authorization token required', 401);
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // { id, role, contact or email, iat, exp }
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return sendError(res, 'Token expired. Please refresh your session.', 401);
    }
    return sendError(res, 'Invalid token', 401);
  }
};

/**
 * Role-based access control middleware factory.
 * Call after authenticate() in the middleware chain.
 *
 * @param {...string} roles - Allowed roles (e.g., 'ADMIN', 'STAFF')
 */
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user) {
    return sendError(res, 'Not authenticated', 401);
  }
  if (!roles.includes(req.user.role)) {
    return sendError(
      res,
      `Access denied. Required role: ${roles.join(' or ')}`,
      403
    );
  }
  next();
};

/**
 * Optional authentication — attaches req.user if token present,
 * but does NOT block the request if token is missing.
 * Useful for endpoints that behave differently for logged-in users.
 */
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      req.user = jwt.verify(token, JWT_SECRET);
    } catch {
      // Token invalid but we allow the request anyway
      req.user = null;
    }
  }
  next();
};

module.exports = { authenticate, requireRole, optionalAuth };

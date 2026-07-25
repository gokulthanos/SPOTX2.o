// server/middleware/security.middleware.js
// ─────────────────────────────────────────────────
// Security Hardening Middleware
// Input sanitization, XSS prevention, audit logging
// ─────────────────────────────────────────────────
const { getOne, run } = require('../db');
const logger = require('../utils/logger');

/**
 * Input sanitization middleware.
 * Strips dangerous characters from request body/query/params.
 */
function sanitizeInput(req, res, next) {
  const sanitize = (obj) => {
    if (!obj || typeof obj !== 'object') return obj;
    const cleaned = {};
    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === 'string') {
        // Strip HTML tags and dangerous characters
        cleaned[key] = value
          .replace(/<[^>]*>/g, '')
          .replace(/javascript:/gi, '')
          .replace(/on\w+\s*=/gi, '')
          .replace(/data:/gi, '')
          .trim();
      } else if (typeof value === 'object') {
        cleaned[key] = sanitize(value);
      } else {
        cleaned[key] = value;
      }
    }
    return cleaned;
  };

  if (req.body && typeof req.body === 'object') {
    req.body = sanitize(req.body);
  }
  if (req.query && typeof req.query === 'object') {
    req.query = sanitize(req.query);
  }
  if (req.params && typeof req.params === 'object') {
    req.params = sanitize(req.params);
  }

  next();
}

/**
 * Request size limiter — reject oversized payloads.
 */
function requestSizeLimiter(maxSizeKb = 500) {
  return (req, res, next) => {
    const contentLength = parseInt(req.headers['content-length'] || '0', 10);
    if (contentLength > maxSizeKb * 1024) {
      logger.warn(`[SECURITY] Request too large: ${contentLength} bytes from ${req.ip}`);
      return res.status(413).json({
        success: false,
        message: 'Request entity too large',
      });
    }
    next();
  };
}

/**
 * Audit logging middleware.
 * Logs all state-changing operations (POST, PUT, PATCH, DELETE).
 */
function auditLogger(req, res, next) {
  const startTime = Date.now();
  const originalJson = res.json.bind(res);

  res.json = async function (body) {
    const duration = Date.now() - startTime;

    // Only log state-changing methods
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
      const userId = req.user?.id || null;
      const userRole = req.user?.role || 'anonymous';

      // Async audit log — don't block the response
      try {
        await run(
          `INSERT INTO audit_log (user_id, user_role, action, resource, resource_id, details, ip_address)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            userId,
            userRole,
            req.method,
            req.originalUrl.split('?')[0],
            req.params?.id || null,
            JSON.stringify({
              body: req.method === 'DELETE' ? {} : req.body,
              statusCode: res.statusCode,
              duration,
            }),
            req.ip || req.connection?.remoteAddress || 'unknown',
          ]
        );
      } catch (err) {
        logger.error('[AUDIT] Failed to log:', err.message);
      }
    }

    return originalJson(body);
  };

  next();
}

/**
 * SQL injection detection — blocks obvious injection attempts.
 */
function sqlInjectionGuard(req, res, next) {
  const sqlPatterns = [
    /(\b(union|select|insert|update|delete|drop|alter|create|truncate)\b)/i,
    /(--|\/\*|\*\/|;)/,
    /(\b(or|and)\b\s+\d+\s*=\s*\d+)/i,
    /(char\(|concat\(|0x[0-9a-f]+)/i,
  ];

  const checkValue = (value) => {
    if (typeof value !== 'string') return false;
    return sqlPatterns.some((pattern) => pattern.test(value));
  };

  const checkObject = (obj) => {
    if (!obj || typeof obj !== 'object') return false;
    for (const value of Object.values(obj)) {
      if (checkValue(value)) return true;
      if (typeof value === 'object' && checkObject(value)) return true;
    }
    return false;
  };

  if (checkObject(req.body) || checkObject(req.query) || checkObject(req.params)) {
    logger.warn(`[SECURITY] Potential SQL injection from ${req.ip}: ${req.originalUrl}`);
    return res.status(400).json({
      success: false,
      message: 'Invalid input detected',
    });
  }

  next();
}

/**
 * CORS pre-flight handler for additional security headers.
 */
function securityHeaders(req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(self)');
  next();
}

/**
 * Brute force protection — track failed login attempts per IP.
 */
const failedAttempts = new Map();

function bruteForceProtection(req, res, next) {
  const ip = req.ip || req.connection?.remoteAddress || 'unknown';
  const key = `${ip}:${req.originalUrl}`;
  const record = failedAttempts.get(key);

  if (record) {
    // Reset after 15 minutes
    if (Date.now() - record.lastAttempt > 15 * 60 * 1000) {
      failedAttempts.delete(key);
    } else if (record.count >= 10) {
      logger.warn(`[SECURITY] Brute force blocked: ${ip} (${record.count} attempts)`);
      return res.status(429).json({
        success: false,
        message: 'Too many failed attempts. Please try again in 15 minutes.',
      });
    }
  }

  // Track failure on error responses
  const originalJson = res.json.bind(res);
  res.json = function (body) {
    if (res.statusCode === 401 || res.statusCode === 403 || res.statusCode === 404) {
      const current = failedAttempts.get(key) || { count: 0, lastAttempt: 0 };
      failedAttempts.set(key, {
        count: current.count + 1,
        lastAttempt: Date.now(),
      });
    } else if (res.statusCode >= 200 && res.statusCode < 300) {
      failedAttempts.delete(key); // Reset on success
    }
    return originalJson(body);
  };

  next();
}

module.exports = {
  sanitizeInput,
  requestSizeLimiter,
  auditLogger,
  sqlInjectionGuard,
  securityHeaders,
  bruteForceProtection,
};

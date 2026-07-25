// server/middleware/rateLimiter.js
// ─────────────────────────────────────────────────
// In-memory rate limiter for sensitive endpoints.
// Prevents OTP brute-force and credential stuffing.
//
// Uses a Map-based sliding window counter.
// No external dependency required.
// ─────────────────────────────────────────────────
const { OTP_MAX_REQUESTS, OTP_WINDOW_MINUTES } = require('../config/env');
const { sendError } = require('../utils/response');

// Map<key, { count, resetAt }>
const store = new Map();

/**
 * Create a rate limiter middleware.
 *
 * @param {Object} options
 * @param {number} options.maxRequests - Max requests allowed in window
 * @param {number} options.windowMs - Window duration in milliseconds
 * @param {Function} options.keyFn - Function to extract the rate limit key from req
 * @param {string} options.message - Error message when limit exceeded
 */
function createRateLimiter({ maxRequests, windowMs, keyFn, message }) {
  return (req, res, next) => {
    const key = keyFn(req);
    const now = Date.now();
    const record = store.get(key);

    if (!record || now > record.resetAt) {
      // New window
      store.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }

    if (record.count >= maxRequests) {
      const retryAfterSeconds = Math.ceil((record.resetAt - now) / 1000);
      res.set('Retry-After', retryAfterSeconds);
      return sendError(
        res,
        message || `Too many requests. Try again in ${retryAfterSeconds}s.`,
        429
      );
    }

    record.count += 1;
    next();
  };
}

/**
 * OTP rate limiter:
 * Max 3 OTP requests per contact per 10 minutes.
 */
const otpRateLimiter = createRateLimiter({
  maxRequests: OTP_MAX_REQUESTS,
  windowMs: OTP_WINDOW_MINUTES * 60 * 1000,
  keyFn: (req) => `otp:${req.body?.contact || req.ip}`,
  message: `Too many OTP requests. Please wait ${OTP_WINDOW_MINUTES} minutes before requesting again.`,
});

/**
 * Login rate limiter:
 * Max 10 login attempts per IP per 15 minutes.
 */
const loginRateLimiter = createRateLimiter({
  maxRequests: 10,
  windowMs: 15 * 60 * 1000,
  keyFn: (req) => `login:${req.ip}`,
  message: 'Too many login attempts. Please wait 15 minutes.',
});

// Cleanup expired entries every 5 minutes to prevent memory leaks
setInterval(() => {
  const now = Date.now();
  for (const [key, record] of store.entries()) {
    if (now > record.resetAt) store.delete(key);
  }
}, 5 * 60 * 1000);

module.exports = { otpRateLimiter, loginRateLimiter, createRateLimiter };

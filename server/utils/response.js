



// server/utils/response.js
// ─────────────────────────────────────────────────
// Standardized JSON response helpers.
// All API responses follow a consistent shape:
//   { success, message, data } — success
//   { success, message, errors } — failure
// ─────────────────────────────────────────────────

/**
 * Send a 200 OK success response.
 * @param {Response} res - Express response object
 * @param {string} message - Human-readable success message
 * @param {*} data - Response payload
 * @param {number} [status=200] - HTTP status code
 */
const sendSuccess = (res, message, data = null, status = 200) => {
  return res.status(status).json({
    success: true,
    message,
    data,
  });
};

/**
 * Send an error response.
 * @param {Response} res - Express response object
 * @param {string} message - Human-readable error message
 * @param {number} [status=400] - HTTP status code
 * @param {Array} [errors=[]] - Validation error array
 */
const sendError = (res, message, status = 400, errors = []) => {
  const body = { success: false, message };
  if (errors.length > 0) body.errors = errors;
  return res.status(status).json(body);
};

module.exports = { sendSuccess, sendError };

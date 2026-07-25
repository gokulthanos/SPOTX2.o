// server/middleware/validate.middleware.js
// ─────────────────────────────────────────────────
// Request Validation Middleware (express-validator)
//
// Each exported array is a validation chain + error handler
// meant to be spread into a route definition.
//
// Usage:
//   router.post('/login', ...validatePassengerLogin, controller)
// ─────────────────────────────────────────────────
const { body, param, query, validationResult } = require('express-validator');
const { sendError } = require('../utils/response');

/**
 * Middleware that reads express-validator results and
 * returns a 422 if any validation errors exist.
 */
const handleValidation = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return sendError(
      res,
      'Validation failed',
      422,
      errors.array().map((e) => ({ field: e.path, message: e.msg }))
    );
  }
  next();
};

// ── Auth validations ──────────────────────────────

const validateRequestOtp = [
  body('contact')
    .notEmpty().withMessage('Contact number is required')
    .isMobilePhone('en-IN').withMessage('Enter a valid 10-digit mobile number'),
  handleValidation,
];

const validateVerifyOtp = [
  body('contact').notEmpty().withMessage('Contact is required'),
  body('otp')
    .notEmpty().withMessage('OTP is required')
    .isLength({ min: 6, max: 6 }).withMessage('OTP must be 6 digits')
    .isNumeric().withMessage('OTP must contain only digits'),
  handleValidation,
];

const validateSetPassword = [
  body('contact').notEmpty().withMessage('Contact is required'),
  body('password')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  handleValidation,
];

const validatePassengerLogin = [
  body('contact').notEmpty().withMessage('Contact is required'),
  body('password').notEmpty().withMessage('Password is required'),
  handleValidation,
];

const validateOfficerLogin = [
  body('email')
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Enter a valid email address'),
  body('password').notEmpty().withMessage('Password is required'),
  handleValidation,
];

const validateRegisterStaff = [
  body('name').notEmpty().withMessage('Name is required').trim(),
  body('email')
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Enter a valid email'),
  body('password')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('role')
    .optional()
    .isIn(['STAFF', 'ADMIN', 'GOV']).withMessage('Role must be STAFF, ADMIN, or GOV'),
  handleValidation,
];

const validateRefreshToken = [
  body('refreshToken').notEmpty().withMessage('Refresh token is required'),
  handleValidation,
];

// ── Bus validations ───────────────────────────────

const validateBusQuery = [
  query('city').optional().isString().trim(),
  query('from').optional().isString().trim(),
  query('to').optional().isString().trim(),
  handleValidation,
];

const validateAddBus = [
  body('busNumber').notEmpty().withMessage('Bus number is required').trim(),
  body('busType')
    .optional()
    .isIn(['Normal', 'Express', 'Deluxe', 'Mini', 'Town', 'Mofussil'])
    .withMessage('Invalid bus type'),
  body('capacity').optional().isInt({ min: 1, max: 100 }),
  handleValidation,
];

// ── Ticket validations ────────────────────────────

const validateBookTicket = [
  body('busId').isInt({ min: 1 }).withMessage('Valid bus ID is required'),
  body('busNumber').notEmpty().withMessage('Bus number is required'),
  body('fromStop').notEmpty().withMessage('Boarding stop is required').trim(),
  body('toStop').notEmpty().withMessage('Destination stop is required').trim(),
  body('totalFare').isFloat({ min: 0 }).withMessage('Valid fare amount required'),
  body('passengers')
    .isArray({ min: 1 }).withMessage('At least one passenger is required'),
  body('passengers.*.name')
    .notEmpty().withMessage('Passenger name is required'),
  handleValidation,
];

const validateTicketNumber = [
  param('ticketNumber')
    .notEmpty().withMessage('Ticket number is required'),
  handleValidation,
];

// ── Payment validations ───────────────────────────

const validateInitiatePayment = [
  body('amount')
    .isFloat({ min: 1 }).withMessage('Amount must be greater than 0'),
  body('purpose')
    .optional()
    .isIn(['wallet_topup', 'ticket']).withMessage('Invalid payment purpose'),
  handleValidation,
];

const validateVerifyPayment = [
  body('razorpay_order_id').notEmpty().withMessage('Order ID required'),
  body('razorpay_payment_id').notEmpty().withMessage('Payment ID required'),
  body('razorpay_signature').notEmpty().withMessage('Signature required'),
  handleValidation,
];

// ── Complaint validations ─────────────────────────

const validateComplaint = [
  body('subject').notEmpty().withMessage('Subject is required').trim(),
  body('description')
    .notEmpty().withMessage('Description is required')
    .isLength({ min: 10 }).withMessage('Description must be at least 10 characters'),
  handleValidation,
];

module.exports = {
  validateRequestOtp,
  validateVerifyOtp,
  validateSetPassword,
  validatePassengerLogin,
  validateOfficerLogin,
  validateRegisterStaff,
  validateRefreshToken,
  validateBusQuery,
  validateAddBus,
  validateBookTicket,
  validateTicketNumber,
  validateInitiatePayment,
  validateVerifyPayment,
  validateComplaint,
};

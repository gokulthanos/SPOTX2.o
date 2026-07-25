// server/controllers/payment.controller.js
// ─────────────────────────────────────────────────
// Payment Controller
// Handles Razorpay order creation, payment verification,
// and wallet operations.
// ─────────────────────────────────────────────────
const paymentService = require('../services/payment.service');
const { getAll } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');

/**
 * POST /api/v1/payments/initiate
 * Create a Razorpay order.
 *
 * Body: { amount, purpose }
 */
const initiatePayment = async (req, res, next) => {
  try {
    const { amount, purpose = 'wallet_topup', ticketId } = req.body;
    const passengerId = req.user.id;

    const order = await paymentService.createOrder({ amount, passengerId, purpose, ticketId });

    return sendSuccess(res, 'Payment order created', {
      orderId: order.id,
      amount: order.amount, // paise
      currency: order.currency,
      keyId: paymentService.RAZORPAY_KEY_ID,
      isLive: paymentService.RAZORPAY_IS_LIVE,
      mock: order.mock || false,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/payments/verify
 * Verify Razorpay payment signature and credit wallet if top-up.
 *
 * Body: { razorpay_order_id, razorpay_payment_id, razorpay_signature, purpose }
 */
const verifyPayment = async (req, res, next) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, purpose = 'wallet_topup' } = req.body;
    const passengerId = req.user.id;

    const result = await paymentService.verifyPayment({
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      passengerId,
      purpose,
    });

    if (!result.verified) {
      return sendError(res, 'Payment verification failed. Please contact support.', 400);
    }

    return sendSuccess(res, 'Payment verified successfully', {
      walletBalance: result.walletBalance,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/payments/wallet
 * Get wallet balance and transaction history for authenticated passenger.
 */
const getWallet = async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    const { limit = 20 } = req.query;

    const wallet = await paymentService.getWalletDetails(passengerId, Number(limit));
    return sendSuccess(res, 'Wallet details fetched', wallet);
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/payments/history
 * Get payment history for authenticated passenger.
 */
const getPaymentHistory = async (req, res, next) => {
  try {
    const passengerId = req.user.id;

    const payments = await getAll(
      `SELECT p.*, t.ticket_number
       FROM payments p
       LEFT JOIN tickets t ON p.ticket_id = t.id
       WHERE p.passenger_id = ?
       ORDER BY p.created_at DESC
       LIMIT 30`,
      [passengerId]
    );

    return sendSuccess(res, 'Payment history fetched', payments);
  } catch (err) {
    next(err);
  }
};

module.exports = { initiatePayment, verifyPayment, getWallet, getPaymentHistory };

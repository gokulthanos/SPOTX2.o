// server/services/payment.service.js
// ─────────────────────────────────────────────────
// Razorpay Payment Service
//
// Handles:
//   - Creating Razorpay orders (wallet top-up / ticket payment)
//   - Verifying payment signatures (HMAC-SHA256)
//   - Recording payments to DB
//   - Wallet top-up on success
// ─────────────────────────────────────────────────
const crypto = require('crypto');
const Razorpay = require('razorpay');
const { RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET } = require('../config/env');
const { getOne, getAll, run, lastInsertId } = require('../db');
const logger = require('../utils/logger');

// Initialize Razorpay instance (only if keys are configured)
let razorpay = null;
const isLiveMode = RAZORPAY_KEY_ID.startsWith('rzp_live_');
const isTestMode = RAZORPAY_KEY_ID.startsWith('rzp_test_');
const isMockMode = !RAZORPAY_KEY_ID || (!isLiveMode && !isTestMode);

if (!isMockMode) {
  razorpay = new Razorpay({
    key_id: RAZORPAY_KEY_ID,
    key_secret: RAZORPAY_KEY_SECRET,
  });
  logger.info(`[PAYMENT] Razorpay initialized in ${isLiveMode ? 'LIVE' : 'TEST'} mode`);
  if (isLiveMode) {
    logger.warn('[PAYMENT] ⚠️  LIVE payment mode is active. Real money transactions will occur.');
  }
} else {
  logger.warn('[PAYMENT] Razorpay keys not configured — payment features will be mocked (dev mode)');
}

// ── Order Creation ────────────────────────────────

/**
 * Create a Razorpay order for wallet top-up or ticket payment.
 *
 * @param {Object} options
 * @param {number} options.amount - Amount in Rupees (will be converted to paise)
 * @param {number} options.passengerId - Passenger placing the order
 * @param {string} options.purpose - 'wallet_topup' | 'ticket'
 * @param {number} [options.ticketId] - Only required for ticket payment
 * @returns {Object} Razorpay order object
 */
const createOrder = async ({ amount, passengerId, purpose, ticketId = null }) => {
  const amountInPaise = Math.round(amount * 100);
  const receiptId = `spotx_${purpose}_${Date.now()}`;

  if (isMockMode) {
    // Mock order when Razorpay is not configured (dev/test)
    logger.warn(`[PAYMENT] Mock order created: ₹${amount} for passenger ${passengerId}`);
    const mockOrderId = `order_mock_${crypto.randomBytes(8).toString('hex')}`;
    // Record pending payment
    await run(
      `INSERT INTO payments (passenger_id, ticket_id, amount, method, razorpay_order_id, status)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [passengerId, ticketId, amount, 'razorpay', mockOrderId, 'pending']
    );
    return {
      id: mockOrderId,
      amount: amountInPaise,
      currency: 'INR',
      receipt: receiptId,
      mock: true,
    };
  }

  const order = await razorpay.orders.create({
    amount: amountInPaise,
    currency: 'INR',
    receipt: receiptId,
    notes: {
      passengerId: String(passengerId),
      purpose,
      ticketId: String(ticketId || ''),
    },
  });

  // Record payment as pending
  await run(
    `INSERT INTO payments (passenger_id, ticket_id, amount, method, razorpay_order_id, status)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [passengerId, ticketId, amount, 'razorpay', order.id, 'pending']
  );

  logger.info(`[PAYMENT] Order created: ${order.id} — ₹${amount} — ${purpose}`);
  return order;
};

// ── Payment Verification ──────────────────────────

/**
 * Verify a Razorpay payment using HMAC-SHA256 signature.
 * On success: marks payment as 'success' and credits wallet if top-up.
 *
 * @param {Object} options
 * @param {string} options.razorpay_order_id
 * @param {string} options.razorpay_payment_id
 * @param {string} options.razorpay_signature
 * @param {number} options.passengerId
 * @param {string} options.purpose - 'wallet_topup' | 'ticket'
 * @returns {{ verified: boolean, walletBalance?: number }}
 */
const verifyPayment = async ({
  razorpay_order_id,
  razorpay_payment_id,
  razorpay_signature,
  passengerId,
  purpose,
}) => {
  // Verify HMAC-SHA256 signature
  const body = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expectedSignature = crypto
    .createHmac('sha256', RAZORPAY_KEY_SECRET)
    .update(body)
    .digest('hex');

  const signatureValid =
    isMockMode || // Skip verification in mock mode
    crypto.timingSafeEqual(
      Buffer.from(expectedSignature),
      Buffer.from(razorpay_signature)
    );

  if (!signatureValid) {
    logger.warn(`[PAYMENT] Signature mismatch for order ${razorpay_order_id}`);
    await run(
      'UPDATE payments SET status = ? WHERE razorpay_order_id = ?',
      ['failed', razorpay_order_id]
    );
    return { verified: false };
  }

  // Update payment record to success
  await run(
    `UPDATE payments
     SET status = ?, razorpay_payment_id = ?, razorpay_signature = ?
     WHERE razorpay_order_id = ?`,
    ['success', razorpay_payment_id, razorpay_signature, razorpay_order_id]
  );

  const paymentRecord = await getOne(
    'SELECT * FROM payments WHERE razorpay_order_id = ?',
    [razorpay_order_id]
  );

  let walletBalance = null;

  // If wallet top-up: credit the passenger wallet
  if (purpose === 'wallet_topup' && paymentRecord) {
    const amount = paymentRecord.amount;

    // Credit wallet
    await run(
      'UPDATE passengers SET wallet_balance = wallet_balance + ? WHERE id = ?',
      [amount, passengerId]
    );

    // Record wallet transaction
    await run(
      `INSERT INTO wallet_transactions (passenger_id, type, amount, description, reference_id)
       VALUES (?, ?, ?, ?, ?)`,
      [passengerId, 'credit', amount, 'Wallet top-up via Razorpay', razorpay_payment_id]
    );

    const passenger = await getOne('SELECT wallet_balance FROM passengers WHERE id = ?', [passengerId]);
    walletBalance = passenger?.wallet_balance;

    logger.info(`[PAYMENT] Wallet credited ₹${amount} for passenger ${passengerId}`);
  }

  return { verified: true, walletBalance };
};

// ── Wallet Deduction ──────────────────────────────

/**
 * Deduct from passenger wallet for a ticket purchase.
 * Validates sufficient balance before deducting.
 *
 * @param {number} passengerId
 * @param {number} amount
 * @param {string} description
 * @param {string} [referenceId] - Ticket number
 * @returns {{ success: boolean, newBalance: number, message?: string }}
 */
const walletDeduct = async (passengerId, amount, description, referenceId = '') => {
  const passenger = await getOne(
    'SELECT wallet_balance FROM passengers WHERE id = ?',
    [passengerId]
  );

  if (!passenger) {
    return { success: false, newBalance: 0, message: 'Passenger not found' };
  }

  if (passenger.wallet_balance < amount) {
    return {
      success: false,
      newBalance: passenger.wallet_balance,
      message: `Insufficient wallet balance. Available: ₹${passenger.wallet_balance.toFixed(2)}`,
    };
  }

  await run(
    'UPDATE passengers SET wallet_balance = wallet_balance - ? WHERE id = ?',
    [amount, passengerId]
  );

  await run(
    `INSERT INTO wallet_transactions (passenger_id, type, amount, description, reference_id)
     VALUES (?, ?, ?, ?, ?)`,
    [passengerId, 'debit', amount, description, referenceId]
  );

  const updated = await getOne('SELECT wallet_balance FROM passengers WHERE id = ?', [passengerId]);
  return { success: true, newBalance: updated.wallet_balance };
};

/**
 * Get wallet balance and recent transactions for a passenger.
 * @param {number} passengerId
 * @returns {{ balance: number, transactions: Array }}
 */
const getWalletDetails = async (passengerId, limit = 20) => {
  const passenger = await getOne(
    'SELECT wallet_balance FROM passengers WHERE id = ?',
    [passengerId]
  );

  const transactions = passenger
    ? await getAll(
        `SELECT * FROM wallet_transactions
         WHERE passenger_id = ?
         ORDER BY created_at DESC LIMIT ?`,
        [passengerId, limit]
      )
    : [];

  return {
    balance: passenger?.wallet_balance ?? 0,
    transactions,
  };
};

module.exports = {
  createOrder,
  verifyPayment,
  walletDeduct,
  getWalletDetails,
  RAZORPAY_KEY_ID,
  RAZORPAY_IS_LIVE: isLiveMode,
};

// server/controllers/payment.controller.js
// ─────────────────────────────────────────────────
// Mock Payment — Initiate & Verify
// ─────────────────────────────────────────────────
const crypto = require('crypto');
const { getOne, run, lastInsertId } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

const initiatePayment = async (req, res) => {
  try {
    const { ticket_id, method } = req.body;

    if (!ticket_id) {
      return sendError(res, 'ticket_id is required');
    }

    const ticket = await getOne('SELECT * FROM tickets WHERE id = ? AND passenger_id = ?', [
      ticket_id,
      req.user.id,
    ]);

    if (!ticket) {
      return sendError(res, 'Ticket not found', 404);
    }

    const mock_transaction_id = 'MOCK_' + crypto.randomBytes(8).toString('hex').toUpperCase();

    await run(
      'INSERT INTO payments (ticket_id, passenger_id, amount, method, status, mock_transaction_id) VALUES (?, ?, ?, ?, ?, ?)',
      [ticket_id, req.user.id, ticket.total_amount, method || 'upi', 'pending', mock_transaction_id]
    );

    const paymentId = await lastInsertId();

    logger.info(`[PAYMENT] Initiated: ticket=${ticket_id}, mock_txn=${mock_transaction_id}`);

    return sendSuccess(res, 'Payment initiated', {
      payment_id: paymentId,
      ticket_id,
      amount: ticket.total_amount,
      method: method || 'upi',
      mock_transaction_id,
    });
  } catch (err) {
    logger.error(`[PAYMENT] Initiate error: ${err.message}`);
    return sendError(res, 'Failed to initiate payment', 500);
  }
};

const verifyPayment = async (req, res) => {
  try {
    const { payment_id, ticket_id } = req.body;

    if (!payment_id || !ticket_id) {
      return sendError(res, 'payment_id and ticket_id are required');
    }

    const payment = await getOne('SELECT * FROM payments WHERE id = ? AND ticket_id = ? AND passenger_id = ?', [
      payment_id,
      ticket_id,
      req.user.id,
    ]);

    if (!payment) {
      return sendError(res, 'Payment not found', 404);
    }

    await run('UPDATE payments SET status = ? WHERE id = ?', ['completed', payment_id]);
    await run('UPDATE tickets SET payment_status = ? WHERE id = ?', ['completed', ticket_id]);

    logger.info(`[PAYMENT] Verified: payment=${payment_id}, ticket=${ticket_id}`);

    return sendSuccess(res, 'Payment verified', {
      payment_id,
      ticket_id,
      status: 'completed',
      mock_transaction_id: payment.mock_transaction_id,
    });
  } catch (err) {
    logger.error(`[PAYMENT] Verify error: ${err.message}`);
    return sendError(res, 'Failed to verify payment', 500);
  }
};

module.exports = {
  initiatePayment,
  verifyPayment,
};

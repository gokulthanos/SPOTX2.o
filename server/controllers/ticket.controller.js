// server/controllers/ticket.controller.js
// ─────────────────────────────────────────────────
// Ticket Controller
// Handles ticket booking, verification, and history.
// ─────────────────────────────────────────────────
const crypto = require('crypto');
const { getOne, getAll, run, lastInsertId } = require('../db');
const { walletDeduct } = require('../services/payment.service');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Generate a unique 8-character alphanumeric ticket number.
 */
const generateTicketNumber = () => {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
};

/**
 * POST /api/v1/tickets
 * Book a ticket. Supports wallet and Razorpay payment methods.
 *
 * Body: { busId, busNumber, fromStop, toStop, totalFare, passengers[], paymentMethod }
 */
const bookTicket = async (req, res, next) => {
  try {
    const {
      busId,
      busNumber,
      fromStop,
      toStop,
      totalFare,
      passengers = [],
      paymentMethod = 'wallet',
      paymentId = '',
    } = req.body;

    const passengerId = req.user?.id || null;

    // If paying by wallet, deduct now
    if (paymentMethod === 'wallet' && passengerId) {
      const deductResult = await walletDeduct(
        passengerId,
        totalFare,
        `Bus ticket: ${fromStop} → ${toStop}`,
        busNumber
      );

      if (!deductResult.success) {
        return sendError(res, deductResult.message || 'Wallet payment failed', 402);
      }
    }

    // Generate ticket
    const ticketNumber = generateTicketNumber();
    const startTime = new Date().toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    });

    // Insert ticket record
    await run(
      `INSERT INTO tickets 
       (ticket_number, passenger_id, bus_id, from_stop, to_stop, total_fare, 
        status, payment_method, payment_id, start_time)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        ticketNumber, passengerId, busId || 0, fromStop, toStop,
        totalFare, 'booked', paymentMethod, paymentId, startTime,
      ]
    );

    const ticketId = await lastInsertId();

    // Insert each passenger
    for (const p of passengers) {
      await run(
        `INSERT INTO ticket_passengers (ticket_id, name, age, gender, concession_type)
         VALUES (?, ?, ?, ?, ?)`,
        [ticketId, p.name || '', p.age || 0, p.gender || '', p.concessionType || 'none']
      );
    }

    // Record payment
    await run(
      `INSERT INTO payments (passenger_id, ticket_id, amount, method, status, razorpay_payment_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [passengerId, ticketId, totalFare, paymentMethod, 'success', paymentId]
    );

    logger.info(`[TICKET] Booked #${ticketNumber} — ${fromStop} → ${toStop} — ₹${totalFare}`);

    return sendSuccess(res, 'Ticket booked successfully', {
      ticketNumber,
      busId,
      busNumber,
      fromStop,
      toStop,
      totalFare,
      startTime,
      passengers,
      paymentMethod,
      createdAt: new Date().toISOString(),
    }, 201);
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/tickets/:ticketNumber
 * Get ticket details by ticket number (for QR verification).
 */
const getTicket = async (req, res, next) => {
  try {
    const ticket = await getOne(
      'SELECT * FROM tickets WHERE ticket_number = ?',
      [req.params.ticketNumber.toUpperCase()]
    );

    if (!ticket) return sendError(res, 'Ticket not found', 404);

    // Fetch passengers for this ticket
    const passengers = await getAll(
      'SELECT * FROM ticket_passengers WHERE ticket_id = ?',
      [ticket.id]
    );

    // Fetch bus data
    let busData = null;
    if (ticket.bus_id) {
      const bus = await getOne('SELECT * FROM buses WHERE id = ?', [ticket.bus_id]);
      if (bus) {
        busData = {
          id: bus.id,
          busNumber: bus.bus_number,
          busType: bus.bus_type,
          travelStatus: bus.travel_status,
          delayMinutes: bus.delay_minutes,
        };
      }
    }

    return sendSuccess(res, 'Ticket found', {
      ticketNumber: ticket.ticket_number,
      ticketId: ticket.ticket_number,
      busId: ticket.bus_id,
      busNumber: ticket.bus_number || busData?.busNumber || '',
      fromStop: ticket.from_stop,
      toStop: ticket.to_stop,
      totalFare: ticket.total_fare,
      fare: ticket.total_fare,
      status: ticket.status,
      paymentMethod: ticket.payment_method,
      startTime: ticket.start_time,
      createdAt: ticket.created_at,
      timestamp: ticket.created_at,
      passengers,
      bus: busData,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/tickets/passenger/me
 * Get all tickets for the authenticated passenger.
 */
const getMyTickets = async (req, res, next) => {
  try {
    const passengerId = req.user.id;

    const tickets = await getAll(
      `SELECT *
       FROM tickets
       WHERE passenger_id = ?
       ORDER BY created_at DESC
       LIMIT 50`,
      [passengerId]
    );

    const parsed = await Promise.all(
      tickets.map(async (t) => {
        const passengers = await getAll(
          'SELECT name, age, gender FROM ticket_passengers WHERE ticket_id = ?',
          [t.id]
        );
        return {
          ticketNumber: t.ticket_number,
          fromStop: t.from_stop,
          toStop: t.to_stop,
          totalFare: t.total_fare,
          status: t.status,
          startTime: t.start_time,
          paymentMethod: t.payment_method,
          createdAt: t.created_at,
          passengers,
        };
      })
    );

    return sendSuccess(res, 'Tickets fetched', parsed);
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /api/v1/tickets/:ticketNumber/verify
 * Mark ticket as verified by an officer (after QR scan).
 * Requires STAFF or ADMIN role.
 */
const verifyTicket = async (req, res, next) => {
  try {
    const officerId = req.user.id;
    const { ticketNumber } = req.params;

    const ticket = await getOne(
      'SELECT * FROM tickets WHERE ticket_number = ?',
      [ticketNumber.toUpperCase()]
    );

    if (!ticket) return sendError(res, 'Ticket not found', 404);
    if (ticket.status === 'verified') {
      return sendError(res, 'Ticket already verified', 409);
    }
    if (ticket.status === 'expired' || ticket.status === 'cancelled') {
      return sendError(res, `Ticket is ${ticket.status}`, 400);
    }

    await run(
      `UPDATE tickets SET status = 'verified', verified_by = ?, verified_at = NOW()
       WHERE ticket_number = ?`,
      [officerId, ticketNumber.toUpperCase()]
    );

    logger.info(`[TICKET] Verified #${ticketNumber} by officer ${officerId}`);

    return sendSuccess(res, 'Ticket verified successfully', {
      ticketNumber,
      status: 'verified',
      verifiedAt: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/tickets/officer/history
 * Get tickets verified by this officer today.
 */
const getOfficerVerifications = async (req, res, next) => {
  try {
    const officerId = req.user.id;
    const { date } = req.query; // YYYY-MM-DD, defaults to today

    const targetDate = date || new Date().toISOString().split('T')[0];

    const tickets = await getAll(
      `SELECT ticket_number, from_stop, to_stop, total_fare, verified_at, passenger_id
       FROM tickets
       WHERE verified_by = ?
         AND DATE(verified_at) = ?
       ORDER BY verified_at DESC`,
      [officerId, targetDate]
    );

    return sendSuccess(res, 'Verification history fetched', {
      date: targetDate,
      count: tickets.length,
      tickets,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  bookTicket,
  getTicket,
  getMyTickets,
  verifyTicket,
  getOfficerVerifications,
};

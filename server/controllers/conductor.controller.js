// server/controllers/conductor.controller.js
// ─────────────────────────────────────────────────
// Conductor Operations — Select Bus, Verify Ticket, Stats
// ─────────────────────────────────────────────────
const { getOne, getAll, run, lastInsertId } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

const conductorBusSelection = new Map();

const selectBusRoute = async (req, res) => {
  try {
    const { bus_id } = req.body;

    if (!bus_id) {
      return sendError(res, 'bus_id is required');
    }

    const bus = await getOne(
      `SELECT b.*, r.route_number, r.name AS route_name
       FROM buses b JOIN routes r ON b.route_id = r.id
       WHERE b.id = ? AND b.is_active = 1`,
      [bus_id]
    );

    if (!bus) {
      return sendError(res, 'Bus not found or inactive', 404);
    }

    conductorBusSelection.set(req.user.id, {
      bus_id: bus.id,
      bus_number: bus.bus_number,
      route_number: bus.route_number,
      route_name: bus.route_name,
      selected_at: new Date().toISOString(),
    });

    return sendSuccess(res, 'Bus route selected', {
      bus_id: bus.id,
      bus_number: bus.bus_number,
      route_number: bus.route_number,
      route_name: bus.route_name,
    });
  } catch (err) {
    logger.error(`[CONDUCTOR] Select bus error: ${err.message}`);
    return sendError(res, 'Failed to select bus route', 500);
  }
};

const verifyTicket = async (req, res) => {
  try {
    const { pnr } = req.body;

    if (!pnr) {
      return sendError(res, 'PNR is required');
    }

    const ticket = await getOne('SELECT * FROM tickets WHERE pnr = ?', [pnr]);

    if (!ticket) {
      return sendError(res, 'Ticket not found', 404);
    }

    let result;
    let message;

    if (ticket.ticket_status === 'active') {
      result = 'valid';
      message = 'Ticket is valid';
      await run('UPDATE tickets SET ticket_status = ? WHERE id = ?', ['used', ticket.id]);
    } else if (ticket.ticket_status === 'used') {
      result = 'invalid';
      message = 'Ticket already used';
    } else {
      result = 'expired';
      message = `Ticket is ${ticket.ticket_status}`;
    }

    await run(
      'INSERT INTO ticket_verifications (ticket_id, conductor_id, result) VALUES (?, ?, ?)',
      [ticket.id, req.user.id, result]
    );

    logger.info(`[CONDUCTOR] Verified PNR=${pnr}, result=${result}, conductor=${req.user.id}`);

    return sendSuccess(res, message, {
      pnr,
      result,
      ticket: {
        passenger_name: ticket.passenger_name,
        bus_number: ticket.bus_number,
        boarding_stop_name: ticket.boarding_stop_name,
        destination_stop_name: ticket.destination_stop_name,
        fare: ticket.fare,
        total_amount: ticket.total_amount,
        journey_date: ticket.journey_date,
        journey_time: ticket.journey_time,
        ticket_status: ticket.ticket_status,
      },
    });
  } catch (err) {
    logger.error(`[CONDUCTOR] Verify ticket error: ${err.message}`);
    return sendError(res, 'Failed to verify ticket', 500);
  }
};

const todayStats = async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];

    const verifications = await getAll(
      `SELECT COUNT(*) AS total_verified,
              SUM(CASE WHEN result = 'valid' THEN 1 ELSE 0 END) AS valid_count,
              SUM(CASE WHEN result = 'invalid' THEN 1 ELSE 0 END) AS invalid_count,
              SUM(CASE WHEN result = 'expired' THEN 1 ELSE 0 END) AS expired_count
       FROM ticket_verifications
       WHERE conductor_id = ? AND DATE(verified_at) = ?`,
      [req.user.id, today]
    );

    let totalRevenue = 0;
    const selection = conductorBusSelection.get(req.user.id);
    if (selection) {
      const revenue = await getOne(
        `SELECT COALESCE(SUM(t.total_amount), 0) AS revenue
         FROM ticket_verifications tv
         JOIN tickets t ON tv.ticket_id = t.id
         WHERE tv.conductor_id = ? AND tv.result = 'valid' AND DATE(tv.verified_at) = ? AND t.bus_id = ?`,
        [req.user.id, today, selection.bus_id]
      );
      totalRevenue = revenue ? revenue.revenue : 0;
    }

    return sendSuccess(res, 'Today stats fetched', {
      date: today,
      bus: selection || null,
      verifications: verifications[0] || { total_verified: 0, valid_count: 0, invalid_count: 0, expired_count: 0 },
      total_revenue: totalRevenue,
    });
  } catch (err) {
    logger.error(`[CONDUCTOR] Stats error: ${err.message}`);
    return sendError(res, 'Failed to fetch stats', 500);
  }
};

module.exports = {
  selectBusRoute,
  verifyTicket,
  todayStats,
};

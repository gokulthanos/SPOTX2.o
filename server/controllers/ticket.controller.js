// server/controllers/ticket.controller.js
// ─────────────────────────────────────────────────
// Ticket Operations — Book, My Tickets, Detail
// ─────────────────────────────────────────────────
const { getOne, getAll, run, lastInsertId } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const { generatePnr } = require('./auth.controller');
const logger = require('../utils/logger');

const bookTicket = async (req, res) => {
  try {
    const { bus_id, boarding_stop_id, destination_stop_id, passenger_name, passenger_dob, passenger_gender, payment_method } = req.body;

    if (!bus_id || !boarding_stop_id || !destination_stop_id) {
      return sendError(res, 'bus_id, boarding_stop_id, and destination_stop_id are required');
    }

    if (Number(boarding_stop_id) === Number(destination_stop_id)) {
      return sendError(res, 'Boarding and destination stops must be different');
    }

    const bus = await getOne(
      'SELECT b.*, r.name AS route_name FROM buses b JOIN routes r ON b.route_id = r.id WHERE b.id = ? AND b.is_active = 1',
      [bus_id]
    );
    if (!bus) {
      return sendError(res, 'Bus not found or inactive', 404);
    }

    const boardingBS = await getOne(
      'SELECT stop_sequence, fare_from_origin FROM bus_stops WHERE bus_id = ? AND stop_id = ?',
      [bus_id, boarding_stop_id]
    );
    const destBS = await getOne(
      'SELECT stop_sequence, fare_from_origin FROM bus_stops WHERE bus_id = ? AND stop_id = ?',
      [bus_id, destination_stop_id]
    );

    if (!boardingBS || !destBS) {
      return sendError(res, 'One or both stops are not on this bus route');
    }

    if (boardingBS.stop_sequence >= destBS.stop_sequence) {
      return sendError(res, 'Boarding stop must come before destination stop');
    }

    const fare = parseFloat((destBS.fare_from_origin - boardingBS.fare_from_origin).toFixed(2));
    const convenience_fee = parseFloat((fare * 0.05).toFixed(2));
    const platform_fee = 1.0;
    const total_amount = parseFloat((fare + convenience_fee + platform_fee).toFixed(2));

    const boardingStop = await getOne('SELECT name FROM stops WHERE id = ?', [boarding_stop_id]);
    const destStop = await getOne('SELECT name FROM stops WHERE id = ?', [destination_stop_id]);

    const pnr = generatePnr();
    const qr_data = JSON.stringify({
      pnr,
      bus_number: bus.bus_number,
      route: bus.route_name,
      boarding: boardingStop ? boardingStop.name : '',
      destination: destStop ? destStop.name : '',
      fare: total_amount,
      date: new Date().toISOString().split('T')[0],
    });

    const passenger = await getOne('SELECT full_name, dob, gender FROM passengers WHERE id = ?', [req.user.id]);
    const name = passenger_name || (passenger ? passenger.full_name : '');
    const dob = passenger_dob || (passenger ? passenger.dob : null);
    const gender = passenger_gender || (passenger ? passenger.gender : '');

    await run(
      `INSERT INTO tickets (pnr, passenger_id, bus_id, boarding_stop_id, destination_stop_id,
        passenger_name, passenger_dob, passenger_gender, route_name, bus_number,
        boarding_stop_name, destination_stop_name, fare, convenience_fee, platform_fee,
        total_amount, payment_method, payment_status, ticket_status, qr_data, journey_date, journey_time)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'active', ?, CURDATE(), ?)`,
      [
        pnr, req.user.id, bus_id, boarding_stop_id, destination_stop_id,
        name, dob, gender, bus.route_name, bus.bus_number,
        boardingStop ? boardingStop.name : '', destStop ? destStop.name : '',
        fare, convenience_fee, platform_fee, total_amount,
        payment_method || 'upi', qr_data, bus.departure_time,
      ]
    );

    const ticketId = await lastInsertId();

    const ticket = await getOne('SELECT * FROM tickets WHERE id = ?', [ticketId]);

    logger.info(`[TICKET] Booked: PNR=${pnr}, passenger=${req.user.id}, bus=${bus.bus_number}, fare=${total_amount}`);

    return sendSuccess(res, 'Ticket booked successfully', ticket, 201);
  } catch (err) {
    logger.error(`[TICKET] Book error: ${err.message}`);
    return sendError(res, 'Failed to book ticket', 500);
  }
};

const getMyTickets = async (req, res) => {
  try {
    const { status } = req.query;
    let sql = 'SELECT * FROM tickets WHERE passenger_id = ?';
    const params = [req.user.id];

    if (status) {
      sql += ' AND ticket_status = ?';
      params.push(status);
    }

    sql += ' ORDER BY created_at DESC';

    const tickets = await getAll(sql, params);
    return sendSuccess(res, 'Tickets fetched', tickets);
  } catch (err) {
    logger.error(`[TICKET] My tickets error: ${err.message}`);
    return sendError(res, 'Failed to fetch tickets', 500);
  }
};

const getTicketDetail = async (req, res) => {
  try {
    const ticket = await getOne('SELECT * FROM tickets WHERE id = ? AND passenger_id = ?', [
      req.params.id,
      req.user.id,
    ]);

    if (!ticket) {
      return sendError(res, 'Ticket not found', 404);
    }

    return sendSuccess(res, 'Ticket detail fetched', ticket);
  } catch (err) {
    logger.error(`[TICKET] Detail error: ${err.message}`);
    return sendError(res, 'Failed to fetch ticket detail', 500);
  }
};

module.exports = {
  bookTicket,
  getMyTickets,
  getTicketDetail,
};

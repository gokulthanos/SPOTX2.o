// server/controllers/admin.controller.js
// ─────────────────────────────────────────────────
// Admin & Government Dashboard Controller
//
// Admin (ADMIN role): Bus/route/officer management
// Government (GOV/ADMIN role): Analytics & reports
// ─────────────────────────────────────────────────
const { getOne, getAll, run } = require('../db');
const { hashPassword } = require('../services/auth.service');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

// ── Dashboard Analytics ───────────────────────────

/**
 * GET /api/v1/admin/dashboard
 * System-wide statistics for government dashboard.
 */
const getDashboard = async (req, res, next) => {
  try {
    const today = new Date().toISOString().split('T')[0];

    const totalBuses = (await getOne('SELECT COUNT(*) as c FROM buses'))?.c || 0;
    const activeBuses = (await getOne("SELECT COUNT(*) as c FROM buses WHERE travel_status = 'Running'"))?.c || 0;
    const delayedBuses = (await getOne("SELECT COUNT(*) as c FROM buses WHERE delay_minutes > 0 AND travel_status != 'Not Started'"))?.c || 0;

    const todayTickets = (await getOne(
      "SELECT COUNT(*) as c FROM tickets WHERE DATE(created_at) = ?", [today]
    ))?.c || 0;

    const todayRevenue = (await getOne(
      "SELECT COALESCE(SUM(total_fare), 0) as total FROM tickets WHERE DATE(created_at) = ?", [today]
    ))?.total || 0;

    const totalPassengers = (await getOne('SELECT COUNT(*) as c FROM passengers WHERE is_active = 1'))?.c || 0;
    const totalOfficers = (await getOne("SELECT COUNT(*) as c FROM users WHERE role = 'STAFF' AND is_active = 1"))?.c || 0;

    const verifiedToday = (await getOne(
      "SELECT COUNT(*) as c FROM tickets WHERE DATE(verified_at) = ? AND status = 'verified'", [today]
    ))?.c || 0;

    const finesIssuedToday = (await getOne(
      "SELECT COUNT(*) as c FROM fines WHERE DATE(created_at) = ?", [today]
    ))?.c || 0;

    const fineAmountToday = (await getOne(
      "SELECT COALESCE(SUM(amount), 0) as total FROM fines WHERE DATE(created_at) = ? AND status = 'paid'", [today]
    ))?.total || 0;

    // Live bus list
    const liveBuses = await getAll(
      `SELECT id, bus_number, bus_type, travel_status, delay_minutes, current_occupancy, capacity, city
       FROM buses WHERE travel_status = 'Running'
       ORDER BY delay_minutes DESC LIMIT 20`
    );

    // Recent complaints
    const recentComplaints = await getAll(
      `SELECT id, subject, status, created_at FROM complaints
       ORDER BY created_at DESC LIMIT 5`
    );

    return sendSuccess(res, 'Dashboard data fetched', {
      overview: {
        totalBuses,
        activeBuses,
        delayedBuses,
        totalPassengers,
        totalOfficers,
      },
      today: {
        tickets: todayTickets,
        revenue: todayRevenue,
        verificationsCount: verifiedToday,
        finesIssued: finesIssuedToday,
        fineRevenue: fineAmountToday,
      },
      liveBuses,
      recentComplaints,
    });
  } catch (err) {
    next(err);
  }
};

// ── Officer Management ────────────────────────────

/**
 * GET /api/v1/admin/officers
 * List all officers/staff.
 */
const getOfficers = async (req, res, next) => {
  try {
    const officers = await getAll(
      'SELECT id, name, email, role, is_active, created_at FROM users ORDER BY created_at DESC'
    );
    return sendSuccess(res, 'Officers fetched', officers);
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /api/v1/admin/officers/:id
 * Enable / disable / update officer.
 */
const updateOfficer = async (req, res, next) => {
  try {
    const officerId = Number(req.params.id);
    const officer = await getOne('SELECT id FROM users WHERE id = ?', [officerId]);
    if (!officer) return sendError(res, 'Officer not found', 404);

    const { name, role, isActive } = req.body;
    await run(
      `UPDATE users SET
         name = COALESCE(?, name),
         role = COALESCE(?, role),
         is_active = COALESCE(?, is_active)
       WHERE id = ?`,
      [name, role, isActive !== undefined ? (isActive ? 1 : 0) : null, officerId]
    );

    logger.info(`[ADMIN] Officer ${officerId} updated`);
    return sendSuccess(res, 'Officer updated');
  } catch (err) {
    next(err);
  }
};

// ── Route Management ──────────────────────────────

/**
 * GET /api/v1/admin/routes
 * List all routes.
 */
const getRoutes = async (req, res, next) => {
  try {
    const routes = await getAll(
      `SELECT r.*,
              sf.name as from_stop_name,
              st.name as to_stop_name
       FROM routes r
       LEFT JOIN stops sf ON r.from_stop_id = sf.id
       LEFT JOIN stops st ON r.to_stop_id = st.id
       ORDER BY r.route_number`
    );
    return sendSuccess(res, 'Routes fetched', routes);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/admin/routes
 * Add a new route.
 */
const addRoute = async (req, res, next) => {
  try {
    const { routeNumber, name, fromStopId, toStopId, distanceKm, baseFare } = req.body;
    if (!routeNumber || !name) return sendError(res, 'Route number and name are required', 400);

    await run(
      `INSERT INTO routes (route_number, name, from_stop_id, to_stop_id, distance_km, base_fare)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [routeNumber, name, fromStopId || null, toStopId || null, distanceKm || 0, baseFare || 0]
    );

    logger.info(`[ADMIN] Route added: ${routeNumber} — ${name}`);
    return sendSuccess(res, 'Route added successfully', {}, 201);
  } catch (err) {
    next(err);
  }
};

// ── Stop Management ───────────────────────────────

/**
 * GET /api/v1/admin/stops
 * List all stops, optionally filtered by city.
 */
const getStops = async (req, res, next) => {
  try {
    const { city, query } = req.query;

    let sql = `SELECT s.*, c.name as city_name
               FROM stops s
               LEFT JOIN cities c ON s.city_id = c.id
               WHERE 1=1`;
    const params = [];

    if (city) {
      sql += ' AND LOWER(c.name) = LOWER(?)';
      params.push(city);
    }
    if (query) {
      sql += ' AND LOWER(s.name) LIKE LOWER(?)';
      params.push(`%${query}%`);
    }

    sql += ' ORDER BY s.name ASC LIMIT 50';

    const stops = await getAll(sql, params);
    return sendSuccess(res, 'Stops fetched', stops);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/admin/stops
 * Add a new stop.
 */
const addStop = async (req, res, next) => {
  try {
    const { name, cityId, lat, lon, stopType = 'stop' } = req.body;
    if (!name) return sendError(res, 'Stop name is required', 400);

    await run(
      'INSERT INTO stops (name, city_id, lat, lon, stop_type) VALUES (?, ?, ?, ?, ?)',
      [name, cityId || null, lat || 0, lon || 0, stopType]
    );

    return sendSuccess(res, 'Stop added successfully', {}, 201);
  } catch (err) {
    next(err);
  }
};

// ── Fare Management ───────────────────────────────

/**
 * PUT /api/v1/admin/routes/:id/fare
 * Update fare for a route.
 */
const updateFare = async (req, res, next) => {
  try {
    const routeId = Number(req.params.id);
    const { baseFare } = req.body;

    if (!baseFare || baseFare <= 0) {
      return sendError(res, 'Valid fare amount required', 400);
    }

    await run('UPDATE routes SET base_fare = ? WHERE id = ?', [baseFare, routeId]);
    logger.info(`[ADMIN] Fare updated for route ${routeId}: ₹${baseFare}`);
    return sendSuccess(res, 'Fare updated successfully');
  } catch (err) {
    next(err);
  }
};

// ── Fines Management ──────────────────────────────

/**
 * POST /api/v1/admin/fines
 * Issue a fine (Officer action).
 */
const issueFine = async (req, res, next) => {
  try {
    const { passengerContact, busId, reason, amount = 500, ticketNumber } = req.body;
    const officerId = req.user.id;

    if (!passengerContact || !reason) {
      return sendError(res, 'Passenger contact and reason are required', 400);
    }

    await run(
      `INSERT INTO fines (passenger_contact, bus_id, issued_by, reason, amount, ticket_number)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [passengerContact, busId || null, officerId, reason, amount, ticketNumber || '']
    );

    logger.info(`[FINE] Issued ₹${amount} to ${passengerContact} by officer ${officerId}`);
    return sendSuccess(res, 'Fine issued successfully', {}, 201);
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/admin/fines
 * Get fines list. Officers see their own; admin sees all.
 */
const getFines = async (req, res, next) => {
  try {
    const { role, id } = req.user;
    const { status } = req.query;

    let sql = `SELECT f.*, u.name as officer_name
               FROM fines f
               LEFT JOIN users u ON f.issued_by = u.id
               WHERE 1=1`;
    const params = [];

    // Staff can only see their own fines
    if (role === 'STAFF') {
      sql += ' AND f.issued_by = ?';
      params.push(id);
    }
    if (status) {
      sql += ' AND f.status = ?';
      params.push(status);
    }

    sql += ' ORDER BY f.created_at DESC LIMIT 50';

    const fines = await getAll(sql, params);
    return sendSuccess(res, 'Fines fetched', fines);
  } catch (err) {
    next(err);
  }
};

// ── Cities Management ─────────────────────────────

/**
 * GET /api/v1/admin/cities
 */
const getCities = async (req, res, next) => {
  try {
    const cities = await getAll('SELECT * FROM cities ORDER BY name');
    return sendSuccess(res, 'Cities fetched', cities);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/admin/cities
 */
const addCity = async (req, res, next) => {
  try {
    const { name, state = 'Tamil Nadu', lat, lon } = req.body;
    if (!name) return sendError(res, 'City name is required', 400);

    const existing = await getOne('SELECT id FROM cities WHERE LOWER(name) = LOWER(?)', [name]);
    if (existing) return sendError(res, 'City already exists', 409);

    await run('INSERT INTO cities (name, state, lat, lon) VALUES (?, ?, ?, ?)',
      [name, state, lat || 0, lon || 0]);

    return sendSuccess(res, 'City added', {}, 201);
  } catch (err) {
    next(err);
  }
};

// ── Complaint Management ──────────────────────────

/**
 * GET /api/v1/admin/complaints
 * Get complaints (all for admin, by passenger for passenger).
 */
const getComplaints = async (req, res, next) => {
  try {
    const { role, id } = req.user;
    const { status } = req.query;

    let sql = 'SELECT * FROM complaints WHERE 1=1';
    const params = [];

    if (role === 'PASSENGER') {
      sql += ' AND passenger_id = ?';
      params.push(id);
    }
    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }

    sql += ' ORDER BY created_at DESC LIMIT 30';
    const complaints = await getAll(sql, params);
    return sendSuccess(res, 'Complaints fetched', complaints);
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/admin/complaints
 * Submit a complaint (passenger).
 */
const submitComplaint = async (req, res, next) => {
  try {
    const { subject, description, busId, ticketNumber } = req.body;
    const passengerId = req.user.id;

    await run(
      `INSERT INTO complaints (passenger_id, bus_id, ticket_number, subject, description)
       VALUES (?, ?, ?, ?, ?)`,
      [passengerId, busId || null, ticketNumber || '', subject, description]
    );

    logger.info(`[COMPLAINT] Submitted by passenger ${passengerId}: ${subject}`);
    return sendSuccess(res, 'Complaint submitted successfully', {}, 201);
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /api/v1/admin/complaints/:id
 * Update complaint status (admin).
 */
const updateComplaintStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const validStatuses = ['open', 'in_review', 'resolved', 'closed'];

    if (!validStatuses.includes(status)) {
      return sendError(res, `Status must be one of: ${validStatuses.join(', ')}`, 400);
    }

    await run('UPDATE complaints SET status = ? WHERE id = ?', [status, id]);
    return sendSuccess(res, 'Complaint status updated');
  } catch (err) {
    next(err);
  }
};

// ── Reports ───────────────────────────────────────

/**
 * GET /api/v1/admin/reports/revenue
 * Daily revenue for the last 7 days.
 */
const getRevenueReport = async (req, res, next) => {
  try {
    const { days = 7 } = req.query;

    const report = await getAll(
      `SELECT DATE(created_at) as date,
              COUNT(*) as tickets,
              SUM(total_fare) as revenue
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY DATE(created_at)
       ORDER BY date DESC`,
      [Number(days)]
    );

    return sendSuccess(res, 'Revenue report fetched', report);
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getDashboard,
  getOfficers,
  updateOfficer,
  getRoutes,
  addRoute,
  getStops,
  addStop,
  updateFare,
  issueFine,
  getFines,
  getCities,
  addCity,
  getComplaints,
  submitComplaint,
  updateComplaintStatus,
  getRevenueReport,
};

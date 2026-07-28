// server/controllers/bus.controller.js
// ─────────────────────────────────────────────────
// Bus Controller
// Handles bus search, details, CRUD (admin), and
// stop-to-stop route matching.
// ─────────────────────────────────────────────────
const { getOne, getAll, run, lastInsertId } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Helper: parse stops JSON blob from bus record.
 */
const parseStops = (raw) => {
  try {
    return JSON.parse(raw || '[]');
  } catch {
    return [];
  }
};

/**
 * Helper: serialize a bus DB row to API response shape.
 */
const serializeBus = (b) => ({
  id: b.id,
  busNumber: b.bus_number,
  busType: b.bus_type,
  capacity: b.capacity,
  currentOccupancy: b.current_occupancy,
  occupancyPercent: b.capacity ? Math.round((b.current_occupancy / b.capacity) * 100) : 0,
  travelStatus: b.travel_status,
  delayMinutes: b.delay_minutes,
  city: b.city,
  lat: b.lat,
  lon: b.lon,
  // Route info (joined)
  routeId: b.route_id,
  routeName: b.route_name || b.route || '',
  routeNumber: b.route_number || '',
  fare: b.base_fare || b.fare || 0,
  // Schedule info (from join or legacy)
  from: b.from_stop || b.from || '',
  to: b.to_stop || b.to || '',
  arrivalTime: b.arrival_time || '',
  stops: parseStops(b.stops),
  currentStopIndex: b.current_stop_index || 0,
});

// ── Read Operations ───────────────────────────────

/**
 * GET /api/v1/buses
 * Query buses by city or stop-to-stop search.
 *
 * Query params:
 *   city   — filter by city name
 *   from   — boarding stop name (partial match)
 *   to     — destination stop name (partial match)
 *   type   — bus type filter
 */
const getBuses = async (req, res, next) => {
  try {
    const { city, from, to, type } = req.query;

    let sql = 'SELECT * FROM buses WHERE 1=1';
    const params = [];

    if (city) {
      sql += ' AND LOWER(city) = LOWER(?)';
      params.push(city);
    }
    // Stop-to-stop search using the legacy stops JSON blob
    // (Will be replaced with proper schedule join in Phase 2)
    if (from) {
      sql += ' AND LOWER(from_stop) LIKE LOWER(?)';
      params.push(`%${from}%`);
    }
    if (to) {
      sql += ' AND LOWER(to_stop) LIKE LOWER(?)';
      params.push(`%${to}%`);
    }
    if (type) {
      sql += ' AND LOWER(bus_type) = LOWER(?)';
      params.push(type);
    }

    sql += ' ORDER BY arrival_time ASC';

    const buses = await getAll(sql, params);
    return sendSuccess(res, 'Buses fetched', buses.map(serializeBus));
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/buses/:id
 * Get single bus details with schedule.
 */
const getBusById = async (req, res, next) => {
  try {
    const bus = await getOne('SELECT * FROM buses WHERE id = ?', [Number(req.params.id)]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    // Fetch schedule for this bus
    const schedule = await getAll(
      `SELECT sc.*, s.name as stop_name, s.lat, s.lon
       FROM schedules sc
       LEFT JOIN stops s ON sc.stop_id = s.id
       WHERE sc.bus_id = ?
       ORDER BY sc.stop_sequence ASC`,
      [bus.id]
    );

    return sendSuccess(res, 'Bus details fetched', {
      ...serializeBus(bus),
      schedule,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/buses/:id/eta
 * Get estimated time of arrival at each stop.
 */
const getBusEta = async (req, res, next) => {
  try {
    const bus = await getOne('SELECT * FROM buses WHERE id = ?', [Number(req.params.id)]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    const stops = parseStops(bus.stops);
    const delayMs = (bus.delay_minutes || 0) * 60 * 1000;

    // Compute ETA for each stop by adding delay to scheduled time
    const eta = stops.map((stop, idx) => {
      let scheduledMs = null;
      if (stop.arrival) {
        try {
          const [time, meridiem] = stop.arrival.split(' ');
          const [h, m] = time.split(':').map(Number);
          let hours = h;
          if (meridiem === 'PM' && h !== 12) hours += 12;
          if (meridiem === 'AM' && h === 12) hours = 0;
          const today = new Date();
          today.setHours(hours, m, 0, 0);
          scheduledMs = today.getTime();
        } catch { /* ignore */ }
      }

      return {
        index: idx,
        name: stop.name,
        scheduledArrival: stop.arrival,
        etaMs: scheduledMs ? scheduledMs + delayMs : null,
        isCurrentStop: idx === (bus.current_stop_index || 0),
        isCompleted: idx < (bus.current_stop_index || 0),
      };
    });

    return sendSuccess(res, 'ETA computed', {
      busId: bus.id,
      delayMinutes: bus.delay_minutes,
      travelStatus: bus.travel_status,
      eta,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/buses/:id/location
 * Update live bus GPS location (called by driver app / IoT device).
 * Requires authentication (STAFF or ADMIN).
 */
const updateBusLocation = async (req, res, next) => {
  try {
    const { lat, lon, speed, currentStopIndex, travelStatus } = req.body;
    const busId = Number(req.params.id);

    const bus = await getOne('SELECT id FROM buses WHERE id = ?', [busId]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    // Update bus current position
    await run(
      `UPDATE buses SET lat = ?, lon = ?,
       current_stop_index = COALESCE(?, current_stop_index),
       travel_status = COALESCE(?, travel_status),
       updated_at = NOW()
       WHERE id = ?`,
      [lat, lon, currentStopIndex ?? null, travelStatus ?? null, busId]
    );

    // Log location to bus_locations history
    await run(
      'INSERT INTO bus_locations (bus_id, lat, lon, speed) VALUES (?, ?, ?, ?)',
      [busId, lat, lon, speed || 0]
    );

    return sendSuccess(res, 'Location updated');
  } catch (err) {
    next(err);
  }
};

// ── Admin CRUD ────────────────────────────────────

/**
 * POST /api/v1/buses (Admin only)
 * Add a new bus to the system.
 */
const addBus = async (req, res, next) => {
  try {
    const {
      busNumber, routeId, busType = 'Normal',
      capacity = 45, city = 'Chennai',
      fromStop = '', toStop = '', arrivalTime = '',
      fare = 0, stops = [],
    } = req.body;

    const existing = await getOne('SELECT id FROM buses WHERE bus_number = ?', [busNumber]);
    if (existing) return sendError(res, 'Bus number already registered', 409);

    await run(
      `INSERT INTO buses
       (bus_number, route_id, bus_type, capacity, city, from_stop, to_stop, arrival_time, fare, stops)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [busNumber, routeId || null, busType, capacity, city, fromStop, toStop, arrivalTime, fare,
       JSON.stringify(stops)]
    );

    logger.info(`[BUS] Added: ${busNumber}`);
    return sendSuccess(res, 'Bus added successfully', { busNumber }, 201);
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/buses/:id (Admin only)
 * Update bus details.
 */
const updateBus = async (req, res, next) => {
  try {
    const busId = Number(req.params.id);
    const bus = await getOne('SELECT id FROM buses WHERE id = ?', [busId]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    const { busType, capacity, travelStatus, delayMinutes, city } = req.body;

    await run(
      `UPDATE buses SET
       bus_type = COALESCE(?, bus_type),
       capacity = COALESCE(?, capacity),
       travel_status = COALESCE(?, travel_status),
       delay_minutes = COALESCE(?, delay_minutes),
       city = COALESCE(?, city),
       updated_at = NOW()
       WHERE id = ?`,
      [busType, capacity, travelStatus, delayMinutes, city, busId]
    );

    return sendSuccess(res, 'Bus updated successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * DELETE /api/v1/buses/:id (Admin only)
 * Remove a bus from the system.
 */
const deleteBus = async (req, res, next) => {
  try {
    const busId = Number(req.params.id);
    const bus = await getOne('SELECT id FROM buses WHERE id = ?', [busId]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    await run('DELETE FROM buses WHERE id = ?', [busId]);
    logger.info(`[BUS] Deleted bus ID: ${busId}`);
    return sendSuccess(res, 'Bus removed successfully');
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getBuses,
  getBusById,
  getBusEta,
  updateBusLocation,
  addBus,
  updateBus,
  deleteBus,
};

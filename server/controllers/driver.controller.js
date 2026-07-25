// server/controllers/driver.controller.js
// ─────────────────────────────────────────────────
// Driver App Controller
// Driver login, trip management, GPS sharing, emergency
// ─────────────────────────────────────────────────
const { getOne, getAll, run } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * POST /api/v1/driver/login
 * Driver login with employee_id + password.
 */
const driverLogin = async (req, res, next) => {
  try {
    const { employeeId, password } = req.body;
    if (!employeeId || !password) {
      return sendError(res, 'Employee ID and password are required', 400);
    }

    const bcrypt = require('bcryptjs');
    const authService = require('../services/auth.service');

    const driver = await getOne(
      'SELECT * FROM users WHERE email = ? AND is_active = 1',
      [employeeId.toUpperCase()]
    );

    if (!driver) {
      return sendError(res, 'Driver account not found', 404);
    }

    let passwordValid = false;
    if (driver.password_hash && driver.password_hash.startsWith('$2')) {
      passwordValid = await bcrypt.compare(password, driver.password_hash);
    } else if (driver.password_hash === password) {
      const newHash = await bcrypt.hash(password, 12);
      await run('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, driver.id]);
      passwordValid = true;
    }

    if (!passwordValid) {
      return sendError(res, 'Invalid password', 401);
    }

    const payload = { id: driver.id, role: driver.role, email: driver.email };
    const accessToken = authService.generateAccessToken(payload);
    const refreshToken = authService.generateRefreshToken({ id: driver.id, role: driver.role });

    await run('UPDATE users SET refresh_token = ? WHERE id = ?', [refreshToken, driver.id]);

    // Fetch assigned bus if any
    const assignedBus = await getOne(
      `SELECT b.*, r.name as route_name, r.route_number
       FROM buses b
       LEFT JOIN routes r ON b.route_id = r.id
       WHERE b.driver_name = ? OR b.id IN (SELECT bus_id FROM schedules WHERE 1=1 LIMIT 1)
       LIMIT 1`,
      [driver.name]
    );

    logger.info(`[DRIVER] Logged in: ${driver.name} (${driver.email})`);
    return sendSuccess(res, 'Driver login successful', {
      driver: {
        id: driver.id,
        name: driver.name,
        email: driver.email,
        role: driver.role,
      },
      assignedBus: assignedBus ? {
        id: assignedBus.id,
        busNumber: assignedBus.bus_number,
        busType: assignedBus.bus_type,
        routeName: assignedBus.route_name,
        routeNumber: assignedBus.route_number,
        capacity: assignedBus.capacity,
        fromStop: assignedBus.from_stop,
        toStop: assignedBus.to_stop,
      } : null,
      accessToken,
      refreshToken,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/driver/profile
 * Get driver profile info.
 */
const getProfile = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await getOne(
      'SELECT id, name, email, role, is_active, created_at FROM users WHERE id = ?',
      [userId]
    );
    if (!user) return sendError(res, 'Driver not found', 404);

    const assignedBus = await getOne(
      `SELECT b.id, b.bus_number, b.bus_type, b.capacity, b.travel_status,
              r.name as route_name, r.route_number
       FROM buses b
       LEFT JOIN routes r ON b.route_id = r.id
       WHERE b.id = (SELECT assigned_bus_id FROM users WHERE id = ? AND assigned_bus_id IS NOT NULL LIMIT 1)`,
      [userId]
    );

    return sendSuccess(res, 'Driver profile', {
      ...user,
      assignedBus: assignedBus || null,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/driver/my-bus
 * Get the bus currently assigned to this driver.
 */
const getMyBus = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);

    // Find bus by driver name match
    let bus = await getOne(
      `SELECT b.*, r.name as route_name, r.route_number
       FROM buses b
       LEFT JOIN routes r ON b.route_id = r.id
       WHERE b.driver_name = ?`,
      [user?.name || '']
    );

    // Fallback: find bus by assigned route
    if (!bus) {
      bus = await getOne(
        `SELECT b.*, r.name as route_name, r.route_number
         FROM buses b
         LEFT JOIN routes r ON b.route_id = r.id
         WHERE r.id = (SELECT assigned_route_id FROM users WHERE id = ?)`,
        [userId]
      );
    }

    if (!bus) return sendError(res, 'No bus assigned to this driver', 404);

    const schedule = await getAll(
      `SELECT sc.*, s.name as stop_name, s.lat, s.lon
       FROM schedules sc
       LEFT JOIN stops s ON sc.stop_id = s.id
       WHERE sc.bus_id = ?
       ORDER BY sc.stop_sequence ASC`,
      [bus.id]
    );

    return sendSuccess(res, 'Assigned bus', {
      id: bus.id,
      busNumber: bus.bus_number,
      busType: bus.bus_type,
      capacity: bus.capacity,
      currentOccupancy: bus.current_occupancy,
      travelStatus: bus.travel_status,
      delayMinutes: bus.delay_minutes,
      lat: bus.lat,
      lon: bus.lon,
      routeName: bus.route_name,
      routeNumber: bus.route_number,
      fromStop: bus.from_stop,
      toStop: bus.to_stop,
      fare: bus.base_fare || bus.fare || 0,
      schedule,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/driver/trip/start
 * Start a trip — set bus status to Running.
 */
const startTrip = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id FROM buses WHERE driver_name = ?', [user?.name || '']);

    if (!bus) return sendError(res, 'No bus assigned', 404);

    await run(
      `UPDATE buses SET travel_status = 'Running', current_occupancy = 0, 
       updated_at = NOW() WHERE id = ?`,
      [bus.id]
    );

    logger.info(`[DRIVER] Trip started for bus ${bus.id} by ${user?.name}`);
    return sendSuccess(res, 'Trip started', { busId: bus.id, status: 'Running' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/driver/trip/pause
 * Pause the trip (break).
 */
const pauseTrip = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id FROM buses WHERE driver_name = ?', [user?.name || '']);

    if (!bus) return sendError(res, 'No bus assigned', 404);

    await run(
      `UPDATE buses SET travel_status = 'Delayed', updated_at = NOW() WHERE id = ?`,
      [bus.id]
    );

    return sendSuccess(res, 'Trip paused', { busId: bus.id, status: 'Delayed' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/driver/trip/resume
 * Resume the trip after a pause.
 */
const resumeTrip = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id FROM buses WHERE driver_name = ?', [user?.name || '']);

    if (!bus) return sendError(res, 'No bus assigned', 404);

    await run(
      `UPDATE buses SET travel_status = 'Running', delay_minutes = 0, 
       updated_at = NOW() WHERE id = ?`,
      [bus.id]
    );

    return sendSuccess(res, 'Trip resumed', { busId: bus.id, status: 'Running' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/driver/trip/end
 * End the trip — set bus status to Arrived.
 */
const endTrip = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id FROM buses WHERE driver_name = ?', [user?.name || '']);

    if (!bus) return sendError(res, 'No bus assigned', 404);

    await run(
      `UPDATE buses SET travel_status = 'Arrived', 
       current_stop_index = 0, updated_at = NOW() WHERE id = ?`,
      [bus.id]
    );

    logger.info(`[DRIVER] Trip ended for bus ${bus.id}`);
    return sendSuccess(res, 'Trip ended', { busId: bus.id, status: 'Arrived' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/driver/location
 * Share driver's live GPS location.
 */
const shareLocation = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { lat, lon, speed, heading } = req.body;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id FROM buses WHERE driver_name = ?', [user?.name || '']);

    if (!bus) return sendError(res, 'No bus assigned', 404);

    // Update bus location
    await run(
      `UPDATE buses SET lat = ?, lon = ?, updated_at = NOW() WHERE id = ?`,
      [lat, lon, bus.id]
    );

    // Log location history
    await run(
      'INSERT INTO bus_locations (bus_id, lat, lon, speed) VALUES (?, ?, ?, ?)',
      [bus.id, lat, lon, speed || 0]
    );

    return sendSuccess(res, 'Location shared');
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/driver/delay
 * Report a delay.
 */
const reportDelay = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { delayMinutes, reason } = req.body;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id FROM buses WHERE driver_name = ?', [user?.name || '']);

    if (!bus) return sendError(res, 'No bus assigned', 404);

    await run(
      `UPDATE buses SET delay_minutes = ?, travel_status = 'Delayed',
       updated_at = NOW() WHERE id = ?`,
      [delayMinutes || 0, bus.id]
    );

    // Log delay notification
    await run(
      `INSERT INTO notifications (passenger_id, title, body, type) 
       SELECT DISTINCT passenger_id, 'Bus Delay Alert', ?, 'warning'
       FROM tickets WHERE bus_id = ? AND status = 'booked'`,
      [`Bus delayed by ${delayMinutes || 0} minutes. ${reason || ''}`, bus.id]
    );

    logger.info(`[DRIVER] Delay reported: ${delayMinutes}min for bus ${bus.id}`);
    return sendSuccess(res, 'Delay reported');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/driver/emergency
 * Trigger emergency alert.
 */
const emergencyAlert = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { lat, lon, message, type = 'medical' } = req.body;
    const user = await getOne('SELECT name FROM users WHERE id = ?', [userId]);
    const bus = await getOne('SELECT id, bus_number FROM buses WHERE driver_name = ?', [user?.name || '']);

    // Log to notifications for admin
    await run(
      `INSERT INTO notifications (passenger_id, title, body, type)
       VALUES (0, ?, ?, 'sos')`,
      [
        `EMERGENCY - ${type.toUpperCase()}`,
        `Driver ${user?.name || 'Unknown'} triggered ${type} alert. Bus: ${bus?.bus_number || 'N/A'}. Location: ${lat || 'N/A'}, ${lon || 'N/A'}. ${message || ''}`,
      ]
    );

    // Also create a complaint record for tracking
    await run(
      `INSERT INTO complaints (passenger_id, subject, description, status)
       VALUES (0, ?, ?, 'open')`,
      [
        `DRIVER EMERGENCY - ${type.toUpperCase()}`,
        `Driver ${user?.name || 'Unknown'} triggered ${type} emergency. Bus: ${bus?.bus_number || 'N/A'}. Lat: ${lat || 'N/A'}, Lon: ${lon || 'N/A'}. ${message || ''}`,
      ]
    );

    logger.warn(`[DRIVER-EMERGENCY] ${type} alert by driver ${userId} (bus ${bus?.id || 'N/A'})`);
    return sendSuccess(res, 'Emergency alert sent to authorities');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/driver/stats
 * Get driver's daily stats.
 */
const getDriverStats = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const today = new Date().toISOString().split('T')[0];

    const verificationsResult = await getOne(
      `SELECT COUNT(*) as c FROM tickets 
       WHERE verified_by = ? AND DATE(verified_at) = ?`,
      [userId, today]
    );
    const verifications = verificationsResult?.c || 0;

    const totalTripsResult = await getOne(
      `SELECT COUNT(DISTINCT DATE(created_at)) as c FROM bus_locations 
       WHERE bus_id IN (
         SELECT id FROM buses WHERE driver_name = (
           SELECT name FROM users WHERE id = ?
         )
       ) AND DATE(created_at) = ?`,
      [userId, today]
    );
    const totalTrips = totalTripsResult?.c || 0;

    const finesIssuedResult = await getOne(
      `SELECT COUNT(*) as c FROM fines 
       WHERE issued_by = ? AND DATE(created_at) = ?`,
      [userId, today]
    );
    const finesIssued = finesIssuedResult?.c || 0;

    return sendSuccess(res, 'Driver stats', {
      today: {
        verifications,
        totalTrips,
        finesIssued,
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  driverLogin,
  getProfile,
  getMyBus,
  startTrip,
  pauseTrip,
  resumeTrip,
  endTrip,
  shareLocation,
  reportDelay,
  emergencyAlert,
  getDriverStats,
};

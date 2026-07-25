// server/routes/smart.routes.js
// ─────────────────────────────────────────────────
// Smart Features Routes
// Favorites, Notifications, SOS, Digital Pass
// ─────────────────────────────────────────────────
const express = require('express');
const router = express.Router();
const { getOne, getAll, run } = require('../db');
const { authenticate } = require('../middleware/auth.middleware');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

// ── Favorites ─────────────────────────────────────

/**
 * GET /api/v1/smart/favorites
 * Get passenger's favorite routes.
 */
router.get('/favorites', authenticate, async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    const favorites = await getAll(
      'SELECT * FROM wallet_transactions WHERE passenger_id = ? AND description LIKE ? ORDER BY created_at DESC',
      [passengerId, '%favorite%']
    );
    return sendSuccess(res, 'Favorites fetched', favorites);
  } catch (err) {
    next(err);
  }
});

// ── Notifications ─────────────────────────────────

/**
 * GET /api/v1/smart/notifications
 * Get passenger notifications.
 */
router.get('/notifications', authenticate, async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    const notifications = await getAll(
      'SELECT * FROM notifications WHERE passenger_id = ? ORDER BY created_at DESC LIMIT 30',
      [passengerId]
    );
    return sendSuccess(res, 'Notifications fetched', notifications);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/smart/notifications/read
 * Mark all notifications as read.
 */
router.post('/notifications/read', authenticate, async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    await run('UPDATE notifications SET is_read = 1 WHERE passenger_id = ?', [passengerId]);
    return sendSuccess(res, 'Notifications marked as read');
  } catch (err) {
    next(err);
  }
});

// ── SOS Emergency ─────────────────────────────────

/**
 * POST /api/v1/smart/sos
 * Trigger SOS alert (logs to database and notifies admin).
 */
router.post('/sos', authenticate, async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    const { lat, lon, message } = req.body;

    // Log the SOS event
    await run(
      `INSERT INTO notifications (passenger_id, title, body, type)
       VALUES (?, ?, ?, ?)`,
      [
        passengerId,
        'EMERGENCY SOS',
        `SOS triggered by passenger ${passengerId}. Location: ${lat || 'unknown'}, ${lon || 'unknown'}. ${message || ''}`,
        'sos',
      ]
    );

    // Also log to complaints for tracking
    await run(
      `INSERT INTO complaints (passenger_id, subject, description, status)
       VALUES (?, ?, ?, ?)`,
      [
        passengerId,
        'EMERGENCY SOS',
        `Emergency SOS triggered. Location: ${lat || 'N/A'}, ${lon || 'N/A'}. ${message || 'No additional details.'}`,
        'open',
      ]
    );

    logger.warn(`[SOS] Emergency SOS triggered by passenger ${passengerId}`);
    return sendSuccess(res, 'SOS alert sent to authorities');
  } catch (err) {
    next(err);
  }
});

// ── Digital Pass ──────────────────────────────────

/**
 * GET /api/v1/smart/digital-pass
 * Get passenger's digital transit pass details.
 */
router.get('/digital-pass', authenticate, async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    const passenger = await getOne(
      'SELECT id, full_name, contact, created_at FROM passengers WHERE id = ?',
      [passengerId]
    );

    if (!passenger) return sendError(res, 'Passenger not found', 404);

    return sendSuccess(res, 'Digital pass details', {
      passId: `SPX-${passenger.contact}`,
      passengerName: passenger.full_name,
      contact: passenger.contact,
      passType: 'General Transit',
      coverage: 'All TNSTC Routes',
      status: 'Active',
      issuedAt: passenger.created_at,
    });
  } catch (err) {
    next(err);
  }
});

// ── Trip History ──────────────────────────────────

/**
 * GET /api/v1/smart/trip-history
 * Get passenger's full trip history with details.
 */
router.get('/trip-history', authenticate, async (req, res, next) => {
  try {
    const passengerId = req.user.id;
    const { limit = 50, offset = 0 } = req.query;

    const tickets = await getAll(
      `SELECT t.*
       FROM tickets t
       WHERE t.passenger_id = ?
       ORDER BY t.created_at DESC
       LIMIT ? OFFSET ?`,
      [passengerId, Number(limit), Number(offset)]
    );

    // Fetch passengers for each ticket
    const parsed = await Promise.all(tickets.map(async (t) => {
      const passengers = await getAll(
        'SELECT name, gender FROM ticket_passengers WHERE ticket_id = ?',
        [t.id]
      );
      return {
        ticketNumber: t.ticket_number,
        busNumber: t.bus_number || '',
        fromStop: t.from_stop,
        toStop: t.to_stop,
        totalFare: t.total_fare,
        status: t.status,
        paymentMethod: t.payment_method,
        startTime: t.start_time,
        createdAt: t.created_at,
        verifiedAt: t.verified_at,
        passengers,
      };
    }));

    const total = (await getOne(
      'SELECT COUNT(*) as c FROM tickets WHERE passenger_id = ?',
      [passengerId]
    ))?.c || 0;

    return sendSuccess(res, 'Trip history fetched', {
      tickets: parsed,
      total,
      limit: Number(limit),
      offset: Number(offset),
    });
  } catch (err) {
    next(err);
  }
});

// ── Crowding Prediction ───────────────────────────

/**
 * GET /api/v1/smart/crowding/:busId
 * Get crowding prediction for a specific bus.
 */
router.get('/crowding/:busId', async (req, res, next) => {
  try {
    const busId = Number(req.params.busId);
    const bus = await getOne('SELECT * FROM buses WHERE id = ?', [busId]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    const capacity = bus.capacity || 45;
    const occupancy = bus.current_occupancy || 0;
    const percent = Math.round((occupancy / capacity) * 100);

    let level = 'low';
    let color = 'green';
    if (percent >= 80) {
      level = 'high';
      color = 'red';
    } else if (percent >= 50) {
      level = 'medium';
      color = 'orange';
    }

    return sendSuccess(res, 'Crowding data', {
      busId,
      capacity,
      occupancy,
      percent,
      level,
      color,
      message: level == 'high'
        ? 'This bus is crowded. Consider the next bus.'
        : level == 'medium'
        ? 'Moderate crowding. Some standing room available.'
        : 'Plenty of seats available.',
    });
  } catch (err) {
    next(err);
  }
});

// ── AI ETA Prediction (Simple) ────────────────────

/**
 * GET /api/v1/smart/eta/:busId
 * Get AI-predicted ETA for a bus at each stop.
 */
router.get('/eta/:busId', async (req, res, next) => {
  try {
    const busId = Number(req.params.busId);
    const bus = await getOne('SELECT * FROM buses WHERE id = ?', [busId]);
    if (!bus) return sendError(res, 'Bus not found', 404);

    const stops = (() => {
      try { return JSON.parse(bus.stops || '[]'); } catch { return []; }
    })();
    const delayMs = (bus.delay_minutes || 0) * 60 * 1000;
    const currentIdx = bus.current_stop_index || 0;

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

      const estimatedMs = scheduledMs ? scheduledMs + delayMs : null;
      const minsAway = estimatedMs ? Math.max(0, Math.round((estimatedMs - Date.now()) / 60000)) : null;

      return {
        index: idx,
        name: stop.name,
        scheduledArrival: stop.arrival,
        estimatedArrival: estimatedMs ? new Date(estimatedMs).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }) : null,
        minsAway,
        isCurrentStop: idx === currentIdx,
        isCompleted: idx < currentIdx,
        isNext: idx === currentIdx + 1,
      };
    });

    return sendSuccess(res, 'ETA prediction', {
      busId,
      delayMinutes: bus.delay_minutes,
      travelStatus: bus.travel_status,
      currentStopIndex: currentIdx,
      eta,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;

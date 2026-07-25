// server/services/realtime.service.js
// ─────────────────────────────────────────────────
// Real-Time GPS Tracking via WebSocket (Socket.IO)
//
// Events:
//   Client → Server: 'bus:join' (busId), 'bus:leave' (busId), 'bus:update-location'
//   Server → Client: 'bus:location-update', 'bus:status-change', 'bus:delay-update'
// ─────────────────────────────────────────────────
const logger = require('../utils/logger');
const { getOne, run } = require('../db');

let io = null;
const busRooms = new Map(); // busId → Set of socket IDs
const driverSockets = new Map(); // socketId → busId

/**
 * Initialize Socket.IO with the HTTP server.
 * @param {http.Server} httpServer
 * @returns {SocketIO.Server}
 */
function initRealtime(httpServer) {
  try {
    const socketIo = require('socket.io');
    io = socketIo(httpServer, {
      cors: {
        origin: process.env.CORS_ORIGIN || '*',
        methods: ['GET', 'POST'],
        credentials: true,
      },
      pingTimeout: 30000,
      pingInterval: 10000,
    });

    io.on('connection', (socket) => {
      logger.debug(`[WS] Client connected: ${socket.id}`);

      // ── Join a bus tracking room ────────────────
      socket.on('bus:join', ({ busId }) => {
        if (!busId) return;
        const room = `bus:${busId}`;
        socket.join(room);

        if (!busRooms.has(busId)) busRooms.set(busId, new Set());
        busRooms.get(busId).add(socket.id);

        logger.debug(`[WS] ${socket.id} joined bus:${busId} (${busRooms.get(busId).size} viewers)`);
      });

      // ── Leave a bus tracking room ───────────────
      socket.on('bus:leave', ({ busId }) => {
        if (!busId) return;
        const room = `bus:${busId}`;
        socket.leave(room);

        if (busRooms.has(busId)) {
          busRooms.get(busId).delete(socket.id);
          if (busRooms.get(busId).size === 0) busRooms.delete(busId);
        }

        logger.debug(`[WS] ${socket.id} left bus:${busId}`);
      });

      // ── Driver: update location ─────────────────
      socket.on('bus:update-location', async ({ busId, lat, lon, speed, heading, occupancy }) => {
        if (!busId || lat == null || lon == null) return;

        // Update DB
        await run(
          `UPDATE buses SET lat = ?, lon = ?,
           current_occupancy = COALESCE(?, current_occupancy),
           updated_at = NOW() WHERE id = ?`,
          [lat, lon, occupancy ?? null, busId]
        );

        await run(
          'INSERT INTO bus_locations (bus_id, lat, lon, speed) VALUES (?, ?, ?, ?)',
          [busId, lat, lon, speed || 0]
        );

        // Broadcast to all viewers
        const room = `bus:${busId}`;
        if (io) {
          io.to(room).emit('bus:location-update', {
            busId,
            lat,
            lon,
            speed: speed || 0,
            heading: heading || 0,
            occupancy: occupancy ?? null,
            timestamp: Date.now(),
          });
        }
      });

      // ── Driver: update trip status ──────────────
      socket.on('bus:update-status', async ({ busId, status, delayMinutes }) => {
        if (!busId) return;

        await run(
          `UPDATE buses SET travel_status = ?,
           delay_minutes = COALESCE(?, delay_minutes),
           updated_at = NOW() WHERE id = ?`,
          [status, delayMinutes ?? null, busId]
        );

        const room = `bus:${busId}`;
        if (io) {
          io.to(room).emit('bus:status-change', {
            busId,
            status,
            delayMinutes: delayMinutes ?? 0,
            timestamp: Date.now(),
          });
        }

        logger.info(`[WS] Bus ${busId} status → ${status}`);
      });

      // ── Driver: register socket ─────────────────
      socket.on('driver:register', ({ busId }) => {
        driverSockets.set(socket.id, busId);
        socket.join(`driver:${busId}`);
        logger.info(`[WS] Driver registered for bus ${busId}`);
      });

      // ── Disconnect ──────────────────────────────
      socket.on('disconnect', () => {
        const busId = driverSockets.get(socket.id);
        if (busId && busRooms.has(busId)) {
          busRooms.get(busId).delete(socket.id);
          driverSockets.delete(socket.id);
        }
        logger.debug(`[WS] Client disconnected: ${socket.id}`);
      });
    });

    logger.info('[WS] Real-time tracking initialized');
    return io;
  } catch (err) {
    logger.warn(`[WS] Socket.IO not available: ${err.message}`);
    return null;
  }
}

/**
 * Emit to a specific bus room.
 */
function emitToBus(busId, event, data) {
  if (!io) return;
  io.to(`bus:${busId}`).emit(event, data);
}

/**
 * Broadcast to all connected clients.
 */
function broadcast(event, data) {
  if (!io) return;
  io.emit(event, data);
}

/**
 * Get viewer count for a bus.
 */
function getViewerCount(busId) {
  return busRooms.has(busId) ? busRooms.get(busId).size : 0;
}

module.exports = { initRealtime, emitToBus, broadcast, getViewerCount };

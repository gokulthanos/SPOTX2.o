// server/controllers/bus.controller.js
// ─────────────────────────────────────────────────
// Bus Operations — Search, Nearby, Detail
// ─────────────────────────────────────────────────
const { getOne, getAll } = require('../db');
const { sendSuccess, sendError } = require('../utils/response');
const logger = require('../utils/logger');

function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

const searchNearbyStops = async (req, res) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lon = parseFloat(req.query.lon);
    const radius = parseFloat(req.query.radius) || 2;

    if (isNaN(lat) || isNaN(lon)) {
      return sendError(res, 'lat and lon query parameters are required');
    }

    const stops = await getAll('SELECT id, name, lat, lon FROM stops');

    const nearby = stops
      .map((stop) => ({
        ...stop,
        distance_km: parseFloat(haversineDistance(lat, lon, stop.lat, stop.lon).toFixed(2)),
      }))
      .filter((stop) => stop.distance_km <= radius)
      .sort((a, b) => a.distance_km - b.distance_km);

    return sendSuccess(res, 'Nearby stops fetched', nearby);
  } catch (err) {
    logger.error(`[BUS] Nearby stops error: ${err.message}`);
    return sendError(res, 'Failed to fetch nearby stops', 500);
  }
};

const getAllStops = async (req, res) => {
  try {
    const stops = await getAll('SELECT id, name, lat, lon FROM stops ORDER BY name');
    return sendSuccess(res, 'Stops fetched', stops);
  } catch (err) {
    logger.error(`[BUS] Get stops error: ${err.message}`);
    return sendError(res, 'Failed to fetch stops', 500);
  }
};

const searchBuses = async (req, res) => {
  try {
    const { from_stop_id, to_stop_id } = req.query;

    if (!from_stop_id || !to_stop_id) {
      return sendError(res, 'from_stop_id and to_stop_id are required');
    }

    if (Number(from_stop_id) === Number(to_stop_id)) {
      return sendError(res, 'Boarding and destination stops must be different');
    }

    const fromBS = await getAll(
      'SELECT bus_id, stop_sequence, fare_from_origin FROM bus_stops WHERE stop_id = ?',
      [from_stop_id]
    );
    const toBS = await getAll(
      'SELECT bus_id, stop_sequence, fare_from_origin FROM bus_stops WHERE stop_id = ?',
      [to_stop_id]
    );

    const fromBusIds = new Map(fromBS.map((r) => [r.bus_id, r]));
    const toBusIds = new Map(toBS.map((r) => [r.bus_id, r]));

    const results = [];

    for (const [busId, fromInfo] of fromBusIds) {
      const toInfo = toBusIds.get(busId);
      if (!toInfo) continue;
      if (fromInfo.stop_sequence >= toInfo.stop_sequence) continue;

      const bus = await getOne(
        `SELECT b.*, r.route_number, r.name AS route_name, r.base_fare
         FROM buses b
         JOIN routes r ON b.route_id = r.id
         WHERE b.id = ? AND b.is_active = 1`,
        [busId]
      );

      if (!bus) continue;

      const fare = parseFloat((toInfo.fare_from_origin - fromInfo.fare_from_origin).toFixed(2));

      const boardingStop = await getOne('SELECT name FROM stops WHERE id = ?', [from_stop_id]);
      const destStop = await getOne('SELECT name FROM stops WHERE id = ?', [to_stop_id]);

      results.push({
        bus_id: bus.id,
        bus_number: bus.bus_number,
        bus_type: bus.bus_type,
        capacity: bus.capacity,
        travel_status: bus.travel_status,
        departure_time: bus.departure_time,
        arrival_time: bus.arrival_time,
        route_id: bus.route_id,
        route_number: bus.route_number,
        route_name: bus.route_name,
        boarding_stop: boardingStop ? boardingStop.name : '',
        destination_stop: destStop ? destStop.name : '',
        fare,
      });
    }

    results.sort((a, b) => a.fare - b.fare);

    return sendSuccess(res, 'Buses found', results);
  } catch (err) {
    logger.error(`[BUS] Search buses error: ${err.message}`);
    return sendError(res, 'Failed to search buses', 500);
  }
};

const getBusDetail = async (req, res) => {
  try {
    const busId = req.params.id;

    const bus = await getOne(
      `SELECT b.*, r.route_number, r.name AS route_name, r.base_fare
       FROM buses b
       JOIN routes r ON b.route_id = r.id
       WHERE b.id = ? AND b.is_active = 1`,
      [busId]
    );

    if (!bus) {
      return sendError(res, 'Bus not found', 404);
    }

    const stops = await getAll(
      `SELECT bs.*, s.name AS stop_name
       FROM bus_stops bs
       JOIN stops s ON bs.stop_id = s.id
       WHERE bs.bus_id = ?
       ORDER BY bs.stop_sequence`,
      [busId]
    );

    return sendSuccess(res, 'Bus detail fetched', { ...bus, stops });
  } catch (err) {
    logger.error(`[BUS] Bus detail error: ${err.message}`);
    return sendError(res, 'Failed to fetch bus detail', 500);
  }
};

module.exports = {
  searchNearbyStops,
  getAllStops,
  searchBuses,
  getBusDetail,
};

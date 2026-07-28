// server/seed-demo.js
// ─────────────────────────────────────────────────
// SpotX 5.0 — Demo Data Seeder
// Seeds: 12 stops, 3 routes, 5 buses, bus_stops, 2 conductors
// ─────────────────────────────────────────────────
const bcrypt = require('bcryptjs');
const { getOne, run, lastInsertId } = require('./db');
const logger = require('./utils/logger');

const STOPS = [
  { name: 'Ukkadam', lat: 10.9965, lon: 76.9590 },
  { name: 'Gandhipuram', lat: 11.0055, lon: 76.9714 },
  { name: 'RS Puram', lat: 11.0125, lon: 76.9468 },
  { name: 'Peelamedu', lat: 11.0299, lon: 77.0118 },
  { name: 'Saibaba Colony', lat: 11.0184, lon: 76.9844 },
  { name: 'Sitra', lat: 10.9730, lon: 76.9350 },
  { name: 'Aerodrome', lat: 11.0300, lon: 77.0400 },
  { name: 'Race Course', lat: 11.0150, lon: 76.9650 },
  { name: 'Mettupalayam', lat: 11.3000, lon: 76.8950 },
  { name: 'Podanur', lat: 10.9580, lon: 76.9120 },
  { name: 'Town Hall', lat: 10.9980, lon: 76.9520 },
  { name: 'Coimbatore Bus Stand', lat: 10.9980, lon: 76.9560 },
];

const ROUTES = [
  { route_number: 'A1', name: 'A1 - Ukkadam to Gandhipuram', base_fare: 25 },
  { route_number: 'B2', name: 'B2 - RS Puram to Peelamedu', base_fare: 30 },
  { route_number: 'C3', name: 'C3 - Town Hall to Mettupalayam', base_fare: 20 },
];

const BUSES = [
  { bus_number: 'TN38A1001', route_index: 0, bus_type: 'Normal', capacity: 45, fare: 25, departure_time: '06:00', arrival_time: '07:30' },
  { bus_number: 'TN38A1002', route_index: 0, bus_type: 'Express', capacity: 40, fare: 30, departure_time: '08:00', arrival_time: '09:15' },
  { bus_number: 'TN38B2001', route_index: 1, bus_type: 'Normal', capacity: 45, fare: 30, departure_time: '07:00', arrival_time: '08:30' },
  { bus_number: 'TN38B2002', route_index: 1, bus_type: 'AC', capacity: 35, fare: 45, departure_time: '09:00', arrival_time: '10:15' },
  { bus_number: 'TN38C3001', route_index: 2, bus_type: 'Normal', capacity: 45, fare: 20, departure_time: '06:30', arrival_time: '07:45' },
];

const BUS_STOPS_MAP = {
  'TN38A1001': [
    { stop_name: 'Ukkadam', seq: 1, arrival: '06:00', departure: '06:05', dist: 0, fare: 0 },
    { stop_name: 'Town Hall', seq: 2, arrival: '06:20', departure: '06:25', dist: 1.5, fare: 5 },
    { stop_name: 'Race Course', seq: 3, arrival: '06:40', departure: '06:45', dist: 3.0, fare: 10 },
    { stop_name: 'Saibaba Colony', seq: 4, arrival: '07:00', departure: '07:05', dist: 4.5, fare: 15 },
    { stop_name: 'Gandhipuram', seq: 5, arrival: '07:20', departure: '07:25', dist: 6.0, fare: 20 },
  ],
  'TN38A1002': [
    { stop_name: 'Ukkadam', seq: 1, arrival: '08:00', departure: '08:05', dist: 0, fare: 0 },
    { stop_name: 'Sitra', seq: 2, arrival: '08:20', departure: '08:25', dist: 2.5, fare: 8 },
    { stop_name: 'Peelamedu', seq: 3, arrival: '08:45', departure: '08:50', dist: 5.5, fare: 18 },
    { stop_name: 'Gandhipuram', seq: 4, arrival: '09:10', departure: '09:15', dist: 6.0, fare: 25 },
  ],
  'TN38B2001': [
    { stop_name: 'RS Puram', seq: 1, arrival: '07:00', departure: '07:05', dist: 0, fare: 0 },
    { stop_name: 'Race Course', seq: 2, arrival: '07:15', departure: '07:20', dist: 1.5, fare: 8 },
    { stop_name: 'Saibaba Colony', seq: 3, arrival: '07:35', departure: '07:40', dist: 3.0, fare: 15 },
    { stop_name: 'Aerodrome', seq: 4, arrival: '07:55', departure: '08:00', dist: 5.0, fare: 22 },
    { stop_name: 'Peelamedu', seq: 5, arrival: '08:20', departure: '08:25', dist: 6.5, fare: 28 },
  ],
  'TN38B2002': [
    { stop_name: 'RS Puram', seq: 1, arrival: '09:00', departure: '09:05', dist: 0, fare: 0 },
    { stop_name: 'Gandhipuram', seq: 2, arrival: '09:15', departure: '09:20', dist: 2.0, fare: 10 },
    { stop_name: 'Saibaba Colony', seq: 3, arrival: '09:35', departure: '09:40', dist: 3.0, fare: 18 },
    { stop_name: 'Peelamedu', seq: 4, arrival: '10:05', departure: '10:10', dist: 6.5, fare: 35 },
  ],
  'TN38C3001': [
    { stop_name: 'Town Hall', seq: 1, arrival: '06:30', departure: '06:35', dist: 0, fare: 0 },
    { stop_name: 'Ukkadam', seq: 2, arrival: '06:50', departure: '06:55', dist: 1.5, fare: 5 },
    { stop_name: 'Podanur', seq: 3, arrival: '07:15', departure: '07:20', dist: 4.0, fare: 12 },
    { stop_name: 'Mettupalayam', seq: 4, arrival: '07:40', departure: '07:45', dist: 7.0, fare: 20 },
  ],
};

const CONDUCTORS = [
  { name: 'Kumar', username: 'conductor1', password: 'pass123' },
  { name: 'Ravi', username: 'conductor2', password: 'pass123' },
];

async function seed() {
  try {
    const existing = await getOne('SELECT COUNT(*) as c FROM stops');
    if (existing && existing.c > 0) {
      logger.info(`[SEED] Database already has ${existing.c} stops — skipping seed`);
      return;
    }

    logger.info('[SEED] Seeding demo data...');

    // 1. Stops
    const stopIds = {};
    for (const stop of STOPS) {
      await run('INSERT INTO stops (name, lat, lon) VALUES (?, ?, ?)', [stop.name, stop.lat, stop.lon]);
      const inserted = await getOne('SELECT id FROM stops WHERE name = ?', [stop.name]);
      if (inserted) stopIds[stop.name] = inserted.id;
    }
    logger.info(`[SEED] ${STOPS.length} stops seeded`);

    // 2. Routes
    const routeIds = {};
    for (const route of ROUTES) {
      await run('INSERT INTO routes (route_number, name, base_fare) VALUES (?, ?, ?)', [
        route.route_number,
        route.name,
        route.base_fare,
      ]);
      const inserted = await getOne('SELECT id FROM routes WHERE route_number = ?', [route.route_number]);
      if (inserted) routeIds[route.route_number] = inserted.id;
    }
    logger.info(`[SEED] ${ROUTES.length} routes seeded`);

    // 3. Buses
    const routeNumbers = ['A1', 'B2', 'C3'];
    for (const bus of BUSES) {
      const route_number = routeNumbers[bus.route_index];
      const route_id = routeIds[route_number];
      await run(
        'INSERT INTO buses (bus_number, route_id, bus_type, capacity, travel_status, departure_time, arrival_time, fare) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [bus.bus_number, route_id, bus.bus_type, bus.capacity, 'scheduled', bus.departure_time, bus.arrival_time, bus.fare]
      );
    }
    logger.info(`[SEED] ${BUSES.length} buses seeded`);

    // 4. Bus-Stops mapping
    for (const [bus_number, stops] of Object.entries(BUS_STOPS_MAP)) {
      const bus = await getOne('SELECT id FROM buses WHERE bus_number = ?', [bus_number]);
      if (!bus) continue;

      for (const s of stops) {
        const stop_id = stopIds[s.stop_name];
        if (!stop_id) continue;

        await run(
          'INSERT INTO bus_stops (bus_id, stop_id, stop_sequence, arrival_time, departure_time, distance_from_origin, fare_from_origin) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [bus.id, stop_id, s.seq, s.arrival, s.departure, s.dist, s.fare]
        );
      }
    }
    logger.info('[SEED] Bus-stop mappings seeded');

    // 5. Conductors
    for (const c of CONDUCTORS) {
      const hash = await bcrypt.hash(c.password, 12);
      await run('INSERT INTO conductors (name, username, password_hash) VALUES (?, ?, ?)', [
        c.name,
        c.username,
        hash,
      ]);
    }
    logger.info(`[SEED] ${CONDUCTORS.length} conductors seeded`);

    logger.info('[SEED] Demo data seeded successfully');
    logger.info('[SEED] Demo conductors: conductor1/pass123, conductor2/pass123');
  } catch (err) {
    logger.error(`[SEED] Error: ${err.message}`);
  }
}

module.exports = { seed };

if (require.main === module) {
  const { initDB } = require('./db');
  initDB()
    .then(() => seed())
    .then(() => process.exit(0))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}

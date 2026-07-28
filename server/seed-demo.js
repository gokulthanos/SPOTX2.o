// server/seed-demo.js
// ─────────────────────────────────────────────────
// SpotX 4.0 — Massive Demo Data Seeder (MySQL)
// Generates: 110+ buses, 550+ tickets, 20+ routes,
//   25+ stops, 15 cities, 50+ passengers
// All realistic Tamil Nadu transit data
// ─────────────────────────────────────────────────
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { initDB, getOne, getAll, run } = require('./db');
const logger = require('./utils/logger');

const TN_CITIES = [
  { name: 'Chennai', state: 'Tamil Nadu', lat: 13.0827, lon: 80.2707 },
  { name: 'Madurai', state: 'Tamil Nadu', lat: 9.9252, lon: 78.1198 },
  { name: 'Coimbatore', state: 'Tamil Nadu', lat: 11.0168, lon: 76.9558 },
  { name: 'Tiruchirappalli', state: 'Tamil Nadu', lat: 10.7905, lon: 78.7047 },
  { name: 'Salem', state: 'Tamil Nadu', lat: 11.6643, lon: 78.1460 },
  { name: 'Tirunelveli', state: 'Tamil Nadu', lat: 8.7139, lon: 77.7567 },
  { name: 'Erode', state: 'Tamil Nadu', lat: 11.3410, lon: 77.7172 },
  { name: 'Vellore', state: 'Tamil Nadu', lat: 12.9165, lon: 79.1325 },
  { name: 'Thoothukudi', state: 'Tamil Nadu', lat: 8.7642, lon: 78.1348 },
  { name: 'Dindigul', state: 'Tamil Nadu', lat: 10.3673, lon: 77.9803 },
  { name: 'Kancheepuram', state: 'Tamil Nadu', lat: 12.8387, lon: 79.7016 },
  { name: 'Pondicherry', state: 'Puducherry', lat: 11.9416, lon: 79.8083 },
  { name: 'Cuddalore', state: 'Tamil Nadu', lat: 11.7480, lon: 79.7714 },
  { name: 'Thanjavur', state: 'Tamil Nadu', lat: 10.7870, lon: 79.1378 },
  { name: 'Karur', state: 'Tamil Nadu', lat: 10.9601, lon: 78.0766 },
];

const TN_STOPS = [
  { name: 'Chennai CMBT', city: 'Chennai', lat: 13.0674, lon: 80.2078, type: 'terminus' },
  { name: 'Chennai T Nagar', city: 'Chennai', lat: 13.0410, lon: 80.2340, type: 'stop' },
  { name: 'Chennai Tambaram', city: 'Chennai', lat: 12.9249, lon: 80.0850, type: 'stop' },
  { name: 'Chennai Egmore', city: 'Chennai', lat: 13.0710, lon: 80.2568, type: 'stop' },
  { name: 'Mahabalipuram', city: 'Chennai', lat: 12.6269, lon: 80.1927, type: 'stop' },
  { name: 'Kancheepuram Bus Stand', city: 'Kancheepuram', lat: 12.8387, lon: 79.7016, type: 'terminus' },
  { name: 'Vellore Bus Stand', city: 'Vellore', lat: 12.9165, lon: 79.1325, type: 'terminus' },
  { name: 'Villupuram Bus Stand', city: 'Cuddalore', lat: 11.9401, lon: 79.4975, type: 'stop' },
  { name: 'Pondicherry Bus Stand', city: 'Pondicherry', lat: 11.9416, lon: 79.8083, type: 'terminus' },
  { name: 'Cuddalore Bus Stand', city: 'Cuddalore', lat: 11.7480, lon: 79.7714, type: 'terminus' },
  { name: 'Trichy Central Bus Stand', city: 'Tiruchirappalli', lat: 10.7905, lon: 78.7047, type: 'terminus' },
  { name: 'Madurai Mattuthavani', city: 'Madurai', lat: 9.9252, lon: 78.1198, type: 'terminus' },
  { name: 'Madurai Periyar Bus Stand', city: 'Madurai', lat: 9.9290, lon: 78.1168, type: 'stop' },
  { name: 'Salem Bus Stand', city: 'Salem', lat: 11.6643, lon: 78.1460, type: 'terminus' },
  { name: 'Coimbatore Town Bus Stand', city: 'Coimbatore', lat: 11.0168, lon: 76.9558, type: 'terminus' },
  { name: 'Coimbatore Gandhipuram', city: 'Coimbatore', lat: 11.0055, lon: 76.9714, type: 'stop' },
  { name: 'Erode Bus Stand', city: 'Erode', lat: 11.3410, lon: 77.7172, type: 'terminus' },
  { name: 'Tirunelveli Bus Stand', city: 'Tirunelveli', lat: 8.7139, lon: 77.7567, type: 'terminus' },
  { name: 'Dindigul Bus Stand', city: 'Dindigul', lat: 10.3673, lon: 77.9803, type: 'terminus' },
  { name: 'Thanjavur Bus Stand', city: 'Thanjavur', lat: 10.7870, lon: 79.1378, type: 'terminus' },
  { name: 'Karur Bus Stand', city: 'Karur', lat: 10.9601, lon: 78.0766, type: 'terminus' },
  { name: 'Thoothukudi Bus Stand', city: 'Thoothukudi', lat: 8.7642, lon: 78.1348, type: 'terminus' },
  { name: 'Nagapattinam Bus Stand', city: 'Thanjavur', lat: 10.7652, lon: 79.8437, type: 'stop' },
  { name: 'Kumbakonam Bus Stand', city: 'Thanjavur', lat: 10.9583, lon: 79.3781, type: 'stop' },
  { name: 'Arani Bus Stand', city: 'Vellore', lat: 12.5692, lon: 79.2833, type: 'stop' },
];

const TN_ROUTES = [
  { num: 'TN-101', name: 'Chennai - Madurai Express', from: 'Chennai CMBT', to: 'Madurai Mattuthavani', dist: 460, fare: 450 },
  { num: 'TN-102', name: 'Chennai - Pondicherry Coastal', from: 'Chennai CMBT', to: 'Pondicherry Bus Stand', dist: 151, fare: 120 },
  { num: 'TN-103', name: 'Chennai - Vellore Local', from: 'Chennai CMBT', to: 'Vellore Bus Stand', dist: 135, fare: 80 },
  { num: 'TN-104', name: 'Chennai - Trichy Superfast', from: 'Chennai CMBT', to: 'Trichy Central Bus Stand', dist: 330, fare: 350 },
  { num: 'TN-105', name: 'Chennai - Kancheepuram', from: 'Chennai CMBT', to: 'Kancheepuram Bus Stand', dist: 75, fare: 45 },
  { num: 'TN-201', name: 'Madurai - Trichy Express', from: 'Madurai Mattuthavani', to: 'Trichy Central Bus Stand', dist: 140, fare: 130 },
  { num: 'TN-202', name: 'Madurai - Tirunelveli', from: 'Madurai Mattuthavani', to: 'Tirunelveli Bus Stand', dist: 160, fare: 140 },
  { num: 'TN-301', name: 'Coimbatore - Salem Express', from: 'Coimbatore Town Bus Stand', to: 'Salem Bus Stand', dist: 165, fare: 150 },
  { num: 'TN-302', name: 'Coimbatore - Erode', from: 'Coimbatore Gandhipuram', to: 'Erode Bus Stand', dist: 100, fare: 80 },
  { num: 'TN-303', name: 'Coimbatore - Madurai Highway', from: 'Coimbatore Town Bus Stand', to: 'Madurai Mattuthavani', dist: 220, fare: 200 },
  { num: 'TN-401', name: 'Salem - Trichy', from: 'Salem Bus Stand', to: 'Trichy Central Bus Stand', dist: 140, fare: 120 },
  { num: 'TN-402', name: 'Erode - Karur - Trichy', from: 'Erode Bus Stand', to: 'Trichy Central Bus Stand', dist: 180, fare: 160 },
  { num: 'TN-501', name: 'Chennai - Mahabalipuram Beach', from: 'Chennai Tambaram', to: 'Mahabalipuram', dist: 58, fare: 40 },
  { num: 'TN-502', name: 'Vellore - Arani - Chennai', from: 'Vellore Bus Stand', to: 'Chennai CMBT', dist: 160, fare: 110 },
  { num: 'TN-601', name: 'Thanjavur - Kumbakonam', from: 'Thanjavur Bus Stand', to: 'Kumbakonam Bus Stand', dist: 55, fare: 35 },
  { num: 'TN-602', name: 'Thanjavur - Nagapattinam', from: 'Thanjavur Bus Stand', to: 'Nagapattinam Bus Stand', dist: 85, fare: 60 },
  { num: 'TN-701', name: 'Dindigul - Madurai', from: 'Dindigul Bus Stand', to: 'Madurai Mattuthavani', dist: 75, fare: 60 },
  { num: 'TN-801', name: 'Thoothukudi - Madurai', from: 'Thoothukudi Bus Stand', to: 'Madurai Mattuthavani', dist: 180, fare: 160 },
  { num: 'TN-802', name: 'Thoothukudi - Tirunelveli', from: 'Thoothukudi Bus Stand', to: 'Tirunelveli Bus Stand', dist: 100, fare: 85 },
  { num: 'TN-901', name: 'Pondicherry - Villupuram - Chennai', from: 'Pondicherry Bus Stand', to: 'Chennai CMBT', dist: 160, fare: 130 },
];

const BUS_TYPES = ['Deluxe', 'Express', 'Normal', 'AC', 'Sleeper', 'Semi-Deluxe', 'Ultra Deluxe'];
const FIRST_NAMES = ['Raj', 'Kumar', 'Priya', 'Anitha', 'Suresh', 'Lakshmi', 'Murugan', 'Kavitha', 'Venkat', 'Deepa', 'Ravi', 'Saranya', 'Ganesh', 'Meena', 'Karthik', 'Divya', 'Senthil', 'Revathi', 'Mani', 'Jothi'];
const LAST_NAMES = ['R', 'K', 'S', 'M', 'P', 'T', 'G', 'V', 'D', 'N'];
const STAFF_NAMES = ['Rajendran', 'Selvam', 'Kumaran', 'Anand', 'Senthil', 'Murugan', 'Velmurugan', 'Gopal', 'Natarajan', 'Suresh', 'Ramanathan', 'Karthikeyan', 'Prakash', 'Durai', 'Mohan'];

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function randFloat(min, max) { return +(min + Math.random() * (max - min)).toFixed(6); }
function genPhone() { return '9' + String(randInt(100000000, 999999999)); }
function genEmail(name) { return `${name.toLowerCase().replace(/\s/g, '')}${randInt(1, 999)}@gmail.com`; }
function genTicketNum() { return crypto.randomBytes(4).toString('hex').toUpperCase(); }

function dateExpr(daysAgo) {
  return `DATE_SUB(NOW(), INTERVAL ${Number(daysAgo)} DAY)`;
}

async function seed() {
  await initDB();

  const existingBuses = await getOne('SELECT COUNT(*) as c FROM buses');
  if (existingBuses && existingBuses.c > 5) {
    logger.info(`[SEED-DEMO] Database already has ${existingBuses.c} buses — skipping seed`);
    return;
  }

  logger.info('[SEED-DEMO] Generating massive demo dataset...');

  // 1. Cities
  for (const city of TN_CITIES) {
    await run("INSERT IGNORE INTO cities (name, state, lat, lon) VALUES (?, ?, ?, ?)",
      [city.name, city.state, city.lat, city.lon]);
  }
  logger.info(`[SEED-DEMO] ${TN_CITIES.length} cities inserted`);

  // 2. Stops
  const stopIds = {};
  for (const stop of TN_STOPS) {
    const city = await getOne('SELECT id FROM cities WHERE name = ?', [stop.city]);
    await run("INSERT IGNORE INTO stops (name, city_id, lat, lon, stop_type) VALUES (?, ?, ?, ?, ?)",
      [stop.name, city?.id || 1, stop.lat, stop.lon, stop.type]);
    const inserted = await getOne('SELECT id FROM stops WHERE name = ?', [stop.name]);
    if (inserted) stopIds[stop.name] = inserted.id;
  }
  logger.info(`[SEED-DEMO] ${TN_STOPS.length} stops inserted`);

  // 3. Routes
  const routeIds = {};
  for (const route of TN_ROUTES) {
    const fromId = stopIds[route.from] || 1;
    const toId = stopIds[route.to] || 4;
    await run("INSERT IGNORE INTO routes (route_number, name, from_stop_id, to_stop_id, distance_km, base_fare) VALUES (?, ?, ?, ?, ?, ?)",
      [route.num, route.name, fromId, toId, route.dist, route.fare]);
    const r = await getOne('SELECT id FROM routes WHERE route_number = ?', [route.num]);
    if (r) routeIds[route.num] = r.id;
  }
  logger.info(`[SEED-DEMO] ${TN_ROUTES.length} routes inserted`);

  // 4. Officers / Staff
  const bcryptPass = bcrypt.hashSync('staff123', 12);
  const adminPass = bcrypt.hashSync('admin123', 12);

  for (const name of STAFF_NAMES) {
    const email = genEmail(name);
    await run("INSERT IGNORE INTO users (name, email, password_hash, role) VALUES (?, ?, ?, 'STAFF')",
      [name, email, bcryptPass]);
  }

  // Admin
  await run("INSERT IGNORE INTO users (name, email, password_hash, role) VALUES (?, ?, ?, 'ADMIN')",
    ['Super Admin', 'ADMIN@GOV.IN', adminPass]);

  logger.info(`[SEED-DEMO] ${STAFF_NAMES.length + 1} officers inserted`);

  // 5. Passengers
  const passengerIds = [];
  for (let i = 0; i < 50; i++) {
    const name = `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`;
    const phone = genPhone();
    const email = genEmail(name);
    const passHash = bcrypt.hashSync('pass123', 12);
    await run("INSERT IGNORE INTO passengers (full_name, contact, email, password_hash, wallet_balance) VALUES (?, ?, ?, ?, ?)",
      [name, phone, email, passHash, randInt(0, 2000)]);
    const p = await getOne('SELECT id FROM passengers WHERE contact = ?', [phone]);
    if (p) passengerIds.push(p.id);
  }
  logger.info(`[SEED-DEMO] 50 passengers inserted`);

  // 6. Buses (110)
  const routeKeys = Object.keys(routeIds);
  const statuses = ['Running', 'Not Started', 'Arrived', 'Delayed', 'Running', 'Running'];
  const drivers = STAFF_NAMES;

  let busCount = 0;
  for (let i = 0; i < 110; i++) {
    const routeKey = pick(routeKeys);
    const rid = routeIds[routeKey];
    const route = TN_ROUTES.find(r => r.num === routeKey);
    const busType = pick(BUS_TYPES);
    const capacity = busType === 'Sleeper' ? 30 : busType === 'AC' ? 35 : busType === 'Ultra Deluxe' ? 50 : 45;
    const status = pick(statuses);
    const occupancy = status === 'Running' ? randInt(5, Math.floor(capacity * 0.95)) :
                      status === 'Delayed' ? randInt(10, capacity) : 0;
    const delay = status === 'Delayed' ? randInt(5, 45) : 0;
    const busNum = `TN${String(randInt(1, 99)).padStart(2, '0')}N${String(randInt(1000, 9999))}`;
    const fromStop = route?.from || pick(TN_STOPS).name;
    const toStop = route?.to || pick(TN_STOPS).name;
    const fare = route?.fare || randInt(40, 500);
    const driver = pick(drivers);
    const city = TN_STOPS.find(s => s.name === fromStop)?.city || pick(TN_CITIES).name;

    const baseLat = route ? TN_STOPS.find(s => s.name === fromStop)?.lat || 13.0 : 13.0;
    const baseLon = route ? TN_STOPS.find(s => s.name === fromStop)?.lon || 80.2 : 80.2;
    const lat = randFloat(baseLat - 0.5, baseLat + 0.5);
    const lon = randFloat(baseLon - 0.5, baseLon + 0.5);

    const stopsJson = JSON.stringify([
      { name: fromStop, arrival: '06:00 AM', departure: '06:00 AM', distance: 0 },
      { name: toStop, arrival: `${randInt(7, 14)}:${String(randInt(0, 59)).padStart(2, '0')} AM`, departure: `${randInt(7, 14)}:${String(randInt(0, 59)).padStart(2, '0')} AM`, distance: route?.dist || randInt(50, 400) },
    ]);

    await run(
      `INSERT IGNORE INTO buses
       (bus_number, route_id, bus_type, capacity, current_occupancy, travel_status,
        delay_minutes, city, stops, from_stop, to_stop, arrival_time, fare, driver_name, lat, lon)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [busNum, rid || null, busType, capacity, occupancy, status, delay, city,
       stopsJson, fromStop, toStop, '06:00 AM', fare, driver, lat, lon]
    );
    busCount++;
  }
  logger.info(`[SEED-DEMO] ${busCount} buses inserted`);

  // 7. Tickets (550)
  const allBuses = await getAll('SELECT id, bus_number, from_stop, to_stop, fare FROM buses');
  let ticketCount = 0;

  for (let i = 0; i < 550; i++) {
    const bus = pick(allBuses);
    const passengerId = pick(passengerIds);
    const ticketNum = genTicketNum();
    const fare = bus.fare || randInt(40, 500);
    const methods = ['wallet', 'razorpay', 'wallet', 'wallet'];
    const method = pick(methods);
    const ticketStatuses = ['booked', 'verified', 'verified', 'verified', 'expired', 'booked'];
    const status = pick(ticketStatuses);

    const daysAgo = randInt(0, 30);

    await run(
      `INSERT IGNORE INTO tickets
       (ticket_number, passenger_id, bus_id, from_stop, to_stop, total_fare,
        status, payment_method, start_time, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ${dateExpr(daysAgo)})`,
      [ticketNum, passengerId, bus.id, bus.from_stop || 'Chennai CMBT',
       bus.to_stop || 'Madurai', fare, status, method, '06:00 AM']
    );
    ticketCount++;
  }
  logger.info(`[SEED-DEMO] ${ticketCount} tickets inserted`);

  // 8. Payments
  const allTickets = await getAll('SELECT id, passenger_id, total_fare, payment_method FROM tickets');
  for (const t of allTickets.slice(0, 300)) {
    const daysAgo = randInt(0, 30);
    await run(
      `INSERT INTO payments (passenger_id, ticket_id, amount, method, status, created_at)
       VALUES (?, ?, ?, ?, 'success', ${dateExpr(daysAgo)})`,
      [t.passenger_id, t.id, t.total_fare, t.payment_method]
    );
  }
  logger.info('[SEED-DEMO] Payments inserted');

  // 9. Wallet transactions
  for (const pid of passengerIds) {
    const numTx = randInt(2, 8);
    for (let i = 0; i < numTx; i++) {
      const type = pick(['topup', 'deduction', 'topup', 'deduction']);
      const amount = randInt(50, 500);
      const daysAgo = randInt(0, 30);
      await run(
        `INSERT INTO wallet_transactions (passenger_id, type, amount, description, created_at)
         VALUES (?, ?, ?, ?, ${dateExpr(daysAgo)})`,
        [pid, type, amount, type === 'topup' ? 'Wallet top-up via Razorpay' : 'Bus ticket purchase']
      );
    }
  }
  logger.info('[SEED-DEMO] Wallet transactions inserted');

  // 10. Complaints
  const complaints = [
    'Bus not arriving on time', 'AC not working', 'Driver was rude', 'Overcrowding', 'Need better seats',
    'Fare too high', 'Bus was dirty', 'Stops not announced', 'No water facility', 'Luggage space insufficient'
  ];
  for (let i = 0; i < 40; i++) {
    const pid = pick(passengerIds);
    const bus = pick(allBuses);
    const daysAgo = randInt(0, 30);
    await run(
      `INSERT INTO complaints (passenger_id, bus_id, subject, description, status, created_at)
       VALUES (?, ?, ?, ?, ?, ${dateExpr(daysAgo)})`,
      [pid, bus.id, pick(complaints), pick(complaints),
       pick(['open', 'open', 'in_review', 'resolved', 'closed'])]
    );
  }
  logger.info('[SEED-DEMO] 40 complaints inserted');

  // 11. Fines
  const fineReasons = ['No ticket', 'Overcrowding violation', 'Wrong route', 'Speeding', 'Illegal stop'];
  for (let i = 0; i < 25; i++) {
    const phone = genPhone();
    const bus = pick(allBuses);
    const officer = await getOne("SELECT id FROM users WHERE role = 'STAFF' LIMIT 1");
    const daysAgo = randInt(0, 30);
    await run(
      `INSERT INTO fines (passenger_contact, bus_id, issued_by, reason, amount, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ${dateExpr(daysAgo)})`,
      [phone, bus.id, officer?.id || 1, pick(fineReasons), randInt(200, 1000),
       pick(['paid', 'unpaid', 'unpaid'])]
    );
  }
  logger.info('[SEED-DEMO] 25 fines inserted');

  // 12. Notifications
  for (const pid of passengerIds) {
    const numNotifs = randInt(1, 5);
    for (let i = 0; i < numNotifs; i++) {
      const daysAgo = randInt(0, 14);
      await run(
        `INSERT INTO notifications (passenger_id, title, body, type, is_read, created_at)
         VALUES (?, ?, ?, ?, ?, ${dateExpr(daysAgo)})`,
        [pid, pick(['Trip Update', 'Payment Confirmed', 'Delay Alert', 'Promotion']),
         pick(['Your trip was successful', 'Payment of ₹120 confirmed', 'Bus delayed by 10 minutes', '50% off on next ride']),
         pick(['info', 'success', 'warning']),
         pick([0, 1, 1])]
      );
    }
  }
  logger.info('[SEED-DEMO] Notifications inserted');

  // 13. Bus location history (recent)
  const runningBuses = await getAll("SELECT id FROM buses WHERE travel_status = 'Running' OR travel_status = 'Delayed'");
  for (const bus of runningBuses.slice(0, 30)) {
    const numPoints = randInt(5, 20);
    for (let i = 0; i < numPoints; i++) {
      const hoursAgo = randInt(0, 2);
      await run(
        `INSERT INTO bus_locations (bus_id, lat, lon, speed, recorded_at)
         VALUES (?, ?, ?, ?, DATE_SUB(NOW(), INTERVAL ${hoursAgo} HOUR))`,
        [bus.id, randFloat(10, 14), randFloat(77, 81), randInt(20, 80)]
      );
    }
  }
  logger.info('[SEED-DEMO] Bus location history inserted');

  logger.info('[SEED-DEMO] ✅ Demo data seeding complete!');
  logger.info(`[SEED-DEMO] Summary: ${TN_CITIES.length} cities, ${TN_STOPS.length} stops, ${TN_ROUTES.length} routes, ${busCount} buses, ${ticketCount} tickets`);
}

module.exports = { seed };

// Run directly
if (require.main === module) {
  seed().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
}

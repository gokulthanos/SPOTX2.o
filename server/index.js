const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const { initDB, getOne, getAll, run, saveDB } = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 5000;

function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function generateTicketNumber() {
  return String(Math.floor(1000 + Math.random() * 9000));
}

// ─── 1. Request OTP ────────────────────────────────────────────
app.post('/api/passenger/request-otp', (req, res) => {
  const { fullName, contact } = req.body;
  if (!contact) return res.status(400).json({ message: 'Contact is required' });

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  run('DELETE FROM otps WHERE contact = ?', [contact]);
  run('INSERT INTO otps (contact, otp, expires_at) VALUES (?, ?, ?)', [contact, otp, expiresAt]);

  console.log(`[OTP] ${contact} -> ${otp}`);

  res.json({ message: 'OTP sent successfully', devOtp: otp, status: 'sent' });
});

// ─── 2. Verify OTP ─────────────────────────────────────────────
app.post('/api/passenger/verify-otp', (req, res) => {
  const { contact, otp } = req.body;
  if (!contact || !otp) return res.status(400).json({ message: 'Contact and OTP required' });

  const record = getOne('SELECT * FROM otps WHERE contact = ? ORDER BY id DESC LIMIT 1', [contact]);
  if (!record) return res.status(400).json({ message: 'No OTP found. Request a new one.' });
  if (record.otp !== otp) return res.status(400).json({ message: 'Invalid OTP' });
  if (new Date(record.expires_at) < new Date()) return res.status(400).json({ message: 'OTP expired' });

  run('UPDATE otps SET verified = 1 WHERE id = ?', [record.id]);

  const existing = getOne('SELECT id FROM passengers WHERE contact = ?', [contact]);
  if (!existing) {
    run('INSERT INTO passengers (full_name, contact) VALUES (?, ?)', ['', contact]);
  }

  res.json({ message: 'OTP verified', contact });
});

// ─── 3. Set Password ───────────────────────────────────────────
app.post('/api/passenger/set-password', (req, res) => {
  const { contact, password } = req.body;
  if (!contact || !password) return res.status(400).json({ message: 'Contact and password required' });

  const token = generateToken();
  const passenger = getOne('SELECT * FROM passengers WHERE contact = ?', [contact]);

  if (passenger) {
    run('UPDATE passengers SET password = ?, token = ? WHERE contact = ?', [password, token, contact]);
  } else {
    run('INSERT INTO passengers (contact, password, token) VALUES (?, ?, ?)', [contact, password, token]);
  }

  const updated = getOne('SELECT * FROM passengers WHERE contact = ?', [contact]);
  res.json({
    message: 'Password set successfully',
    fullName: updated.full_name || '',
    contact: updated.contact,
    token,
  });
});

// ─── 4. Passenger Login ────────────────────────────────────────
app.post('/api/passenger/login', (req, res) => {
  const { contact, password } = req.body;
  if (!contact || !password) return res.status(400).json({ message: 'Contact and password required' });

  const passenger = getOne('SELECT * FROM passengers WHERE contact = ?', [contact]);
  if (!passenger) return res.status(400).json({ message: 'Account not found. Please sign up first.' });
  if (passenger.password !== password) return res.status(400).json({ message: 'Invalid password' });

  const token = generateToken();
  run('UPDATE passengers SET token = ? WHERE contact = ?', [token, contact]);

  res.json({
    message: 'Login successful',
    fullName: passenger.full_name,
    contact: passenger.contact,
    token,
  });
});

// ─── 5. Officer Login ──────────────────────────────────────────
app.post('/api/users/login', (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ message: 'ID and password required' });

  const user = getOne('SELECT * FROM users WHERE email = ?', [email]);
  if (!user) return res.status(400).json({ message: 'Officer not found' });
  if (user.password !== password) return res.status(400).json({ message: 'Invalid password' });

  const token = generateToken();
  run('UPDATE users SET token = ? WHERE id = ?', [token, user.id]);

  res.json({
    message: 'Login successful',
    name: user.name,
    email: user.email,
    role: user.role,
    token,
  });
});

// ─── 6. Register Staff ─────────────────────────────────────────
app.post('/api/users/register', (req, res) => {
  const { name, email, password, role } = req.body;
  if (!name || !email || !password) return res.status(400).json({ message: 'All fields required' });

  const existing = getOne('SELECT id FROM users WHERE email = ?', [email]);
  if (existing) return res.status(400).json({ message: 'Officer ID already registered' });

  run('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)', [name, email, password, role || 'STAFF']);

  res.status(201).json({ message: 'Staff registered successfully', name, email, role: role || 'STAFF' });
});

// ─── 7. Get Buses ──────────────────────────────────────────────
app.get('/api/buses', (req, res) => {
  const { city } = req.query;
  let buses;
  if (city) {
    buses = getAll('SELECT * FROM buses WHERE city = ?', [city]);
  } else {
    buses = getAll('SELECT * FROM buses');
  }
  const parsed = buses.map(b => ({
    id: b.id,
    busNumber: b.bus_number,
    arrivalTime: b.arrival_time,
    fare: b.fare,
    route: b.route,
    from: b.from_stop,
    to: b.to_stop,
    busType: b.bus_type,
    stops: (() => { try { return JSON.parse(b.stops || '[]'); } catch { return []; } })(),
    currentStopIndex: b.current_stop_index,
    travelStatus: b.travel_status,
    delayMinutes: b.delay_minutes,
    city: b.city,
  }));
  res.json(parsed);
});

// ─── 8. Get Bus Details ────────────────────────────────────────
app.get('/api/buses/:id', (req, res) => {
  const bus = getOne('SELECT * FROM buses WHERE id = ?', [Number(req.params.id)]);
  if (!bus) return res.status(404).json({ message: 'Bus not found' });
  res.json({
    id: bus.id,
    busNumber: bus.bus_number,
    arrivalTime: bus.arrival_time,
    fare: bus.fare,
    route: bus.route,
    from: bus.from_stop,
    to: bus.to_stop,
    busType: bus.bus_type,
    stops: (() => { try { return JSON.parse(bus.stops || '[]'); } catch { return []; } })(),
    currentStopIndex: bus.current_stop_index,
    travelStatus: bus.travel_status,
    delayMinutes: bus.delay_minutes,
    city: bus.city,
  });
});

// ─── 9. Book Ticket ────────────────────────────────────────────
app.post('/api/tickets', (req, res) => {
  const { busId, busNumber, fromStop, toStop, totalFare, passengers } = req.body;
  const ticketNumber = generateTicketNumber();
  const startTime = new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });

  run(
    'INSERT INTO tickets (ticket_number, bus_id, bus_number, from_stop, to_stop, total_fare, status, start_time, passengers) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [ticketNumber, busId || 0, busNumber || '', fromStop || '', toStop || '', totalFare || 0, 'booked', startTime, JSON.stringify(passengers || [])]
  );

  res.json({ message: 'Ticket booked', ticketNumber, busId, busNumber, fromStop, toStop, totalFare, startTime, passengers, createdAt: new Date().toISOString() });
});

// ─── 10. Verify Ticket ─────────────────────────────────────────
app.get('/api/tickets/:ticketNumber', (req, res) => {
  const ticket = getOne('SELECT * FROM tickets WHERE ticket_number = ?', [req.params.ticketNumber]);
  if (!ticket) return res.status(404).json({ message: 'Ticket not found' });

  let busData = null;
  if (ticket.bus_id) {
    const bus = getOne('SELECT * FROM buses WHERE id = ?', [ticket.bus_id]);
    if (bus) {
      busData = {
        id: bus.id,
        busNumber: bus.bus_number,
        arrivalTime: bus.arrival_time,
        fare: bus.fare,
        route: bus.route,
        from: bus.from_stop,
        to: bus.to_stop,
        busType: bus.bus_type,
        stops: (() => { try { return JSON.parse(bus.stops || '[]'); } catch { return []; } })(),
        currentStopIndex: bus.current_stop_index,
        travelStatus: bus.travel_status,
        delayMinutes: bus.delay_minutes,
        city: bus.city,
      };
    }
  }

  const parsedPassengers = (() => { try { return JSON.parse(ticket.passengers || '[]'); } catch { return []; } })();

  res.json({
    ticketNumber: ticket.ticket_number,
    ticketId: ticket.ticket_number,
    busId: ticket.bus_id,
    busNumber: ticket.bus_number,
    fromStop: ticket.from_stop,
    toStop: ticket.to_stop,
    totalFare: ticket.total_fare,
    fare: ticket.total_fare,
    status: ticket.status,
    createdAt: ticket.created_at,
    timestamp: ticket.created_at,
    startTime: ticket.start_time,
    passengers: parsedPassengers,
    bus: busData,
  });
});

// ─── Seed Data ─────────────────────────────────────────────────
function seedDatabase() {
  const count = getOne('SELECT COUNT(*) as c FROM buses');
  if (count && count.c > 0) return;

  console.log('[SEED] Seeding bus data...');

  const chennaiBuses = [
    {
      bus_number: 'TN01N1234', arrival_time: '06:00 AM', fare: 120, route: 'Chennai - Madurai',
      from_stop: 'Chennai', to_stop: 'Madurai', bus_type: 'Deluxe', city: 'Chennai',
      stops: JSON.stringify([
        { name: 'Chennai', arrival: '06:00 AM', departure: '06:00 AM', distance: 0 },
        { name: 'Villupuram', arrival: '08:30 AM', departure: '08:35 AM', distance: 158 },
        { name: 'Trichy', arrival: '10:45 AM', departure: '10:50 AM', distance: 330 },
        { name: 'Madurai', arrival: '12:30 PM', departure: '12:30 PM', distance: 460 },
      ]),
      current_stop_index: 1, travel_status: 'Running', delay_minutes: 0,
    },
    {
      bus_number: 'TN01N5678', arrival_time: '07:30 AM', fare: 85, route: 'Chennai - Pondicherry',
      from_stop: 'Chennai', to_stop: 'Pondicherry', bus_type: 'Express', city: 'Chennai',
      stops: JSON.stringify([
        { name: 'Chennai', arrival: '07:30 AM', departure: '07:30 AM', distance: 0 },
        { name: 'Mahabalipuram', arrival: '08:15 AM', departure: '08:20 AM', distance: 58 },
        { name: 'Pondicherry', arrival: '09:30 AM', departure: '09:30 AM', distance: 151 },
      ]),
      current_stop_index: 0, travel_status: 'Not Started', delay_minutes: 0,
    },
    {
      bus_number: 'TN01N9012', arrival_time: '08:00 AM', fare: 60, route: 'Chennai - Vellore',
      from_stop: 'Chennai', to_stop: 'Vellore', bus_type: 'Normal', city: 'Chennai',
      stops: JSON.stringify([
        { name: 'Chennai', arrival: '08:00 AM', departure: '08:00 AM', distance: 0 },
        { name: 'Kanchipuram', arrival: '08:45 AM', departure: '08:50 AM', distance: 75 },
        { name: 'Vellore', arrival: '09:45 AM', departure: '09:45 AM', distance: 135 },
      ]),
      current_stop_index: 2, travel_status: 'Arrived', delay_minutes: 5,
    },
    {
      bus_number: 'TN01N3456', arrival_time: '09:15 AM', fare: 200, route: 'Chennai - Coimbatore',
      from_stop: 'Chennai', to_stop: 'Coimbatore', bus_type: 'Deluxe', city: 'Chennai',
      stops: JSON.stringify([
        { name: 'Chennai', arrival: '09:15 AM', departure: '09:15 AM', distance: 0 },
        { name: 'Villupuram', arrival: '11:30 AM', departure: '11:35 AM', distance: 158 },
        { name: 'Salem', arrival: '01:45 PM', departure: '01:50 PM', distance: 340 },
        { name: 'Coimbatore', arrival: '03:30 PM', departure: '03:30 PM', distance: 505 },
      ]),
      current_stop_index: 1, travel_status: 'Running', delay_minutes: 10,
    },
    {
      bus_number: 'TN01N7890', arrival_time: '10:00 AM', fare: 45, route: 'Chennai - Tiruvallur',
      from_stop: 'Chennai', to_stop: 'Tiruvallur', bus_type: 'Town', city: 'Chennai',
      stops: JSON.stringify([
        { name: 'Chennai', arrival: '10:00 AM', departure: '10:00 AM', distance: 0 },
        { name: 'Ambattur', arrival: '10:20 AM', departure: '10:25 AM', distance: 18 },
        { name: 'Tiruvallur', arrival: '10:50 AM', departure: '10:50 AM', distance: 45 },
      ]),
      current_stop_index: 0, travel_status: 'Not Started', delay_minutes: 0,
    },
  ];

  const maduraiBuses = [
    {
      bus_number: 'TN58N1111', arrival_time: '06:30 AM', fare: 100, route: 'Madurai - Chennai',
      from_stop: 'Madurai', to_stop: 'Chennai', bus_type: 'Express', city: 'Madurai',
      stops: JSON.stringify([
        { name: 'Madurai', arrival: '06:30 AM', departure: '06:30 AM', distance: 0 },
        { name: 'Trichy', arrival: '08:00 AM', departure: '08:05 AM', distance: 140 },
        { name: 'Villupuram', arrival: '10:30 AM', departure: '10:35 AM', distance: 310 },
        { name: 'Chennai', arrival: '12:30 PM', departure: '12:30 PM', distance: 460 },
      ]),
      current_stop_index: 1, travel_status: 'Running', delay_minutes: 0,
    },
    {
      bus_number: 'TN58N2222', arrival_time: '07:00 AM', fare: 55, route: 'Madurai - Dindigul',
      from_stop: 'Madurai', to_stop: 'Dindigul', bus_type: 'Mini', city: 'Madurai',
      stops: JSON.stringify([
        { name: 'Madurai', arrival: '07:00 AM', departure: '07:00 AM', distance: 0 },
        { name: 'Dindigul', arrival: '08:15 AM', departure: '08:15 AM', distance: 65 },
      ]),
      current_stop_index: 1, travel_status: 'Arrived', delay_minutes: 0,
    },
  ];

  const allBuses = [...chennaiBuses, ...maduraiBuses];
  for (const b of allBuses) {
    run(
      'INSERT INTO buses (bus_number, arrival_time, fare, route, from_stop, to_stop, bus_type, stops, current_stop_index, travel_status, delay_minutes, city) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [b.bus_number, b.arrival_time, b.fare, b.route, b.from_stop, b.to_stop, b.bus_type, b.stops, b.current_stop_index, b.travel_status, b.delay_minutes, b.city]
    );
  }

  run('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)', ['Admin Officer', 'ADMIN@GOV.IN', 'admin123', 'ADMIN']);
  run('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)', ['Staff Raj', 'RAJ@GOV.IN', 'staff123', 'STAFF']);

  console.log(`[SEED] Inserted ${allBuses.length} buses, 2 demo officers`);
}

// ─── Start ─────────────────────────────────────────────────────
async function start() {
  await initDB();
  seedDatabase();

  app.listen(PORT, () => {
    console.log(`\n  SPOTX Server running on http://localhost:${PORT}\n`);
    console.log('  Demo Officer Credentials:');
    console.log('    Admin  -> ID: ADMIN@GOV.IN  | Password: admin123');
    console.log('    Staff  -> ID: RAJ@GOV.IN    | Password: staff123\n');
    console.log('  Passenger: Sign up from the app to create an account\n');
  });
}

start().catch(console.error);

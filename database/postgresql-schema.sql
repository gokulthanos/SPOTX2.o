-- ─────────────────────────────────────────────────
-- SpotX 4.0 — PostgreSQL Production Schema
-- For use with Prisma/Sequelize/Knex migrations
-- ─────────────────────────────────────────────────

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Cities ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS cities (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  state VARCHAR(100) DEFAULT 'Tamil Nadu',
  lat DOUBLE PRECISION DEFAULT 0,
  lon DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Stops ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stops (
  id SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  city_id INTEGER REFERENCES cities(id) ON DELETE SET NULL,
  lat DOUBLE PRECISION DEFAULT 0,
  lon DOUBLE PRECISION DEFAULT 0,
  stop_type VARCHAR(20) DEFAULT 'stop',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Routes ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS routes (
  id SERIAL PRIMARY KEY,
  route_number VARCHAR(20) NOT NULL,
  name VARCHAR(200) NOT NULL,
  from_stop_id INTEGER REFERENCES stops(id) ON DELETE SET NULL,
  to_stop_id INTEGER REFERENCES stops(id) ON DELETE SET NULL,
  distance_km DOUBLE PRECISION DEFAULT 0,
  base_fare DOUBLE PRECISION DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Buses ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS buses (
  id SERIAL PRIMARY KEY,
  bus_number VARCHAR(20) NOT NULL UNIQUE,
  route_id INTEGER REFERENCES routes(id) ON DELETE SET NULL,
  bus_type VARCHAR(50) DEFAULT 'Normal',
  capacity INTEGER DEFAULT 45,
  current_occupancy INTEGER DEFAULT 0,
  current_stop_id INTEGER REFERENCES stops(id) ON DELETE SET NULL,
  travel_status VARCHAR(30) DEFAULT 'Not Started',
  delay_minutes INTEGER DEFAULT 0,
  driver_name TEXT DEFAULT '',
  lat DOUBLE PRECISION DEFAULT 0,
  lon DOUBLE PRECISION DEFAULT 0,
  city VARCHAR(100) DEFAULT 'Chennai',
  stops JSONB DEFAULT '[]',
  from_stop VARCHAR(200) DEFAULT '',
  to_stop VARCHAR(200) DEFAULT '',
  arrival_time VARCHAR(20) DEFAULT '',
  fare DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_buses_route ON buses(route_id);
CREATE INDEX IF NOT EXISTS idx_buses_city ON buses(city);
CREATE INDEX IF NOT EXISTS idx_buses_status ON buses(travel_status);

-- ── Schedules ────────────────────────────────────
CREATE TABLE IF NOT EXISTS schedules (
  id SERIAL PRIMARY KEY,
  bus_id INTEGER NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
  stop_id INTEGER NOT NULL REFERENCES stops(id) ON DELETE CASCADE,
  stop_sequence INTEGER NOT NULL,
  scheduled_arrival VARCHAR(20) NOT NULL,
  scheduled_departure VARCHAR(20) NOT NULL,
  distance_from_origin DOUBLE PRECISION DEFAULT 0
);

-- ── Passengers ───────────────────────────────────
CREATE TABLE IF NOT EXISTS passengers (
  id SERIAL PRIMARY KEY,
  full_name VARCHAR(200) NOT NULL DEFAULT '',
  contact VARCHAR(20) UNIQUE NOT NULL,
  email VARCHAR(200) DEFAULT '',
  password_hash TEXT NOT NULL DEFAULT '',
  refresh_token TEXT DEFAULT '',
  wallet_balance DOUBLE PRECISION DEFAULT 0.0,
  fcm_token TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Users (Officers / Admin / Drivers) ──────────
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(200) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'STAFF',
  refresh_token TEXT DEFAULT '',
  assigned_route_id INTEGER REFERENCES routes(id) ON DELETE SET NULL,
  fcm_token TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── OTPs ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS otps (
  id SERIAL PRIMARY KEY,
  contact VARCHAR(20) NOT NULL,
  otp VARCHAR(10) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Tickets ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS tickets (
  id SERIAL PRIMARY KEY,
  ticket_number VARCHAR(10) UNIQUE NOT NULL,
  passenger_id INTEGER REFERENCES passengers(id) ON DELETE SET NULL,
  bus_id INTEGER REFERENCES buses(id) ON DELETE SET NULL,
  from_stop VARCHAR(200) DEFAULT '',
  to_stop VARCHAR(200) DEFAULT '',
  total_fare DOUBLE PRECISION DEFAULT 0,
  status VARCHAR(20) DEFAULT 'booked',
  payment_method VARCHAR(20) DEFAULT 'wallet',
  payment_id VARCHAR(200) DEFAULT '',
  start_time VARCHAR(20) DEFAULT '',
  boarded_at TIMESTAMP,
  verified_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  verified_at TIMESTAMP,
  sms_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tickets_passenger ON tickets(passenger_id);
CREATE INDEX IF NOT EXISTS idx_tickets_bus ON tickets(bus_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_created ON tickets(created_at);

-- ── Ticket Passengers ────────────────────────────
CREATE TABLE IF NOT EXISTS ticket_passengers (
  id SERIAL PRIMARY KEY,
  ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  age INTEGER DEFAULT 0,
  gender VARCHAR(10) DEFAULT '',
  concession_type VARCHAR(20) DEFAULT 'none'
);

-- ── Payments ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  passenger_id INTEGER REFERENCES passengers(id) ON DELETE SET NULL,
  ticket_id INTEGER REFERENCES tickets(id) ON DELETE SET NULL,
  amount DOUBLE PRECISION NOT NULL,
  method VARCHAR(20) NOT NULL,
  razorpay_order_id VARCHAR(200) DEFAULT '',
  razorpay_payment_id VARCHAR(200) DEFAULT '',
  razorpay_signature VARCHAR(200) DEFAULT '',
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Wallet Transactions ──────────────────────────
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id SERIAL PRIMARY KEY,
  passenger_id INTEGER REFERENCES passengers(id) ON DELETE CASCADE,
  type VARCHAR(20) NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  description TEXT DEFAULT '',
  reference_id VARCHAR(200) DEFAULT '',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Bus Locations ────────────────────────────────
CREATE TABLE IF NOT EXISTS bus_locations (
  id SERIAL PRIMARY KEY,
  bus_id INTEGER NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL,
  lon DOUBLE PRECISION NOT NULL,
  speed DOUBLE PRECISION DEFAULT 0,
  heading DOUBLE PRECISION DEFAULT 0,
  recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bus_locations_bus ON bus_locations(bus_id);
CREATE INDEX IF NOT EXISTS idx_bus_locations_time ON bus_locations(recorded_at);

-- ── Notifications ────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  passenger_id INTEGER REFERENCES passengers(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(20) DEFAULT 'info',
  is_read BOOLEAN DEFAULT FALSE,
  fcm_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Complaints ───────────────────────────────────
CREATE TABLE IF NOT EXISTS complaints (
  id SERIAL PRIMARY KEY,
  passenger_id INTEGER REFERENCES passengers(id) ON DELETE SET NULL,
  bus_id INTEGER REFERENCES buses(id) ON DELETE SET NULL,
  ticket_number VARCHAR(20) DEFAULT '',
  subject VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'open',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Fines ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fines (
  id SERIAL PRIMARY KEY,
  passenger_contact VARCHAR(20) NOT NULL,
  bus_id INTEGER REFERENCES buses(id) ON DELETE SET NULL,
  issued_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  amount DOUBLE PRECISION DEFAULT 500,
  status VARCHAR(20) DEFAULT 'unpaid',
  ticket_number VARCHAR(20) DEFAULT '',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ── Audit Log ────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id SERIAL PRIMARY KEY,
  user_id INTEGER,
  user_role VARCHAR(20),
  action VARCHAR(50) NOT NULL,
  resource VARCHAR(50) NOT NULL,
  resource_id INTEGER,
  details JSONB DEFAULT '{}',
  ip_address VARCHAR(45),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit_log(created_at);

-- ── Performance Indexes ──────────────────────────
-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_tickets_passenger_date ON tickets(passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_bus_status ON tickets(bus_id, status);
CREATE INDEX IF NOT EXISTS idx_buses_route_status ON buses(route_id, travel_status);
CREATE INDEX IF NOT EXISTS idx_payments_passenger ON payments(passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_passenger_read ON notifications(passenger_id, is_read);

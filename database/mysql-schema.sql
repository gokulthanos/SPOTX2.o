-- ─────────────────────────────────────────────────
-- SpotX 4.0 — MySQL 8.x Schema
-- Engine: InnoDB, Charset: utf8mb4
-- ─────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS spotx
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE spotx;

-- ── Cities ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS cities (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  state VARCHAR(100) DEFAULT 'Tamil Nadu',
  lat DOUBLE DEFAULT 0,
  lon DOUBLE DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Stops ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stops (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  city_id INT,
  lat DOUBLE DEFAULT 0,
  lon DOUBLE DEFAULT 0,
  stop_type VARCHAR(20) DEFAULT 'stop',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Routes ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS routes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  route_number VARCHAR(20) NOT NULL,
  name VARCHAR(200) NOT NULL,
  from_stop_id INT,
  to_stop_id INT,
  distance_km DOUBLE DEFAULT 0,
  base_fare DOUBLE DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (from_stop_id) REFERENCES stops(id) ON DELETE SET NULL,
  FOREIGN KEY (to_stop_id) REFERENCES stops(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Buses ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS buses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  bus_number VARCHAR(20) NOT NULL UNIQUE,
  route_id INT,
  bus_type VARCHAR(50) DEFAULT 'Normal',
  capacity INT DEFAULT 45,
  current_occupancy INT DEFAULT 0,
  current_stop_id INT,
  current_stop_index INT DEFAULT 0,
  travel_status VARCHAR(30) DEFAULT 'Not Started',
  delay_minutes INT DEFAULT 0,
  driver_name VARCHAR(200) DEFAULT '',
  lat DOUBLE DEFAULT 0,
  lon DOUBLE DEFAULT 0,
  city VARCHAR(100) DEFAULT 'Chennai',
  stops JSON,
  from_stop VARCHAR(200) DEFAULT '',
  to_stop VARCHAR(200) DEFAULT '',
  arrival_time VARCHAR(20) DEFAULT '',
  fare DOUBLE DEFAULT 0,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE SET NULL,
  FOREIGN KEY (current_stop_id) REFERENCES stops(id) ON DELETE SET NULL,
  INDEX idx_buses_route (route_id),
  INDEX idx_buses_city (city),
  INDEX idx_buses_status (travel_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Schedules ────────────────────────────────────
CREATE TABLE IF NOT EXISTS schedules (
  id INT AUTO_INCREMENT PRIMARY KEY,
  bus_id INT NOT NULL,
  stop_id INT NOT NULL,
  stop_sequence INT NOT NULL,
  scheduled_arrival VARCHAR(20) NOT NULL,
  scheduled_departure VARCHAR(20) NOT NULL,
  distance_from_origin DOUBLE DEFAULT 0,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE CASCADE,
  FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Passengers ───────────────────────────────────
CREATE TABLE IF NOT EXISTS passengers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(200) NOT NULL DEFAULT '',
  contact VARCHAR(20) UNIQUE NOT NULL,
  email VARCHAR(200) DEFAULT '',
  password_hash VARCHAR(1000) NOT NULL DEFAULT '',
  refresh_token VARCHAR(1000) DEFAULT '',
  wallet_balance DOUBLE DEFAULT 0.0,
  fcm_token VARCHAR(1000) DEFAULT '',
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Users (Officers / Admin / Drivers) ──────────
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(200) UNIQUE NOT NULL,
  password_hash VARCHAR(1000) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'STAFF',
  refresh_token VARCHAR(1000) DEFAULT '',
  assigned_route_id INT,
  assigned_bus_id INT,
  fcm_token VARCHAR(1000) DEFAULT '',
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (assigned_route_id) REFERENCES routes(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── OTPs ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS otps (
  id INT AUTO_INCREMENT PRIMARY KEY,
  contact VARCHAR(20) NOT NULL,
  otp VARCHAR(10) NOT NULL,
  expires_at DATETIME NOT NULL,
  verified TINYINT(1) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otps_contact (contact)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Tickets ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_number VARCHAR(10) UNIQUE NOT NULL,
  passenger_id INT,
  bus_id INT,
  bus_number VARCHAR(20) DEFAULT '',
  from_stop VARCHAR(200) DEFAULT '',
  to_stop VARCHAR(200) DEFAULT '',
  total_fare DOUBLE DEFAULT 0,
  status VARCHAR(20) DEFAULT 'booked',
  payment_method VARCHAR(20) DEFAULT 'wallet',
  payment_id VARCHAR(200) DEFAULT '',
  start_time VARCHAR(20) DEFAULT '',
  boarded_at DATETIME,
  verified_by INT,
  verified_at DATETIME,
  sms_sent TINYINT(1) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE SET NULL,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE SET NULL,
  FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_tickets_passenger (passenger_id),
  INDEX idx_tickets_bus (bus_id),
  INDEX idx_tickets_status (status),
  INDEX idx_tickets_created (created_at),
  INDEX idx_tickets_passenger_date (passenger_id, created_at DESC),
  INDEX idx_tickets_bus_status (bus_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Ticket Passengers ────────────────────────────
CREATE TABLE IF NOT EXISTS ticket_passengers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_id INT NOT NULL,
  name VARCHAR(200) NOT NULL,
  age INT DEFAULT 0,
  gender VARCHAR(10) DEFAULT '',
  concession_type VARCHAR(20) DEFAULT 'none',
  FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Payments ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_id INT,
  ticket_id INT,
  amount DOUBLE NOT NULL,
  method VARCHAR(20) NOT NULL,
  razorpay_order_id VARCHAR(200) DEFAULT '',
  razorpay_payment_id VARCHAR(200) DEFAULT '',
  razorpay_signature VARCHAR(200) DEFAULT '',
  status VARCHAR(20) DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE SET NULL,
  FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE SET NULL,
  INDEX idx_payments_passenger (passenger_id, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Wallet Transactions ──────────────────────────
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_id INT,
  type VARCHAR(20) NOT NULL,
  amount DOUBLE NOT NULL,
  description VARCHAR(500) DEFAULT '',
  reference_id VARCHAR(200) DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Bus Locations ────────────────────────────────
CREATE TABLE IF NOT EXISTS bus_locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  bus_id INT NOT NULL,
  lat DOUBLE NOT NULL,
  lon DOUBLE NOT NULL,
  speed DOUBLE DEFAULT 0,
  heading DOUBLE DEFAULT 0,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE CASCADE,
  INDEX idx_bus_locations_bus (bus_id),
  INDEX idx_bus_locations_time (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Notifications ────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_id INT,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(20) DEFAULT 'info',
  is_read TINYINT(1) DEFAULT 0,
  fcm_sent TINYINT(1) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE CASCADE,
  INDEX idx_notifications_passenger_read (passenger_id, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Complaints ───────────────────────────────────
CREATE TABLE IF NOT EXISTS complaints (
  id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_id INT,
  bus_id INT,
  ticket_number VARCHAR(20) DEFAULT '',
  subject VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'open',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE SET NULL,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Fines ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fines (
  id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_contact VARCHAR(20) NOT NULL,
  bus_id INT,
  issued_by INT,
  reason TEXT NOT NULL,
  amount DOUBLE DEFAULT 500,
  status VARCHAR(20) DEFAULT 'unpaid',
  ticket_number VARCHAR(20) DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE SET NULL,
  FOREIGN KEY (issued_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Audit Log ────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  user_role VARCHAR(20),
  action VARCHAR(50) NOT NULL,
  resource VARCHAR(50) NOT NULL,
  resource_id INT,
  details JSON,
  ip_address VARCHAR(45),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_user (user_id),
  INDEX idx_audit_action (action),
  INDEX idx_audit_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Performance Composite Indexes ────────────────
CREATE INDEX idx_buses_route_status ON buses(route_id, travel_status);

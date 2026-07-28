-- ─────────────────────────────────────────────────
-- SpotX 5.0 — Urban Transit MVP
-- Engine: MySQL 8.x, InnoDB, utf8mb4
-- ─────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS spotx
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE spotx;

-- ── Passengers ───────────────────────────────────
CREATE TABLE IF NOT EXISTS passengers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(200) NOT NULL DEFAULT '',
  dob DATE DEFAULT NULL,
  gender ENUM('male','female','other') DEFAULT 'male',
  mobile VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(200) DEFAULT '',
  emergency_contact VARCHAR(15) DEFAULT '',
  password_hash VARCHAR(1000) NOT NULL,
  wallet_balance DOUBLE DEFAULT 0.0,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Conductors ───────────────────────────────────
CREATE TABLE IF NOT EXISTS conductors (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  username VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(1000) NOT NULL,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Stops ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stops (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  lat DOUBLE DEFAULT 0,
  lon DOUBLE DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Routes ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS routes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  route_number VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  base_fare DOUBLE DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Buses ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS buses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  bus_number VARCHAR(20) NOT NULL UNIQUE,
  route_id INT NOT NULL,
  bus_type VARCHAR(50) DEFAULT 'Normal',
  capacity INT DEFAULT 45,
  travel_status ENUM('scheduled','running','completed','cancelled') DEFAULT 'scheduled',
  departure_time VARCHAR(20) DEFAULT '',
  arrival_time VARCHAR(20) DEFAULT '',
  fare DOUBLE DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
  INDEX idx_buses_route (route_id),
  INDEX idx_buses_status (travel_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Bus-Stop Mapping (stops each bus visits in order) ──
CREATE TABLE IF NOT EXISTS bus_stops (
  id INT AUTO_INCREMENT PRIMARY KEY,
  bus_id INT NOT NULL,
  stop_id INT NOT NULL,
  stop_sequence INT NOT NULL,
  arrival_time VARCHAR(20) DEFAULT '',
  departure_time VARCHAR(20) DEFAULT '',
  distance_from_origin DOUBLE DEFAULT 0,
  fare_from_origin DOUBLE DEFAULT 0,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE CASCADE,
  FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE CASCADE,
  UNIQUE KEY unique_bus_stop_seq (bus_id, stop_sequence),
  INDEX idx_bus_stops_bus (bus_id),
  INDEX idx_bus_stops_stop (stop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── OTPs ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS otps (
  id INT AUTO_INCREMENT PRIMARY KEY,
  contact VARCHAR(15) NOT NULL,
  otp VARCHAR(10) NOT NULL,
  expires_at DATETIME NOT NULL,
  verified TINYINT(1) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otps_contact (contact)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Tickets ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pnr VARCHAR(20) UNIQUE NOT NULL,
  passenger_id INT NOT NULL,
  bus_id INT NOT NULL,
  boarding_stop_id INT NOT NULL,
  destination_stop_id INT NOT NULL,
  passenger_name VARCHAR(200) NOT NULL,
  passenger_dob DATE DEFAULT NULL,
  passenger_gender VARCHAR(10) DEFAULT '',
  route_name VARCHAR(200) DEFAULT '',
  bus_number VARCHAR(20) DEFAULT '',
  boarding_stop_name VARCHAR(200) DEFAULT '',
  destination_stop_name VARCHAR(200) DEFAULT '',
  fare DOUBLE DEFAULT 0,
  convenience_fee DOUBLE DEFAULT 0,
  platform_fee DOUBLE DEFAULT 0,
  total_amount DOUBLE DEFAULT 0,
  payment_method VARCHAR(30) DEFAULT 'upi',
  payment_status ENUM('pending','completed','failed','refunded') DEFAULT 'pending',
  ticket_status ENUM('active','used','cancelled','expired') DEFAULT 'active',
  qr_data TEXT,
  journey_date DATE DEFAULT NULL,
  journey_time VARCHAR(20) DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE CASCADE,
  FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE CASCADE,
  FOREIGN KEY (boarding_stop_id) REFERENCES stops(id) ON DELETE CASCADE,
  FOREIGN KEY (destination_stop_id) REFERENCES stops(id) ON DELETE CASCADE,
  INDEX idx_tickets_passenger (passenger_id),
  INDEX idx_tickets_pnr (pnr),
  INDEX idx_tickets_bus (bus_id),
  INDEX idx_tickets_status (ticket_status),
  INDEX idx_tickets_passenger_date (passenger_id, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Payments ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_id INT NOT NULL,
  passenger_id INT NOT NULL,
  amount DOUBLE NOT NULL,
  method VARCHAR(30) NOT NULL,
  status ENUM('pending','completed','failed','refunded') DEFAULT 'pending',
  mock_transaction_id VARCHAR(200) DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
  FOREIGN KEY (passenger_id) REFERENCES passengers(id) ON DELETE CASCADE,
  INDEX idx_payments_passenger (passenger_id, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Ticket Verifications (conductor scans) ──────
CREATE TABLE IF NOT EXISTS ticket_verifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_id INT NOT NULL,
  conductor_id INT NOT NULL,
  result ENUM('valid','invalid','expired') NOT NULL,
  verified_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
  FOREIGN KEY (conductor_id) REFERENCES conductors(id) ON DELETE CASCADE,
  INDEX idx_verifications_ticket (ticket_id),
  INDEX idx_verifications_conductor (conductor_id),
  INDEX idx_verifications_date (verified_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

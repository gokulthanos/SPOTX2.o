// server/db.js
// ─────────────────────────────────────────────────
// SpotX 4.0 — Database Layer
// Engine: MySQL 8.x via mysql2/promise
// ─────────────────────────────────────────────────
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const { MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE } = require('./config/env');
const logger = require('./utils/logger');

let pool = null;

async function initDB() {
  pool = mysql.createPool({
    host: MYSQL_HOST,
    port: MYSQL_PORT,
    user: MYSQL_USER,
    password: MYSQL_PASSWORD,
    database: MYSQL_DATABASE,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    charset: 'utf8mb4',
  });

  // Test connection
  const conn = await pool.getConnection();
  logger.info(`[DB] Connected to MySQL at ${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}`);
  conn.release();

  return pool;
}

/**
 * Auto-create all tables from the MySQL schema file.
 * Safe to run on every startup — uses IF NOT EXISTS.
 */
async function createTables() {
  try {
    const schemaPath = path.join(__dirname, '..', 'database', 'mysql-schema.sql');
    if (!fs.existsSync(schemaPath)) {
      logger.warn('[DB] mysql-schema.sql not found — skipping auto-create');
      return;
    }

    const schema = fs.readFileSync(schemaPath, 'utf-8');

    // Split by semicolons and execute each statement
    // Filter out comments and empty lines
    const statements = schema
      .split(';')
      .map(s => s.replace(/--[^\n]*/g, '').trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const stmt of statements) {
      try {
        await pool.execute(stmt);
      } catch (err) {
        // Ignore "table already exists" and "duplicate key" errors during init
        if (err.code === 'ER_TABLE_EXISTS_ERROR' || err.code === 'ER_DUP_ENTRY') continue;
        logger.warn(`[DB] Schema statement skipped: ${err.message}`);
      }
    }

    logger.info('[DB] MySQL tables verified / created');
  } catch (err) {
    logger.error(`[DB] Error creating tables: ${err.message}`);
  }
}

/**
 * Execute a query and return the first matching row, or null.
 */
async function getOne(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows.length > 0 ? rows[0] : null;
}

/**
 * Execute a query and return all matching rows.
 */
async function getAll(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows;
}

/**
 * Execute a write query (INSERT / UPDATE / DELETE).
 */
async function run(sql, params = []) {
  const [result] = await pool.execute(sql, params);
  return result;
}

/**
 * Return the last inserted row id.
 */
async function lastInsertId() {
  const [result] = await pool.execute('SELECT LAST_INSERT_ID() as id');
  return result[0] ? result[0].id : null;
}

/**
 * No-op for MySQL (transactions handle this automatically).
 */
function saveDB() {
  // No-op — MySQL handles persistence automatically
}

module.exports = { initDB, createTables, getOne, getAll, run, saveDB, lastInsertId, pool };

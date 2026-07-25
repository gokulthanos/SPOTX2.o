// server/config/env.js
// ─────────────────────────────────────────────────
// Centralized environment configuration.
// All env variables are read here and exported as
// typed constants — never use process.env directly
// outside this file.
// ─────────────────────────────────────────────────
require('dotenv').config();

module.exports = {
  PORT: parseInt(process.env.PORT || '5000', 10),
  NODE_ENV: process.env.NODE_ENV || 'development',

  // JWT
  JWT_SECRET: process.env.JWT_SECRET || 'spotx_dev_jwt_secret_min_32_chars!!',
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'spotx_dev_refresh_secret_min_32!!',
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '15m',
  JWT_REFRESH_EXPIRES_IN: process.env.JWT_REFRESH_EXPIRES_IN || '7d',

  // Database
  DB_PATH: process.env.DB_PATH || './spotx.db',

  // MySQL
  MYSQL_HOST: process.env.MYSQL_HOST || 'localhost',
  MYSQL_PORT: parseInt(process.env.MYSQL_PORT || '3306', 10),
  MYSQL_USER: process.env.MYSQL_USER || 'root',
  MYSQL_PASSWORD: process.env.MYSQL_PASSWORD || 'spotx123',
  MYSQL_DATABASE: process.env.MYSQL_DATABASE || 'spotx',

  // PostgreSQL (production)
  DATABASE_URL: process.env.DATABASE_URL || '',

  // CORS
  CORS_ORIGIN: process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(',')
    : (process.env.NODE_ENV === 'production'
        ? ['https://your-domain.com']
        : ['http://localhost:3000', 'http://localhost:*', 'http://127.0.0.1:*']),

  // Razorpay
  RAZORPAY_KEY_ID: process.env.RAZORPAY_KEY_ID || '',
  RAZORPAY_KEY_SECRET: process.env.RAZORPAY_KEY_SECRET || '',

  // Rate limiting
  OTP_MAX_REQUESTS: parseInt(process.env.OTP_MAX_REQUESTS || '3', 10),
  OTP_WINDOW_MINUTES: parseInt(process.env.OTP_WINDOW_MINUTES || '10', 10),

  // SMS Provider
  SMS_PROVIDER: process.env.SMS_PROVIDER || 'CONSOLE',
  MSG91_AUTH_KEY: process.env.MSG91_AUTH_KEY || '',
  MSG91_TEMPLATE_ID: process.env.MSG91_TEMPLATE_ID || '',
  FAST2SMS_API_KEY: process.env.FAST2SMS_API_KEY || '',
  TWILIO_SID: process.env.TWILIO_SID || '',
  TWILIO_AUTH: process.env.TWILIO_AUTH || '',
  TWILIO_FROM: process.env.TWILIO_FROM || '',

  // Firebase Cloud Messaging
  FIREBASE_SERVICE_ACCOUNT: process.env.FIREBASE_SERVICE_ACCOUNT || '',
};

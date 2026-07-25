// server/services/sms.service.js
// ─────────────────────────────────────────────────
// SMS Service — Abstraction layer for multiple providers
// Supports: MSG91, Fast2SMS, Twilio, Console (dev)
//
// Set SMS_PROVIDER env var to switch providers:
//   MSG91, FAST2SMS, TWILIO, CONSOLE (default)
// ─────────────────────────────────────────────────
const logger = require('../utils/logger');

const SMS_PROVIDER = process.env.SMS_PROVIDER || 'CONSOLE';
const MSG91_AUTH_KEY = process.env.MSG91_AUTH_KEY || '';
const MSG91_TEMPLATE_ID = process.env.MSG91_TEMPLATE_ID || '';
const FAST2SMS_API_KEY = process.env.FAST2SMS_API_KEY || '';
const TWILIO_SID = process.env.TWILIO_SID || '';
const TWILIO_AUTH = process.env.TWILIO_AUTH || '';
const TWILIO_FROM = process.env.TWILIO_FROM || '';

/**
 * Send an SMS to a phone number.
 * Falls back to console logging in development.
 *
 * @param {string} to - Phone number
 * @param {string} message - SMS body text
 * @param {Object} [options] - Extra params (templateId, variables, etc.)
 * @returns {Promise<{ success: boolean, provider: string, messageId?: string }>}
 */
async function sendSMS(to, message, options = {}) {
  // Normalize phone number
  const cleanNumber = to.replace(/\D/g, '');
  const formatted = cleanNumber.length === 10 ? `+91${cleanNumber}` : cleanNumber;

  switch (SMS_PROVIDER) {
    case 'MSG91':
      return sendViaMSG91(formatted, message, options);
    case 'FAST2SMS':
      return sendViaFast2SMS(formatted, message, options);
    case 'TWILIO':
      return sendViaTwilio(formatted, message, options);
    default:
      return sendViaConsole(formatted, message);
  }
}

/**
 * Console provider — logs SMS to console (development only).
 */
async function sendViaConsole(to, message) {
  logger.info(`[SMS-CONSOLE] To: ${to} | Message: ${message}`);
  return { success: true, provider: 'CONSOLE', messageId: `DEV-${Date.now()}` };
}

/**
 * MSG91 provider — https://msg91.com
 */
async function sendViaMSG91(to, message, options = {}) {
  if (!MSG91_AUTH_KEY) {
    logger.warn('[SMS] MSG91 auth key not configured, falling back to console');
    return sendViaConsole(to, message);
  }

  try {
    const https = require('https');
    const payload = JSON.stringify({
      authorization: MSG91_AUTH_KEY,
      message: message,
      sender: 'SPOTX',
      route: 4,
      numbers: to.replace('+91', ''),
      ...(MSG91_TEMPLATE_ID && {
        variables: { '% otp%': message.match(/\d{6}/)?.[0] || '' },
        DLT_TE_ID: MSG91_TEMPLATE_ID,
      }),
    });

    return new Promise((resolve, reject) => {
      const req = https.request({
        hostname: 'api.msg91.com',
        path: '/api/v5/flow',
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': payload.length },
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          logger.info(`[SMS-MSG91] Sent to ${to}: ${res.statusCode}`);
          resolve({ success: true, provider: 'MSG91', messageId: `MSG91-${Date.now()}` });
        });
      });
      req.on('error', (err) => {
        logger.error('[SMS-MSG91] Error:', err.message);
        resolve({ success: false, provider: 'MSG91', error: err.message });
      });
      req.write(payload);
      req.end();
    });
  } catch (err) {
    logger.error('[SMS-MSG91] Failed:', err.message);
    return { success: false, provider: 'MSG91', error: err.message };
  }
}

/**
 * Fast2SMS provider — https://fast2sms.com
 */
async function sendViaFast2SMS(to, message, options = {}) {
  if (!FAST2SMS_API_KEY) {
    logger.warn('[SMS] Fast2SMS API key not configured, falling back to console');
    return sendViaConsole(to, message);
  }

  try {
    const https = require('https');
    const number = to.replace('+91', '');
    const payload = `sender_id=FSTSMS&message=${encodeURIComponent(message)}&language=english&route=q&numbers=${number}`;

    return new Promise((resolve) => {
      const req = https.request({
        hostname: 'www.fast2sms.com',
        path: '/dev/bulkV2',
        method: 'POST',
        headers: {
          'authorization': FAST2SMS_API_KEY,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': payload.length,
        },
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          logger.info(`[SMS-FAST2SMS] Sent to ${to}: ${res.statusCode}`);
          resolve({ success: true, provider: 'FAST2SMS', messageId: `FS2S-${Date.now()}` });
        });
      });
      req.on('error', (err) => {
        resolve({ success: false, provider: 'FAST2SMS', error: err.message });
      });
      req.write(payload);
      req.end();
    });
  } catch (err) {
    return { success: false, provider: 'FAST2SMS', error: err.message };
  }
}

/**
 * Twilio provider — https://twilio.com
 */
async function sendViaTwilio(to, message, options = {}) {
  if (!TWILIO_SID || !TWILIO_AUTH) {
    logger.warn('[SMS] Twilio credentials not configured, falling back to console');
    return sendViaConsole(to, message);
  }

  try {
    const https = require('https');
    const from = TWILIO_FROM || '+15005550006';
    const payload = `To=${encodeURIComponent(to)}&From=${encodeURIComponent(from)}&Body=${encodeURIComponent(message)}`;
    const auth = Buffer.from(`${TWILIO_SID}:${TWILIO_AUTH}`).toString('base64');

    return new Promise((resolve) => {
      const req = https.request({
        hostname: 'api.twilio.com',
        path: `/2010-04-01/Accounts/${TWILIO_SID}/Messages.json`,
        method: 'POST',
        headers: {
          'Authorization': `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': payload.length,
        },
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          logger.info(`[SMS-TWILIO] Sent to ${to}: ${res.statusCode}`);
          resolve({ success: true, provider: 'TWILIO', messageId: `TW-${Date.now()}` });
        });
      });
      req.on('error', (err) => {
        resolve({ success: false, provider: 'TWILIO', error: err.message });
      });
      req.write(payload);
      req.end();
    });
  } catch (err) {
    return { success: false, provider: 'TWILIO', error: err.message };
  }
}

/**
 * Send ticket confirmation SMS.
 */
async function sendTicketSMS(to, ticketData) {
  const { ticketNumber, fromStop, toStop, fare, busNumber } = ticketData;
  const message = `SpotX Ticket Confirmed!\nTicket: ${ticketNumber}\nBus: ${busNumber}\n${fromStop} → ${toStop}\nFare: ₹${fare}\nShow QR at boarding.`;
  return sendSMS(to, message);
}

/**
 * Send OTP SMS.
 */
async function sendOTP(to, otp) {
  const message = `Your SpotX OTP is ${otp}. Valid for 10 minutes. Do not share this code.`;
  return sendSMS(to, message);
}

/**
 * Send delay notification SMS.
 */
async function sendDelaySMS(to, busNumber, delayMinutes) {
  const message = `SpotX Alert: Bus ${busNumber} delayed by ${delayMinutes} minutes. Sorry for the inconvenience.`;
  return sendSMS(to, message);
}

module.exports = {
  sendSMS,
  sendTicketSMS,
  sendOTP,
  sendDelaySMS,
};

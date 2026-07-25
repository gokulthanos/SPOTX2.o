// server/services/fcm.service.js
// ─────────────────────────────────────────────────
// Firebase Cloud Messaging (FCM) Service
// Handles push notification sending and device token management
//
// NOTE: Requires FIREBASE_SERVICE_ACCOUNT env var (JSON string)
// or firebase-service-account.json in server root
// ─────────────────────────────────────────────────
const logger = require('../utils/logger');

let fcmInitialized = false;
let admin = null;

/**
 * Initialize Firebase Admin SDK.
 * In production, set FIREBASE_SERVICE_ACCOUNT as JSON string env var.
 */
function initFCM() {
  try {
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!serviceAccount) {
      logger.info('[FCM] No Firebase service account configured — push notifications disabled');
      return false;
    }

    admin = require('firebase-admin');
    const parsed = typeof serviceAccount === 'string' ? JSON.parse(serviceAccount) : serviceAccount;

    admin.initializeApp({
      credential: admin.credential.cert(parsed),
    });

    fcmInitialized = true;
    logger.info('[FCM] Firebase Admin SDK initialized');
    return true;
  } catch (err) {
    logger.warn(`[FCM] Failed to initialize Firebase: ${err.message}`);
    return false;
  }
}

/**
 * Send a push notification to a device token.
 *
 * @param {string} fcmToken - Device FCM token
 * @param {Object} notification - { title, body }
 * @param {Object} [data] - Additional data payload
 * @returns {Promise<{ success: boolean, messageId?: string }>}
 */
async function sendPush(fcmToken, notification, data = {}) {
  if (!fcmInitialized || !admin) {
    logger.debug('[FCM] Not initialized, skipping push');
    return { success: false, reason: 'not_initialized' };
  }

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: notification.channelId || 'spotx_general',
          priority: 'max',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title: notification.title, body: notification.body },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`[FCM] Push sent: ${response}`);
    return { success: true, messageId: response };
  } catch (err) {
    logger.error(`[FCM] Push failed: ${err.message}`);
    return { success: false, error: err.message };
  }
}

/**
 * Send push notification to multiple device tokens.
 */
async function sendMulticast(tokens, notification, data = {}) {
  if (!fcmInitialized || !admin || tokens.length === 0) {
    return { success: false, reason: 'not_initialized_or_empty' };
  }

  try {
    const message = {
      tokens,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: notification.channelId || 'spotx_general',
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info(`[FCM] Multicast sent: ${response.successCount}/${tokens.length} succeeded`);
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (err) {
    logger.error(`[FCM] Multicast failed: ${err.message}`);
    return { success: false, error: err.message };
  }
}

/**
 * Subscribe tokens to a topic.
 */
async function subscribeToTopic(tokens, topic) {
  if (!fcmInitialized || !admin) return { success: false };

  try {
    await admin.messaging().subscribeToTopic(tokens, topic);
    logger.info(`[FCM] Subscribed ${tokens.length} tokens to topic: ${topic}`);
    return { success: true };
  } catch (err) {
    logger.error(`[FCM] Subscribe failed: ${err.message}`);
    return { success: false, error: err.message };
  }
}

module.exports = {
  initFCM,
  sendPush,
  sendMulticast,
  subscribeToTopic,
};

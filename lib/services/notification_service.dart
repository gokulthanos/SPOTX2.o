// lib/services/notification_service.dart
// ─────────────────────────────────────────────────
// SpotX 4.0 — Firebase Cloud Messaging Service
//
// Handles:
//   - FCM initialization and permission requests
//   - Foreground notifications (flutter_local_notifications)
//   - Background / terminated app message handling
//   - FCM token retrieval + auto-refresh
//   - Token sync to SpotX backend
// ─────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'storage_service.dart';

// ── Background message handler (must be top-level) ──────────────────
/// Called when the app is in background/terminated and a FCM data message arrives.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // NOTE: Firebase.initializeApp() is already called in main.dart before this.
  // Show a local notification for the background message.
  await NotificationService._showLocalNotification(
    title: message.notification?.title ?? 'SpotX Alert',
    body: message.notification?.body ?? '',
    payload: jsonEncode(message.data),
  );
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Android notification channel for SpotX
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'spotx_high_importance',
    'SpotX Notifications',
    description: 'Critical transit alerts, ticket confirmations, and bus updates.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ── Initialization ───────────────────────────────────────────────
  static Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize flutter_local_notifications
    await _initLocalNotifications();

    // Request permissions from the user
    await _requestPermissions();

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification opened the app from background state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App launched from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get and sync token
    await _syncToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed: $newToken');
      await _uploadToken(newToken);
    });
  }

  // ── Permission Request ───────────────────────────────────────────
  static Future<NotificationSettings> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  // ── Local Notifications Setup ────────────────────────────────────
  static Future<void> _initLocalNotifications() async {
    // Android channel creation
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsIOS,
      ),
      onDidReceiveNotificationResponse: (details) {
        _onLocalNotificationTap(details.payload);
      },
    );

    // On Android 13+, ensure foreground service notifications are shown
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // ── Foreground Message Handler ───────────────────────────────────
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    _showLocalNotification(
      title: message.notification?.title ?? 'SpotX Alert',
      body: message.notification?.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  // ── Show Local Notification ──────────────────────────────────────
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── Notification Tap Handlers ────────────────────────────────────
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    // TODO: Use a NavigationService or global key to navigate to relevant screen
    // e.g., if message.data['screen'] == 'ticket', navigate to ticket screen
  }

  static void _onLocalNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      debugPrint('[FCM] Local notification tapped with data: $data');
      // TODO: Navigate based on data['screen']
    } catch (_) {}
  }

  // ── Token Management ─────────────────────────────────────────────

  /// Get the current FCM token.
  static Future<String?> getToken() async {
    try {
      final token = await _fcm.getToken();
      return token;
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
      return null;
    }
  }

  /// Sync FCM token to backend — call after login.
  static Future<void> syncTokenAfterLogin() async {
    await _syncToken();
  }

  static Future<void> _syncToken() async {
    final token = await getToken();
    if (token == null) return;

    // Cache token locally
    await StorageService.setString('fcmToken', token);
    debugPrint('[FCM] Token: $token');

    // Upload to backend
    await _uploadToken(token);
  }

  static Future<void> _uploadToken(String token) async {
    try {
      final authToken = await StorageService.getSecure('passengerToken') ??
          await StorageService.getSecure('authToken');

      if (authToken == null || authToken.isEmpty) {
        // Not logged in — defer upload until login
        debugPrint('[FCM] Not logged in — token upload deferred');
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[FCM] Token uploaded to backend');
      } else {
        debugPrint('[FCM] Token upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Token upload error: $e');
    }
  }

  // ── Topic Subscription ───────────────────────────────────────────

  /// Subscribe to a FCM topic (e.g., city-wide alerts).
  static Future<void> subscribeTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from a FCM topic.
  static Future<void> unsubscribeTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from topic: $topic');
  }

  // ── Delete Token (on logout) ─────────────────────────────────────
  static Future<void> deleteToken() async {
    await _fcm.deleteToken();
    await StorageService.remove('fcmToken');
    debugPrint('[FCM] Token deleted on logout');
  }
}

// lib/main.dart
// ─────────────────────────────────────────────────
// SpotX 4.0 — Application Entry Point
// ─────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/storage_service.dart';
import 'services/realtime_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'core/app_theme.dart';
import 'screens/auth/landing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize local storage (Hive + SecureStorage)
  await StorageService.init();

  // Initialize offline sync service (connectivity listener + pending action queue)
  await OfflineSyncService.initialize();

  // Initialize Firebase (required before FirebaseMessaging)
  // NOTE: Replace DefaultFirebaseOptions with real values from:
  //   flutterfire configure  OR  lib/firebase_options.dart
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize FCM notifications (permissions, handlers, token sync)
    await NotificationService.init();
  } catch (e) {
    // Firebase not configured yet — app runs without push notifications
    // Configure firebase_options.dart with real credentials to enable FCM
    debugPrint('[Firebase] Not configured: $e');
  }

  // Initialize real-time WebSocket connection
  RealtimeService.initialize();

  runApp(const SpotXApp());
}

class SpotXApp extends StatelessWidget {
  const SpotXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final auth = AuthProvider();
          auth.loadFromStorage();
          return auth;
        }),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: MaterialApp(
        title: 'SpotX 4.0',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LandingPage(),
      ),
    );
  }
}

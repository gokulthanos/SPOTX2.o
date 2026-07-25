// lib/firebase_options.dart
// ─────────────────────────────────────────────────
// SpotX 4.0 — Firebase Options Configuration
//
// HOW TO CONFIGURE:
// ─────────────────────────────────────────────────
// 1. Go to https://console.firebase.google.com
// 2. Create a project (or use existing "spotx-app")
// 3. Add an Android app:
//    - Package name: com.example.spotx_ride_app
//    - Download google-services.json
//    - Place it at: android/app/google-services.json
// 4. Run: dart pub global activate flutterfire_cli
// 5. Run: flutterfire configure
//    This will auto-generate this file with your real credentials.
//
// MANUAL CONFIGURATION (if flutterfire CLI is not available):
//   Replace the placeholder values below with real values from
//   your Firebase project settings > General > Your apps.
// ─────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
///
/// Obtain these values from your Firebase project settings:
/// https://console.firebase.google.com/project/_/settings/general
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── REPLACE THESE WITH YOUR REAL FIREBASE CREDENTIALS ──────────
  // Get from: Firebase Console > Project Settings > Your Apps > SDK setup

  static const FirebaseOptions android = FirebaseOptions(
    // TODO: Replace with your real Firebase Android app credentials
    // from google-services.json > client > api_key / client_info
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',         // e.g. 1:123456789:android:abc123
    messagingSenderId: 'YOUR_SENDER_ID',   // e.g. 123456789012
    projectId: 'YOUR_PROJECT_ID',          // e.g. spotx-app-xxxxx
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    // TODO: Replace with your real Firebase iOS app credentials
    // from GoogleService-Info.plist
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.spotxRideApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );
}

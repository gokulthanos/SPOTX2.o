class AppConfig {
  static const String serverPort = '5000';

  // Configures the backend base API URL dynamically.
  // Can be configured at build/run time using:
  // flutter run --dart-define=API_URL=http://your-ip:5000/api/v1
  static String get baseUrl {
    const defineUrl = String.fromEnvironment('API_URL');
    if (defineUrl.isNotEmpty) {
      return defineUrl;
    }
    
    // Default fallback addresses
    return 'http://localhost:$serverPort/api/v1'; 
  }

  // Legacy fallback baseUrl for old routes that haven't been versioned yet (if any)
  static String get legacyBaseUrl {
    const defineUrl = String.fromEnvironment('API_URL');
    if (defineUrl.isNotEmpty) {
      // Strip '/api/v1' from end if present
      if (defineUrl.endsWith('/api/v1')) {
        return defineUrl.substring(0, defineUrl.length - 7);
      }
      return defineUrl;
    }
    return 'http://localhost:$serverPort';
  }

  // WebSocket URL for real-time tracking
  static String get wsUrl {
    const defineUrl = String.fromEnvironment('WS_URL');
    if (defineUrl.isNotEmpty) {
      return defineUrl;
    }
    return 'ws://localhost:$serverPort';
  }
}

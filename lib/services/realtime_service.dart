import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import 'storage_service.dart';

class RealtimeService {
  static String get _baseUrl => AppConfig.legacyBaseUrl;
  static String? _socketUrl;
  static dynamic _socket;
  static bool _connected = false;
  static final Map<String, List<Function(dynamic)>> _listeners = {};
  static Timer? _reconnectTimer;

  static bool get isConnected => _connected;

  static void initialize() {
    try {
      final uri = Uri.parse(_baseUrl);
      _socketUrl = 'ws://${uri.host}:${uri.port}';

      // Attempt socket.io connection
      _connectSocket();
    } catch (e) {
      debugPrint('[WS] Init failed: $e');
    }
  }

  static void _connectSocket() {
    try {
      // Use socket_io_client package
      // This is a simplified version — in production, use the full socket.io client
      debugPrint('[WS] Connecting to $_socketUrl...');
      _connected = true;
      _notifyListeners('connected', {});
    } catch (e) {
      debugPrint('[WS] Socket connect failed: $e');
      _connected = false;
      _scheduleReconnect();
    }
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_connected) _connectSocket();
    });
  }

  /// Join a bus tracking room
  static void joinBusTracking(int busId) {
    debugPrint('[WS] Joining bus:$busId');
    // In production: _socket.emit('bus:join', {'busId': busId});
  }

  /// Leave a bus tracking room
  static void leaveBusTracking(int busId) {
    debugPrint('[WS] Leaving bus:$busId');
    // In production: _socket.emit('bus:leave', {'busId': busId});
  }

  /// Register driver socket
  static void registerDriver(int busId) {
    debugPrint('[WS] Registering driver for bus:$busId');
    // In production: _socket.emit('driver:register', {'busId': busId});
  }

  /// Update driver location via WebSocket
  static void updateLocation({
    required int busId,
    required double lat,
    required double lon,
    double? speed,
    double? heading,
    int? occupancy,
  }) {
    // In production: _socket.emit('bus:update-location', {...});
    debugPrint('[WS] Location update: bus=$busId ($lat, $lon)');
  }

  /// Update bus status
  static void updateStatus(int busId, String status, {int? delayMinutes}) {
    // In production: _socket.emit('bus:update-status', {...});
    debugPrint('[WS] Status update: bus=$busId → $status');
  }

  /// Subscribe to bus location updates
  static void onBusLocation(Function(dynamic) callback) {
    _addListener('bus:location-update', callback);
  }

  /// Subscribe to bus status changes
  static void onBusStatusChange(Function(dynamic) callback) {
    _addListener('bus:status-change', callback);
  }

  /// Subscribe to connection state changes
  static void onConnect(Function(dynamic) callback) {
    _addListener('connected', callback);
  }

  static void onDisconnect(Function(dynamic) callback) {
    _addListener('disconnected', callback);
  }

  static void _addListener(String event, Function(dynamic) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  static void _notifyListeners(String event, dynamic data) {
    final listeners = _listeners[event];
    if (listeners != null) {
      for (final callback in listeners) {
        try {
          callback(data);
        } catch (e) {
          debugPrint('[WS] Listener error: $e');
        }
      }
    }
  }

  /// Disconnect and clean up
  static void dispose() {
    _reconnectTimer?.cancel();
    _connected = false;
    _listeners.clear();
  }

  /// Polling fallback when WebSocket unavailable
  static Future<Map<String, dynamic>?> pollBusLocation(int busId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/buses/$busId'),
        headers: headers,
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      debugPrint('[WS] Poll failed: $e');
    }
    return null;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getSecure('passengerToken') ??
                  await StorageService.getSecure('authToken');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

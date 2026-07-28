import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';

class OfflineSyncService {
  static late Box _syncBox;
  static StreamSubscription? _connectivitySub;
  static bool _isSyncing = false;

  static const String _pendingActionsKey = 'pending_sync_actions';
  static const String _cachedBusesKey = 'cached_buses';
  static const String _cachedTicketsKey = 'cached_tickets';
  static const String _lastSyncKey = 'last_sync_timestamp';

  static Future<void> initialize() async {
    _syncBox = await Hive.openBox('offline_sync_box');

    // Listen for connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        _syncPendingActions();
      }
    });

    // Attempt sync on startup if connected
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    if (result.any((r) => r != ConnectivityResult.none)) {
      _syncPendingActions();
    }
  }

  static void dispose() {
    _connectivitySub?.cancel();
  }

  // ── Queue an action for offline sync ───────────
  static Future<void> queueAction({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final actions = getPendingActions();
    actions.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
    await _syncBox.put(_pendingActionsKey, actions);
    debugPrint('[OfflineSync] Queued action: $type');
  }

  // ── Get all pending offline actions ─────────────
  static List<Map<String, dynamic>> getPendingActions() {
    final raw = _syncBox.get(_pendingActionsKey);
    if (raw == null) return [];
    try {
      return (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Sync pending actions when online ────────────
  static Future<void> _syncPendingActions() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final actions = getPendingActions();
      if (actions.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[OfflineSync] Syncing ${actions.length} pending actions...');

      final failed = <Map<String, dynamic>>[];

      for (final action in actions) {
        try {
          final success = await _executeAction(action);
          if (!success) {
            final retryCount = (action['retryCount'] ?? 0) + 1;
            if (retryCount < 3) {
              action['retryCount'] = retryCount;
              failed.add(action);
            }
          }
        } catch (e) {
          debugPrint('[OfflineSync] Failed to sync action ${action['id']}: $e');
          final retryCount = (action['retryCount'] ?? 0) + 1;
          if (retryCount < 3) {
            action['retryCount'] = retryCount;
            failed.add(action);
          }
        }
      }

      await _syncBox.put(_pendingActionsKey, failed);
      await _syncBox.put(_lastSyncKey, DateTime.now().toIso8601String());

      debugPrint('[OfflineSync] Sync complete. ${actions.length - failed.length} synced, ${failed.length} failed.');
    } finally {
      _isSyncing = false;
    }
  }

  // ── Execute a single queued action ──────────────
  static Future<bool> _executeAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;
    final payload = action['payload'] as Map<String, dynamic>;

    switch (type) {
      case 'BOOK_TICKET':
        final ticketNumber = await ApiService.bookTicket(
          busId: payload['busId'] ?? 0,
          busNumber: payload['busNumber'] ?? '',
          fromStop: payload['fromStop'] ?? '',
          toStop: payload['toStop'] ?? '',
          totalFare: payload['totalFare']?.toDouble() ?? 0,
          passengers: List<Map<String, String>>.from(
            (payload['passengers'] as List? ?? []).map((e) => Map<String, String>.from(e)),
          ),
          paymentMethod: payload['paymentMethod'] ?? 'wallet',
          paymentId: payload['paymentId'] ?? '',
        );
        return ticketNumber.isNotEmpty;

      case 'SUBMIT_COMPLAINT':
        await ApiService.submitComplaint(
          subject: payload['subject'] ?? '',
          description: payload['description'] ?? '',
          busId: payload['busId'],
          ticketNumber: payload['ticketNumber'],
        );
        return true;

      case 'UPDATE_DRIVER_LOCATION':
        await ApiService.shareLocation(
          lat: payload['latitude']?.toDouble() ?? 0,
          lon: payload['longitude']?.toDouble() ?? 0,
        );
        return true;

      default:
        debugPrint('[OfflineSync] Unknown action type: $type');
        return false;
    }
  }

  // ── Cache buses for offline viewing ─────────────
  static Future<void> cacheBuses(List<Map<String, dynamic>> buses) async {
    await _syncBox.put(_cachedBusesKey, buses);
    await _syncBox.put('${_cachedBusesKey}_time', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>> getCachedBuses() {
    final raw = _syncBox.get(_cachedBusesKey);
    if (raw == null) return [];
    try {
      return (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Cache tickets for offline viewing ───────────
  static Future<void> cacheTickets(String contact, List<Map<String, dynamic>> tickets) async {
    await _syncBox.put('${_cachedTicketsKey}_$contact', tickets);
  }

  static List<Map<String, dynamic>> getCachedTickets(String contact) {
    final raw = _syncBox.get('${_cachedTicketsKey}_$contact');
    if (raw == null) return [];
    try {
      return (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Connectivity check ──────────────────────────
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.any((r) => r == ConnectivityResult.none);
  }

  // ── Last sync time ──────────────────────────────
  static String? getLastSyncTime() {
    return _syncBox.get(_lastSyncKey) as String?;
  }

  // ── Clear all offline data ──────────────────────
  static Future<void> clearAll() async {
    await _syncBox.clear();
  }

  // ── Get sync status ─────────────────────────────
  static Map<String, dynamic> getSyncStatus() {
    final pending = getPendingActions();
    return {
      'pendingCount': pending.length,
      'lastSyncTime': getLastSyncTime(),
      'cachedBusCount': getCachedBuses().length,
      'isSyncing': _isSyncing,
    };
  }
}

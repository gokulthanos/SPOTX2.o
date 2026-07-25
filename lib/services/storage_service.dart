import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage();
  static late Box _sessionBox;
  static late Box _ticketsBox;
  static late Box _walletBox;
  static late Box _officerBox;

  static Future<void> init() async {
    // Initialize Hive
    await Hive.initFlutter();
    
    // Open boxes
    _sessionBox = await Hive.openBox('session_box');
    _ticketsBox = await Hive.openBox('tickets_box');
    _walletBox = await Hive.openBox('wallet_box');
    _officerBox = await Hive.openBox('officer_box');

    // Run migration from legacy SharedPreferences on first run
    await _migrateLegacyData();
  }

  /// Automatically migrates session, tickets, and wallet data from SharedPreferences
  static Future<void> _migrateLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // If migration has already run, skip
    if (_sessionBox.get('migrated_v3', defaultValue: false) == true) {
      return;
    }

    // Migrate Passenger Session
    final pToken = prefs.getString('passengerToken');
    if (pToken != null && pToken.isNotEmpty) {
      await _secureStorage.write(key: 'passengerToken', value: pToken);
      await _sessionBox.put('passengerName', prefs.getString('passengerName') ?? '');
      await _sessionBox.put('passengerContact', prefs.getString('passengerContact') ?? '');
      await _sessionBox.put('passengerEmail', prefs.getString('passengerEmail') ?? '');
    }

    // Migrate Officer Session
    final oToken = prefs.getString('authToken');
    if (oToken != null && oToken.isNotEmpty) {
      await _secureStorage.write(key: 'authToken', value: oToken);
      await _sessionBox.put('govOfficerId', prefs.getString('govOfficerId') ?? '');
      await _sessionBox.put('govOfficerName', prefs.getString('govOfficerName') ?? '');
      await _sessionBox.put('userRole', prefs.getString('userRole') ?? 'STAFF');
    }

    // Migrate Tickets for known passengers
    final passengerContact = prefs.getString('passengerContact') ?? '';
    if (passengerContact.isNotEmpty) {
      final rawTickets = prefs.getString('tickets_$passengerContact');
      if (rawTickets != null) {
        try {
          final List decoded = jsonDecode(rawTickets);
          await _ticketsBox.put(passengerContact, decoded.cast<Map>());
        } catch (_) {}
      }

      // Migrate Wallet balance & transactions
      final rawBalance = prefs.getString('wallet_${passengerContact}_balance');
      if (rawBalance != null) {
        await _walletBox.put('${passengerContact}_balance', double.tryParse(rawBalance) ?? 0.0);
      }
      final rawTx = prefs.getString('wallet_${passengerContact}_transactions');
      if (rawTx != null) {
        try {
          final List decoded = jsonDecode(rawTx);
          await _walletBox.put('${passengerContact}_transactions', decoded.cast<Map>());
        } catch (_) {}
      }
    }

    // Migrate Checked Tickets logs
    final rawChecked = prefs.getString('checkedTickets');
    if (rawChecked != null) {
      try {
        final List decoded = jsonDecode(rawChecked);
        await _officerBox.put('checkedTickets', decoded.cast<Map>());
      } catch (_) {}
    }

    // Mark migration complete
    await _sessionBox.put('migrated_v3', true);
  }

  // ── Session Secure Storage helper (JWT Access/Refresh tokens) ──────
  static Future<void> setSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> getSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  static Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  // ── Session non-secure variables helper ──────────────────────────────
  static Future<void> setString(String key, String value) async {
    await _sessionBox.put(key, value);
  }

  static String? getString(String key) {
    return _sessionBox.get(key) as String?;
  }

  static Future<void> remove(String key) async {
    await _sessionBox.delete(key);
  }

  static Future<void> clear() async {
    await _sessionBox.clear();
    await _secureStorage.deleteAll();
  }

  // ── Session variables helpers ───────────────────────────────────────
  static Future<void> savePassengerSession({
    required String token,
    required String name,
    required String contact,
    String? refreshToken,
  }) async {
    await setSecure('passengerToken', token);
    if (refreshToken != null) {
      await setSecure('passengerRefreshToken', refreshToken);
    }
    await setString('passengerName', name);
    await setString('passengerContact', contact);
    await setString('passengerEmail', contact);
  }

  static Future<void> clearPassengerSession() async {
    await deleteSecure('passengerToken');
    await deleteSecure('passengerRefreshToken');
    await remove('passengerName');
    await remove('passengerContact');
    await remove('passengerEmail');
  }

  static Future<void> saveOfficerSession({
    required String token,
    required String officerId,
    required String name,
    required String role,
    String? refreshToken,
  }) async {
    await setSecure('authToken', token);
    if (refreshToken != null) {
      await setSecure('officerRefreshToken', refreshToken);
    }
    await setString('govOfficerId', officerId);
    await setString('govOfficerName', name);
    await setString('userRole', role);
  }

  static Future<void> clearOfficerSession() async {
    await deleteSecure('authToken');
    await deleteSecure('officerRefreshToken');
    await remove('govOfficerId');
    await remove('govOfficerName');
    await remove('userRole');
  }

  // ── Tickets ─────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> getSavedTickets(String email) {
    final rawList = _ticketsBox.get(email);
    if (rawList == null) return [];
    try {
      return (rawList as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTickets(String email, List<Map<String, dynamic>> tickets) async {
    await _ticketsBox.put(email, tickets);
  }

  static Future<void> addTicket(String email, Map<String, dynamic> ticket) async {
    final tickets = getSavedTickets(email);
    tickets.add(ticket);
    await saveTickets(email, tickets);
  }

  // ── Checked tickets (Officer logs) ───────────────────────────────
  static List<Map<String, dynamic>> getCheckedTickets() {
    final rawList = _officerBox.get('checkedTickets');
    if (rawList == null) return [];
    try {
      return (rawList as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCheckedTickets(List<Map<String, dynamic>> list) async {
    await _officerBox.put('checkedTickets', list);
  }

  static Future<void> addCheckedTicket(String ticketNumber) async {
    final list = getCheckedTickets();
    list.add({
      'ticketNumber': ticketNumber,
      'checkedAt': DateTime.now().toIso8601String(),
    });
    await saveCheckedTickets(list);
  }

  // ── Wallet ──────────────────────────────────────────────────────────
  static double getWalletBalance(String email) {
    return _walletBox.get('${email}_balance', defaultValue: 0.0) as double;
  }

  static Future<void> setWalletBalance(String email, double balance) async {
    await _walletBox.put('${email}_balance', balance);
  }

  static List<Map<String, dynamic>> getWalletTransactions(String email) {
    final rawList = _walletBox.get('${email}_transactions');
    if (rawList == null) return [];
    try {
      return (rawList as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWalletTransactions(String email, List<Map<String, dynamic>> list) async {
    await _walletBox.put('${email}_transactions', list);
  }

  static Future<void> addWalletTransaction(String email, Map<String, dynamic> tx) async {
    final txs = getWalletTransactions(email);
    txs.insert(0, tx);
    await saveWalletTransactions(email, txs);
  }
}

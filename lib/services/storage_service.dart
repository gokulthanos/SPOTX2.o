import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generic key-value helpers
  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

  // Session variables helpers
  static Future<void> savePassengerSession({
    required String token,
    required String name,
    required String contact,
  }) async {
    await setString('passengerToken', token);
    await setString('passengerName', name);
    await setString('passengerContact', contact);
    await setString('passengerEmail', contact);
  }

  static Future<void> clearPassengerSession() async {
    await remove('passengerToken');
    await remove('passengerName');
    await remove('passengerContact');
    await remove('passengerEmail');
  }

  static Future<void> saveOfficerSession({
    required String token,
    required String officerId,
    required String name,
    required String role,
  }) async {
    await setString('authToken', token);
    await setString('govOfficerId', officerId);
    await setString('govOfficerName', name);
    await setString('userRole', role);
  }

  static Future<void> clearOfficerSession() async {
    await remove('authToken');
    await remove('govOfficerId');
    await remove('govOfficerName');
    await remove('userRole');
  }

  // Tickets
  static List<Map<String, dynamic>> getSavedTickets(String email) {
    final raw = getString('tickets_$email');
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTickets(String email, List<Map<String, dynamic>> tickets) async {
    await setString('tickets_$email', jsonEncode(tickets));
  }

  static Future<void> addTicket(String email, Map<String, dynamic> ticket) async {
    final tickets = getSavedTickets(email);
    tickets.add(ticket);
    await saveTickets(email, tickets);
  }

  // Checked tickets (Officer logs)
  static List<Map<String, dynamic>> getCheckedTickets() {
    final raw = getString('checkedTickets');
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCheckedTickets(List<Map<String, dynamic>> list) async {
    await setString('checkedTickets', jsonEncode(list));
  }

  // Wallet
  static double getWalletBalance(String email) {
    final raw = getString('wallet_${email}_balance');
    if (raw == null) return 0.0;
    return double.tryParse(raw) ?? 0.0;
  }

  static Future<void> setWalletBalance(String email, double balance) async {
    await setString('wallet_${email}_balance', balance.toString());
  }

  static List<Map<String, dynamic>> getWalletTransactions(String email) {
    final raw = getString('wallet_${email}_transactions');
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWalletTransactions(String email, List<Map<String, dynamic>> list) async {
    await setString('wallet_${email}_transactions', jsonEncode(list));
  }

  static Future<void> addWalletTransaction(String email, Map<String, dynamic> tx) async {
    final txs = getWalletTransactions(email);
    txs.insert(0, tx);
    await saveWalletTransactions(email, txs);
  }
}

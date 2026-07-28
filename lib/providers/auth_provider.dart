import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/passenger.dart';

class AuthProvider extends ChangeNotifier {
  Passenger? _passenger;
  String? _token;
  String? _error;
  bool _isLoading = false;
  bool _isConductor = false;
  Map<String, dynamic>? _conductorData;
  String? _conductorToken;

  Passenger? get passenger => _passenger;
  String? get token => _token;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isConductor => _isConductor;
  Map<String, dynamic>? get conductorData => _conductorData;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? e) { _error = e; notifyListeners(); }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      try {
        final res = await ApiService.getProfile();
        final data = res['data'] ?? res;
        _passenger = Passenger.fromJson(data);
      } catch (e) {
        debugPrint('[Auth] Failed to load profile: $e');
      }
      notifyListeners();
    }
  }

  Future<bool> login(String mobile, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.login(mobile, password);
      final data = res['data'] ?? res;
      _token = data['token'] ?? data['accessToken'] ?? '';
      _passenger = Passenger.fromJson(data['passenger'] ?? data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_role', 'passenger');
      await prefs.setString('user_name', _passenger?.fullName ?? '');
      await prefs.setString('user_mobile', _passenger?.mobile ?? mobile);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String name, String mobile, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.register(name, mobile, password);
      final data = res['data'] ?? res;
      _token = data['token'] ?? data['accessToken'] ?? '';
      _passenger = Passenger.fromJson(data['passenger'] ?? data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_role', 'passenger');
      await prefs.setString('user_name', _passenger?.fullName ?? '');
      await prefs.setString('user_mobile', _passenger?.mobile ?? mobile);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _passenger = null;
    _token = null;
    _isConductor = false;
    _conductorData = null;
    _conductorToken = null;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    try {
      final res = await ApiService.getProfile();
      final data = res['data'] ?? res;
      _passenger = Passenger.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] Load profile failed: $e');
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.updateProfile(data);
      final updated = res['data'] ?? res;
      _passenger = Passenger.fromJson(updated);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> requestOtp(String mobile) async {
    _setLoading(true);
    _setError(null);
    try {
      await ApiService.requestOtp(mobile);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp(String mobile, String otp) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.verifyOtp(mobile, otp);
      final data = res['data'] ?? res;
      _token = data['token'] ?? data['accessToken'] ?? '';
      if (_token != null && _token!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
      }
      _passenger = Passenger.fromJson(data['passenger'] ?? data);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> forgotPassword(String mobile, String otp, String newPassword) async {
    _setLoading(true);
    _setError(null);
    try {
      await ApiService.forgotPassword(mobile, otp, newPassword);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  // ── Conductor ────────────────────────────
  Future<bool> conductorLogin(String username, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.conductorLogin(username, password);
      final data = res['data'] ?? res;
      _conductorToken = data['token'] ?? data['accessToken'] ?? '';
      _conductorData = data['conductor'] ?? data;
      _isConductor = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _conductorToken!);
      await prefs.setString('user_role', 'conductor');
      await prefs.setString('user_name', _conductorData?['name'] ?? '');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  void conductorLogout() {
    _isConductor = false;
    _conductorData = null;
    _conductorToken = null;
    logout();
  }
}

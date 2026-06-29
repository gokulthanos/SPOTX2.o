import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

enum AuthMode { none, passenger, officer }

class AuthProvider extends ChangeNotifier {
  AuthMode _mode = AuthMode.none;
  String _passengerName = '';
  String _passengerContact = '';
  String _passengerToken = '';
  String _officerName = '';
  String _officerId = '';
  String _officerRole = '';
  String _officerToken = '';

  AuthMode get mode => _mode;
  bool get isPassenger => _mode == AuthMode.passenger;
  bool get isOfficer => _mode == AuthMode.officer;
  bool get isLoggedIn => _mode != AuthMode.none;

  String get passengerName => _passengerName;
  String get passengerContact => _passengerContact;
  String get passengerToken => _passengerToken;
  String get officerName => _officerName;
  String get officerId => _officerId;
  String get officerRole => _officerRole;
  String get officerToken => _officerToken;
  bool get isAdmin => _officerRole == 'ADMIN';

  /// Load saved session on app startup
  void loadFromStorage() {
    final passengerToken = StorageService.getString('passengerToken');
    final govId = StorageService.getString('govOfficerId');

    if (passengerToken != null && passengerToken.isNotEmpty) {
      _mode = AuthMode.passenger;
      _passengerToken = passengerToken;
      _passengerName = StorageService.getString('passengerName') ?? '';
      _passengerContact = StorageService.getString('passengerContact') ?? '';
    } else if (govId != null && govId.isNotEmpty) {
      _mode = AuthMode.officer;
      _officerId = govId;
      _officerName = StorageService.getString('govOfficerName') ?? '';
      _officerRole = StorageService.getString('userRole') ?? 'STAFF';
      _officerToken = StorageService.getString('authToken') ?? '';
    }
    notifyListeners();
  }

  Future<void> loginPassenger({
    required String name,
    required String contact,
    required String token,
  }) async {
    await StorageService.savePassengerSession(
      token: token,
      name: name,
      contact: contact,
    );
    _mode = AuthMode.passenger;
    _passengerName = name;
    _passengerContact = contact;
    _passengerToken = token;
    notifyListeners();
  }

  Future<void> loginOfficer({
    required String officerId,
    required String name,
    required String role,
    required String token,
  }) async {
    await StorageService.saveOfficerSession(
      token: token,
      officerId: officerId,
      name: name,
      role: role,
    );
    _mode = AuthMode.officer;
    _officerId = officerId;
    _officerName = name;
    _officerRole = role;
    _officerToken = token;
    notifyListeners();
  }

  Future<void> logout() async {
    await StorageService.clearPassengerSession();
    await StorageService.clearOfficerSession();
    _mode = AuthMode.none;
    _passengerName = '';
    _passengerContact = '';
    _passengerToken = '';
    _officerName = '';
    _officerId = '';
    _officerRole = '';
    _officerToken = '';
    notifyListeners();
  }
}

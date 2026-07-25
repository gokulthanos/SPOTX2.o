import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/bus.dart';
import '../models/ticket.dart';
import 'storage_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  static String get legacyBaseUrl => AppConfig.legacyBaseUrl;

  // ─── Headers and Authentication Helper ─────────────────────────────

  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      // Fetch token depending on passenger or officer role
      final token = await StorageService.getSecure('passengerToken') ??
                    await StorageService.getSecure('authToken');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Sends a request and retries once if 401 (expired token) using Refresh Token.
  static Future<http.Response> _requestWithRetry(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final finalHeaders = headers ?? await _getHeaders();
    final uri = Uri.parse(url);
    http.Response response;

    // Send original request
    if (method == 'POST') {
      response = await http.post(uri, headers: finalHeaders, body: body);
    } else if (method == 'PUT') {
      response = await http.put(uri, headers: finalHeaders, body: body);
    } else if (method == 'PATCH') {
      response = await http.patch(uri, headers: finalHeaders, body: body);
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: finalHeaders);
    } else {
      response = await http.get(uri, headers: finalHeaders);
    }

    // If unauthorized/expired token, attempt to refresh
    if (response.statusCode == 401) {
      debugPrint('[API] Unauthorized (401), attempting token refresh...');
      final refreshSuccess = await refreshSessionToken();
      if (refreshSuccess) {
        debugPrint('[API] Refresh successful, retrying request...');
        // Fetch new headers containing the refreshed access token
        final retryHeaders = await _getHeaders();
        if (method == 'POST') {
          return await http.post(uri, headers: retryHeaders, body: body);
        } else if (method == 'PUT') {
          return await http.put(uri, headers: retryHeaders, body: body);
        } else if (method == 'PATCH') {
          return await http.patch(uri, headers: retryHeaders, body: body);
        } else if (method == 'DELETE') {
          return await http.delete(uri, headers: retryHeaders);
        } else {
          return await http.get(uri, headers: retryHeaders);
        }
      }
    }

    return response;
  }

  /// Refreshes JWT access token using the stored refresh token.
  static Future<bool> refreshSessionToken() async {
    try {
      final isPassenger = await StorageService.getSecure('passengerToken') != null;
      final refreshToken = await StorageService.getSecure(
        isPassenger ? 'passengerRefreshToken' : 'officerRefreshToken'
      );

      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final data = body['data'] ?? body; // Support both wrapped & direct JSON shape
        final newAccess = data['accessToken'] as String;
        final newRefresh = data['refreshToken'] as String;

        if (isPassenger) {
          await StorageService.setSecure('passengerToken', newAccess);
          await StorageService.setSecure('passengerRefreshToken', newRefresh);
        } else {
          await StorageService.setSecure('authToken', newAccess);
          await StorageService.setSecure('officerRefreshToken', newRefresh);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[API] Token refresh failed: $e');
    }
    return false;
  }

  // ─── 1. Request OTP ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> requestOtp(String fullName, String contact) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fullName': fullName, 'contact': contact}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final errors = data['message'] ?? 'Failed to request OTP';
      throw Exception(errors);
    }
    // Return standard payload map (compatible with legacy OTP return)
    final innerData = data['data'] ?? data;
    return {
      'message': data['message'] ?? 'OTP sent successfully',
      'devOtp': innerData['devOtp'] ?? '',
      'status': 'sent',
    };
  }

  // ─── 2. Verify OTP ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp(String contact, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contact': contact, 'otp': otp}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to verify OTP');
    }
    return {'message': data['message'] ?? 'OTP verified', 'contact': contact};
  }

  // ─── 3. Set Password ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> setPassword(String contact, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/set-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contact': contact, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to set password');
    }
    final innerData = data['data'] ?? data;
    return {
      'message': data['message'] ?? 'Password set successfully',
      'fullName': innerData['fullName'] ?? '',
      'contact': innerData['contact'] ?? contact,
      'token': innerData['accessToken'] ?? '',
      'refreshToken': innerData['refreshToken'] ?? '',
    };
  }

  // ─── 4. Passenger Login ──────────────────────────────────────────
  static Future<Map<String, dynamic>> passengerLogin(String contact, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contact': contact, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to log in');
    }
    final innerData = data['data'] ?? data;
    return {
      'message': data['message'] ?? 'Login successful',
      'fullName': innerData['passenger']?['fullName'] ?? innerData['fullName'] ?? '',
      'contact': innerData['passenger']?['contact'] ?? innerData['contact'] ?? contact,
      'token': innerData['accessToken'] ?? '',
      'refreshToken': innerData['refreshToken'] ?? '',
    };
  }

  // ─── 5. Government Officer Login ─────────────────────────────────
  static Future<Map<String, dynamic>> officerLogin(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/officer/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to log in');
    }
    final innerData = data['data'] ?? data;
    return {
      'message': data['message'] ?? 'Login successful',
      'name': innerData['user']?['name'] ?? innerData['name'] ?? '',
      'email': innerData['user']?['email'] ?? innerData['email'] ?? email,
      'role': innerData['user']?['role'] ?? innerData['role'] ?? 'STAFF',
      'token': innerData['accessToken'] ?? '',
      'refreshToken': innerData['refreshToken'] ?? '',
    };
  }

  // ─── 6. Admin Panel: Register Staff ──────────────────────────────
  static Future<Map<String, dynamic>> registerStaff({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/officer/register',
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to register staff member');
    }
    return data;
  }

  // ─── 7. Get Buses for City ───────────────────────────────────────
  static Future<List<Bus>> fetchBuses({String? city, String? from, String? to}) async {
    String url = '$baseUrl/buses';
    final queryParams = <String>[];
    if (city != null && city.isNotEmpty) queryParams.add('city=$city');
    if (from != null && from.isNotEmpty) queryParams.add('from=$from');
    if (to != null && to.isNotEmpty) queryParams.add('to=$to');

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    try {
      final response = await _requestWithRetry('GET', url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List<dynamic> list = body['data'] ?? body;
        return list.map((b) => Bus.fromJson(b)).toList();
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network failed, returning mock/empty buses: $e');
      return []; // Return empty when backend offline
    }
  }

  // ─── 8. Get Live Bus Details ─────────────────────────────────────
  static Future<Bus> fetchBusDetails(int id) async {
    final response = await _requestWithRetry('GET', '$baseUrl/buses/$id');
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final data = body['data'] ?? body;
      return Bus.fromJson(data);
    } else {
      throw Exception('Failed to fetch bus details');
    }
  }

  // ─── 9. Book Ticket ──────────────────────────────────────────────
  static Future<String> bookTicket({
    required int busId,
    required String busNumber,
    required String fromStop,
    required String toStop,
    required double totalFare,
    required List<Map<String, String>> passengers,
    String paymentMethod = 'wallet',
    String paymentId = '',
  }) async {
    try {
      final response = await _requestWithRetry(
        'POST',
        '$baseUrl/tickets',
        body: jsonEncode({
          'busId': busId,
          'busNumber': busNumber,
          'fromStop': fromStop,
          'toStop': toStop,
          'totalFare': totalFare,
          'passengers': passengers,
          'paymentMethod': paymentMethod,
          'paymentId': paymentId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final innerData = data['data'] ?? data;
        return innerData['ticketNumber'].toString();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to book on server');
      }
    } catch (e) {
      // Return a random 4-digit code as offline fallback
      debugPrint('Booking server offline, generating offline ticket code: $e');
      final randomCode = (1000 + (Uri.parse(busNumber).hashCode % 9000)).toString();
      return randomCode;
    }
  }

  // ─── 10. Verify Ticket ───────────────────────────────────────────
  static Future<Ticket?> verifyTicket(String ticketNumber) async {
    try {
      final response = await _requestWithRetry(
        'GET',
        '$baseUrl/tickets/$ticketNumber',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return Ticket.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Failed to reach ticket database: $e');
      throw Exception('Database unreachable');
    }
  }

  // ─── 11. Razorpay Payment Helpers ─────────────────────────────────

  /// Request Razorpay server-side order creation.
  static Future<Map<String, dynamic>> initiatePayment(double amount, String purpose, {int? ticketId}) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/payments/initiate',
      body: jsonEncode({
        'amount': amount,
        'purpose': purpose,
        if (ticketId != null) 'ticketId': ticketId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to initiate payment');
    }
    return data['data'] ?? data;
  }

  /// Verify Razorpay signature and credit wallet.
  static Future<Map<String, dynamic>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
    required String purpose,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/payments/verify',
      body: jsonEncode({
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'purpose': purpose,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Payment verification failed');
    }
    return data['data'] ?? data;
  }

  /// Sync local offline tickets to the server.
  static Future<void> syncOfflineTickets(List<Map<String, dynamic>> offlineTickets) async {
    for (var ticket in offlineTickets) {
      try {
        await bookTicket(
          busId: ticket['busId'] ?? 0,
          busNumber: ticket['busNumber'] ?? '',
          fromStop: ticket['fromStop'] ?? '',
          toStop: ticket['toStop'] ?? '',
          totalFare: (ticket['totalFare'] as num?)?.toDouble() ?? 0.0,
          passengers: (ticket['passengers'] as List)
              .map((p) => Map<String, String>.from(p))
              .toList(),
          paymentMethod: ticket['paymentMethod'] ?? 'wallet',
        );
      } catch (e) {
        debugPrint('[API] Sync offline ticket failed: $e');
      }
    }
  }

  // ─── 12. Government Dashboard ──────────────────────────────────────
  static Future<Map<String, dynamic>> fetchDashboard() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/dashboard')
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body;
      }
    } catch (e) {
      debugPrint('[API] Dashboard fetch failed: $e');
    }
    return {};
  }

  // ─── 13. Complaints ───────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchComplaints() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/complaints')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Complaints fetch failed: $e');
    }
    return [];
  }

  static Future<void> submitComplaint({
    required String subject,
    required String description,
    int? busId,
    String? ticketNumber,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/admin/complaints',
      body: jsonEncode({
        'subject': subject,
        'description': description,
        if (busId != null) 'busId': busId,
        if (ticketNumber != null) 'ticketNumber': ticketNumber,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to submit complaint');
    }
  }

  // ─── 14. Notifications ────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/complaints')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Notifications fetch failed: $e');
    }
    return [];
  }

  // ─── 15. Favorites ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchStops() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/stops')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Stops fetch failed: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchCities() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/cities')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Cities fetch failed: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchRoutes() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/routes')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Routes fetch failed: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchOfficers() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/officers')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Officers fetch failed: $e');
    }
    return [];
  }

  // ─── 16. Admin CRUD ───────────────────────────────────────────────
  static Future<void> addBus({
    required String busNumber,
    String? routeId,
    String busType = 'Normal',
    int capacity = 45,
    String city = 'Chennai',
    String fromStop = '',
    String toStop = '',
    String arrivalTime = '',
    double fare = 0,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/buses',
      body: jsonEncode({
        'busNumber': busNumber,
        'routeId': routeId,
        'busType': busType,
        'capacity': capacity,
        'city': city,
        'fromStop': fromStop,
        'toStop': toStop,
        'arrivalTime': arrivalTime,
        'fare': fare,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to add bus');
    }
  }

  static Future<void> deleteBus(int busId) async {
    final response = await _requestWithRetry('DELETE', '$baseUrl/buses/$busId');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete bus');
    }
  }

  static Future<void> addRoute({
    required String routeNumber,
    required String name,
    int? fromStopId,
    int? toStopId,
    double distanceKm = 0,
    double baseFare = 0,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/admin/routes',
      body: jsonEncode({
        'routeNumber': routeNumber,
        'name': name,
        'fromStopId': fromStopId,
        'toStopId': toStopId,
        'distanceKm': distanceKm,
        'baseFare': baseFare,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to add route');
    }
  }

  static Future<void> updateFare(int routeId, double baseFare) async {
    final response = await _requestWithRetry(
      'PUT',
      '$baseUrl/admin/routes/$routeId/fare',
      body: jsonEncode({'baseFare': baseFare}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update fare');
    }
  }

  static Future<void> addStop({required String name, int? cityId, double? lat, double? lon}) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/admin/stops',
      body: jsonEncode({
        'name': name,
        'cityId': cityId,
        'lat': lat,
        'lon': lon,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to add stop');
    }
  }

  static Future<void> addCity({required String name, String state = 'Tamil Nadu', double? lat, double? lon}) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/admin/cities',
      body: jsonEncode({
        'name': name,
        'state': state,
        'lat': lat,
        'lon': lon,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to add city');
    }
  }

  static Future<void> issueFine({
    required String passengerContact,
    required String reason,
    double amount = 500,
    int? busId,
    String? ticketNumber,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/admin/fines',
      body: jsonEncode({
        'passengerContact': passengerContact,
        'reason': reason,
        'amount': amount,
        'busId': busId,
        'ticketNumber': ticketNumber,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to issue fine');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFines() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/admin/fines')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return List<Map<String, dynamic>>.from(data is List ? data : []);
      }
    } catch (e) {
      debugPrint('[API] Fines fetch failed: $e');
    }
    return [];
  }

  static Future<void> updateOfficer(int id, {String? name, String? role, bool? isActive}) async {
    final response = await _requestWithRetry(
      'PATCH',
      '$baseUrl/admin/officers/$id',
      body: jsonEncode({
        if (name != null) 'name': name,
        if (role != null) 'role': role,
        if (isActive != null) 'isActive': isActive,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update officer');
    }
  }

  // ─── 17. Driver App Methods ───────────────────────────────────────
  static Future<Map<String, dynamic>> driverLogin(String employeeId, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'employeeId': employeeId, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to log in as driver');
    }
    return data['data'] ?? data;
  }

  static Future<Map<String, dynamic>> fetchDriverProfile() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/driver/profile')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body;
      }
    } catch (e) {
      debugPrint('[API] Driver profile fetch failed: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> fetchDriverBus() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/driver/my-bus')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body;
      }
    } catch (e) {
      debugPrint('[API] Driver bus fetch failed: $e');
    }
    return {};
  }

  static Future<void> startTrip() async {
    final response = await _requestWithRetry('PUT', '$baseUrl/driver/trip/start');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to start trip');
    }
  }

  static Future<void> pauseTrip() async {
    final response = await _requestWithRetry('PUT', '$baseUrl/driver/trip/pause');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to pause trip');
    }
  }

  static Future<void> resumeTrip() async {
    final response = await _requestWithRetry('PUT', '$baseUrl/driver/trip/resume');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to resume trip');
    }
  }

  static Future<void> endTrip() async {
    final response = await _requestWithRetry('PUT', '$baseUrl/driver/trip/end');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to end trip');
    }
  }

  static Future<void> shareLocation({
    required double lat,
    required double lon,
    double? speed,
    double? heading,
  }) async {
    final response = await _requestWithRetry(
      'PUT',
      '$baseUrl/driver/location',
      body: jsonEncode({
        'lat': lat,
        'lon': lon,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
      }),
    );
    if (response.statusCode != 200) {
      debugPrint('[API] Location share failed');
    }
  }

  static Future<void> reportDelay({required int delayMinutes, String? reason}) async {
    final response = await _requestWithRetry(
      'PUT',
      '$baseUrl/driver/delay',
      body: jsonEncode({
        'delayMinutes': delayMinutes,
        if (reason != null) 'reason': reason,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to report delay');
    }
  }

  static Future<void> sendEmergency({
    required String type,
    double? lat,
    double? lon,
    String? message,
  }) async {
    final response = await _requestWithRetry(
      'POST',
      '$baseUrl/driver/emergency',
      body: jsonEncode({
        'type': type,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (message != null) 'message': message,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to send emergency alert');
    }
  }

  // ─── 18. Analytics Methods ────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchAnalytics({int days = 7}) async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/analytics/overview?days=$days')
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body;
      }
    } catch (e) {
      debugPrint('[API] Analytics fetch failed: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> fetchRevenueAnalytics({int days = 30, String groupBy = 'day'}) async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/analytics/revenue?days=$days&groupBy=$groupBy')
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body;
      }
    } catch (e) {
      debugPrint('[API] Revenue analytics fetch failed: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> fetchOccupancyAnalytics() async {
    try {
      final response = await _requestWithRetry('GET', '$baseUrl/analytics/occupancy')
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body;
      }
    } catch (e) {
      debugPrint('[API] Occupancy analytics fetch failed: $e');
    }
    return {};
  }
}

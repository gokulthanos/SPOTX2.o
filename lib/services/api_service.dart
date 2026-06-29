import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bus.dart';
import '../models/ticket.dart';
import 'storage_service.dart';

class ApiService {
  // Replace this with your computer's IP address when testing on a physical phone
  static const String serverIp = '10.50.1.33'; 
  static const String serverPort = '5000';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$serverPort';
    } else {
      // For android emulator, use 10.0.2.2. If testing on physical phone, use serverIp.
      try {
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:$serverPort';
        }
      } catch (_) {}
      return 'http://localhost:$serverPort';
    }
  }

  // 1. Request OTP
  static Future<Map<String, dynamic>> requestOtp(String fullName, String contact) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/passenger/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fullName': fullName, 'contact': contact}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 211) {
      throw Exception(data['message'] ?? 'Failed to request OTP');
    }
    return data;
  }

  // 2. Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(String contact, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/passenger/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contact': contact, 'otp': otp}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to verify OTP');
    }
    return data;
  }

  // 3. Set Password
  static Future<Map<String, dynamic>> setPassword(String contact, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/passenger/set-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contact': contact, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to set password');
    }
    return data;
  }

  // 4. Passenger Login
  static Future<Map<String, dynamic>> passengerLogin(String contact, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/passenger/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contact': contact, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to log in');
    }
    return data;
  }

  // 5. Government Officer Login
  static Future<Map<String, dynamic>> officerLogin(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to log in');
    }
    return data;
  }

  // 6. Admin Panel: Register staff
  static Future<Map<String, dynamic>> registerStaff({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/register'),
      headers: {'Content-Type': 'application/json'},
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

  // 7. Get Buses for City
  static Future<List<Bus>> fetchBuses({String? city}) async {
    final url = city != null ? '$baseUrl/api/buses?city=$city' : '$baseUrl/api/buses';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((b) => Bus.fromJson(b)).toList();
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Network failed, returning mock/empty buses: $e');
      return []; // Return empty when backend offline
    }
  }

  // 8. Get Live Bus Details
  static Future<Bus> fetchBusDetails(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/api/buses/$id'));
    if (response.statusCode == 200) {
      return Bus.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch bus details');
    }
  }

  // 9. Book Ticket
  static Future<String> bookTicket({
    required int busId,
    required String busNumber,
    required String fromStop,
    required String toStop,
    required double totalFare,
    required List<Map<String, String>> passengers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tickets'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'busId': busId,
          'busNumber': busNumber,
          'fromStop': fromStop,
          'toStop': toStop,
          'totalFare': totalFare,
          'passengers': passengers,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['ticketNumber'].toString();
      } else {
        throw Exception('Failed to book on server');
      }
    } catch (e) {
      // Return a random 4-digit code as offline fallback
      print('Booking server offline, generating offline ticket code: $e');
      final randomCode = (1000 + (Uri.parse(busNumber).hashCode % 9000)).toString();
      return randomCode;
    }
  }

  // 10. Verify Ticket (Officer dashboard query)
  static Future<Ticket?> verifyTicket(String ticketNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tickets/$ticketNumber'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return Ticket.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('Failed to reach ticket database: $e');
      throw Exception('Database unreachable');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/bus.dart';
import '../models/stop.dart';
import '../models/ticket.dart';
import 'storage_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Future<http.Response> _get(String url, {bool auth = true}) async {
    return http.get(Uri.parse(url), headers: await _headers(auth: auth));
  }

  static Future<http.Response> _post(String url, {Map<String, dynamic>? body, bool auth = true}) async {
    return http.post(Uri.parse(url), headers: await _headers(auth: auth), body: body != null ? jsonEncode(body) : null);
  }

  static Future<http.Response> _put(String url, {Map<String, dynamic>? body, bool auth = true}) async {
    return http.put(Uri.parse(url), headers: await _headers(auth: auth), body: body != null ? jsonEncode(body) : null);
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
  }

  // ── Auth ────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(String name, String mobile, String password) async {
    final res = await _post('$baseUrl/auth/register', body: {'name': name, 'mobile': mobile, 'password': password}, auth: false);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> login(String mobile, String password) async {
    final res = await _post('$baseUrl/auth/login', body: {'mobile': mobile, 'password': password}, auth: false);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> requestOtp(String mobile) async {
    final res = await _post('$baseUrl/auth/request-otp', body: {'mobile': mobile}, auth: false);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyOtp(String mobile, String otp) async {
    final res = await _post('$baseUrl/auth/verify-otp', body: {'mobile': mobile, 'otp': otp}, auth: false);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> forgotPassword(String mobile, String otp, String newPassword) async {
    final res = await _post('$baseUrl/auth/forgot-password', body: {'mobile': mobile, 'otp': otp, 'newPassword': newPassword}, auth: false);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await _get('$baseUrl/auth/profile');
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _put('$baseUrl/auth/profile', body: data);
    return _parse(res);
  }

  // ── Buses ───────────────────────────────────────────
  static Future<List<Stop>> searchNearbyStops(double lat, double lon) async {
    final res = await _get('$baseUrl/buses/nearby?lat=$lat&lon=$lon', auth: false);
    final parsed = _parse(res);
    final list = parsed['data'] ?? parsed;
    return (list as List).map((s) => Stop.fromJson(s)).toList();
  }

  static Future<List<Stop>> getAllStops() async {
    final res = await _get('$baseUrl/buses/stops', auth: false);
    final parsed = _parse(res);
    final list = parsed['data'] ?? parsed;
    return (list as List).map((s) => Stop.fromJson(s)).toList();
  }

  static Future<List<Bus>> searchBuses(int fromId, int toId) async {
    final res = await _get('$baseUrl/buses/search?from_stop_id=$fromId&to_stop_id=$toId', auth: false);
    final parsed = _parse(res);
    final list = parsed['data'] ?? parsed;
    return (list as List).map((b) => Bus.fromJson(b)).toList();
  }

  static Future<Bus> getBusDetail(int id) async {
    final res = await _get('$baseUrl/buses/$id', auth: false);
    final parsed = _parse(res);
    return Bus.fromJson(parsed['data'] ?? parsed);
  }

  // ── Tickets ─────────────────────────────────────────
  static Future<Map<String, dynamic>> bookTicket(int busId, int boardingId, int destId) async {
    final res = await _post('$baseUrl/tickets/book', body: {'bus_id': busId, 'boarding_stop_id': boardingId, 'destination_stop_id': destId});
    return _parse(res);
  }

  static Future<List<Ticket>> getMyTickets() async {
    final res = await _get('$baseUrl/tickets/my-tickets');
    final parsed = _parse(res);
    final list = parsed['data'] ?? parsed;
    return (list as List).map((t) => Ticket.fromJson(t)).toList();
  }

  static Future<Ticket> getTicketDetail(dynamic id) async {
    final res = await _get('$baseUrl/tickets/$id');
    final parsed = _parse(res);
    return Ticket.fromJson(parsed['data'] ?? parsed);
  }

  // ── Payments ────────────────────────────────────────
  static Future<Map<String, dynamic>> initiatePayment(int ticketId) async {
    final res = await _post('$baseUrl/payments/initiate', body: {'ticket_id': ticketId});
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyPayment(int ticketId, int paymentId) async {
    final res = await _post('$baseUrl/payments/verify', body: {'ticket_id': ticketId, 'payment_id': paymentId});
    return _parse(res);
  }

  // ── Conductor ───────────────────────────────────────
  static Future<Map<String, dynamic>> conductorLogin(String username, String password) async {
    final res = await _post('$baseUrl/auth/conductor/login', body: {'username': username, 'password': password}, auth: false);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> selectBus(int busId) async {
    final res = await _post('$baseUrl/conductor/select-bus', body: {'bus_id': busId});
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyTicket(String pnr) async {
    final res = await _post('$baseUrl/conductor/verify-ticket', body: {'pnr': pnr});
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getTodayStats() async {
    final res = await _get('$baseUrl/conductor/today-stats');
    return _parse(res);
  }
}

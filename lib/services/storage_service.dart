import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<String?> getToken() async => _prefs.getString('auth_token');
  static Future<void> saveToken(String token) async => _prefs.setString('auth_token', token);
  static Future<void> clearToken() async => _prefs.remove('auth_token');

  static bool isLoggedIn() => _prefs.getString('auth_token')?.isNotEmpty == true;

  static String? getUserRole() => _prefs.getString('user_role');
  static Future<void> saveUserRole(String role) async => _prefs.setString('user_role', role);

  static String? getUserName() => _prefs.getString('user_name');
  static Future<void> saveUserName(String name) async => _prefs.setString('user_name', name);

  static String? getUserMobile() => _prefs.getString('user_mobile');
  static Future<void> saveUserMobile(String mobile) async => _prefs.setString('user_mobile', mobile);

  static Future<void> clearAll() async => _prefs.clear();
}

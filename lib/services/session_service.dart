import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SessionService {
  static const _keyLoggedIn   = 'hadir_in_logged_in';
  static const _keyUsername   = 'hadir_in_username';
  static const _keyEmployeeId = 'hadir_in_employee_id';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    if (loggedIn) {
      final empId = prefs.getString(_keyEmployeeId) ?? '';
      if (empId.isNotEmpty) AppSession.setUserById(empId);
    }
    return loggedIn;
  }

  static Future<void> saveSession({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUsername, username);
    // await prefs.setString(_keyEmployeeId, employeeId);
    AppSession.setUser(username, password);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmployeeId);
    AppSession.clearUser();
  }

  static Future<String> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? '';
  }
}
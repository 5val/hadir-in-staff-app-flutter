import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SessionService {
  static const _keyLoggedIn      = 'hadir_in_logged_in';
  static const _keyEmployeeId    = 'hadir_in_employee_id';
  static const _keyPhone         = 'hadir_in_phone';
  static const _keyPasscode      = 'hadir_in_passcode';
  static const _keySessionActive = 'hadir_in_session_active';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    if (loggedIn) {
      final empId = prefs.getString(_keyEmployeeId) ?? '';
      if (empId.isNotEmpty) {
        AppSession.setUserById(empId);
      }
    }
    return loggedIn;
  }

  static Future<Map<String, dynamic>> getAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    final sessionActive = prefs.getBool(_keySessionActive) ?? false;
    final passcode = prefs.getString(_keyPasscode) ?? '';
    final empId = prefs.getString(_keyEmployeeId) ?? '';

    if (loggedIn && empId.isNotEmpty) {
      AppSession.setUserById(empId);
    }

    return {
      'isLoggedIn': loggedIn,
      'isSessionActive': sessionActive,
      'hasPasscode': passcode.isNotEmpty,
    };
  }

  static Future<void> saveSessionWithPhone({
    required String phone,
    required String employeeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyEmployeeId, employeeId);
    await prefs.setBool(_keySessionActive, true);
    AppSession.setUserById(employeeId);
  }

  static Future<void> savePasscode(String passcode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPasscode, passcode);
  }

  static Future<String?> getPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPasscode);
  }

  static Future<void> setSessionActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, active);
  }

  static Future<void> lockSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, false);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyEmployeeId);
    await prefs.remove(_keyPasscode);
    await prefs.remove(_keySessionActive);
    AppSession.clearUser();
  }

  static const _keySoundNotifMode = 'hadir_in_sound_notif_mode';

  static Future<String> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone) ?? '';
  }

  static Future<void> saveSoundNotifMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySoundNotifMode, mode);
  }

  static Future<String> getSoundNotifMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySoundNotifMode) ?? 'Sound';
  }
}
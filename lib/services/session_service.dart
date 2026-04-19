import 'package:shared_preferences/shared_preferences.dart';

/// Mengelola sesi login karyawan di perangkat.
/// Mirip Instagram — login sekali, tetap masuk sampai logout eksplisit.
class SessionService {
  static const _keyLoggedIn   = 'hadir_in_logged_in';
  static const _keyUsername   = 'hadir_in_username';
  static const _keyEmployeeId = 'hadir_in_employee_id';

  /// Cek apakah user sudah pernah login (sesi aktif).
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  /// Simpan sesi setelah login berhasil.
  static Future<void> saveSession({
    required String username,
    String employeeId = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyEmployeeId, employeeId);
  }

  /// Hapus sesi (logout).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmployeeId);
  }

  /// Ambil username yang tersimpan.
  static Future<String> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? '';
  }
}
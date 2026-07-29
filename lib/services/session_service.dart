import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SessionService {
  static const _keyLoggedIn      = 'hadir_in_logged_in';
  static const _keyEmployeeId    = 'hadir_in_employee_id';
  static const _keyPhone         = 'hadir_in_phone';
  static const _keySessionActive = 'hadir_in_session_active';
  // Kredensial backend (diisi setelah login API berhasil di Tahap 1).
  static const _keyToken         = 'hadir_in_token';
  static const _keyStaffId       = 'hadir_in_staff_id';

  // ── Kredensial backend (JWT staff + id staff asli dari database) ──────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> saveStaffId(String staffId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStaffId, staffId);
  }

  static Future<String?> getStaffId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStaffId);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<Map<String, dynamic>> getAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool(_keyLoggedIn) ?? false,
      'isSessionActive': prefs.getBool(_keySessionActive) ?? false,
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
  }

  static Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone);
  }

  static Future<void> setSessionActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, active);
  }

  static Future<void> lockSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, false);
  }

  /// Keluar dari akun.
  ///
  /// CATATAN (Fase 8): tidak ada lagi passcode tersimpan di HP untuk dihapus.
  /// Passcode sekarang tinggal di database (`Staff.passcodeHash`) — lihat
  /// `PasscodeService`. Itulah yang membuat staff yang logout lalu login lagi
  /// cukup memasukkan passcode LAMANYA, bukan disuruh OTP + bikin passcode
  /// baru: dulu `clearSession()` menghapus passcode lokal, sehingga app
  /// kehilangan satu-satunya bukti bahwa staff itu pernah punya passcode.
  ///
  /// Nomor HP sengaja TIDAK dihapus — murni kenyamanan (kolom nomor terisi
  /// otomatis di layar login). Ia bukan kredensial: tanpa passcode/OTP nomor
  /// itu tidak memberi akses apa pun.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyEmployeeId);
    await prefs.remove(_keySessionActive);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyStaffId);
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

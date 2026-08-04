import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SessionService {
  static const _keyLoggedIn      = 'hadir_in_logged_in';
  static const _keyEmployeeId    = 'hadir_in_employee_id';
  static const _keyPhone         = 'hadir_in_phone';
  static const _keySessionActive = 'hadir_in_session_active';
  // Kredensial backend (diisi setelah login API berhasil di Tahap 1).
  //
  // Sprint 3 EPIC 5a: token JWT & staffId dipindah ke `flutter_secure_storage`
  // (keystore/keychain OS terenkripsi) — sebelumnya SharedPreferences
  // plaintext, extractable di HP root/kompromais atau lewat ADB backup tanpa
  // perlu passcode/OTP. Key-key lain (login flag, phone, dst) TETAP di
  // SharedPreferences — bukan kredensial, cuma preferensi UX lokal.
  static const _keyToken   = 'hadir_in_token';
  static const _keyStaffId = 'hadir_in_staff_id';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Kredensial backend (JWT staff + id staff asli dari database) ──────
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return _secureStorage.read(key: _keyToken);
  }

  static Future<void> saveStaffId(String staffId) async {
    await _secureStorage.write(key: _keyStaffId, value: staffId);
  }

  static Future<String?> getStaffId() async {
    return _secureStorage.read(key: _keyStaffId);
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
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyStaffId);
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

import 'api_client.dart';
import 'session_service.dart';

/// Hasil permintaan OTP (langkah pertama login).
class OtpRequestResult {
  final String phone;
  final int expiresInMinutes;

  /// Kode OTP versi development (dikirim backend saat NODE_ENV != production).
  /// Di produksi bernilai null — OTP dikirim lewat WhatsApp/SMS/email.
  final String? devCode;

  OtpRequestResult({
    required this.phone,
    required this.expiresInMinutes,
    this.devCode,
  });

  factory OtpRequestResult.fromMap(Map<String, dynamic> m) => OtpRequestResult(
        phone: (m['phone'] ?? '').toString(),
        expiresInMinutes: (m['expiresInMinutes'] as num?)?.toInt() ?? 10,
        devCode: m['devCode']?.toString(),
      );
}

/// Data staff yang login (dikembalikan setelah verifikasi OTP).
class StaffAuth {
  final String id;
  final String nama;
  final String email;
  final String phone;

  StaffAuth({
    required this.id,
    required this.nama,
    required this.email,
    required this.phone,
  });

  factory StaffAuth.fromMap(Map<String, dynamic> m) => StaffAuth(
        id: (m['id'] ?? '').toString(),
        nama: (m['nama'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
      );
}

/// Status passcode sebuah nomor HP — jawaban langkah pertama login.
class PasscodeStatus {
  /// true → nomor ini SUDAH pernah set passcode (di device mana pun).
  final bool hasPasscode;
  final String nama;

  /// > 0 bila akun sedang dikunci karena terlalu banyak salah passcode.
  final int lockedForMinutes;

  PasscodeStatus({
    required this.hasPasscode,
    required this.nama,
    required this.lockedForMinutes,
  });

  factory PasscodeStatus.fromMap(Map<String, dynamic> m) => PasscodeStatus(
        hasPasscode: m['hasPasscode'] == true,
        nama: (m['nama'] ?? '').toString(),
        lockedForMinutes: (m['lockedForMinutes'] as num?)?.toInt() ?? 0,
      );
}

/// Hasil login — token sudah tersimpan, plus info apakah staff sudah punya
/// passcode (menentukan apakah app perlu menampilkan layar "buat passcode").
class LoginResult {
  final StaffAuth staff;
  final bool hasPasscode;

  LoginResult({required this.staff, required this.hasPasscode});
}

/// Autentikasi staff via nomor telepon + OTP/passcode.
/// Melempar [ApiException] bila gagal (mis. nomor tidak terdaftar, OTP salah).
class AuthService {
  const AuthService._();

  /// Langkah 1 — cek apakah nomor ini sudah punya passcode.
  ///
  /// Fase 8: inilah yang membuat staff lama tidak perlu OTP lagi. Sebelumnya
  /// pertanyaan ini dijawab dari SharedPreferences HP, yang ikut terhapus
  /// saat logout; sekarang dijawab database (`Staff.passcodeHash`), sehingga
  /// jawabannya tetap benar setelah logout, ganti HP, atau install ulang.
  static Future<PasscodeStatus> passcodeStatus(String phone) async {
    final res = await ApiClient.instance.post(
      '/mobile/auth/staff/passcode-status',
      body: {'phone': phone},
      auth: false,
    );
    return PasscodeStatus.fromMap(res.asMap);
  }

  /// Login staff lama: nomor + passcode yang sudah pernah diset (tanpa OTP).
  static Future<StaffAuth> loginWithPasscode({
    required String phone,
    required String passcode,
  }) async {
    final res = await ApiClient.instance.post(
      '/mobile/auth/staff/login-passcode',
      body: {'phone': phone, 'passcode': passcode},
      auth: false,
    );
    final result = await _persistLogin(res.asMap);
    return result.staff;
  }

  /// Simpan/ubah passcode di server. [passcodeLama] wajib bila staff sudah
  /// punya passcode sebelumnya (dipakai layar "Ubah Passcode").
  static Future<void> setPasscode({
    required String passcode,
    String? passcodeLama,
  }) async {
    await ApiClient.instance.post(
      '/mobile/auth/staff/set-passcode',
      body: {
        'passcode': passcode,
        if (passcodeLama != null && passcodeLama.isNotEmpty)
          'passcodeLama': passcodeLama,
      },
    );
  }

  /// Langkah 1 (alur staff baru / lupa passcode) — minta OTP via WhatsApp.
  static Future<OtpRequestResult> requestOtp(String phone) async {
    final res = await ApiClient.instance.post(
      '/mobile/auth/staff/request-otp',
      body: {'phone': phone},
      auth: false,
    );
    return OtpRequestResult.fromMap(res.asMap);
  }

  /// Langkah 2 — verifikasi OTP. Bila valid, token & id staff disimpan ke
  /// [SessionService] dan data staff dikembalikan.
  static Future<LoginResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final res = await ApiClient.instance.post(
      '/mobile/auth/staff/verify-otp',
      body: {'phone': phone, 'code': code},
      auth: false,
    );
    return _persistLogin(res.asMap);
  }

  /// Umum untuk kedua jalur login: validasi bentuk respons lalu simpan sesi.
  ///
  /// Token & staffId WAJIB selesai tersimpan sebelum fungsi ini kembali —
  /// layar berikutnya langsung melakukan request ber-auth (profil, absensi
  /// hari ini, log popup), dan semuanya membaca token lewat
  /// `SessionService.getToken()`.
  static Future<LoginResult> _persistLogin(Map<String, dynamic> data) async {
    final token = (data['token'] ?? '').toString();
    final staff = StaffAuth.fromMap(
      data['staff'] is Map ? Map<String, dynamic>.from(data['staff'] as Map) : {},
    );
    if (token.isEmpty || staff.id.isEmpty) {
      throw ApiException('Respons login tidak valid dari server.');
    }

    await SessionService.saveToken(token);
    await SessionService.saveStaffId(staff.id);

    return LoginResult(staff: staff, hasPasscode: data['hasPasscode'] == true);
  }
}

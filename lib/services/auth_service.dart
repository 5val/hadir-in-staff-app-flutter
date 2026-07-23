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

/// Autentikasi staff via nomor telepon + OTP.
/// Melempar [ApiException] bila gagal (mis. nomor tidak terdaftar, OTP salah).
class AuthService {
  const AuthService._();

  /// Langkah 1 — minta kode OTP dikirim ke nomor telepon staff.
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
  static Future<StaffAuth> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final res = await ApiClient.instance.post(
      '/mobile/auth/staff/verify-otp',
      body: {'phone': phone, 'code': code},
      auth: false,
    );
    final data = res.asMap;
    final token = (data['token'] ?? '').toString();
    final staff = StaffAuth.fromMap(
      data['staff'] is Map ? Map<String, dynamic>.from(data['staff'] as Map) : {},
    );

    if (token.isEmpty || staff.id.isEmpty) {
      throw ApiException('Respons login tidak valid dari server.');
    }

    await SessionService.saveToken(token);
    await SessionService.saveStaffId(staff.id);
    return staff;
  }
}

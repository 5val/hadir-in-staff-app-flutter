import 'api_client.dart';
import 'session_service.dart';

/// Hasil permintaan OTP untuk penggantian nomor HP.
class PhoneChangeOtpResult {
  /// Email tujuan OTP — ditampilkan di layar agar staff tahu harus mengecek ke mana.
  final String email;
  final String pendingPhone;
  final int expiresInMinutes;
  final bool delivered;

  /// Hanya terisi di lingkungan pengembangan saat email tidak terkirim.
  final String? devCode;

  PhoneChangeOtpResult({
    required this.email,
    required this.pendingPhone,
    required this.expiresInMinutes,
    required this.delivered,
    required this.devCode,
  });

  factory PhoneChangeOtpResult.fromApi(Map<String, dynamic> j) =>
      PhoneChangeOtpResult(
        email: (j['email'] ?? '').toString(),
        pendingPhone: (j['pendingPhone'] ?? '').toString(),
        expiresInMinutes: (j['expiresInMinutes'] is num)
            ? (j['expiresInMinutes'] as num).toInt()
            : 10,
        delivered: j['delivered'] == true,
        devCode: j['devCode']?.toString(),
      );
}

/// Penggantian nomor HP oleh staff sendiri.
///
/// OTP-nya dikirim ke EMAIL, bukan ke nomor baru — mengirim ke nomor tujuan
/// akan sirkular (siapa pun yang memegang HP staff bisa memindahkan akun ke
/// nomornya sendiri). Nomor lama tetap berlaku sampai OTP terbukti benar,
/// jadi percobaan yang gagal atau ditinggalkan tidak pernah mengunci staff.
///
/// Setelah berhasil, backend membuka ulang gerbang dokumen onboarding —
/// lihat `DocumentService.onboardingStatus().isResubmission`.
class PhoneChangeService {
  const PhoneChangeService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// Minta OTP ke email untuk memindahkan akun ke [newPhone].
  static Future<PhoneChangeOtpResult> requestOtp(String newPhone) async {
    final id = await _staffId();
    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/phone-change/request-otp',
      body: {'phone': newPhone},
    );
    return PhoneChangeOtpResult.fromApi(res.asMap);
  }

  /// Verifikasi OTP. Bila berhasil, nomor HP resmi berganti DAN dokumen
  /// onboarding wajib diajukan ulang.
  static Future<void> verify(String code) async {
    final id = await _staffId();
    await ApiClient.instance.post(
      '/mobile/staff/$id/phone-change/verify',
      body: {'code': code},
    );
  }

  /// Batalkan permintaan yang belum diverifikasi.
  static Future<void> cancel() async {
    final id = await _staffId();
    await ApiClient.instance.post('/mobile/staff/$id/phone-change/cancel');
  }
}

import 'api_client.dart';
import 'session_service.dart';

/// Hasil permintaan OTP (langkah pertama login).
///
/// Sprint 2 OTP/auth overhaul (2026-08-03): OTP sekarang dikirim lewat EMAIL,
/// bukan WhatsApp lagi (`waDelivered` di respons lama berganti nama jadi
/// [delivered], dan field [email] baru ditambahkan — lihat
/// `docs/api-contracts/sprint2.md` backend, bagian "OTP/auth overhaul
/// dispatch").
class OtpRequestResult {
  final String phone;

  /// Alamat email tujuan pengiriman kode OTP (`Staff.email`, selalu ada).
  final String email;

  final int expiresInMinutes;

  /// true bila email OTP berhasil dikirim server. false hanya mungkin di
  /// non-production (dev/staging) — di production, gagal kirim membuat
  /// request ini melempar [ApiException] (503) alih-alih mengembalikan
  /// false.
  final bool delivered;

  /// Kode OTP versi development (dikirim backend saat NODE_ENV != production
  /// DAN `!delivered`). Di produksi selalu null.
  final String? devCode;

  final String message;

  OtpRequestResult({
    required this.phone,
    required this.email,
    required this.expiresInMinutes,
    required this.delivered,
    this.devCode,
    this.message = '',
  });

  factory OtpRequestResult.fromMap(Map<String, dynamic> m) => OtpRequestResult(
        phone: (m['phone'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        expiresInMinutes: (m['expiresInMinutes'] as num?)?.toInt() ?? 10,
        delivered: m['delivered'] == true,
        devCode: m['devCode']?.toString(),
        message: (m['message'] ?? '').toString(),
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

  /// Bentuk body request `set-passcode` — diekstrak jadi fungsi murni
  /// (tanpa I/O) supaya gampang diuji tanpa mocking network. [passcodeLama]
  /// SENGAJA tidak pernah dikirim (bahkan sebagai key kosong) bila null/
  /// kosong — Piece 3 (Sprint 2 OTP/auth overhaul): backend membedakan
  /// "field tidak ada" dari alur lupa-passcode (token verify-otp segar boleh
  /// set passcode baru tanpa passcode lama) dengan "field ada tapi salah"
  /// dari alur Ubah Passcode biasa (token sesi lama, passcode lama WAJIB
  /// benar).
  static Map<String, dynamic> buildSetPasscodeBody({
    required String passcode,
    String? passcodeLama,
  }) =>
      {
        'passcode': passcode,
        if (passcodeLama != null && passcodeLama.isNotEmpty)
          'passcodeLama': passcodeLama,
      };

  /// Simpan/ubah passcode di server. [passcodeLama] wajib bila staff sudah
  /// punya passcode sebelumnya (dipakai layar "Ubah Passcode") — KECUALI
  /// token yang dipakai berasal dari verify-otp yang masih segar (jalur
  /// "Lupa Passcode?"), di mana [passcodeLama] harus TIDAK diisi sama sekali
  /// (lihat [buildSetPasscodeBody]).
  static Future<void> setPasscode({
    required String passcode,
    String? passcodeLama,
  }) async {
    await ApiClient.instance.post(
      '/mobile/auth/staff/set-passcode',
      body: buildSetPasscodeBody(passcode: passcode, passcodeLama: passcodeLama),
    );
  }

  /// Langkah 1 (alur staff baru / lupa passcode) — minta OTP via email.
  ///
  /// Server menegakkan cooldown 60 detik antar-permintaan dan maksimum 3
  /// permintaan per 30 menit — pelanggaran keduanya melempar [ApiException]
  /// dengan `statusCode == 429` dan pesan Indonesia siap tampil (lihat
  /// `docs/api-contracts/sprint2.md`).
  static Future<OtpRequestResult> requestOtp(String phone) async {
    final res = await ApiClient.instance.post(
      '/mobile/auth/staff/request-otp',
      body: {'phone': phone},
      auth: false,
    );
    return OtpRequestResult.fromMap(res.asMap);
  }

  /// Coba ekstrak jumlah menit dari pesan lockout/rate-limit backend (mis.
  /// "...Coba lagi dalam 15 menit." / "...Coba lagi setelah 30 menit.").
  /// Backend TIDAK mengirim field terstruktur untuk sisa waktu — hanya teks
  /// pesan siap tampil — jadi ini best-effort untuk hitung mundur di UI.
  /// Null bila polanya tidak ditemukan; pemanggil harus tetap menampilkan
  /// [message] asli sebagai fallback.
  static int? parseLockoutMinutes(String message) {
    final match = RegExp(r'(\d+)\s*menit').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Langkah 2 — verifikasi OTP. Bila valid, token & id staff disimpan ke
  /// [SessionService] dan data staff dikembalikan.
  ///
  /// Server mengunci akun 15 menit setelah 3 kali kode salah — respons
  /// tersebut punya `statusCode == 429` (berbeda dari 400 "kode salah, masih
  /// ada sisa percobaan"), begitu juga saat lockout itu masih aktif.
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

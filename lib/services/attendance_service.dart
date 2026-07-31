import 'dart:convert';
import 'dart:io';

import '../config/testing_config.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Panggilan backend untuk absensi staff yang sedang login.
/// Semua method melempar [ApiException] bila gagal.
class AttendanceService {
  const AttendanceService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// GET today — mengembalikan record hari ini, atau null bila belum absen.
  static Future<AttendanceRecord?> today() async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/attendance/today');
    if (res.data == null) return null;
    return AttendanceRecord.fromApi(res.asMap);
  }

  /// Baca file foto lalu ubah ke base64 agar backend bisa mengunggahnya ke
  /// Google Drive.
  ///
  /// Fase 8 — sebelumnya app mengirim PATH FILE lokal HP sebagai `fotoMasuk`,
  /// dan backend menyimpan string itu apa adanya. Hasilnya kolom foto berisi
  /// sesuatu seperti "/data/user/0/.../IMG_123.jpg" yang tidak bisa dibuka
  /// admin mana pun, dan hilang total begitu app di-install ulang.
  static Future<String?> _encodePhoto(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return base64Encode(await file.readAsBytes());
  }

  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// POST check-in.
  ///
  /// [latitude]/[longitude] WAJIB bila staff punya lokasi kerja: server
  /// memverifikasinya terhadap radius Lokasi (lib/geo.ts) dan menolak
  /// check-in di luar area. [accuracy] adalah akurasi horizontal dari GPS HP;
  /// server memakainya sebagai toleransi tambahan supaya sinyal lemah tidak
  /// membuat staff yang benar-benar di kantor ikut tertolak.
  static Future<AttendanceRecord> checkIn({
    String? fotoMasuk,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final id = await _staffId();
    final foto = await _encodePhoto(fotoMasuk);

    // TESTING — `time` hanya ikut terkirim saat TestingConfig.enabled &
    // fakeTime = true. Di mode normal nilainya null, field-nya tidak
    // dikirim, dan backend memakai jam SERVER seperti biasa.
    final jamTesting = TestingConfig.checkInTimeOverride;

    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/attendance/check-in',
      body: {
        if (foto != null) 'fotoMasuk': foto,
        if (foto != null && fotoMasuk != null)
          'fotoMimeType': _mimeFromPath(fotoMasuk),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (jamTesting != null) 'time': jamTesting,
      },
    );
    return AttendanceRecord.fromApi(res.asMap);
  }

  /// POST check-out. Lihat [checkIn] soal parameter lokasi.
  static Future<AttendanceRecord> checkOut({
    String? fotoKeluar,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final id = await _staffId();
    final foto = await _encodePhoto(fotoKeluar);

    // TESTING — lihat catatan `time` di [checkIn].
    final jamTesting = TestingConfig.checkOutTimeOverride;

    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/attendance/check-out',
      body: {
        if (foto != null) 'fotoKeluar': foto,
        if (foto != null && fotoKeluar != null)
          'fotoMimeType': _mimeFromPath(fotoKeluar),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (jamTesting != null) 'time': jamTesting,
      },
    );
    return AttendanceRecord.fromApi(res.asMap);
  }

  /// Mulai istirahat. Server yang mencatat waktunya.
  static Future<AttendanceRecord> breakIn() async {
    final id = await _staffId();
    final res = await ApiClient.instance.post('/mobile/staff/$id/attendance/break-in');
    return AttendanceRecord.fromApi(res.asMap);
  }

  /// Selesai istirahat — server menghitung durasinya dan menambahkannya ke
  /// `Attendance.breakDurasi` (akumulatif bila istirahat lebih dari sekali).
  static Future<AttendanceRecord> breakOut() async {
    final id = await _staffId();
    final res = await ApiClient.instance.post('/mobile/staff/$id/attendance/break-out');
    return AttendanceRecord.fromApi(res.asMap);
  }

  /// GET riwayat. [month] format "YYYY-MM" (opsional), [limit] default server 60.
  static Future<List<AttendanceRecord>> history({String? month, int? limit}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/attendance',
      query: {
        if (month != null) 'month': month,
        if (limit != null) 'limit': limit,
      },
    );
    return res.asList.map(AttendanceRecord.fromApi).toList();
  }
}

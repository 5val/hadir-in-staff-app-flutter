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

  /// POST check-in. [lokasi] & [fotoMasuk] opsional.
  static Future<AttendanceRecord> checkIn({
    String? lokasi,
    String? fotoMasuk,
  }) async {
    final id = await _staffId();
    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/attendance/check-in',
      body: {
        if (lokasi != null) 'lokasi': lokasi,
        if (fotoMasuk != null) 'fotoMasuk': fotoMasuk,
      },
    );
    return AttendanceRecord.fromApi(res.asMap);
  }

  /// POST check-out. [fotoKeluar] opsional.
  static Future<AttendanceRecord> checkOut({String? fotoKeluar}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/attendance/check-out',
      body: {
        if (fotoKeluar != null) 'fotoKeluar': fotoKeluar,
      },
    );
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

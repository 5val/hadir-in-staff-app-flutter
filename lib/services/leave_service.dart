import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Panggilan backend untuk cuti/izin staff yang sedang login.
/// Semua method melempar [ApiException] bila gagal.
class LeaveService {
  const LeaveService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// GET daftar pengajuan cuti/izin milik staff.
  static Future<List<LeaveRequest>> myLeaves({String? status}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/leave',
      query: {if (status != null) 'status': status},
    );
    return res.asList.map(LeaveRequest.fromApi).toList();
  }

  /// POST pengajuan cuti/izin baru.
  static Future<LeaveRequest> create({
    required String tipe, // Cuti | Izin | Sakit | Dinas
    String subTipe = '',
    required String alasan,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required int jumlahHari,
  }) async {
    final id = await _staffId();
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/leave',
      body: {
        'tipe': tipe,
        'subTipe': subTipe,
        'alasan': alasan,
        'tanggalMulai': d(tanggalMulai),
        'tanggalSelesai': d(tanggalSelesai),
        'jumlahHari': jumlahHari,
      },
    );
    return LeaveRequest.fromApi(res.asMap);
  }

  /// GET sisa & total cuti staff.
  static Future<({int sisaCuti, int totalCuti})> balance() async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/leave/balance');
    final m = res.asMap;
    return (
      sisaCuti: (m['sisaCuti'] as num?)?.toInt() ?? 0,
      totalCuti: (m['totalCuti'] as num?)?.toInt() ?? 0,
    );
  }
}

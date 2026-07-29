import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Satu pengajuan lembur milik bawahan.
class SubordinateOvertime {
  final String id;
  final String staffId;
  final String staffNama;
  final String jabatan;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String alasan;
  final String status;

  SubordinateOvertime({
    required this.id,
    required this.staffId,
    required this.staffNama,
    required this.jabatan,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.alasan,
    required this.status,
  });

  factory SubordinateOvertime.fromApi(Map<String, dynamic> j) {
    final staff = j['staff'] is Map
        ? Map<String, dynamic>.from(j['staff'] as Map)
        : <String, dynamic>{};
    final jabatan = staff['jabatan'] is Map
        ? Map<String, dynamic>.from(staff['jabatan'] as Map)
        : <String, dynamic>{};

    return SubordinateOvertime(
      id: (j['id'] ?? '').toString(),
      staffId: (staff['id'] ?? '').toString(),
      staffNama: (staff['nama'] ?? '-').toString(),
      jabatan: (jabatan['nama'] ?? '-').toString(),
      tanggal: DateTime.tryParse((j['tanggal'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      jamMulai: (j['jamMulai'] ?? '').toString(),
      jamSelesai: (j['jamSelesai'] ?? '').toString(),
      alasan: (j['alasan'] ?? '').toString(),
      status: (j['status'] ?? 'pending').toString(),
    );
  }
}

/// Hasil muat pengajuan bawahan.
class SubordinateRequests {
  /// false = staff ini memang bukan atasan siapa pun (tidak punya
  /// AuthorityGrant), jadi tab "Pengajuan Karyawan" tidak perlu ditampilkan.
  final bool isApprover;

  /// Hanya Manager yang boleh memproses lembur (aturan Fase 5).
  final bool canApproveLembur;

  final List<LeaveRequest> leave;
  final List<SubordinateOvertime> lembur;

  const SubordinateRequests({
    required this.isApprover,
    required this.canApproveLembur,
    required this.leave,
    required this.lembur,
  });

  static const empty = SubordinateRequests(
    isApprover: false,
    canApproveLembur: false,
    leave: [],
    lembur: [],
  );
}

/// Pengajuan cuti/izin & lembur milik bawahan — Fase 8.
///
/// Menggantikan `SampleData.subordinateLeaveRequests`: daftar dummy yang
/// tombol Setujui/Tolak-nya hanya menutup dialog tanpa mengubah apa pun di
/// database.
class SubordinateService {
  const SubordinateService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  static Future<SubordinateRequests> load({String status = 'pending'}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/subordinates/requests',
      query: {'status': status},
    );
    final data = res.asMap;

    List<Map<String, dynamic>> listOf(String key) => data[key] is List
        ? (data[key] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return SubordinateRequests(
      isApprover: data['isApprover'] == true,
      canApproveLembur: data['canApproveLembur'] == true,
      leave: listOf('leave').map(LeaveRequest.fromApi).toList(),
      lembur: listOf('lembur').map(SubordinateOvertime.fromApi).toList(),
    );
  }

  static Future<void> respondLeave({
    required String leaveId,
    required bool approve,
    String? alasanTolak,
  }) async {
    final id = await _staffId();
    await ApiClient.instance.patch(
      '/mobile/staff/$id/subordinates/leave/$leaveId',
      body: {
        'action': approve ? 'approve' : 'reject',
        if (alasanTolak != null && alasanTolak.isNotEmpty)
          'alasanTolak': alasanTolak,
      },
    );
  }

  static Future<void> respondLembur({
    required String lemburId,
    required bool approve,
  }) async {
    final id = await _staffId();
    await ApiClient.instance.patch(
      '/mobile/staff/$id/subordinates/lembur/$lemburId',
      body: {'action': approve ? 'approve' : 'reject'},
    );
  }
}

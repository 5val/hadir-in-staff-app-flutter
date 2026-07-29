import 'api_client.dart';
import 'session_service.dart';

/// Satu baris `log_pesan` yang BELUM dibaca — akan ditampilkan sebagai popup
/// setelah login, lalu ditandai dibaca sehingga tidak muncul lagi.
class StaffLog {
  final String id;

  /// promosi | surat_peringatan | info
  final String tipe;
  final String judul;
  final String pesan;
  final DateTime tanggal;
  final Map<String, dynamic> metadata;

  StaffLog({
    required this.id,
    required this.tipe,
    required this.judul,
    required this.pesan,
    required this.tanggal,
    required this.metadata,
  });

  bool get isPromosi => tipe == 'promosi';
  bool get isSuratPeringatan => tipe == 'surat_peringatan';

  factory StaffLog.fromApi(Map<String, dynamic> j) => StaffLog(
        id: (j['id'] ?? '').toString(),
        tipe: (j['tipe'] ?? 'info').toString(),
        judul: (j['judul'] ?? '').toString(),
        pesan: (j['pesan'] ?? '').toString(),
        tanggal:
            DateTime.tryParse((j['tanggal'] ?? '').toString())?.toLocal() ??
                DateTime.now(),
        metadata: j['metadata'] is Map
            ? Map<String, dynamic>.from(j['metadata'] as Map)
            : <String, dynamic>{},
      );
}

/// Antrean popup log (promosi / surat peringatan).
///
/// Backend HANYA mengembalikan log yang `readAt`-nya masih null — sesuai
/// aturan "app hanya akan membaca data log yang statusnya belum di-read".
class StaffLogService {
  const StaffLogService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  static Future<List<StaffLog>> unread() async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/logs');
    return res.asList.map(StaffLog.fromApi).toList();
  }

  static Future<void> markRead(String logId) async {
    final id = await _staffId();
    await ApiClient.instance.patch('/mobile/staff/$id/logs/$logId/read');
  }
}

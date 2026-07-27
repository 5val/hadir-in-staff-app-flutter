import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Panggilan backend untuk slip gaji staff yang sedang login.
class SalaryService {
  const SalaryService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// GET daftar slip gaji (hanya yang sudah dikirim office). Setiap slip sudah
  /// berisi seluruh komponen sehingga detail tidak perlu request terpisah.
  static Future<List<SalarySlip>> mySlips({int? limit}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/gaji/slip',
      query: {if (limit != null) 'limit': limit},
    );
    return res.asList.map(SalarySlip.fromApi).toList();
  }
}

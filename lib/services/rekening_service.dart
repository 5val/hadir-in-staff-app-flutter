import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Validasi isian rekening di sisi app. Aturannya sama dengan server
/// (`staffRekeningSchema`): server tetap validasi akhir, ini hanya supaya staff
/// dapat pesan langsung di kolomnya.
class RekeningValidator {
  const RekeningValidator._();

  /// Spasi dan strip yang biasa diketik di nomor rekening dibuang.
  static String normalizeNomor(String input) =>
      input.replaceAll(RegExp(r'[\s-]'), '');

  static String? bank(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Nama bank wajib diisi';
    if (t.length > 100) return 'Nama bank maksimal 100 karakter';
    return null;
  }

  static String? nomor(String? v) {
    final n = normalizeNomor(v ?? '');
    if (n.isEmpty) return 'Nomor rekening wajib diisi';
    if (!RegExp(r'^\d+$').hasMatch(n)) return 'Nomor rekening hanya boleh angka';
    if (n.length < 5 || n.length > 20) {
      return 'Nomor rekening harus 5-20 digit';
    }
    return null;
  }

  static String? pemilik(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Nama pemilik rekening wajib diisi';
    if (t.length > 150) return 'Nama pemilik maksimal 150 karakter';
    return null;
  }
}

/// Staff mengisi rekening gaji sendiri (meeting klien 2026-09-20).
class RekeningService {
  const RekeningService._();

  /// PUT /api/mobile/staff/:id/rekening. Setelah sukses profil di
  /// [AppSession] ikut diperbarui, jadi banner pengingat di Home hilang
  /// tanpa menunggu muat ulang profil.
  static Future<void> save({
    required String namaBank,
    required String nomorRekening,
    required String namaPemilikRekening,
  }) async {
    final staffId = await SessionService.getStaffId();
    if (staffId == null || staffId.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    final res = await ApiClient.instance.put(
      '/mobile/staff/$staffId/rekening',
      body: {
        'namaBank': namaBank.trim(),
        'nomorRekening': RekeningValidator.normalizeNomor(nomorRekening),
        'namaPemilikRekening': namaPemilikRekening.trim(),
      },
    );
    // Pakai nilai yang dinormalkan server, bukan yang diketik.
    final saved = res.asMap;
    final current = AppSession.staff;
    if (current != null) {
      AppSession.setStaff(current.copyWithRekening(
        namaBank: (saved['namaBank'] ?? namaBank).toString(),
        nomorRekening: (saved['nomorRekening'] ?? nomorRekening).toString(),
        namaPemilikRekening:
            (saved['namaPemilikRekening'] ?? namaPemilikRekening).toString(),
      ));
    }
  }
}

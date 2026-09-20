import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'google_drive_service.dart';
import 'salary_service.dart';

/// Menyimpan slip gaji yang sudah TERKUNCI ke Google Drive pribadi staff
/// (permintaan klien 2026-09-19: "slip disimpan ke Drive staff").
///
/// Aturannya:
///  - hanya slip `terkunci` (server yang memutuskan lewat `bisaUnduh`);
///  - yang diunggah adalah PDF dari server -- file yang sama dengan yang HR
///    kirim lewat email;
///  - id slip yang sudah tersimpan dicatat di perangkat supaya tidak diunggah
///    berulang-ulang;
///  - mode otomatis TIDAK pernah memunculkan dialog login Google: bila belum
///    ada sesi, ia diam dan staff cukup menekan tombol simpan sekali.
class SlipDriveSync {
  const SlipDriveSync._();

  static const _prefsKey = 'slip_drive_saved_ids';

  static Future<Set<String>> savedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
  }

  static Future<bool> isSaved(String slipId) async =>
      (await savedIds()).contains(slipId);

  static Future<void> _markSaved(String slipId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet()
      ..add(slipId);
    await prefs.setStringList(_prefsKey, ids.toList());
  }

  static String filenameFor(SalarySlip slip) =>
      'Slip-Gaji-${slip.periodeKey}.pdf';

  /// Menyimpan satu slip. Melempar (String / ApiException) bila gagal;
  /// pemanggil yang menampilkan pesannya.
  static Future<DriveSaveOutcome> save(SalarySlip slip,
      {required bool interactive}) async {
    if (!slip.bisaUnduh) {
      throw 'Slip baru bisa disimpan setelah dikunci oleh HR.';
    }
    final bytes = await SalaryService.downloadPdf(slip.id);
    final outcome = await GoogleDriveService.saveSlipPdf(
      filename: filenameFor(slip),
      bytes: bytes,
      interactive: interactive,
    );
    if (outcome == DriveSaveOutcome.saved ||
        outcome == DriveSaveOutcome.alreadySaved) {
      await _markSaved(slip.id);
    }
    return outcome;
  }

  /// Menyimpan di latar semua slip terkunci yang belum tersimpan. Berurutan,
  /// diam, dan berhenti begitu ketahuan belum ada sesi Google. Mengembalikan
  /// jumlah slip yang berhasil disimpan kali ini.
  static Future<int> autoSyncLocked(List<SalarySlip> slips) async {
    final done = await savedIds();
    var saved = 0;
    for (final slip in slips) {
      if (!slip.bisaUnduh || slip.id.isEmpty || done.contains(slip.id)) continue;
      try {
        final outcome = await save(slip, interactive: false);
        if (outcome == DriveSaveOutcome.needsSignIn) return saved;
        if (outcome == DriveSaveOutcome.saved) saved++;
      } catch (_) {
        // Penyimpanan otomatis tidak boleh mengganggu layar; tombol manual
        // tetap tersedia dan menampilkan pesan errornya.
        return saved;
      }
    }
    return saved;
  }
}

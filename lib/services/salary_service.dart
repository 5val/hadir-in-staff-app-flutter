import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Hasil `POST .../konfirmasi`. Status akhir diputuskan SERVER: sejak Sprint 3
/// konfirmasi staff langsung mengunci slip (`terkunci`, `bisaUnduh: true`);
/// app tidak boleh menebak/hardcode statusnya.
class KonfirmasiResult {
  final String statusSlip;
  final bool bisaUnduh;

  const KonfirmasiResult({required this.statusSlip, required this.bisaUnduh});

  /// Server lama yang tidak mengirim status dianggap `dikonfirmasi` (perilaku
  /// lama: menunggu HR mengunci).
  factory KonfirmasiResult.fromApi(Map<String, dynamic> data) {
    final status = (data['statusSlip'] ?? '').toString();
    final effective = status.isEmpty ? 'dikonfirmasi' : status;
    return KonfirmasiResult(
      statusSlip: effective,
      bisaUnduh: data['bisaUnduh'] is bool
          ? data['bisaUnduh'] as bool
          : effective == 'terkunci',
    );
  }

  /// Slip yang diperbarui dengan status dari server.
  SalarySlip applyTo(SalarySlip slip) =>
      slip.copyWith(statusSlip: statusSlip, bisaUnduh: bisaUnduh);
}

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

  /// GET daftar slip gaji. Sejak alur konfirmasi (2026-09-19) daftar ini
  /// memuat slip sejak HR menekan "Kirim Konfirmasi" (`menunggu_konfirmasi`)
  /// sampai `terkunci` -- bukan lagi hanya yang sudah final. Setiap slip sudah
  /// berisi seluruh komponen sehingga detail tidak perlu request terpisah.
  static Future<List<SalarySlip>> mySlips({int? limit}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/gaji/slip',
      query: {if (limit != null) 'limit': limit},
    );
    return res.asList.map(SalarySlip.fromApi).toList();
  }

  /// POST: staff menyatakan angka di slip sudah benar
  /// (`menunggu_konfirmasi` -> `terkunci` di server terbaru). 409 bila slip
  /// tidak sedang menunggu konfirmasinya (mis. HR sudah menariknya kembali).
  /// Mengembalikan status yang ditetapkan server.
  ///
  /// [dikirimKonfirmasiAt] = nilai persis dari slip yang sedang dilihat staff;
  /// server membalas 409 bila HR sudah memperbaruinya (lihat
  /// [isSlipStaleConflict]).
  static Future<KonfirmasiResult> konfirmasi(String slipId,
      {String? dikirimKonfirmasiAt}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/gaji/slip/$slipId/konfirmasi',
      body: konfirmasiBody(dikirimKonfirmasiAt),
    );
    return KonfirmasiResult.fromApi(res.asMap);
  }

  /// POST: staff menolak slip beserta alasannya
  /// (`menunggu_konfirmasi` -> `ditolak`). Alasan wajib, 5-500 karakter --
  /// itulah yang dibaca HR di tabel slip untuk tahu apa yang harus diperbaiki.
  static Future<void> tolak(String slipId, String alasan,
      {String? dikirimKonfirmasiAt}) async {
    final id = await _staffId();
    await ApiClient.instance.post(
      '/mobile/staff/$id/gaji/slip/$slipId/tolak',
      body: tolakBody(alasan, dikirimKonfirmasiAt),
    );
  }

  /// Body konfirmasi: kosong untuk slip tanpa `dikirimKonfirmasiAt` (server
  /// lama), supaya request tetap sama seperti dulu.
  static Map<String, dynamic>? konfirmasiBody(String? dikirimKonfirmasiAt) =>
      dikirimKonfirmasiAt == null
          ? null
          : {'dikirimKonfirmasiAt': dikirimKonfirmasiAt};

  /// Batas panjang alasan di server (`slipTolakSchema`: 5-500 karakter).
  static const tolakAlasanMax = 500;

  /// Susun alasan tolak dari bagian slip yang dicentang staff ([bagian],
  /// mis. "Tunjangan: Transport Harian") dan catatan bebas ([catatan]).
  /// Hasilnya satu string -- itulah yang dibaca admin/manajer di tabel slip
  /// dan notifikasi, jadi server tidak perlu field baru. Dipotong ke
  /// [tolakAlasanMax] bila kepanjangan.
  static String susunAlasanTolak(List<String> bagian, String catatan) {
    final note = catatan.trim();
    final parts = <String>[
      if (bagian.isNotEmpty) 'Bagian yang salah: ${bagian.join('; ')}.',
      if (note.isNotEmpty) bagian.isEmpty ? note : 'Catatan: $note',
    ];
    final text = parts.join(' ');
    return text.length <= tolakAlasanMax
        ? text
        : '${text.substring(0, tolakAlasanMax - 1)}…';
  }

  static Map<String, dynamic> tolakBody(
          String alasan, String? dikirimKonfirmasiAt) =>
      {
        'alasan': alasan.trim(),
        if (dikirimKonfirmasiAt != null)
          'dikirimKonfirmasiAt': dikirimKonfirmasiAt,
      };

  /// 409 = slip sudah berubah di server (HR memperbarui / menariknya). App
  /// menampilkan pesan server dan memuat ulang, tanpa mengubah status lokal.
  static bool isSlipStaleConflict(ApiException e) => e.statusCode == 409;

  /// GET PDF slip yang dirender server (template yang sama dengan yang
  /// dikirim HR lewat email). Hanya slip `terkunci`; selain itu server
  /// membalas 403 dan app tidak boleh menawarkan unduhan.
  static Future<Uint8List> downloadPdf(String slipId) async {
    final id = await _staffId();
    return ApiClient.instance.getBytes('/mobile/staff/$id/gaji/slip/$slipId/pdf');
  }
}

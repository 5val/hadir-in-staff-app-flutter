import 'dart:typed_data';

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
  /// (`menunggu_konfirmasi` -> `dikonfirmasi`). 409 bila slip tidak sedang
  /// menunggu konfirmasinya (mis. HR sudah menariknya kembali).
  static Future<void> konfirmasi(String slipId) async {
    final id = await _staffId();
    await ApiClient.instance.post('/mobile/staff/$id/gaji/slip/$slipId/konfirmasi');
  }

  /// POST: staff menolak slip beserta alasannya
  /// (`menunggu_konfirmasi` -> `ditolak`). Alasan wajib, 5-500 karakter --
  /// itulah yang dibaca HR di tabel slip untuk tahu apa yang harus diperbaiki.
  static Future<void> tolak(String slipId, String alasan) async {
    final id = await _staffId();
    await ApiClient.instance.post(
      '/mobile/staff/$id/gaji/slip/$slipId/tolak',
      body: {'alasan': alasan.trim()},
    );
  }

  /// GET PDF slip yang dirender server (template yang sama dengan yang
  /// dikirim HR lewat email). Hanya slip `terkunci`; selain itu server
  /// membalas 403 dan app tidak boleh menawarkan unduhan.
  static Future<Uint8List> downloadPdf(String slipId) async {
    final id = await _staffId();
    return ApiClient.instance.getBytes('/mobile/staff/$id/gaji/slip/$slipId/pdf');
  }
}

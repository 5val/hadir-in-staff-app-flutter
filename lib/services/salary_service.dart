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

/// Berkas bukti pembayaran: byte + content-type dari server (bila ada).
class BuktiFile {
  final Uint8List bytes;
  final String? contentType;
  const BuktiFile(this.bytes, [this.contentType]);

  /// Content-type server didahulukan; tanpa itu, deteksi dari byte.
  bool get isPdf {
    final t = (contentType ?? '').toLowerCase();
    if (t.contains('pdf')) return true;
    if (t.startsWith('image/')) return false;
    return SalaryService.isPdfBytes(bytes);
  }
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

  /// Batas maksimum `limit` yang diterima server (default server 200, jadi
  /// tanpa ini "Semua periode" terpotong diam-diam).
  static const maxSlipLimit = 500;

  /// GET satu slip (dipakai menyegarkan detail setelah 409).
  static Future<SalarySlip> slipById(String slipId) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/gaji/slip/$slipId');
    return SalarySlip.fromApi(res.asMap);
  }

  /// GET daftar slip gaji. Sejak alur konfirmasi (2026-09-19) daftar ini
  /// memuat slip sejak HR menekan "Kirim Konfirmasi" (`menunggu_konfirmasi`)
  /// sampai `terkunci` -- bukan lagi hanya yang sudah final. Setiap slip sudah
  /// berisi seluruh komponen sehingga detail tidak perlu request terpisah.
  static Future<List<SalarySlip>> mySlips({int limit = maxSlipLimit}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/gaji/slip',
      query: {'limit': limit},
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
  /// [bagian] = kunci baris yang dicentang (lihat `SalaryComponent.key`),
  /// disimpan server supaya baris itu bisa ditandai di slip. Penolakan hanya
  /// boleh SEKALI per slip: server membalas 409 untuk penolakan kedua.
  static Future<void> tolak(String slipId, String alasan,
      {String? dikirimKonfirmasiAt, List<String> bagian = const []}) async {
    final id = await _staffId();
    await ApiClient.instance.post(
      '/mobile/staff/$id/gaji/slip/$slipId/tolak',
      body: tolakBody(alasan, dikirimKonfirmasiAt, bagian: bagian),
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
          String alasan, String? dikirimKonfirmasiAt,
          {List<String> bagian = const []}) =>
      {
        'alasan': alasan.trim(),
        if (dikirimKonfirmasiAt != null)
          'dikirimKonfirmasiAt': dikirimKonfirmasiAt,
        if (bagian.isNotEmpty) 'bagian': bagian,
      };

  /// 409 = slip sudah berubah di server (HR memperbarui / menariknya). App
  /// menampilkan pesan server dan memuat ulang, tanpa mengubah status lokal.
  static bool isSlipStaleConflict(ApiException e) => e.statusCode == 409;

  /// Batas alasan batal-setuju di server (min 5, maks 300).
  static const batalAlasanMin = 5;
  static const batalAlasanMax = 300;

  static Map<String, dynamic> batalSetujuBody(
          String alasan, String? dikirimKonfirmasiAt) =>
      {
        'alasan': alasan.trim(),
        if (dikirimKonfirmasiAt != null)
          'dikirimKonfirmasiAt': dikirimKonfirmasiAt,
      };

  /// POST: staff membatalkan persetujuannya (D1) selama slip belum disetujui
  /// cair. Slip menjadi `ditolak` di server. 409 membawa pesan server yang
  /// ditampilkan apa adanya.
  static Future<void> batalSetuju(String slipId, String alasan,
      {String? dikirimKonfirmasiAt}) async {
    final id = await _staffId();
    await ApiClient.instance.post(
      '/mobile/staff/$id/gaji/slip/$slipId/batal-setuju',
      body: batalSetujuBody(alasan, dikirimKonfirmasiAt),
    );
  }

  /// GET berkas bukti pembayaran (gambar atau PDF) dengan header auth.
  static Future<BuktiFile> buktiBayar(String slipId) async {
    final id = await _staffId();
    final f = await ApiClient.instance
        .getFile('/mobile/staff/$id/gaji/slip/$slipId/bukti');
    return BuktiFile(f.bytes, f.contentType);
  }

  /// `%PDF` di 1024 byte pertama (beberapa PDF punya sampah sebelum header).
  static bool isPdfBytes(Uint8List b) {
    final end = b.length < 1024 ? b.length : 1024;
    for (var i = 0; i + 4 <= end; i++) {
      if (b[i] == 0x25 && b[i + 1] == 0x50 && b[i + 2] == 0x44 && b[i + 3] == 0x46) {
        return true;
      }
    }
    return false;
  }

  /// GET PDF slip yang dirender server (template yang sama dengan yang
  /// dikirim HR lewat email). Hanya slip `terkunci`; selain itu server
  /// membalas 403 dan app tidak boleh menawarkan unduhan.
  static Future<Uint8List> downloadPdf(String slipId) async {
    final id = await _staffId();
    return ApiClient.instance.getBytes('/mobile/staff/$id/gaji/slip/$slipId/pdf');
  }
}

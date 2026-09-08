import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu dokumen yang sudah DIPILIH staff tapi BELUM diajukan.
///
/// Ada dua bentuk draft:
///   • berkas baru dari kamera/galeri ([filePath] terisi), dan
///   • pemakaian ulang berkas lama yang sudah disetujui ([reuse] true) —
///     dua-duanya sama-sama menunggu tombol "Ajukan Dokumen" di bawah.
class DocumentDraft {
  final String jenis;

  /// Path berkas di HP. Kosong bila draft ini berupa pemakaian ulang berkas
  /// lama yang sudah ada di server.
  final String filePath;

  /// Draft ini adalah "pakai berkas sebelumnya", bukan berkas baru.
  final bool reuse;

  /// URL berkas lama yang dipakai ulang (hanya untuk pratinjau saat [reuse]).
  final String reuseFileUrl;

  final String catatanStaff;
  final DateTime pickedAt;

  const DocumentDraft({
    required this.jenis,
    required this.filePath,
    required this.catatanStaff,
    required this.pickedAt,
    this.reuse = false,
    this.reuseFileUrl = '',
  });

  bool get isNewFile => !reuse && filePath.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'jenis': jenis,
        'filePath': filePath,
        'reuse': reuse,
        'reuseFileUrl': reuseFileUrl,
        'catatanStaff': catatanStaff,
        'pickedAt': pickedAt.toIso8601String(),
      };

  factory DocumentDraft.fromJson(Map<String, dynamic> j) => DocumentDraft(
        jenis: (j['jenis'] ?? '').toString(),
        filePath: (j['filePath'] ?? '').toString(),
        reuse: j['reuse'] == true,
        reuseFileUrl: (j['reuseFileUrl'] ?? '').toString(),
        catatanStaff: (j['catatanStaff'] ?? '').toString(),
        pickedAt: DateTime.tryParse((j['pickedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

/// Penyimpanan LOKAL untuk dokumen yang sudah dipilih tapi belum diajukan.
///
/// Perubahan perilaku yang diperbaiki di sini: dulu memilih berkas =
/// langsung `POST /documents`, yang berarti berkasnya seketika terunggah ke
/// Google Drive perusahaan dan sebuah baris `staff_document` berstatus
/// `pending` langsung muncul di antrean HRD — padahal staff baru sekadar
/// MEMILIH foto, belum tentu foto yang benar, dan belum tentu selesai
/// menyiapkan dokumen lainnya. Tidak ada cara membatalkannya dari app.
///
/// Sekarang berkas hanya DISALIN ke folder privat app
/// (`<app-docs>/document_drafts/`) dan dicatat di SharedPreferences. Tidak
/// ada satu pun panggilan jaringan sampai staff menekan satu tombol
/// "Ajukan Dokumen" di bagian bawah layar.
///
/// Berkasnya disalin, bukan dirujuk apa adanya: `image_picker` menaruh hasil
/// kamera/galeri di direktori CACHE yang boleh dihapus OS kapan saja, jadi
/// draft yang menunjuk ke sana bisa hilang sebelum sempat diajukan.
class DocumentDraftService {
  const DocumentDraftService._();

  static const _prefsKey = 'document_drafts_v1';
  static const _folder = 'document_drafts';

  /// Semua draft, dipetakan per jenis dokumen.
  ///
  /// Entri yang berkasnya sudah tidak ada di HP (dibersihkan OS / app
  /// di-install ulang) DIBUANG di sini, bukan dibiarkan jadi draft hantu yang
  /// gagal saat diajukan.
  static Future<Map<String, DocumentDraft>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};

    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }

    final result = <String, DocumentDraft>{};
    var pruned = false;
    for (final entry in decoded.entries) {
      if (entry.value is! Map) continue;
      final draft =
          DocumentDraft.fromJson(Map<String, dynamic>.from(entry.value as Map));
      if (draft.isNewFile && !File(draft.filePath).existsSync()) {
        pruned = true;
        continue;
      }
      result[entry.key] = draft;
    }
    if (pruned) await _write(result);
    return result;
  }

  /// Simpan berkas baru sebagai draft (menimpa draft sebelumnya untuk jenis
  /// yang sama, termasuk menghapus salinan lamanya).
  static Future<DocumentDraft> putFile({
    required String jenis,
    required File source,
    String catatanStaff = '',
  }) async {
    final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = _extensionOf(source.path);
    final target =
        '${dir.path}/${jenis}_${DateTime.now().millisecondsSinceEpoch}$ext';
    await source.copy(target);

    final drafts = await all();
    await _deleteFileOf(drafts[jenis]);
    final draft = DocumentDraft(
      jenis: jenis,
      filePath: target,
      catatanStaff: catatanStaff,
      pickedAt: DateTime.now(),
    );
    drafts[jenis] = draft;
    await _write(drafts);
    return draft;
  }

  /// Tandai jenis ini akan diajukan dengan berkas LAMA yang sudah disetujui.
  static Future<DocumentDraft> putReuse({
    required String jenis,
    required String fileUrl,
  }) async {
    final drafts = await all();
    await _deleteFileOf(drafts[jenis]);
    final draft = DocumentDraft(
      jenis: jenis,
      filePath: '',
      reuse: true,
      reuseFileUrl: fileUrl,
      catatanStaff: '',
      pickedAt: DateTime.now(),
    );
    drafts[jenis] = draft;
    await _write(drafts);
    return draft;
  }

  /// Ganti catatan staff pada draft yang sudah ada.
  static Future<void> setCatatan(String jenis, String catatan) async {
    final drafts = await all();
    final existing = drafts[jenis];
    if (existing == null) return;
    drafts[jenis] = DocumentDraft(
      jenis: existing.jenis,
      filePath: existing.filePath,
      reuse: existing.reuse,
      reuseFileUrl: existing.reuseFileUrl,
      catatanStaff: catatan,
      pickedAt: existing.pickedAt,
    );
    await _write(drafts);
  }

  /// Buang satu draft beserta salinan berkasnya.
  static Future<void> remove(String jenis) async {
    final drafts = await all();
    await _deleteFileOf(drafts.remove(jenis));
    await _write(drafts);
  }

  /// Buang semua draft — dipanggil setelah pengajuan berhasil, dan saat
  /// logout supaya berkas staff sebelumnya tidak tertinggal di HP.
  static Future<void> clear() async {
    final drafts = await all();
    for (final d in drafts.values) {
      await _deleteFileOf(d);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static Future<void> _write(Map<String, DocumentDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(drafts.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  static Future<void> _deleteFileOf(DocumentDraft? draft) async {
    if (draft == null || !draft.isNewFile) return;
    try {
      final f = File(draft.filePath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[doc-draft] gagal menghapus ${draft.filePath}: $e');
    }
  }

  static String _extensionOf(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0 || path.length - i > 6) return '.jpg';
    return path.substring(i).toLowerCase();
  }
}

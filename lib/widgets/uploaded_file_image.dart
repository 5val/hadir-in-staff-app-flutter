import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Gambar milik server (selfie absensi, dokumen onboarding) dari salah satu
/// dari dua sumber.
///
/// Kenapa perlu dua sumber: tepat setelah mengunggah, gambar yang paling cepat
/// dan paling tajam adalah file yang masih ada di HP ([localPath]). Tapi file
/// itu hanya hidup selama sesi — begitu HP terkunci lalu staff membuka app
/// lagi lewat passcode, layar dibangun dari nol dan satu-satunya yang tersisa
/// adalah nilai kolom dari server ([remoteUrl]). Sebelum widget ini ada, kartu
/// detail kehadiran ikut hilang di titik itu.
///
/// Dipakai dua tempat: kartu detail kehadiran (home_tab) dan pratinjau dokumen
/// onboarding (pas foto/KTP/BPJS/NPWP).
///
/// [remoteUrl] bisa berbentuk tiga hal yang semuanya harus tetap jalan:
///   1. URL Google Drive — file PRIVAT, tidak bisa dipakai `Image.network`
///      langsung. Harus lewat proxy terautentikasi
///      `GET /api/mobile/files/:fileId` dengan token staff.
///   2. `/uploads/...` — fallback disk lokal server, disajikan
///      `express.static` tanpa auth, cukup diberi prefix origin backend.
///   3. URL absolut lain (mis. data contoh) — dipakai apa adanya.
class UploadedFileImage extends StatefulWidget {
  /// Path file di HP untuk unggahan yang baru saja dilakukan. Null bila widget
  /// ini dibangun ulang dari data server.
  final String? localPath;

  /// Nilai kolom URL dari server — `fotoMasuk`/`fotoKeluar` untuk absensi,
  /// `fileUrl` untuk dokumen onboarding (boleh kosong).
  final String remoteUrl;

  /// `cover` untuk thumbnail/kartu (mengisi bingkai), `contain` untuk penampil
  /// layar penuh — memotong dokumen identitas saat diperbesar justru
  /// menghilangkan bagian yang ingin diperiksa.
  final BoxFit fit;

  /// Radius sudut. 0 untuk penampil layar penuh.
  final double borderRadius;

  const UploadedFileImage({
    super.key,
    required this.localPath,
    required this.remoteUrl,
    this.fit = BoxFit.cover,
    this.borderRadius = 10,
  });

  @override
  State<UploadedFileImage> createState() => _UploadedFileImageState();
}

class _UploadedFileImageState extends State<UploadedFileImage> {
  /// Header Authorization untuk foto yang harus lewat proxy. Null selama
  /// token belum terbaca dari secure storage.
  Map<String, String>? _authHeaders;

  @override
  void initState() {
    super.initState();
    if (_driveFileId(widget.remoteUrl) != null) _loadToken();
  }

  @override
  void didUpdateWidget(covariant UploadedFileImage old) {
    super.didUpdateWidget(old);
    if (old.remoteUrl != widget.remoteUrl &&
        _driveFileId(widget.remoteUrl) != null &&
        _authHeaders == null) {
      _loadToken();
    }
  }

  Future<void> _loadToken() async {
    final token = await SessionService.getToken();
    if (!mounted || token == null || token.isEmpty) return;
    setState(() => _authHeaders = {'Authorization': 'Bearer $token'});
  }

  /// Ambil file id dari bentuk-bentuk URL yang biasa dibagikan Drive.
  /// Null bila `url` sama sekali bukan URL Drive.
  static String? _driveFileId(String url) {
    if (url.isEmpty) return null;
    for (final re in [
      RegExp(r'/file/d/([a-zA-Z0-9_-]{10,})'),
      RegExp(r'/d/([a-zA-Z0-9_-]{10,})'),
      RegExp(r'[?&]id=([a-zA-Z0-9_-]{10,})'),
    ]) {
      final m = re.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Origin backend tanpa akhiran `/api` — untuk aset statis `/uploads/...`.
  static String get _origin =>
      ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  Widget get _placeholder =>
      const Icon(Icons.person_rounded, color: AppColors.slate400, size: 32);

  @override
  Widget build(BuildContext context) {
    final local = widget.localPath;

    // File kamera sesi ini selalu didahulukan: tidak perlu jaringan sama
    // sekali, jadi tampil seketika setelah absen.
    if (local != null && local.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: kIsWeb
            ? Image.network(local,
                fit: widget.fit,
                errorBuilder: (_, __, ___) => _placeholder)
            : Image.file(File(local),
                fit: widget.fit,
                errorBuilder: (_, __, ___) => _placeholder),
      );
    }

    final url = widget.remoteUrl;
    if (url.isEmpty) return _placeholder;

    final driveId = _driveFileId(url);
    final String src;
    if (driveId != null) {
      // Tanpa token, request ke proxy pasti 401 — tampilkan placeholder saja
      // sampai token terbaca daripada memicu error jaringan yang sia-sia.
      if (_authHeaders == null) return _placeholder;
      src = '${ApiConfig.baseUrl}/mobile/files/$driveId';
    } else if (url.startsWith('/')) {
      src = '$_origin$url';
    } else {
      src = url;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.network(
        src,
        fit: widget.fit,
        headers: driveId != null ? _authHeaders : null,
        errorBuilder: (_, __, ___) => _placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}

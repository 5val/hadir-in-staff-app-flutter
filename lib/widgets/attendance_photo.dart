import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Foto absensi (selfie check-in/check-out) dari salah satu dari dua sumber.
///
/// Kenapa perlu dua sumber: tepat setelah absen, foto yang paling cepat dan
/// paling tajam adalah file hasil kamera yang masih ada di HP ([localPath]).
/// Tapi file itu hanya hidup selama sesi — begitu HP terkunci lalu staff
/// membuka app lagi lewat passcode, layar dibangun dari nol dan satu-satunya
/// yang tersisa adalah nilai kolom dari server ([remoteUrl]). Sebelum widget
/// ini ada, kartu detail kehadiran ikut hilang di titik itu.
///
/// [remoteUrl] bisa berbentuk tiga hal yang semuanya harus tetap jalan:
///   1. URL Google Drive — file PRIVAT, tidak bisa dipakai `Image.network`
///      langsung. Harus lewat proxy terautentikasi
///      `GET /api/mobile/files/:fileId` dengan token staff.
///   2. `/uploads/...` — fallback disk lokal server, disajikan
///      `express.static` tanpa auth, cukup diberi prefix origin backend.
///   3. URL absolut lain (mis. data contoh) — dipakai apa adanya.
class AttendancePhoto extends StatefulWidget {
  /// Path file kamera di HP untuk absen yang baru saja dilakukan. Null bila
  /// kartu ini dibangun ulang dari data server.
  final String? localPath;

  /// Nilai kolom `fotoMasuk`/`fotoKeluar` dari server (boleh kosong).
  final String remoteUrl;

  const AttendancePhoto({
    super.key,
    required this.localPath,
    required this.remoteUrl,
  });

  @override
  State<AttendancePhoto> createState() => _AttendancePhotoState();
}

class _AttendancePhotoState extends State<AttendancePhoto> {
  /// Header Authorization untuk foto yang harus lewat proxy. Null selama
  /// token belum terbaca dari secure storage.
  Map<String, String>? _authHeaders;

  @override
  void initState() {
    super.initState();
    if (_driveFileId(widget.remoteUrl) != null) _loadToken();
  }

  @override
  void didUpdateWidget(covariant AttendancePhoto old) {
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
        borderRadius: BorderRadius.circular(10),
        child: kIsWeb
            ? Image.network(local,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder)
            : Image.file(File(local),
                fit: BoxFit.cover,
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
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        src,
        fit: BoxFit.cover,
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

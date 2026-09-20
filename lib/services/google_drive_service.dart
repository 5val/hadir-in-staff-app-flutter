import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  // ─────────────────────────────────────────────────────────────────────────
  // FIX #1: clientId is ONLY needed on Web.
  //   • Android → uses google-services.json  (no clientId here)
  //   • iOS     → uses GoogleService-Info.plist + URL scheme in Info.plist
  //   • Web     → pass the WEB OAuth 2.0 client ID
  //
  // If you pass an Android/iOS client ID here on mobile you get
  // PlatformException(sign_in_failed) or a silent null from authenticatedClient().
  // ─────────────────────────────────────────────────────────────────────────
  static final _googleSignIn = GoogleSignIn(
    // clientId is only needed for Web.
    clientId: kIsWeb
        ? '299014718603-giq097m9iicuvropcuddnh2bspbtvgo0.apps.googleusercontent.com'
        : null,
    scopes: [drive.DriveApi.driveFileScope],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // uploadToDrive — throws a descriptive String on any failure
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> uploadToDrive(String filePath) async {
    // ── 1. Sign in ──────────────────────────────────────────────────────────
    GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
    googleUser ??= await _googleSignIn.signInSilently();
    googleUser ??= await _googleSignIn.signIn();

    if (googleUser == null) {
      throw 'Login Google dibatalkan oleh pengguna.';
    }

    // ── 2. Authenticated HTTP client ─────────────────────────────────────────
    //
    // FIX #2: authenticatedClient() returns null when the granted scopes don't
    // include driveFileScope (e.g. user tapped "Allow" only for profile/email).
    // We force a fresh auth request with the exact scope we need.
    //
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      // Disconnect and re-authenticate to force scope consent screen
      await _googleSignIn.disconnect();
      final freshUser = await _googleSignIn.signIn();
      if (freshUser == null) throw 'Izin Google Drive ditolak oleh pengguna.';
      final freshClient = await _googleSignIn.authenticatedClient();
      if (freshClient == null) {
        throw 'Gagal membuat HTTP Client terverifikasi.\n'
            'Pastikan izin "Google Drive" diberikan saat popup muncul.';
      }
      return _doUpload(freshClient, filePath);
    }

    return _doUpload(httpClient, filePath);
  }

  // ── Internal upload helper ──────────────────────────────────────────────
  static Future<void> _doUpload(
      http.Client httpClient, String filePath) async {
    final driveApi = drive.DriveApi(httpClient);

    // ── 3. Read bytes ───────────────────────────────────────────────────────
    // FIX #3: removed unused `io.File imageFile` variable.
    final List<int> bytes;

    if (kIsWeb) {
      // Web: filePath is a blob URL (blob:http://...)
      final response = await http.get(Uri.parse(filePath));
      if (response.statusCode != 200) {
        throw 'Gagal membaca file di browser (status ${response.statusCode}).';
      }
      bytes = response.bodyBytes;
    } else {
      // Mobile / Desktop
      final file = io.File(filePath);
      if (!await file.exists()) {
        throw 'File tidak ditemukan: $filePath';
      }
      bytes = await file.readAsBytes();
    }

    if (bytes.isEmpty) throw 'File kosong, tidak ada yang diupload.';

    // ── 4. Build metadata & upload ──────────────────────────────────────────
    //
    // FIX #4: drive.Media expects Stream<List<int>>.
    // Stream.value(bytes) produces Stream<List<int>> correctly because
    // bytes IS a List<int>.  But we add an explicit cast to be safe.
    //
    final driveFile = drive.File()
      ..name = 'Absen_${DateTime.now().millisecondsSinceEpoch}.jpg'
      ..mimeType = 'image/jpeg';

    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'image/jpeg',
    );

    await driveApi.files.create(driveFile, uploadMedia: media);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Slip gaji ke Google Drive PRIBADI staff (permintaan klien 2026-09-19).
  //
  // Server tidak bisa menaruh file di Drive tiap staff (butuh OAuth offline per
  // staff), jadi app-lah yang mengunggah, memakai akun Google staff sendiri
  // dan scope `drive.file` (hanya file yang dibuat app ini -- app tidak bisa
  // membaca isi Drive lainnya). Slip masuk ke folder "Hadir-In - Slip Gaji".
  // ─────────────────────────────────────────────────────────────────────────
  static const _slipFolderName = 'Hadir-In - Slip Gaji';
  static const _folderMime = 'application/vnd.google-apps.folder';

  /// Menyimpan PDF slip ke folder Drive staff.
  ///
  /// [interactive] = false hanya memakai sesi Google yang SUDAH ada
  /// (`signInSilently`) dan tidak pernah memunculkan dialog login -- dipakai
  /// penyimpanan otomatis di latar. Bila belum ada sesi, hasilnya
  /// [DriveSaveOutcome.needsSignIn]. [interactive] = true boleh meminta login
  /// dan izin (dipakai tombol "Simpan ke Google Drive").
  static Future<DriveSaveOutcome> saveSlipPdf({
    required String filename,
    required List<int> bytes,
    bool interactive = false,
  }) async {
    if (bytes.isEmpty) throw 'File slip kosong, tidak ada yang disimpan.';

    GoogleSignInAccount? user = _googleSignIn.currentUser;
    user ??= await _googleSignIn.signInSilently();
    if (user == null) {
      if (!interactive) return DriveSaveOutcome.needsSignIn;
      user = await _googleSignIn.signIn();
      if (user == null) throw 'Login Google dibatalkan oleh pengguna.';
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      if (!interactive) return DriveSaveOutcome.needsSignIn;
      throw 'Izin Google Drive belum diberikan. Coba lagi dan setujui izin akses.';
    }

    final api = drive.DriveApi(client);
    final folderId = await _findOrCreateFolder(api);

    // Sudah ada dengan nama yang sama di folder itu -> jangan dobel.
    final existing = await api.files.list(
      q: "name = '${filename.replaceAll("'", "\'")}' and '$folderId' in parents and trashed = false",
      $fields: 'files(id)',
      pageSize: 1,
    );
    if ((existing.files ?? const []).isNotEmpty) {
      return DriveSaveOutcome.alreadySaved;
    }

    final file = drive.File()
      ..name = filename
      ..parents = [folderId]
      ..mimeType = 'application/pdf';
    await api.files.create(
      file,
      uploadMedia: drive.Media(Stream<List<int>>.value(bytes), bytes.length,
          contentType: 'application/pdf'),
    );
    return DriveSaveOutcome.saved;
  }

  static Future<String> _findOrCreateFolder(drive.DriveApi api) async {
    final found = await api.files.list(
      q: "name = '$_slipFolderName' and mimeType = '$_folderMime' and trashed = false",
      $fields: 'files(id)',
      pageSize: 1,
    );
    final id = (found.files ?? const []).isEmpty ? null : found.files!.first.id;
    if (id != null) return id;

    final created = await api.files.create(
      drive.File()
        ..name = _slipFolderName
        ..mimeType = _folderMime,
    );
    return created.id!;
  }
}

/// Hasil [GoogleDriveService.saveSlipPdf].
enum DriveSaveOutcome {
  /// Berhasil diunggah.
  saved,

  /// Sudah ada di folder itu sebelumnya (tidak diunggah ulang).
  alreadySaved,

  /// Belum ada sesi Google dan penyimpanan tidak boleh meminta login
  /// (mode otomatis) -- staff perlu menekan tombol simpan sekali.
  needsSignIn,
}
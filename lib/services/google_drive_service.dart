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
}
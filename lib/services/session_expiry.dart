import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'session_service.dart';

/// Penanganan global "sesi berakhir" (HTTP 401 pada request ber-auth).
///
/// Dipanggil [ApiClient] sekali per kejadian: jalankan logout terpadu
/// ([SessionService.clearSession]) lalu arahkan ke layar login dengan pesan
/// singkat. Beberapa 401 bersamaan (banyak request in-flight dengan token yang
/// sama) hanya memicu satu logout.
class SessionExpiry {
  SessionExpiry._();

  static const message = 'Sesi Anda berakhir, silakan masuk lagi.';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Dapat diganti di test.
  static Future<void> Function() logout = SessionService.clearSession;
  static Future<String?> Function() readToken = SessionService.getToken;
  static void Function() navigateToLogin = _defaultNavigateToLogin;

  static bool _handling = false;

  static Future<void> handleUnauthorized() async {
    // Anti-rekursi/dedup: clearSession() memanggil FcmService.unregisterFromBackend
    // (ber-auth) yang bisa ikut 401 -> masuk lagi ke sini; abaikan.
    if (_handling) return;
    _handling = true;
    try {
      // Token sudah tidak ada = sudah logout (mis. 401 susulan dari request
      // lama yang masih in-flight) -> jangan logout/navigasi dua kali.
      final token = await readToken();
      if (token == null || token.isEmpty) return;

      try {
        await logout();
      } catch (_) {
        // Best-effort: kegagalan membersihkan tidak boleh menahan navigasi.
      }
      navigateToLogin();
    } finally {
      _handling = false;
    }
  }

  static void _defaultNavigateToLogin() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(destination: LoginDestination.landing),
      ),
      (r) => false,
    );
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(message)));
  }
}

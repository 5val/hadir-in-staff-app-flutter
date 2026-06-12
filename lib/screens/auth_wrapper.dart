import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'passcode_unlock_screen.dart';

/// Layar pertama — cek sesi login.
/// Sudah login & Sesi Aktif → MainScreen langsung.
/// Sudah login tapi Sesi Habis → PasscodeUnlockScreen.
/// Belum login → LoginScreen.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: SessionService.getAuthState(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        final authState = snap.data ?? {
          'isLoggedIn': false,
          'isSessionActive': false,
          'hasPasscode': false,
        };
        final isLoggedIn = authState['isLoggedIn'] ?? false;
        final isSessionActive = authState['isSessionActive'] ?? false;

        if (isLoggedIn) {
          if (isSessionActive) {
            return const MainScreen();
          } else {
            return const PasscodeUnlockScreen();
          }
        }
        return const LoginScreen(destination: LoginDestination.landing);
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2D377F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            SizedBox(height: 16),
            Text(
              'Hadir-In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
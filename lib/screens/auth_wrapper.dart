import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'landing_screen.dart';
import 'login_screen.dart';

/// Layar pertama yang dimuat — cek sesi login.
/// Jika sudah login sebelumnya → LandingScreen (seperti Instagram).
/// Jika belum → LoginScreen.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SessionService.isLoggedIn(),
      builder: (context, snap) {
        // Saat mengecek sesi, tampilkan splash sederhana
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        final hasSession = snap.data ?? false;
        if (hasSession) {
          return const LandingScreen();
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
    return Scaffold(
      backgroundColor: const Color(0xFF2D377F), // brandNavy
      body: const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }
}
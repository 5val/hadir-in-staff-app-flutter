import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'landing_screen.dart';
import 'leave_request_screen.dart';

/// Kemana user diarahkan setelah login berhasil.
enum LoginDestination {
  /// Login pertama kali — masuk ke LandingScreen
  landing,
  /// Re-verifikasi dari landing — masuk ke LeaveRequestScreen (Cuti & Izin)
  leaveRequest,
}

class LoginScreen extends StatefulWidget {
  final LoginDestination destination;

  const LoginScreen({
    super.key,
    this.destination = LoginDestination.landing,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _isLoading = false;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slide;
  late Animation<double>   _fade;

  // Apakah ini layar login awal (tidak bisa di-back)
  bool get _isInitialLogin => widget.destination == LoginDestination.landing;

  // Label subtitle berdasarkan tujuan
  String get _subtitle => _isInitialLogin
      ? 'Masuk ke akun karyawan Hadir-In'
      : 'Verifikasi ulang untuk melanjutkan pengajuan';

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // simulasi API call
    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (widget.destination) {
      case LoginDestination.landing:
        // Login awal → masuk ke LandingScreen, hapus stack
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingScreen()),
        );
        break;

      case LoginDestination.leaveRequest:
        // Re-verifikasi → masuk ke LeaveRequestScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LeaveRequestScreen(
              user: SampleData.currentUser,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      // Login awal: tidak ada back button (tidak bisa kembali)
      // Re-verifikasi: ada back button (bisa kembali ke landing)
      appBar: _isInitialLogin ? null : AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.slate700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(AppAssets.logoFull, height: 28, fit: BoxFit.contain),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: _isInitialLogin ? 40 : 32),

                    // ── Logo (hanya di login awal) ─────────
                    if (_isInitialLogin)
                      Center(
                        child: Image.asset(
                          AppAssets.logoFull,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),

                    SizedBox(height: _isInitialLogin ? 24 : 0),

                    // ── Mascot + greeting ──────────────────
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            _isInitialLogin ? AppAssets.mascotWave : AppAssets.mascot,
                            height: _isInitialLogin ? 130 : 80,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _isInitialLogin ? 'Selamat Datang! 👋' : 'Verifikasi Identitas 🔐',
                            style: AppText.headline2.copyWith(color: AppColors.brandNavy),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _subtitle,
                            style: AppText.body2,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Re-verifikasi banner ───────────────
                    if (!_isInitialLogin) ...[
                      SectionCard(
                        color: AppColors.brandCyan.withOpacity(0.07),
                        borderColor: AppColors.brandCyanDark.withOpacity(0.3),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                color: AppColors.brandCyanDark, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Untuk mengajukan cuti & izin, diperlukan verifikasi ulang demi keamanan data karyawan.',
                                style: AppText.body2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Username ───────────────────────────
                    Text('Username / ID Karyawan', style: AppText.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameCtrl,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: AppColors.slate900),
                      decoration: const InputDecoration(
                        hintText: 'Masukkan username atau ID karyawan',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Username wajib diisi' : null,
                    ),

                    const SizedBox(height: 16),

                    // ── Password ───────────────────────────
                    Text('Password', style: AppText.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: AppColors.slate900),
                      decoration: InputDecoration(
                        hintText: 'Masukkan password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.slate400,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                    ),

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Lupa password?',
                          style: GoogleFonts.inter(
                            color: AppColors.brandCyanDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Submit ─────────────────────────────
                    GradientButton(
                      label: _isLoading
                          ? 'Memverifikasi...'
                          : (_isInitialLogin ? 'Masuk' : 'Verifikasi & Lanjutkan'),
                      color: AppColors.brandNavy,
                      icon: _isInitialLogin
                          ? Icons.login_rounded
                          : Icons.verified_user_rounded,
                      isLoading: _isLoading,
                      onTap: _isLoading ? null : _login,
                    ),

                    const SizedBox(height: 16),

                    // ── Info ───────────────────────────────
                    SectionCard(
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.brandCyanDark, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Gunakan ID Karyawan dan password yang sama dengan sistem absensi Hadir-In.',
                              style: AppText.body2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
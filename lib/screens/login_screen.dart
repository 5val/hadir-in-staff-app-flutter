import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import 'landing_screen.dart';
import 'leave_choice_screen.dart';

enum LoginDestination { landing, leaveRequest }

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

  bool get _isInitialLogin => widget.destination == LoginDestination.landing;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
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
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (_isInitialLogin) {
      // Simpan sesi — tidak perlu login lagi sampai logout
      await SessionService.saveSession(
        username: _usernameCtrl.text.trim(),
        employeeId: SampleData.currentUser.employeeId,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingScreen()),
        (r) => false,
      );
    } else {
      // Re-verifikasi untuk Cuti & Izin — tampilkan pilihan
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LeaveChoiceScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: _isInitialLogin
          ? null
          : AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.slate700),
                onPressed: () => Navigator.pop(context),
              ),
              title: Image.asset(AppAssets.logoFull, height: 28),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.slate200),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: _isInitialLogin ? 48 : 32),

                    // Logo (initial login only)
                    if (_isInitialLogin) ...[
                      Center(child: Image.asset(AppAssets.logoFull, height: 44)),
                      const SizedBox(height: 32),
                    ],

                    // Mascot
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            _isInitialLogin ? AppAssets.mascotWave : AppAssets.mascot,
                            height: _isInitialLogin ? 120 : 72,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isInitialLogin ? 'Selamat Datang! 👋' : 'Verifikasi Identitas 🔐',
                            style: AppText.headline2.copyWith(color: AppColors.brandNavy),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isInitialLogin
                                ? 'Masuk ke akun karyawan Hadir-In'
                                : 'Masukkan kembali kredensial kamu',
                            style: AppText.body2,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Re-verify info banner
                    if (!_isInitialLogin) ...[
                      SectionCard(
                        color: AppColors.brandCyan.withOpacity(0.07),
                        borderColor: AppColors.brandCyanDark.withOpacity(0.3),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded,
                                color: AppColors.brandCyanDark, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Diperlukan verifikasi ulang untuk mengakses Cuti & Izin.',
                                style: AppText.body2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Username
                    Text('Username / ID Karyawan', style: AppText.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameCtrl,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: AppColors.slate900),
                      decoration: const InputDecoration(
                        hintText: 'Masukkan username atau ID',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Username wajib diisi' : null,
                    ),

                    const SizedBox(height: 16),

                    // Password
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
                            color: AppColors.slate400, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Password wajib diisi' : null,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Lupa password?',
                            style: GoogleFonts.inter(
                              color: AppColors.brandCyanDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                      ),
                    ),

                    GradientButton(
                      label: _isInitialLogin ? 'Masuk' : 'Verifikasi & Lanjutkan',
                      color: AppColors.brandNavy,
                      icon: _isInitialLogin
                          ? Icons.login_rounded
                          : Icons.verified_user_rounded,
                      isLoading: _isLoading,
                      height: 54,
                      onTap: _isLoading ? null : _login,
                    ),

                    const SizedBox(height: 16),

                    // Info card
                    SectionCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.brandCyanDark, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Gunakan ID Karyawan dan password sistem Hadir-In.',
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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'leave_request_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure    = true;
  bool _isLoading  = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slide;
  late Animation<double>  _fade;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
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
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LeaveRequestScreen(user: SampleData.currentUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Login', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
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
                  const SizedBox(height: 32),

                  // ── Header ──────────────────────────────
                  Text('Selamat Datang 👋', style: AppText.headline2),
                  const SizedBox(height: 6),
                  Text(
                    'Masuk untuk mengajukan cuti atau izin',
                    style: AppText.body2,
                  ),

                  const SizedBox(height: 36),

                  // ── Username ─────────────────────────────
                  Text('Username / ID Karyawan', style: AppText.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameCtrl,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Masukkan username',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Username wajib diisi' : null,
                  ),

                  const SizedBox(height: 18),

                  // ── Password ─────────────────────────────
                  Text('Password', style: AppText.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Masukkan password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
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
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  GradientButton(
                    label: 'Masuk',
                    icon: Icons.login_rounded,
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _login,
                  ),

                  const SizedBox(height: 20),

                  SectionCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.info, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gunakan ID Karyawan dan password yang sama dengan sistem absensi.',
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
    );
  }
}
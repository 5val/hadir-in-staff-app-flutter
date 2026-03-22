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
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _isLoading = false;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slide;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose(); _usernameCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => const LeaveRequestScreen(user: SampleData.currentUser),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
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

                  // Mascot + greeting
                  Center(
                    child: Column(
                      children: [
                        Image.asset(AppAssets.mascot, height: 90),
                        const SizedBox(height: 12),
                        Text('Selamat Datang 👋',
                            style: AppText.headline2
                                .copyWith(color: AppColors.brandNavy)),
                        const SizedBox(height: 4),
                        Text('Masuk untuk mengajukan cuti atau izin',
                            style: AppText.body2, textAlign: TextAlign.center),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text('Username / ID Karyawan', style: AppText.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameCtrl,
                    style: const TextStyle(color: AppColors.slate900),
                    decoration: const InputDecoration(
                      hintText: 'Masukkan username',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Username wajib diisi' : null,
                  ),

                  const SizedBox(height: 16),

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
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.slate400, size: 20,
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
                      child: Text('Lupa password?',
                          style: GoogleFonts.inter(
                            color: AppColors.brandCyanDark,
                            fontWeight: FontWeight.w600, fontSize: 13,
                          )),
                    ),
                  ),

                  const SizedBox(height: 24),

                  GradientButton(
                    label: 'Masuk',
                    color: AppColors.brandNavy,
                    icon: Icons.login_rounded,
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _login,
                  ),

                  const SizedBox(height: 16),

                  SectionCard(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.brandCyanDark, size: 18),
                        const SizedBox(width: 10),
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
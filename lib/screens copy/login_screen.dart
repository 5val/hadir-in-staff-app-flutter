import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool valid = true;
    String? emailErr;
    String? passErr;

    if (_emailController.text.trim().isEmpty) {
      emailErr = 'Email atau nama wajib diisi';
      valid = false;
    }
    if (_passwordController.text.trim().isEmpty) {
      passErr = 'Password wajib diisi';
      valid = false;
    } else if (_passwordController.text.length < 4) {
      passErr = 'Password minimal 4 karakter';
      valid = false;
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });
    return valid;
  }

  Future<void> _handleLogin() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go('/tabs');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFF1F5F9),
                  Color(0xFFE0F7FA),
                ],
              ),
            ),
          ),
          // Decorative circle top-right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrandColors.cyan.withOpacity(0.08),
              ),
            ),
          ),
          // Decorative circle bottom-left
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrandColors.navy.withOpacity(0.06),
              ),
            ),
          ),
          // Animated content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            _buildLogoSection(),
                            const SizedBox(height: 32),
                            _buildLoginCard(),
                            const SizedBox(height: 24),
                            const Text(
                              '© 2026 Hadir-In. Sistem Absensi Karyawan Modern.',
                              style: TextStyle(
                                  fontSize: 12, color: NeutralColors.slate500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BrandColors.navy, BrandColors.cyan],
            ),
            boxShadow: [
              BoxShadow(
                color: BrandColors.navy.withOpacity(0.3),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.fingerprint, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hadir-In',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: NeutralColors.slate900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Aplikasi Absensi Staff',
          style: TextStyle(fontSize: 14, color: NeutralColors.slate500),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 24,
          ),
        ],
        border:
            Border.all(color: NeutralColors.slate200.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Selamat Datang',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NeutralColors.slate900,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              text: 'Masuk ke akun ',
              style: TextStyle(fontSize: 14, color: NeutralColors.slate600),
              children: [
                TextSpan(
                  text: 'Hadir-In',
                  style: TextStyle(
                    color: BrandColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' Anda'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildTextField(
            label: 'Nama atau Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            placeholder: 'Masukkan nama atau email Anda',
            error: _emailError,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: 20),
          _buildPasswordField(),
          const SizedBox(height: 20),
          _buildLoginButton(),
          const SizedBox(height: 16),
          const Text(
            'Belum punya akun? Hubungi admin untuk pendaftaran',
            style: TextStyle(fontSize: 13, color: NeutralColors.slate500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildDemoBox(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    String? error,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NeutralColors.slate700)),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: hasError ? SemanticColors.errorBg : NeutralColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? SemanticColors.error : NeutralColors.slate300,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon,
                  size: 20,
                  color: hasError
                      ? SemanticColors.error
                      : NeutralColors.slate400),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  onChanged: onChanged,
                  style: const TextStyle(
                      fontSize: 16, color: NeutralColors.slate900),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: const TextStyle(
                        color: NeutralColors.slate400, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(error!,
              style: const TextStyle(
                  fontSize: 12, color: SemanticColors.error)),
        ],
      ],
    );
  }

  Widget _buildPasswordField() {
    final hasError = _passwordError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NeutralColors.slate700)),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: hasError ? SemanticColors.errorBg : NeutralColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? SemanticColors.error : NeutralColors.slate300,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.lock_outline,
                  size: 20,
                  color: hasError
                      ? SemanticColors.error
                      : NeutralColors.slate400),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  style: const TextStyle(
                      fontSize: 16, color: NeutralColors.slate900),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan password Anda',
                    hintStyle: TextStyle(
                        color: NeutralColors.slate400, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: NeutralColors.slate400,
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(_passwordError!,
              style: const TextStyle(
                  fontSize: 12, color: SemanticColors.error)),
        ],
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [BrandColors.navy, BrandColors.navyDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: BrandColors.navy.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Masuk',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }

  Widget _buildDemoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.cyan.withOpacity(0.08),
        border: Border.all(color: BrandColors.cyan.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: BrandColors.cyan),
              SizedBox(width: 6),
              Text('Demo Login',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.navy)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gunakan email dan password apapun untuk demo. Data akan direset saat aplikasi dimuat ulang.',
            style: TextStyle(
                fontSize: 12,
                color: NeutralColors.slate600,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

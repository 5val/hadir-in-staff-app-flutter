import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'main_screen.dart';
import 'login_screen.dart';

enum UnlockStep {
  enterPasscode,
  selectRecovery,
  verifyOtp,
  resetPasscode,
  confirmResetPasscode
}

class PasscodeUnlockScreen extends StatefulWidget {
  const PasscodeUnlockScreen({super.key});

  @override
  State<PasscodeUnlockScreen> createState() => _PasscodeUnlockScreenState();
}

class _PasscodeUnlockScreenState extends State<PasscodeUnlockScreen>
    with TickerProviderStateMixin {
  UnlockStep _currentStep = UnlockStep.enterPasscode;
  String _enteredCode = "";
  /// Nomor HP staff — dikirim bersama passcode ke server saat verifikasi.
  /// Fase 8: passcode itu sendiri TIDAK pernah lagi disimpan/dibaca di HP.
  String _phone = "";
  String _enteredOtp = "";
  String _newPasscode = "";
  String _confirmNewPasscode = "";

  // Sprint 2 OTP/auth overhaul: OTP pemulihan sekarang SELALU dikirim lewat
  // email (backend tidak lagi punya pilihan channel WA/Gmail) — email tujuan
  // dari respons `request-otp`, ditampilkan di subtitle.
  String _otpEmail = "";

  // Cooldown kirim ulang 60 detik (sama seperti langkah OTP login utama di
  // `login_screen.dart`) — server juga menegakkan ini sendiri (429 bila
  // dilanggar), ini cuma UX supaya tombol tidak langsung ditekan berkali-kali.
  int _resendSeconds = 0;
  Timer? _resendTimer;

  // Pesan permanen saat batas kirim ulang (maks 3x/30 menit) tercapai.
  String? _resendBlockedMessage;

  bool _isLoading = false;
  String _errorMessage = "";

  // Animations for error shake
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // Mascot animation
  late AnimationController _mascotCtrl;
  late Animation<double> _mascotBounce;

  // Custom Banner Notification state
  bool _showBannerNotif = false;
  String _bannerTitle = "";
  String _bannerMessage = "";
  Color _bannerColor = AppColors.brandNavy;
  IconData _bannerIcon = Icons.mail_outline_rounded;
  late AnimationController _bannerCtrl;
  late Animation<Offset> _bannerSlide;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 12), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 12, end: -12), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -12, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -8, end: 0), weight: 1),
    ]).animate(_shakeCtrl);

    _mascotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _mascotBounce = Tween<double>(begin: 0, end: -6)
        .animate(CurvedAnimation(parent: _mascotCtrl, curve: Curves.easeInOut));

    _bannerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutBack));

    _loadPhone();
  }

  /// Fase 8: layar ini tidak lagi memuat passcode ke memori app. Passcode
  /// tinggal terhash di server; yang dibutuhkan di sini hanya nomor HP staff
  /// untuk dikirim bersama passcode saat verifikasi.
  Future<void> _loadPhone() async {
    final phone = await SessionService.getSavedPhone();
    if (!mounted) return;
    setState(() => _phone = phone);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _mascotCtrl.dispose();
    _bannerCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _showNotification(
      String title, String message, Color color, IconData icon) {
    setState(() {
      _bannerTitle = title;
      _bannerMessage = message;
      _bannerColor = color;
      _bannerIcon = icon;
      _showBannerNotif = true;
    });
    _bannerCtrl.forward();

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _bannerCtrl.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showBannerNotif = false;
            });
          }
        });
      }
    });
  }

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = "";
    });

    if (_currentStep == UnlockStep.enterPasscode) {
      if (_enteredCode.length < 6) {
        setState(() {
          _enteredCode += val;
        });
      }

      if (_enteredCode.length == 6) {
        _verifyUnlockCode();
      }
    } else if (_currentStep == UnlockStep.verifyOtp) {
      if (_enteredOtp.length < 6) {
        setState(() {
          _enteredOtp += val;
        });
      }

      if (_enteredOtp.length == 6) {
        _verifyRecoveryOtp();
      }
    } else if (_currentStep == UnlockStep.resetPasscode) {
      if (_newPasscode.length < 6) {
        setState(() {
          _newPasscode += val;
        });
      }

      if (_newPasscode.length == 6) {
        setState(() {
          _currentStep = UnlockStep.confirmResetPasscode;
        });
      }
    } else if (_currentStep == UnlockStep.confirmResetPasscode) {
      if (_confirmNewPasscode.length < 6) {
        setState(() {
          _confirmNewPasscode += val;
        });
      }

      if (_confirmNewPasscode.length == 6) {
        _saveNewPasscode();
      }
    }
  }

  void _onBackspace() {
    setState(() {
      _errorMessage = "";
    });

    if (_currentStep == UnlockStep.enterPasscode && _enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      });
    } else if (_currentStep == UnlockStep.verifyOtp && _enteredOtp.isNotEmpty) {
      setState(() {
        _enteredOtp = _enteredOtp.substring(0, _enteredOtp.length - 1);
      });
    } else if (_currentStep == UnlockStep.resetPasscode &&
        _newPasscode.isNotEmpty) {
      setState(() {
        _newPasscode = _newPasscode.substring(0, _newPasscode.length - 1);
      });
    } else if (_currentStep == UnlockStep.confirmResetPasscode &&
        _confirmNewPasscode.isNotEmpty) {
      setState(() {
        _confirmNewPasscode =
            _confirmNewPasscode.substring(0, _confirmNewPasscode.length - 1);
      });
    }
  }

  /// Fase 8: verifikasi ke SERVER.
  ///
  /// Dua hal dihapus di sini:
  ///  - perbandingan lokal `_enteredCode == _savedPasscode` (yang berarti
  ///    passcode tersimpan apa adanya di HP), dan
  ///  - master backdoor `"123456"`, yang menerima siapa pun yang memegang
  ///    HP staff tanpa tahu passcode-nya sama sekali.
  ///
  /// Login ulang lewat passcode juga menyegarkan token staff, jadi sesi yang
  /// tokennya sudah kedaluwarsa ikut pulih saat membuka kunci.
  void _verifyUnlockCode() async {
    setState(() => _isLoading = true);

    try {
      await AuthService.loginWithPasscode(phone: _phone, passcode: _enteredCode);
      await SessionService.setSessionActive(true);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (r) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _shakeCtrl.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _enteredCode = "";
        _errorMessage = e.message;
      });
    }
  }

  /// Kirim (atau kirim ulang) OTP pemulihan ke email staff — endpoint OTP
  /// login yang sama dipakai lagi di sini.
  ///
  /// Fase 8: kode `654321` yang dulu di-hardcode di app — dan ditampilkan
  /// sendiri lewat notifikasi palsu — dihapus. Kodenya sekarang dibuat
  /// server dan dikirim asli; app tidak pernah mengetahuinya (kecuali
  /// `devCode` di lingkungan dev/staging).
  ///
  /// Sprint 2 OTP/auth overhaul: backend hanya punya SATU channel (email) —
  /// pilihan WA/Gmail yang dulu ada di sini sudah dihapus.
  void _sendRecoveryOtp() async {
    if (_resendSeconds > 0 || _resendBlockedMessage != null) return;
    setState(() {
      _isLoading = true;
      _enteredOtp = "";
      _errorMessage = "";
    });

    try {
      final result = await AuthService.requestOtp(_phone);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpEmail = result.email;
        _resendBlockedMessage = null;
        _currentStep = UnlockStep.verifyOtp;
      });
      _startResendTimer();

      _showNotification(
        "Email • Hadir-In Recovery",
        result.devCode != null && result.devCode!.isNotEmpty
            ? "[Hadir-In] Kode pemulihan Anda: ${result.devCode}. Jangan berikan kepada siapa pun."
            : "Kode pemulihan telah dikirim ke email Anda: ${result.email}.",
        AppColors.brandNavy,
        Icons.mail_outline_rounded,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.statusCode == 429) {
          // Batas kirim ulang (3x/30 menit) TERCAPAI, atau akun sedang
          // lockout salah-kode (blok request-otp juga) — tampilkan pesan
          // asli backend, jangan diam saja.
          _resendBlockedMessage = e.message;
        } else {
          _errorMessage = e.message;
        }
      });
    }
  }

  /// Verifikasi OTP pemulihan ke server. Bila benar, token staff baru
  /// tersimpan — itulah yang membuat penyimpanan passcode baru di langkah
  /// berikutnya bisa diotorisasi.
  void _verifyRecoveryOtp() async {
    setState(() => _isLoading = true);

    try {
      await AuthService.verifyOtp(phone: _phone, code: _enteredOtp);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _newPasscode = "";
        _confirmNewPasscode = "";
        _currentStep = UnlockStep.resetPasscode;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _shakeCtrl.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _enteredOtp = "";
        _errorMessage = e.message;
      });
    }
  }

  void _saveNewPasscode() async {
    if (_newPasscode != _confirmNewPasscode) {
      _shakeCtrl.forward(from: 0.0);
      setState(() {
        _confirmNewPasscode = "";
        _errorMessage = "Passcode tidak cocok! Silakan ulangi.";
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Passcode baru disimpan terhash di server (Staff.passcodeHash).
      // Token dari verifikasi OTP barusan yang mengotorisasi panggilan ini.
      await AuthService.setPasscode(passcode: _confirmNewPasscode);
      await SessionService.setSessionActive(true);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Passcode baru berhasil dibuat!"),
        backgroundColor: AppColors.brandNavy,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (r) => false,
    );
  }

  /// Keluar dari akun dari layar passcode.
  ///
  /// Jalan keluar untuk staff yang terjebak di layar ini — misalnya HP dipakai
  /// staff lain, atau nomor tersimpan bukan miliknya — supaya bisa login ulang
  /// dengan nomor berbeda tanpa harus menebak passcode/lewat alur OTP.
  /// Sama seperti logout di tab Akun: sesi lokal dibersihkan lalu kembali ke
  /// layar login (passcode tetap tersimpan terhash di server, jadi staff lama
  /// cukup pakai passcode lamanya saat login lagi).
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content:
            Text('Kamu perlu login ulang lain kali.', style: AppText.body2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _resendTimer?.cancel();
    await SessionService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(destination: LoginDestination.landing)),
      (r) => false,
    );
  }

  /// Konfirmasi sebelum mengirim OTP pemulihan.
  ///
  /// Sprint 2 OTP/auth overhaul: backend sekarang cuma punya satu channel
  /// (email) — pilihan WA/Gmail yang dulu ada di sini sudah dihapus karena
  /// tidak lagi mencerminkan cara kerja backend.
  void _showRecoveryOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Lupa Passcode?",
              style: AppText.headline3.copyWith(color: AppColors.slate900),
            ),
            const SizedBox(height: 4),
            Text(
              "Kami akan kirim kode OTP 6 digit ke email terdaftar Anda untuk membuat passcode baru.",
              style: AppText.body2,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    color: AppColors.brandNavy),
              ),
              title: Text("Kirim OTP ke Email", style: AppText.label),
              subtitle: Text("Kirim kode 6 digit ke email terdaftar Anda",
                  style: AppText.caption),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.slate400),
              onTap: () {
                Navigator.pop(ctx);
                _sendRecoveryOtp();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Keypad Number Button
  Widget _buildKeypadButton(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () => _onKeyPress(label),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.slate200, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.brandNavy,
          ),
        ),
      ),
    );
  }

  // Special Button (Backspace / Forgot)
  Widget _buildSpecialButton(Widget child, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(10),
        child: child,
      ),
    );
  }

  Widget _buildKeypad() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.25,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) {
          // Forgot button / Empty
          if (_currentStep == UnlockStep.enterPasscode) {
            return _buildSpecialButton(
              Text(
                "Lupa?",
                style: GoogleFonts.inter(
                  color: AppColors.brandCyanDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              _showRecoveryOptions,
            );
          } else {
            return const SizedBox.shrink();
          }
        }
        if (index == 10) {
          return _buildKeypadButton("0");
        }
        if (index == 11) {
          return _buildSpecialButton(
            const Icon(Icons.backspace_outlined,
                color: AppColors.slate600, size: 22),
            _onBackspace,
          );
        }
        return _buildKeypadButton("${index + 1}");
      },
    );
  }

  Widget _buildCodeDots(String val) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          bool active = i < val.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.brandNavy : Colors.transparent,
              border: Border.all(
                color: active ? AppColors.brandNavy : AppColors.slate300,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _getStepTitle();
    final subtitle = _getStepSubtitle();
    final displayCode = _getDisplayCode();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Baris atas: tombol kembali untuk sub-langkah pemulihan
                // (kiri) + tombol keluar akun (kanan). Tombol keluar sengaja
                // selalu tampil supaya staff yang lupa passcode DAN tidak bisa
                // akses email pemulihan tetap punya jalan keluar: logout lalu
                // login lagi dengan nomor lain.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      if (_currentStep != UnlockStep.enterPasscode)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: AppColors.slate600),
                          onPressed: () {
                            setState(() {
                              _errorMessage = "";
                              if (_currentStep == UnlockStep.verifyOtp) {
                                _currentStep = UnlockStep.enterPasscode;
                                _resendTimer?.cancel();
                                _resendSeconds = 0;
                                _resendBlockedMessage = null;
                              } else if (_currentStep ==
                                  UnlockStep.resetPasscode) {
                                _currentStep = UnlockStep.verifyOtp;
                              } else if (_currentStep ==
                                  UnlockStep.confirmResetPasscode) {
                                _currentStep = UnlockStep.resetPasscode;
                              }
                            });
                          },
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _logout,
                        icon: const Icon(Icons.logout_rounded,
                            size: 16, color: AppColors.danger),
                        label: Text(
                          "Keluar",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mascot & Logo
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _mascotBounce,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _mascotBounce.value),
                            child: child,
                          ),
                          child: Image.asset(AppAssets.mascot, height: 110),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: AppText.headline2
                              .copyWith(color: AppColors.brandNavy),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            subtitle,
                            style: AppText.body2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Dots
                        _buildCodeDots(displayCode),
                        const SizedBox(height: 16),

                        if (_isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else if (_errorMessage.isNotEmpty)
                          Text(
                            _errorMessage,
                            style: GoogleFonts.inter(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          )
                        else
                          const SizedBox(height: 20),

                        // Sprint 2: kirim ulang OTP pemulihan — cooldown 60
                        // detik lokal (server juga menegakkan sendiri), atau
                        // pesan permanen bila batas 3x/30 menit tercapai.
                        if (_currentStep == UnlockStep.verifyOtp) ...[
                          const SizedBox(height: 8),
                          if (_resendBlockedMessage != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 36),
                              child: Text(
                                _resendBlockedMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger,
                                ),
                              ),
                            )
                          else if (_resendSeconds > 0)
                            Text(
                              "Kirim ulang OTP ($_resendSeconds s)",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.slate600,
                              ),
                            )
                          else
                            TextButton(
                              onPressed: _isLoading ? null : _sendRecoveryOtp,
                              child: Text(
                                "Kirim Ulang OTP",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandCyanDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Keypad area
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: _buildKeypad(),
                ),
              ],
            ),
          ),

          // Custom Notification Banner
          if (_showBannerNotif)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SlideTransition(
                position: _bannerSlide,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _bannerColor.withOpacity(0.4), width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _bannerColor,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(_bannerIcon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _bannerTitle,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                  Text(
                                    "sekarang",
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _bannerMessage,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.slate700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case UnlockStep.enterPasscode:
        return "Masukkan Passcode";
      case UnlockStep.selectRecovery:
        return "Pilih Saluran OTP";
      case UnlockStep.verifyOtp:
        return "Verifikasi OTP Pemulihan";
      case UnlockStep.resetPasscode:
        return "Buat Passcode Baru";
      case UnlockStep.confirmResetPasscode:
        return "Konfirmasi Passcode Baru";
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case UnlockStep.enterPasscode:
        return "Masukkan 6 digit passcode Anda untuk melanjutkan";
      case UnlockStep.selectRecovery:
        return "Pilih bagaimana cara memulihkan passcode";
      case UnlockStep.verifyOtp:
        return _otpEmail.isEmpty
            ? "Masukkan 6 digit kode OTP pemulihan yang dikirimkan ke email Anda"
            : "Masukkan 6 digit kode OTP pemulihan yang dikirimkan ke email Anda: $_otpEmail";
      case UnlockStep.resetPasscode:
        return "Masukkan 6 digit passcode baru Anda";
      case UnlockStep.confirmResetPasscode:
        return "Masukkan kembali passcode baru Anda untuk konfirmasi";
    }
  }

  String _getDisplayCode() {
    switch (_currentStep) {
      case UnlockStep.enterPasscode:
        return _enteredCode;
      case UnlockStep.verifyOtp:
        return _enteredOtp;
      case UnlockStep.resetPasscode:
        return _newPasscode;
      case UnlockStep.confirmResetPasscode:
        return _confirmNewPasscode;
      default:
        return "";
    }
  }
}

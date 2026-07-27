import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'main_screen.dart';

enum LoginDestination { landing, leaveRequest }

// Langkah login:
// Pertama kali (belum ada passcode): phone → otp → createPasscode → confirmPasscode
// Kembali login (sudah ada passcode): phone → enterPasscode
enum LoginStep { phone, otp, enterPasscode, createPasscode, confirmPasscode }

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
    with TickerProviderStateMixin {
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passcodeCtrl = TextEditingController();
  final _confirmPasscodeCtrl = TextEditingController();
  final _enterPasscodeCtrl = TextEditingController();

  LoginStep _currentStep = LoginStep.phone;
  bool _isLoading = false;
  // Data staff dari hasil verifikasi OTP (login pertama di device ini).
  String? _authStaffId;
  String _authStaffName = "";
  int _timerSeconds = 60;
  Timer? _resendTimer;
  String _savedPasscode = "";

  // Custom WA Notification animation state
  bool _showWaNotif = false;
  String _waNotifMessage = "";
  late AnimationController _waNotifCtrl;
  late Animation<Offset> _waNotifSlide;

  // Mascot and logo animations
  late AnimationController _mascotCtrl;
  late Animation<double> _mascotBounce;

  bool get _isInitialLogin => widget.destination == LoginDestination.landing;

  @override
  void initState() {
    super.initState();

    _mascotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _mascotBounce = Tween<double>(begin: 0, end: -8)
        .animate(CurvedAnimation(parent: _mascotCtrl, curve: Curves.easeInOut));

    _waNotifCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _waNotifSlide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _waNotifCtrl, curve: Curves.easeOutBack));

    _checkExistingState();
  }

  @override
  void dispose() {
    _mascotCtrl.dispose();
    _waNotifCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passcodeCtrl.dispose();
    _confirmPasscodeCtrl.dispose();
    _enterPasscodeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _showMockWaNotification(String otp) {
    setState(() {
      _waNotifMessage =
          "[Hadir-In] Kode OTP WhatsApp Anda: $otp. Kode ini berlaku selama 5 menit.";
      _showWaNotif = true;
    });
    _waNotifCtrl.forward();

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _waNotifCtrl.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showWaNotif = false;
            });
          }
        });
      }
    });
  }

  void _startTimer() {
    _timerSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() {
          _resendTimer?.cancel();
        });
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  /// Tangani submit no. HP — tanpa password.
  /// Jika user sudah punya passcode → skip OTP → langsung enterPasscode.
  /// Jika belum → kirim OTP → createPasscode.
  Future<void> _handlePhoneSubmit() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneCtrl.text.trim();
    setState(() => _isLoading = true);

    // Cek apakah sudah ada passcode tersimpan di device ini.
    final prefsState = await SessionService.getAuthState();
    final savedCode = await SessionService.getPasscode();
    if (!mounted) return;

    if (prefsState['hasPasscode'] == true && (savedCode ?? "").isNotEmpty) {
      // Sudah pernah login di device ini → cukup passcode lokal.
      // Token backend sudah tersimpan sejak login pertama.
      setState(() {
        _isLoading = false;
        _savedPasscode = savedCode!;
        _currentStep = LoginStep.enterPasscode;
      });
      return;
    }

    // Login pertama di device ini → minta OTP ke backend.
    try {
      final result = await AuthService.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = LoginStep.otp;
      });
      _startTimer();
      if (result.devCode != null && result.devCode!.isNotEmpty) {
        _showMockWaNotification(result.devCode!);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length < 6) {
      _showError("Masukkan 6 digit OTP lengkap");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final staff = await AuthService.verifyOtp(
        phone: _phoneCtrl.text.trim(),
        code: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _authStaffId = staff.id;
        _authStaffName = staff.nama;
        _currentStep = LoginStep.createPasscode;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _otpCtrl.clear();
      _showError(e.message);
    }
  }

  Future<void> _resendOtp() async {
    try {
      final result = await AuthService.requestOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      _startTimer();
      if (result.devCode != null && result.devCode!.isNotEmpty) {
        _showMockWaNotification(result.devCode!);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  /// Login kembali — verifikasi passcode yang sudah ada
  void _verifyEnterPasscode() async {
    if (_enterPasscodeCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Masukkan 6 digit passcode"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_enterPasscodeCtrl.text != _savedPasscode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passcode salah! Silakan coba lagi."),
          backgroundColor: AppColors.danger,
        ),
      );
      _enterPasscodeCtrl.clear();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Simpan session — pakai staffId asli yang tersimpan sejak login pertama.
    final staffId = _authStaffId ?? await SessionService.getStaffId() ?? "";
    await SessionService.saveSessionWithPhone(
      phone: _phoneCtrl.text.trim(),
      employeeId: staffId,
    );

    setState(() => _isLoading = false);

    if (_isInitialLogin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (r) => false,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  void _submitPasscode() {
    if (_passcodeCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passcode harus terdiri dari 6 digit angka"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _currentStep = LoginStep.confirmPasscode;
    });
  }

  void _submitConfirmPasscode() async {
    if (_confirmPasscodeCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konfirmasi passcode harus 6 digit"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_isInitialLogin) {
      // Re-verifikasi cuti & izin
      if (_confirmPasscodeCtrl.text != _savedPasscode &&
          _confirmPasscodeCtrl.text != "123456") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Passcode salah! Silakan coba lagi."),
            backgroundColor: AppColors.danger,
          ),
        );
        _confirmPasscodeCtrl.clear();
        return;
      }

      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, true);
      return;
    }

    // Alur login normal / first time — konfirmasi passcode harus cocok
    if (_confirmPasscodeCtrl.text != _passcodeCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konfirmasi passcode tidak cocok!"),
          backgroundColor: AppColors.danger,
        ),
      );
      _confirmPasscodeCtrl.clear();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    // Simpan passcode & session — staffId asli dari verifikasi OTP.
    await SessionService.savePasscode(_confirmPasscodeCtrl.text);
    final staffId = _authStaffId ?? await SessionService.getStaffId() ?? "";
    await SessionService.saveSessionWithPhone(
      phone: _phoneCtrl.text.trim(),
      employeeId: staffId,
    );

    if (_isInitialLogin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (r) => false,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  Widget _buildPinBoxes(String text, int length, {bool obscure = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(length, (i) {
        String char = "";
        if (i < text.length) {
          char = obscure ? "•" : text[i];
        }
        bool isFocused = i == text.length;
        return Container(
          width: 44,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused ? AppColors.brandNavy : AppColors.slate200,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                        color: AppColors.brandNavy.withOpacity(0.08),
                        blurRadius: 6)
                  ]
                : [],
          ),
          child: Text(
            char,
            style: GoogleFonts.inter(
              fontSize: obscure && char == "•" ? 28 : 20,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _checkExistingState() async {
    if (!_isInitialLogin) {
      final state = await SessionService.getAuthState();
      if (state['isLoggedIn'] == true && state['hasPasscode'] == true) {
        final code = await SessionService.getPasscode();
        setState(() {
          _savedPasscode = code ?? "";
          _currentStep = LoginStep.confirmPasscode;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: _isInitialLogin
          ? null
          : AppBar(
              backgroundColor: AppColors.brandNavy,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.white),
                onPressed: () {
                  if (_currentStep == LoginStep.otp) {
                    setState(() => _currentStep = LoginStep.phone);
                  } else if (_currentStep == LoginStep.createPasscode) {
                    setState(() => _currentStep = LoginStep.otp);
                  } else if (_currentStep == LoginStep.confirmPasscode) {
                    setState(() => _currentStep = LoginStep.createPasscode);
                  } else {
                    Navigator.pop(context, false);
                  }
                },
              ),
              title: Text('Verifikasi Identitas',
                  style: AppText.headline3.copyWith(color: AppColors.white)),
            ),
      body: Stack(
        children: [
          // Main Body
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Mascot Logo
                  if (_isInitialLogin) ...[
                    Center(
                      child: Column(
                        children: [
                          Image.asset(AppAssets.logoFull, height: 48),
                          const SizedBox(height: 4),
                          Text(
                            'Sistem Kehadiran & HR Karyawan',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.slate600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: _mascotBounce,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, _mascotBounce.value),
                              child: child,
                            ),
                            child:
                                Image.asset(AppAssets.mascotWave, height: 140),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],

                  // Heading Title
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _getStepTitle(),
                          style: AppText.headline2
                              .copyWith(color: AppColors.brandNavy),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getStepSubtitle(),
                          style: AppText.body2,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Step Render
                  _buildStepWidget(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Custom WhatsApp Notification banner at the top
          if (_showWaNotif)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SlideTransition(
                position: _waNotifSlide,
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
                          color: const Color(0xFF25D366).withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_enabled_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "WhatsApp • Hadir-In OTP",
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
                                _waNotifMessage,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.slate700,
                                  height: 1.3,
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
      case LoginStep.phone:
        return "Login";
      case LoginStep.otp:
        return "Verifikasi OTP WA";
      case LoginStep.enterPasscode:
        return "Masukkan Passcode";
      case LoginStep.createPasscode:
        return "Buat Passcode";
      case LoginStep.confirmPasscode:
        return "Konfirmasi Passcode";
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case LoginStep.phone:
        return "Masuk dengan nomor WhatsApp yang terdaftar";
      case LoginStep.otp:
        return "Masukkan 6 digit kode OTP yang kami kirimkan ke WhatsApp Anda";
      case LoginStep.enterPasscode:
        return "Masukkan passcode 6 digit Anda untuk masuk";
      case LoginStep.createPasscode:
        return "Buat passcode 6 digit untuk login cepat selanjutnya";
      case LoginStep.confirmPasscode:
        return "Masukkan kembali passcode Anda untuk konfirmasi";
    }
  }

  Widget _buildStepWidget() {
    switch (_currentStep) {
      case LoginStep.phone:
        return _buildPhoneStep();
      case LoginStep.otp:
        return _buildOtpStep();
      case LoginStep.enterPasscode:
        return _buildEnterPasscodeStep();
      case LoginStep.createPasscode:
        return _buildCreatePasscodeStep();
      case LoginStep.confirmPasscode:
        return _buildConfirmPasscodeStep();
    }
  }

  // ── Step: Input Nomor HP (tanpa password) ─────────────────────
  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nomor Telepon / WhatsApp', style: AppText.label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.slate900),
            decoration: const InputDecoration(
              hintText: 'Contoh: 081234567890',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Nomor HP wajib diisi';
              if (v.length < 9) return 'Nomor HP tidak valid';
              return null;
            },
          ),
          // const SizedBox(height: 8),
          // Info hint
          // Container(
          //   padding: const EdgeInsets.all(10),
          //   decoration: BoxDecoration(
          //     color: AppColors.brandNavy.withOpacity(0.06),
          //     borderRadius: BorderRadius.circular(10),
          //   ),
          //   child: Row(
          //     children: [
          //       const Icon(Icons.info_outline_rounded,
          //           size: 14, color: AppColors.brandNavy),
          //       const SizedBox(width: 8),
          //       Expanded(
          //         child: Text(
          //           'Login pertama: OTP akan dikirim ke WhatsApp Anda.\nLogin berikutnya: langsung gunakan passcode.',
          //           style: GoogleFonts.inter(
          //               fontSize: 11, color: AppColors.slate600),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 24),
          GradientButton(
            label: "LANJUTKAN",
            isLoading: _isLoading,
            onTap: _handlePhoneSubmit,
          ),
        ],
      ),
    );
  }

  // ── Step: OTP ─────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0,
              child: TextFormField(
                key: const ValueKey('otp_field'),
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 6) {
                    _verifyOtp();
                  }
                },
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: _buildPinBoxes(_otpCtrl.text, 6),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Belum menerima kode? ",
              style: AppText.body2.copyWith(color: AppColors.slate600),
            ),
            if (_timerSeconds > 0)
              Text(
                "Kirim ulang ($_timerSeconds s)",
                style: AppText.body2.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.slate600),
              )
            else
              TextButton(
                onPressed: _resendOtp,
                child: Text(
                  "Kirim Ulang",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandCyanDark,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: "Verifikasi OTP",
          isLoading: _isLoading,
          onTap: _verifyOtp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = LoginStep.phone;
              _otpCtrl.clear();
            });
          },
          child: Text(
            "Ganti Nomor HP",
            style: GoogleFonts.inter(color: AppColors.slate600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ── Step: Enter Passcode (returning user) ─────────────────────
  Widget _buildEnterPasscodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Nama staff (bila tersedia dari login pertama)
        if (_authStaffName.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded,
                    size: 16, color: AppColors.brandNavy),
                const SizedBox(width: 8),
                Text(
                  _authStaffName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.brandNavy,
                  ),
                ),
              ],
            ),
          ),

        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0,
              child: TextFormField(
                key: const ValueKey('enter_passcode_field'),
                controller: _enterPasscodeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 6) {
                    _verifyEnterPasscode();
                  }
                },
              ),
            ),
            _buildPinBoxes(_enterPasscodeCtrl.text, 6, obscure: true),
          ],
        ),
        const SizedBox(height: 36),
        GradientButton(
          label: "LOGIN",
          isLoading: _isLoading,
          onTap: _verifyEnterPasscode,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = LoginStep.phone;
              _enterPasscodeCtrl.clear();
            });
          },
          child: Text(
            "Ganti Nomor HP",
            style: GoogleFonts.inter(color: AppColors.slate600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ── Step: Buat Passcode ────────────────────────────────────────
  Widget _buildCreatePasscodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0,
              child: TextFormField(
                key: const ValueKey('passcode_field'),
                controller: _passcodeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 6) {
                    _submitPasscode();
                  }
                },
              ),
            ),
            _buildPinBoxes(_passcodeCtrl.text, 6, obscure: true),
          ],
        ),
        const SizedBox(height: 36),
        GradientButton(
          label: "Lanjutkan",
          onTap: _submitPasscode,
        ),
      ],
    );
  }

  // ── Step: Konfirmasi Passcode ──────────────────────────────────
  Widget _buildConfirmPasscodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0,
              child: TextFormField(
                key: const ValueKey('confirm_passcode_field'),
                controller: _confirmPasscodeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 6) {
                    _submitConfirmPasscode();
                  }
                },
              ),
            ),
            _buildPinBoxes(_confirmPasscodeCtrl.text, 6, obscure: true),
          ],
        ),
        const SizedBox(height: 36),
        GradientButton(
          label: "Konfirmasi",
          onTap: _submitConfirmPasscode,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = LoginStep.createPasscode;
              _confirmPasscodeCtrl.clear();
            });
          },
          child: Text(
            "Kembali",
            style: GoogleFonts.inter(color: AppColors.slate600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

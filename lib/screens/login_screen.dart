import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/document_service.dart';
import 'main_screen.dart';
import 'onboarding_documents_screen.dart';

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

  // Sprint 2 OTP/auth overhaul: alamat email tujuan OTP terakhir (dari
  // respons `request-otp`), ditampilkan di subtitle langkah OTP.
  String _otpEmail = "";

  // Jalur "Lupa Passcode? Kirim OTP" — staff INI sudah punya passcode, tapi
  // lupa. Backend selalu membalas `hasPasscode: true` untuk mereka, yang
  // biasanya berarti "langsung masuk tanpa buat passcode baru". Jalur ini
  // butuh pengecualian: harus tetap diarahkan ke buat-passcode-baru supaya
  // staff benar-benar bisa mereset passcode yang lupa (Piece 3 backend).
  bool _isForgotPasscodeFlow = false;

  // Sprint 2: pesan saat batas kirim ulang OTP (maks 3x/30 menit) tercapai —
  // backend menolak dengan 429, tombol kirim ulang diblokir sampai layar OTP
  // ini dibuka ulang dari awal.
  String? _resendBlockedMessage;

  // Sprint 2: lockout verifikasi OTP salah 3x (429, 15 menit) — beda dari
  // 400 "kode salah, masih ada sisa percobaan" biasa.
  String? _otpLockoutMessage;
  int _otpLockoutSeconds = 0;
  Timer? _otpLockoutTimer;

  bool get _otpLocked => _otpLockoutSeconds > 0;

  // Custom OTP Notification animation state (dulu bertema WhatsApp — Sprint
  // 2 OTP/auth overhaul pindah pengiriman OTP ke email).
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
    _otpLockoutTimer?.cancel();
    super.dispose();
  }

  void _showMockWaNotification(String otp, {int expiresInMinutes = 10}) {
    setState(() {
      _waNotifMessage =
          "[Hadir-In] Kode OTP Email Anda: $otp. Kode ini berlaku selama $expiresInMinutes menit.";
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

  void _clearOtpLockout() {
    _otpLockoutTimer?.cancel();
    _otpLockoutMessage = null;
    _otpLockoutSeconds = 0;
  }

  /// Verifikasi OTP salah 3x → server mengunci 15 menit (429, beda dari 400
  /// "kode salah, masih ada sisa percobaan"). Sama juga saat lockout itu
  /// masih aktif dan staff mencoba minta/verifikasi OTP lagi. Backend tidak
  /// mengirim field terstruktur untuk sisa waktu — [AuthService.
  /// parseLockoutMinutes] coba mengekstraknya dari teks pesan; bila gagal,
  /// tetap pakai default 15 menit (durasi lockout yang didokumentasikan).
  void _startOtpLockout(String message) {
    final minutes = AuthService.parseLockoutMinutes(message) ?? 15;
    _otpLockoutTimer?.cancel();
    setState(() {
      _otpLockoutMessage = message;
      _otpLockoutSeconds = minutes * 60;
    });
    _otpLockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpLockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _otpLockoutSeconds = 0;
          _otpLockoutMessage = null;
        });
      } else {
        setState(() => _otpLockoutSeconds--);
      }
    });
  }

  String _formatLockoutCountdown(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Tangani submit no. HP — tanpa password.
  ///
  /// Fase 8: pertanyaan "sudah punya passcode atau belum" kini dijawab
  /// SERVER (`Staff.passcodeHash`), bukan SharedPreferences HP.
  ///
  /// Dulu jawabannya dibaca dari `SessionService.getPasscode()`, padahal
  /// `clearSession()` menghapus passcode itu setiap kali staff logout.
  /// Akibatnya staff lama yang logout selalu dianggap "belum pernah punya
  /// passcode" → dipaksa OTP + membuat passcode baru lagi. Dengan sumber
  /// kebenaran di database, logout / ganti HP / install ulang tidak lagi
  /// menghapus fakta bahwa staff itu sudah punya passcode.
  Future<void> _handlePhoneSubmit() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneCtrl.text.trim();
    setState(() => _isLoading = true);

    try {
      final status = await AuthService.passcodeStatus(phone);
      if (!mounted) return;

      if (status.lockedForMinutes > 0) {
        setState(() => _isLoading = false);
        _showError(
          'Akun terkunci sementara karena terlalu banyak percobaan. '
          'Coba lagi dalam ${status.lockedForMinutes} menit.',
        );
        return;
      }

      if (status.hasPasscode) {
        // Staff lama → langsung minta passcode, TANPA OTP.
        setState(() {
          _isLoading = false;
          _authStaffName = status.nama;
          _currentStep = LoginStep.enterPasscode;
        });
        return;
      }

      // Staff yang benar-benar baru → buktikan kepemilikan nomor lewat OTP.
      _isForgotPasscodeFlow = false;
      final result = await AuthService.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpEmail = result.email;
        _resendBlockedMessage = null;
        _currentStep = LoginStep.otp;
      });
      _clearOtpLockout();
      _startTimer();
      if (result.devCode != null && result.devCode!.isNotEmpty) {
        _showMockWaNotification(result.devCode!,
            expiresInMinutes: result.expiresInMinutes);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    }
  }

  /// Lanjutan setelah token didapat: tentukan layar berikutnya.
  ///
  /// Staff yang belum melengkapi dokumen onboarding (pas foto/KTP/BPJS/NPWP)
  /// diarahkan ke [OnboardingDocumentsScreen] dan belum bisa masuk app.
  /// Gerbangnya milik server (`GET /onboarding-status`) — app hanya menuruti.
  Future<void> _finishLogin(String staffId) async {
    await SessionService.saveSessionWithPhone(
      phone: _phoneCtrl.text.trim(),
      employeeId: staffId,
    );

    if (!mounted) return;

    if (!_isInitialLogin) {
      Navigator.pop(context, true);
      return;
    }

    bool onboardingDone = true;
    try {
      onboardingDone = (await DocumentService.onboardingStatus()).completed;
    } on ApiException {
      // Gagal memeriksa status onboarding bukan alasan untuk mengunci staff
      // di luar app — MainScreen akan memeriksanya lagi.
      onboardingDone = true;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => onboardingDone
            ? const MainScreen()
            : const OnboardingDocumentsScreen(),
      ),
      (r) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpLocked) return;
    if (_otpCtrl.text.length < 6) {
      _showError("Masukkan 6 digit OTP lengkap");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.verifyOtp(
        phone: _phoneCtrl.text.trim(),
        code: _otpCtrl.text.trim(),
      );
      if (!mounted) return;

      _authStaffId = result.staff.id;
      _authStaffName = result.staff.nama;

      // Staff yang sudah punya passcode (mis. login OTP karena lupa passcode)
      // biasanya tidak perlu membuat passcode baru — langsung masuk.
      // KECUALI ini jalur "Lupa Passcode? Kirim OTP" — staff itu memang
      // sudah punya passcode (makanya `hasPasscode: true`), tapi lupa,
      // sehingga harus tetap diarahkan buat passcode baru (Piece 3 backend:
      // token dari verify-otp yang masih segar boleh set-passcode tanpa
      // passcode lama).
      if (result.hasPasscode && !_isForgotPasscodeFlow) {
        await _finishLogin(result.staff.id);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _isLoading = false;
        _currentStep = LoginStep.createPasscode;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _otpCtrl.clear();
      if (e.statusCode == 429) {
        _startOtpLockout(e.message);
      } else {
        _showError(e.message);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendBlockedMessage != null || _otpLocked) return;
    try {
      final result = await AuthService.requestOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() => _otpEmail = result.email);
      _startTimer();
      if (result.devCode != null && result.devCode!.isNotEmpty) {
        _showMockWaNotification(result.devCode!,
            expiresInMinutes: result.expiresInMinutes);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        // Bisa berarti batas 3x kirim ulang / 30 menit TERCAPAI, atau akun
        // sedang lockout salah-kode (blok kedua endpoint). Tampilkan pesan
        // asli backend secara permanen di layar ini (bukan cuma snackbar
        // sekilas) supaya staff tahu kenapa tombol kirim ulang tidak bisa
        // dipakai lagi, alih-alih diam saja / gagal tanpa penjelasan.
        setState(() => _resendBlockedMessage = e.message);
      } else {
        _showError(e.message);
      }
    }
  }

  /// Login kembali — verifikasi passcode ke SERVER.
  ///
  /// Fase 8: passcode tidak lagi dibandingkan dengan string di HP
  /// (`_enterPasscodeCtrl.text != _savedPasscode`). Perbandingan lokal itu
  /// tidak hanya rapuh saat logout — ia juga berarti passcode tersimpan apa
  /// adanya di SharedPreferences. Sekarang yang dikirim adalah nomor +
  /// passcode, dan server membandingkannya dengan bcrypt hash sekaligus
  /// menerapkan penguncian setelah 5 percobaan gagal.
  void _verifyEnterPasscode() async {
    if (_enterPasscodeCtrl.text.length < 6) {
      _showError("Masukkan 6 digit passcode");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final staff = await AuthService.loginWithPasscode(
        phone: _phoneCtrl.text.trim(),
        passcode: _enterPasscodeCtrl.text.trim(),
      );
      if (!mounted) return;
      _authStaffId = staff.id;
      await _finishLogin(staff.id);
      if (mounted) setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _enterPasscodeCtrl.clear();
      _showError(e.message);
    }
  }

  /// Jalur "Lupa passcode" — kembali ke OTP untuk membuat passcode baru.
  ///
  /// Piece 3 (Sprint 2 OTP/auth overhaul): staff ini SUDAH punya passcode
  /// (makanya sedang di langkah `enterPasscode`), jadi `_verifyOtp()` perlu
  /// tahu untuk tidak langsung `_finishLogin` begitu OTP-nya benar — lewat
  /// [_isForgotPasscodeFlow] — supaya staff benar-benar sampai ke layar buat
  /// passcode baru alih-alih diam-diam login pakai passcode lama yang lupa.
  Future<void> _forgotPasscode() async {
    setState(() => _isLoading = true);
    try {
      _isForgotPasscodeFlow = true;
      final result = await AuthService.requestOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _enterPasscodeCtrl.clear();
        _otpEmail = result.email;
        _resendBlockedMessage = null;
        _currentStep = LoginStep.otp;
      });
      _clearOtpLockout();
      _startTimer();
      if (result.devCode != null && result.devCode!.isNotEmpty) {
        _showMockWaNotification(result.devCode!,
            expiresInMinutes: result.expiresInMinutes);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _isForgotPasscodeFlow = false;
      setState(() => _isLoading = false);
      _showError(e.message);
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
      // Re-verifikasi identitas sebelum aksi sensitif (mis. ajukan cuti).
      //
      // Fase 8: diverifikasi ke SERVER, bukan dibandingkan dengan passcode
      // di HP. Backdoor "123456" yang dulu selalu diterima di sini juga
      // dihapus — siapa pun yang memegang HP staff bisa memakainya untuk
      // lolos verifikasi.
      setState(() => _isLoading = true);
      try {
        await AuthService.loginWithPasscode(
          phone: await SessionService.getSavedPhone(),
          passcode: _confirmPasscodeCtrl.text.trim(),
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _confirmPasscodeCtrl.clear();
        _showError(e.message);
      }
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
    setState(() => _isLoading = true);

    try {
      // Fase 8: passcode disimpan TERHASH di server (Staff.passcodeHash),
      // bukan apa adanya di SharedPreferences. Inilah yang membuatnya
      // bertahan setelah logout / ganti HP.
      await AuthService.setPasscode(passcode: _confirmPasscodeCtrl.text.trim());
      if (!mounted) return;

      final staffId = _authStaffId ?? await SessionService.getStaffId() ?? "";
      await _finishLogin(staffId);
      if (mounted) setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
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

  /// Layar ini dipakai dua peran:
  ///  - login penuh (destination landing), dan
  ///  - re-verifikasi identitas sebelum aksi sensitif (destination
  ///    leaveRequest), yang langsung meminta passcode.
  ///
  /// Fase 8: nomor HP terakhir diisikan otomatis agar staff tidak perlu
  /// mengetiknya ulang tiap login.
  Future<void> _checkExistingState() async {
    final savedPhone = await SessionService.getSavedPhone();
    if (!mounted) return;

    if (savedPhone.isNotEmpty && _phoneCtrl.text.isEmpty) {
      _phoneCtrl.text = savedPhone;
    }

    if (!_isInitialLogin) {
      final state = await SessionService.getAuthState();
      if (!mounted) return;
      if (state['isLoggedIn'] == true) {
        setState(() => _currentStep = LoginStep.confirmPasscode);
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

          // Custom OTP notification banner at the top (email, sejak Sprint 2)
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
                          color: AppColors.brandNavy.withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.brandNavy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mail_outline_rounded,
                              color: Colors.white, size: 22),
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
                                    "Email • Hadir-In OTP",
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
        return "Verifikasi OTP Email";
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
        return _otpEmail.isEmpty
            ? "Masukkan 6 digit kode OTP yang kami kirimkan ke email Anda"
            : "Masukkan 6 digit kode OTP yang kami kirimkan ke email Anda: $_otpEmail";
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
                enabled: !_otpLocked,
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

        // Sprint 2: lockout verifikasi OTP salah 3x (429, 15 menit) —
        // ditampilkan menonjol (bukan snackbar sekilas) selama masih aktif.
        if (_otpLockoutMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _otpLockoutMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Sisa waktu: ${_formatLockoutCountdown(_otpLockoutSeconds)}",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        if (_otpLocked)
          const SizedBox.shrink()
        else if (_resendBlockedMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _resendBlockedMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          )
        else
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
          onTap: _otpLocked ? null : _verifyOtp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = LoginStep.phone;
              _isForgotPasscodeFlow = false;
              _otpCtrl.clear();
            });
            _clearOtpLockout();
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
        // Fase 8: jalur pemulihan. Karena passcode kini tersimpan terhash di
        // server, app tidak bisa (dan tidak boleh) "mengingatkan" passcode —
        // satu-satunya jalan adalah membuktikan ulang kepemilikan nomor
        // lewat OTP, lalu membuat passcode baru.
        TextButton(
          onPressed: _isLoading ? null : _forgotPasscode,
          child: Text(
            "Lupa Passcode? Kirim OTP",
            style: GoogleFonts.inter(
                color: AppColors.brandNavy,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
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
  String _savedPasscode = "";
  String _recoveryMethod = ""; // "WA" or "Gmail"
  String _recoveryOtp = "";
  String _enteredOtp = "";
  String _newPasscode = "";
  String _confirmNewPasscode = "";

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
  Color _bannerColor = const Color(0xFF25D366);
  IconData _bannerIcon = Icons.phone_enabled_rounded;
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

    _loadPasscode();
  }

  Future<void> _loadPasscode() async {
    final code = await SessionService.getPasscode();
    setState(() {
      _savedPasscode = code ?? "";
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _mascotCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
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

  void _verifyUnlockCode() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (_enteredCode == _savedPasscode ||
          _enteredCode == "123456" /* master backup */) {
        // Unlock session
        await SessionService.setSessionActive(true);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (r) => false,
          );
        }
      } else {
        // Shake animation and error
        _shakeCtrl.forward(from: 0.0);
        setState(() {
          _enteredCode = "";
          _errorMessage = "Passcode salah! Silakan coba lagi.";
        });
      }
    });
  }

  void _sendRecoveryOtp(String method) {
    setState(() {
      _isLoading = true;
      _recoveryMethod = method;
      _enteredOtp = "";
      _recoveryOtp = "654321"; // Simulated Recovery OTP
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = UnlockStep.verifyOtp;
      });

      if (method == "WA") {
        _showNotification(
          "WhatsApp • Hadir-In Recovery",
          "[Hadir-In] OTP Pemulihan Passcode Anda: 654321. Jangan berikan kode ini kepada siapapun.",
          const Color(0xFF25D366),
          Icons.phone_enabled_rounded,
        );
      } else {
        _showNotification(
          "Gmail • Hadir-In Security",
          "Kode verifikasi pemulihan passcode Hadir-In Anda adalah: 654321.",
          const Color(0xFFD44638),
          Icons.mail_outline_rounded,
        );
      }
    });
  }

  void _verifyRecoveryOtp() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (_enteredOtp == _recoveryOtp) {
        setState(() {
          _newPasscode = "";
          _confirmNewPasscode = "";
          _currentStep = UnlockStep.resetPasscode;
        });
      } else {
        _shakeCtrl.forward(from: 0.0);
        setState(() {
          _enteredOtp = "";
          _errorMessage = "Kode OTP salah! Coba lagi.";
        });
      }
    });
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
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Save
    await SessionService.savePasscode(_confirmNewPasscode);
    await SessionService.setSessionActive(true);

    // Show success dialog or notification
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
              "Pilih Metode Pemulihan",
              style: AppText.headline3.copyWith(color: AppColors.slate900),
            ),
            const SizedBox(height: 4),
            Text(
              "Pilih saluran pengiriman kode OTP untuk mereset passcode Anda",
              style: AppText.body2,
            ),
            const SizedBox(height: 20),

            // Opsi 1: WhatsApp
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_enabled_rounded,
                    color: Color(0xFF25D366)),
              ),
              title: Text("Kirim OTP via WhatsApp", style: AppText.label),
              subtitle: Text("Kirim kode 6 digit ke nomor WA terdaftar",
                  style: AppText.caption),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.slate400),
              onTap: () {
                Navigator.pop(ctx);
                _sendRecoveryOtp("WA");
              },
            ),
            const AppDivider(),

            // Opsi 2: Gmail
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD44638).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    color: Color(0xFFD44638)),
              ),
              title: Text("Kirim OTP via GMAIL", style: AppText.label),
              subtitle: Text("Kirim kode 6 digit ke alamat Email kantor Anda",
                  style: AppText.caption),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.slate400),
              onTap: () {
                Navigator.pop(ctx);
                _sendRecoveryOtp("Gmail");
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

                // Back Button for Recovery Sub-steps
                if (_currentStep != UnlockStep.enterPasscode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AppColors.slate600),
                        onPressed: () {
                          setState(() {
                            _errorMessage = "";
                            if (_currentStep == UnlockStep.verifyOtp) {
                              _currentStep = UnlockStep.enterPasscode;
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
        return "Masukkan 6 digit kode OTP pemulihan yang dikirimkan ke ${_recoveryMethod == "WA" ? "WhatsApp" : "Gmail"} Anda";
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

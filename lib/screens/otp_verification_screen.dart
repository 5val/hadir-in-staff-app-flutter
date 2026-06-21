import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'main_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String newPhone;
  final String newEmail;

  const OtpVerificationScreen({
    super.key,
    required this.newPhone,
    required this.newEmail,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpCtrl = TextEditingController();
  bool _isVerifying = false;
  bool _isError = false;

  void _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _isError = false;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    if (otp == '123456') {
      AppSession.updateEmail(widget.newEmail);
      AppSession.updatePhoneNumber(widget.newPhone);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifikasi berhasil! Profil diperbarui.'),
          backgroundColor: AppColors.brandLimeDark,
        ),
      );
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isError = true;
      });
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Widget _buildPinBoxes(String text, int length) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(length, (i) {
        String char = "";
        if (i < text.length) {
          char = text[i];
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const StaffAppBar(title: 'Verifikasi WhatsApp'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan Kode OTP',
                style: AppText.headline3.copyWith(color: AppColors.slate900),
              ),
              const SizedBox(height: 8),
              Text(
                'Kode OTP telah dikirimkan ke nomor WhatsApp Anda: ${widget.newPhone}.\n(Hint: ketik 123456)',
                style: AppText.body2,
              ),
              const SizedBox(height: 32),
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0,
                    child: TextFormField(
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
                  _buildPinBoxes(_otpCtrl.text, 6),
                ],
              ),
              if (_isError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Kode OTP salah',
                      style: GoogleFonts.inter(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Verifikasi',
                isLoading: _isVerifying,
                onTap: _verifyOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

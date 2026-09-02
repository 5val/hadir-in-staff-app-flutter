import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Layar verifikasi OTP 6 digit — bentuk yang sama dengan langkah OTP di
/// `login_screen.dart` (judul, subjudul, kotak PIN, hitung mundur kirim
/// ulang, tombol verifikasi), tapi berdiri sendiri sebagai halaman.
///
/// Dibuat karena penggantian nomor HP butuh langkah OTP yang persis sama
/// dengan yang staff temui saat pertama kali login. Sebelumnya alur itu
/// memakai bottom sheet kecil dengan `TextField` biasa, yang terasa seperti
/// mekanisme lain padahal secara konsep kejadiannya identik: membuktikan
/// identitas dengan kode yang dikirim ke email.
///
/// Sengaja TIDAK dibuat dengan cara mengangkat `LoginStep.otp` keluar dari
/// `login_screen.dart`: langkah di sana terjalin erat dengan state login
/// (lockout, alur lupa-passcode, langkah buat/konfirmasi passcode
/// sesudahnya), dan membongkarnya berisiko merusak jalur login yang sudah
/// jalan. Yang dibagikan di sini adalah TAMPILAN dan perilakunya; logikanya
/// tetap milik masing-masing pemanggil lewat [onVerify] dan [onResend].
class OtpVerificationScreen extends StatefulWidget {
  /// Judul di app bar. Mis. "Verifikasi Identitas".
  final String appBarTitle;

  /// Email tujuan OTP, ditampilkan di subjudul agar staff tahu harus
  /// memeriksa ke mana. Boleh kosong.
  final String email;

  /// Keterangan tambahan di bawah kotak PIN — dipakai memberi tahu
  /// konsekuensi dari aksi yang sedang diverifikasi. Boleh null.
  final String? footnote;

  /// Dipanggil dengan kode 6 digit. Lempar pesan error (String) atau
  /// exception ber-`message` untuk menampilkannya di layar. Selesai tanpa
  /// melempar = verifikasi berhasil.
  final Future<void> Function(String code) onVerify;

  /// Kirim ulang kode. Null = tombol kirim ulang tidak ditampilkan.
  final Future<void> Function()? onResend;

  const OtpVerificationScreen({
    super.key,
    required this.appBarTitle,
    required this.email,
    required this.onVerify,
    this.onResend,
    this.footnote,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();

  bool _isLoading = false;
  String? _error;

  /// Hitung mundur kirim ulang — 60 detik, sama dengan alur login (server
  /// juga menegakkannya sendiri, ini hanya supaya tombolnya tidak ditekan
  /// berkali-kali percuma).
  int _resendSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpCtrl.dispose();
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

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Masukkan 6 digit kode OTP');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.onVerify(code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _messageOf(e);
        // Kode salah -> kosongkan supaya staff langsung bisa mengetik ulang
        // tanpa menghapus 6 digit satu per satu.
        _otpCtrl.clear();
      });
    }
  }

  Future<void> _resend() async {
    final onResend = widget.onResend;
    if (onResend == null) return;
    setState(() => _error = null);
    try {
      await onResend();
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode OTP baru telah dikirim'),
          backgroundColor: AppColors.brandNavy,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageOf(e));
    }
  }

  /// Pesan yang layak dibaca staff dari apa pun yang dilempar pemanggil.
  static String _messageOf(Object e) {
    if (e is String) return e;
    try {
      final message = (e as dynamic).message;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Verifikasi gagal. Coba lagi.';
  }

  /// Kotak PIN — disalin dari `login_screen.dart#_buildPinBoxes` supaya
  /// bentuknya benar-benar sama di kedua alur.
  Widget _buildPinBoxes(String text, int length) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(length, (i) {
        final char = i < text.length ? text[i] : '';
        final isFocused = i == text.length;
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
    final subtitle = widget.email.isEmpty
        ? 'Masukkan 6 digit kode OTP yang kami kirimkan ke email Anda'
        : 'Masukkan 6 digit kode OTP yang kami kirimkan ke email Anda: ${widget.email}';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(widget.appBarTitle,
            style: AppText.headline3.copyWith(color: AppColors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Verifikasi OTP Email',
                      style:
                          AppText.headline2.copyWith(color: AppColors.brandNavy),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: AppText.body2, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Field asli disembunyikan di balik kotak PIN — pola yang sama
              // dengan layar login: keyboard tetap muncul dan autofill OTP
              // tetap bekerja, tapi yang terlihat adalah 6 kotak.
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      key: const ValueKey('otp_field'),
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      onChanged: (val) {
                        setState(() {});
                        if (val.length == 6) _verify();
                      },
                    ),
                  ),
                  _buildPinBoxes(_otpCtrl.text, 6),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              if (widget.onResend != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Belum menerima kode? ',
                        style: AppText.body2.copyWith(color: AppColors.slate600)),
                    if (_resendSeconds > 0)
                      Text(
                        'Kirim ulang ($_resendSeconds s)',
                        style: AppText.body2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate600),
                      )
                    else
                      TextButton(
                        onPressed: _resend,
                        child: Text(
                          'Kirim Ulang',
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
                label: 'Verifikasi OTP',
                isLoading: _isLoading,
                onTap: _verify,
              ),

              if (widget.footnote != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.warning.withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.footnote!,
                            style: AppText.caption.copyWith(
                                color: AppColors.slate700, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

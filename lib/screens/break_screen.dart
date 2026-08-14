import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/attendance_provider.dart';

class BreakScreen extends StatefulWidget {
  final VoidCallback onBreakEnd;
  const BreakScreen({super.key, required this.onBreakEnd});
  @override
  State<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends State<BreakScreen> with TickerProviderStateMixin {
  // Fallback dipakai HANYA bila Shift staff tidak punya jam istirahat
  // terkonfigurasi (`AttendanceRules.secondsUntilBreakEnd` == null) — di
  // kasus itu tidak ada jam TETAP yang bisa dituju, jadi kembali ke durasi
  // lama (60 menit sejak layar ini dibuka).
  static const int _fallbackTotalSec = 60 * 60;
  static const int _alertSec = 5  * 60;

  /// Target countdown: jam SELESAI TETAP shift (`jamIstirahatSelesai`),
  /// terlepas dari jam berapa staff menekan "Mulai Istirahat". Null bila
  /// Shift tidak punya jam istirahat terkonfigurasi.
  final DateTime? _target = AttendanceRules.breakEndTargetToday;

  /// Denominator progress ring saja (persentase) — bukan batas keras.
  /// Countdown TETAP boleh lanjut ke negatif (overtime) setelah ini habis.
  late int _totalSec;

  /// Detik tersisa. BOLEH negatif — itu artinya staff sudah melewati jam
  /// selesai istirahat (overtime), bukan kondisi error.
  late int _secondsRemaining;

  Timer? _timer;
  bool   _alertShown = false;
  bool   _overtimeNoticeShown = false;
  bool   _showMascot = false;
  int    _msgIndex   = 0;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _msgIndex  = DateTime.now().second % SampleData.breakMessages.length;

    final initialRemaining = AttendanceRules.secondsUntilBreakEnd;
    if (initialRemaining != null) {
      _secondsRemaining = initialRemaining;
      // Kalau staff baru menekan "Mulai Istirahat" SETELAH jam selesai
      // shift sudah lewat, ring tidak boleh dibagi angka <= 0 — pakai 1
      // detik sebagai denominator supaya ring langsung tampil penuh/merah,
      // bukan crash atau NaN.
      _totalSec = initialRemaining > 0 ? initialRemaining : 1;
    } else {
      _secondsRemaining = _fallbackTotalSec;
      _totalSec = _fallbackTotalSec;
    }

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse     = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        // Target TETAP: hitung ulang dari jam sekarang tiap detik (bukan
        // sekadar `--`) supaya selalu akurat ke jam istirahat selesai yang
        // sebenarnya, termasuk saat app di-resume dari background.
        final live = AttendanceRules.secondsUntilBreakEnd;
        _secondsRemaining = live ?? (_secondsRemaining - 1);
      });
      if (_secondsRemaining <= _alertSec && _secondsRemaining > 0 && !_alertShown) {
        _alertShown = true; _triggerAlert();
      }
      if (_secondsRemaining <= 0 && !_overtimeNoticeShown) {
        _overtimeNoticeShown = true;
        _onReachedZero();
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); _pulseCtrl.dispose(); super.dispose(); }

  void _triggerAlert() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 600), HapticFeedback.heavyImpact);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Text('⏰', style: TextStyle(fontSize: 38)),
        title: Text('5 Menit Lagi!',
            style: TextStyle(color: AppColors.warning), textAlign: TextAlign.center),
        content: Text('Waktu istirahatmu hampir habis.\nSiapkan diri untuk kembali bekerja.',
            style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning,
                foregroundColor: AppColors.brandNavyDark),
            onPressed: () => Navigator.pop(context),
            child: const Text('Siap!'),
          ),
        ],
      ),
    );
  }

  /// Dipanggil SEKALI saat countdown pertama kali menyentuh 0 — hanya
  /// menampilkan notifikasi ramah (haptic + mascot), TIDAK mengunci layar
  /// dan TIDAK menghentikan timer. Setelah ini countdown lanjut ke negatif
  /// (overtime); tombol "Akhiri Istirahat" tetap bisa ditekan kapan pun,
  /// sebelum maupun sesudah titik ini.
  void _onReachedZero() {
    HapticFeedback.mediumImpact();
    setState(() => _showMascot = true);
  }

  /// Tombol akhiri istirahat. Selama masih ada sisa waktu, konfirmasi dulu
  /// (staff mungkin belum sadar masih ada sisa). Begitu sudah 0/overtime,
  /// tidak perlu dialog "yakin kembali lebih awal?" — langsung selesaikan.
  void _handleEndBreakTap() {
    if (_secondsRemaining > 0) {
      _endEarly();
    } else {
      _finish();
    }
  }

  void _endEarly() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Akhiri Istirahat?'),
        content: Text(
          'Kamu masih memiliki ${_fmtTime(_secondsRemaining)} waktu istirahat. Yakin kembali bekerja?',
          style: AppText.body2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _finish(); },
            child: const Text('Ya, Kembali'),
          ),
        ],
      ),
    );
  }

  void _finish() {
    _timer?.cancel();
    widget.onBreakEnd();
    Navigator.pop(context);
  }

  /// `s` boleh negatif (overtime) — pemanggil yang menambahkan tanda "+".
  String _fmtTime(int s) {
    final abs = s.abs();
    return '${(abs ~/ 60).toString().padLeft(2,'0')}:${(abs % 60).toString().padLeft(2,'0')}';
  }

  String _fmtClock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Label countdown yang tampil di tengah ring: "MM:SS" kalau masih ada
  /// sisa, "+MM:SS" kalau sudah overtime (lewat jam selesai istirahat).
  String get _remainingLabel =>
      _secondsRemaining >= 0 ? _fmtTime(_secondsRemaining) : '+${_fmtTime(_secondsRemaining)}';

  bool get _isOvertime => _secondsRemaining < 0;

  String get _totalLabel => _target != null
      ? 'Istirahat sampai ${_fmtClock(_target!)}'
      : 'Istirahat total: 60 menit';

  double get _pct   => (_secondsRemaining / _totalSec).clamp(0.0, 1.0);
  Color  get _color {
    if (_secondsRemaining <= _alertSec)     return AppColors.danger;
    if (_secondsRemaining <= _alertSec * 2) return AppColors.warning;
    return AppColors.brandNavy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Image.asset(AppAssets.logoIcon, height: 24),
            // const SizedBox(width: 8),
            Text('Waktu Istirahat', style: AppText.headline3.copyWith(color: AppColors.white)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),

                // Mascot + message
                Image.asset(AppAssets.mascot, height: 80),
                const SizedBox(height: 10),
                Text(SampleData.breakMessages[_msgIndex],
                    style: AppText.headline3.copyWith(color: AppColors.brandNavy),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(_totalLabel, style: AppText.body2),

                const SizedBox(height: 36),

                // Circular timer
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                    scale: _pulse.value, child: child,
                  ),
                  child: SizedBox(
                    width: 200, height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 200, height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white,
                            border: Border.all(color: AppColors.slate200),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandNavy.withOpacity(0.08),
                                blurRadius: 16, offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 180, height: 180,
                          child: CircularProgressIndicator(
                            value: _pct, strokeWidth: 8,
                            backgroundColor: AppColors.slate100,
                            valueColor: AlwaysStoppedAnimation<Color>(_color),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_isOvertime ? '⏰' : '☕',
                                style: const TextStyle(fontSize: 30)),
                            const SizedBox(height: 4),
                            Text(
                              _remainingLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 28,
                                fontWeight: FontWeight.w800, color: _color,
                              ),
                            ),
                            Text(_isOvertime ? 'lewat waktu' : 'tersisa',
                                style: AppText.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Alert banner — sebelum 0: peringatan "hampir habis"; setelah
                // 0: penanda overtime (tanpa memblokir apa pun, cuma info).
                if (_secondsRemaining <= _alertSec)
                  SectionCard(
                    color: AppColors.danger.withOpacity(0.05),
                    borderColor: AppColors.danger.withOpacity(0.3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.danger, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isOvertime
                                ? 'Waktu istirahat sudah lewat ${_fmtTime(_secondsRemaining)} — jangan lupa kembali bekerja.'
                                : 'Waktu istirahat hampir habis!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: AppColors.danger, fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Tombol akhiri istirahat SELALU aktif — tidak pernah
                // dikunci oleh countdown, baik sebelum maupun sesudah 0.
                GradientButton(
                  label: _isOvertime
                      ? '✅  Kembali Bekerja Sekarang'
                      : 'Akhiri Istirahat Sekarang',
                  color: _isOvertime ? AppColors.brandLimeDark : AppColors.brandNavy,
                  height: _isOvertime ? 54 : 50,
                  onTap: _handleEndBreakTap,
                ),

                const SizedBox(height: 14),

                SectionCard(
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Gunakan waktu ini untuk minum air putih, peregangan, atau tarik napas dalam 😊',
                          style: AppText.body2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Mascot overlay when break ends
          if (_showMascot)
            Positioned.fill(
              child: MascotOverlay(
                wave: true,
                message: 'Istirahat Selesai! 🎉\nSemangat balik kerja!',
                onDismiss: () => setState(() => _showMascot = false),
              ),
            ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class BreakScreen extends StatefulWidget {
  final VoidCallback onBreakEnd;
  const BreakScreen({super.key, required this.onBreakEnd});

  @override
  State<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends State<BreakScreen> with TickerProviderStateMixin {
  static const int _totalSec     = 60 * 60;
  static const int _alertSec     = 5  * 60;

  int  _secondsRemaining = _totalSec;
  Timer? _timer;
  bool _alertShown = false;
  bool _breakDone  = false;
  int  _msgIndex   = 0;

  late AnimationController _pulseCtrl;
  late AnimationController _doneCtrl;
  late Animation<double>   _pulse;
  late Animation<double>   _doneFade;
  late Animation<double>   _doneScale;

  @override
  void initState() {
    super.initState();
    _msgIndex = DateTime.now().second % SampleData.breakMessages.length;

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _doneCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );

    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _doneFade  = CurvedAnimation(parent: _doneCtrl, curve: Curves.easeIn);
    _doneScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _doneCtrl, curve: Curves.elasticOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining <= 0) {
        t.cancel();
        _onFinished();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining == _alertSec && !_alertShown) {
        _alertShown = true;
        _triggerAlert();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _doneCtrl.dispose();
    super.dispose();
  }

  void _triggerAlert() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 600), HapticFeedback.heavyImpact);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Text('⏰', style: TextStyle(fontSize: 40)),
        title: Text('5 Menit Lagi!',
            style: TextStyle(color: AppColors.warning),
            textAlign: TextAlign.center),
        content: Text(
          'Waktu istirahatmu hampir habis.\nSiapkan diri untuk kembali bekerja.',
          style: AppText.body2, textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(context),
            child: const Text('Siap!'),
          ),
        ],
      ),
    );
  }

  void _onFinished() {
    setState(() => _breakDone = true);
    _doneCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  void _endEarly() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Akhiri Istirahat?'),
        content: Text(
          'Kamu masih memiliki ${_fmtTime(_secondsRemaining)} waktu istirahat. Yakin ingin kembali bekerja?',
          style: AppText.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finish();
            },
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

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  double get _pct => _secondsRemaining / _totalSec;

  Color get _color {
    if (_secondsRemaining <= _alertSec)     return AppColors.danger;
    if (_secondsRemaining <= _alertSec * 2) return AppColors.warning;
    return AppColors.primary;
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
        title: Text('Waktu Istirahat', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),

            // Message
            Text(
              SampleData.breakMessages[_msgIndex],
              style: AppText.headline3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('Istirahat total: 60 menit', style: AppText.body2),

            const SizedBox(height: 44),

            // ── Circular timer ──────────────────────────────
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _breakDone ? 1.0 : _pulse.value,
                child: child,
              ),
              child: SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: CircularProgressIndicator(
                        value: _pct,
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(_color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _breakDone ? '✅' : '☕',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _breakDone ? 'SELESAI!' : _fmtTime(_secondsRemaining),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: _breakDone ? 20 : 30,
                            fontWeight: FontWeight.w800,
                            color: _color,
                          ),
                        ),
                        if (!_breakDone)
                          Text('tersisa', style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Alert banner
            if (!_breakDone && _secondsRemaining <= _alertSec)
              SectionCard(
                borderColor: AppColors.danger.withOpacity(0.4),
                color: AppColors.danger.withOpacity(0.08),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_rounded,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 6),
                    Text('Waktu istirahat hampir habis!',
                        style: GoogleFonts.inter(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),

            const Spacer(),

            // Buttons
            if (_breakDone)
              GradientButton(
                label: '✅  Kembali Bekerja (IN)',
                color: AppColors.success,
                height: 56,
                onTap: _finish,
              )
            else
              GradientButton(
                label: 'Akhiri Istirahat Sekarang',
                color: AppColors.primary,
                height: 52,
                onTap: _endEarly,
              ),

            const SizedBox(height: 14),

            SectionCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tips: Gunakan waktu ini untuk minum air putih, peregangan, atau tarik napas dalam 😊',
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
    );
  }
}
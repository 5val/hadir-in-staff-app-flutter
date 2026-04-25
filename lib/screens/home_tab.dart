import 'dart:async';
import 'package:hadirin_staff_app/screens/account_tab.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import 'break_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import 'checkin_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToAccount;
  const HomeTab({super.key, required this.onNavigateToAccount});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final user = SampleData.currentUser;

  AttendanceState _state       = AttendanceState.notCheckedIn;
  DateTime        _now         = DateTime.now();
  DateTime?       _checkInTime;
  DateTime?       _breakStartTime;
  Duration        _workDur     = Duration.zero;
  Duration        _breakDur    = Duration.zero;
  bool            _showMascot  = false;
  String          _mascotMsg   = '';
  // bool get _isWorkDay => _now.weekday >= 1 && _now.weekday <= 5;
  bool get _isWorkDay => true;

  static const int _checkoutCutoffHour = 12; // 12:00 siang
  bool get _pastCutoff => _now.hour >= _checkoutCutoffHour;
  String get _autoCheckType => _pastCutoff ? 'checkout' : 'checkin';

  // Location state
  bool _locationChecked = false;
  bool _locationOn      = false;
  bool _fakeLocation    = false;
  bool _checkingLoc     = false;

  Timer? _clockTimer, _workTimer;

  static const _officeName    = 'Kantor Pusat Hadir-In';
  static const _officeAddress = 'Jl. Sudirman No. 1, Jakarta Pusat';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == AttendanceState.checkedIn && _checkInTime != null) {
        setState(() => _workDur = _now.difference(_checkInTime!));
      }
      if (_state == AttendanceState.onBreak && _breakStartTime != null) {
        setState(() => _breakDur = _now.difference(_breakStartTime!));
      }
    });
    // Auto check location on init
    Future.delayed(const Duration(milliseconds: 800), _checkLocation);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _workTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────
  String _fmtDur(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:'
      '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _fmtHM(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String get _ampm => _now.hour < 12 ? 'AM' : 'PM';

  bool get _isCheckedIn =>
      _state == AttendanceState.checkedIn ||
      _state == AttendanceState.onBreak ||
      _state == AttendanceState.breakEnded ||
      _state == AttendanceState.checkedOut;

  bool get _canCheckout {
    if (_state != AttendanceState.checkedIn) return false;
    final shiftEnd = DateTime(
      _now.year, _now.month, _now.day,
      user.currentShift.endTime.hour, user.currentShift.endTime.minute,
    );
    return _now.isAfter(shiftEnd.subtract(
        Duration(minutes: user.position.earlyCheckoutToleranceMinutes)));
  }

  // ── Contextual greeting ───────────────────────────────────
  String get _greetingMsg {
    final h = _now.hour;
    if (_state == AttendanceState.checkedOut) {
      return 'Kerja hari ini selesai. Sampai besok! 🌙';
    }
    if (_state == AttendanceState.checkedIn || _state == AttendanceState.breakEnded) {
      return 'Kamu sudah check-in. Semangat terus! 💪';
    }
    if (_state == AttendanceState.onBreak) {
      return 'Selamat beristirahat! Kembali segar ya ☕';
    }
    // Not checked in yet
    if(_autoCheckType == 'checkout') {
      return 'Kamu belum check-out hari ini. Jangan lupa check-out sebelum pulang ya! 🕐';
    }
    final shiftStartH = user.currentShift.startTime.hour;
    final shiftStartM = user.currentShift.startTime.minute;
    final shiftStart = DateTime(_now.year, _now.month, _now.day, shiftStartH, shiftStartM);
    if (_now.isAfter(shiftStart.add(const Duration(minutes: 15)))) {
      return 'Kamu sudah terlambat! Segera check-in sekarang 🏃';
    }
    if (h < 9) return 'Selamat pagi! Sudah siap memulai hari? 🌅';
    if (h < 12) return 'Selamat pagi! Waktunya check-in sekarang ⏰';
    if (h < 15) return 'Selamat siang! Jangan lupa check-in ya 🌤️';
    return 'Selamat sore! Segera check-in sebelum terlambat 🕐';
  }

  // ── Location check (simulated) ────────────────────────────
  Future<void> _checkLocation() async {
    setState(() => _checkingLoc = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _checkingLoc    = false;
      _locationChecked = true;
      _locationOn     = true;   // simulate GPS on
      _fakeLocation   = false;  // simulate no fake GPS
    });
  }

  // ── Actions ───────────────────────────────────────────────
  void _doCheckin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckinScreen()),
    ).then((_) {
      setState(() {
        _state       = AttendanceState.checkedIn;
        _checkInTime = DateTime.now();
      });
    });
  }

  void _checkout() {
    setState(() {
      _state      = AttendanceState.checkedOut;
      _showMascot = true;
      _mascotMsg  = 'Kerja hari ini selesai!\nGood job! 🎉';
    });
  }

  void _startBreak() {
    setState(() {
      _state          = AttendanceState.onBreak;
      _breakStartTime = DateTime.now();
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreakScreen(
          onBreakEnd: () => setState(() {
            _state = AttendanceState.breakEnded;
          }),
        ),
      ),
    );
  }

  void _returnFromBreak() {
    setState(() {
      _state      = AttendanceState.checkedIn;
      _showMascot = true;
      _mascotMsg  = 'Selamat bekerja kembali! 💪\nLanjut produktif!';
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: Text('Kamu perlu login ulang lain kali.', style: AppText.body2),
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
    await SessionService.clearSession();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(destination: LoginDestination.landing),
      ),
      (r) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.slate50,
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderInfo(),
                        const SizedBox(height: 12),
                        _buildLocationStatus(),
                        const SizedBox(height: 16),
                        if (_state == AttendanceState.checkedIn ||
                            _state == AttendanceState.onBreak ||
                            _state == AttendanceState.breakEnded) ...[
                          _buildCurrentActivityCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildAttendanceSection(),
                        const SizedBox(height: 18),
                        if(_isWorkDay)
                          _buildTimeline(),
                        const SizedBox(height: 18),
                        _buildAttendanceHistory(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showMascot)
          Positioned.fill(
            child: MascotOverlay(
              wave: true,
              message: _mascotMsg,
              onDismiss: () => setState(() => _showMascot = false),
            ),
          ),
      ],
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: widget.onNavigateToAccount,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandNavy,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.brandNavy.withOpacity(0.2), width: 2),
              ),
              child: Center(
                child: Text(
                  user.name.split(' ').map((w) => w[0]).take(2).join(),
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hadir-In',
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: AppColors.brandNavy,
                    )),
                Text(
                  user.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: AppColors.slate400, letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Notification
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.slate600, size: 22),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen())),
              ),
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.danger, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header Info ───────────────────────────────────────────
  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WELCOME BACK',
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.brandNavy, letterSpacing: 1.2,
            )),
        const SizedBox(height: 2),
        Text(user.name,
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            )),
        Text(user.position.name, style: AppText.body2),
        const SizedBox(height: 10),
        // Contextual greeting card
        if(_isWorkDay)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _state == AttendanceState.checkedOut
                  ? AppColors.brandNavy.withOpacity(0.06)
                  : (_state == AttendanceState.notCheckedIn &&
                          _now.isAfter(DateTime(_now.year, _now.month, _now.day,
                              user.currentShift.startTime.hour + 0,
                              user.currentShift.startTime.minute + 15))
                      ? AppColors.danger.withOpacity(0.07)
                      : AppColors.brandLime.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  _state == AttendanceState.checkedOut
                      ? '🌙'
                      : (_state == AttendanceState.notCheckedIn &&
                              _now.isAfter(DateTime(_now.year, _now.month, _now.day,
                                  user.currentShift.startTime.hour,
                                  user.currentShift.startTime.minute + 15))
                          ? '🚨'
                          : '👋'),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_greetingMsg,
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.slate800,
                      )),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Location Status ───────────────────────────────────────
  Widget _buildLocationStatus() {
    if (_checkingLoc) {
      return SectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brandNavy),
            ),
            const SizedBox(width: 12),
            Text('Memeriksa lokasi...', style: AppText.body2),
          ],
        ),
      );
    }

    if (!_locationChecked) {
      return SectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_off_rounded,
                  color: AppColors.slate400, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lokasi belum diperiksa',
                      style: AppText.label.copyWith(color: AppColors.slate900)),
                  Text('Tap untuk aktifkan GPS', style: AppText.body2),
                ],
              ),
            ),
            TextButton(
              onPressed: _checkLocation,
              child: const Text('Cek'),
            ),
          ],
        ),
      );
    }

    if (!_locationOn) {
      return SectionCard(
        color: AppColors.danger.withOpacity(0.06),
        borderColor: AppColors.danger.withOpacity(0.3),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('GPS tidak aktif. Aktifkan GPS untuk check-in.',
                  style: AppText.body2),
            ),
            TextButton(
              onPressed: _checkLocation,
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      );
    }

    if (_fakeLocation) {
      return SectionCard(
        color: AppColors.danger.withOpacity(0.06),
        borderColor: AppColors.danger.withOpacity(0.3),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.gps_off_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fake location terdeteksi!',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                          fontSize: 13)),
                  Text('Matikan aplikasi mock GPS untuk melanjutkan.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // OK
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.brandNavy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_officeName,
                    style: AppText.label.copyWith(color: AppColors.slate900)),
                Text(_officeAddress, style: AppText.body2),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.brandLimeDark,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('TERVERIFIKASI · DALAM AREA',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.brandLimeDark, letterSpacing: 0.5,
                        )),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.slate400, size: 18),
            onPressed: () {
              setState(() => _locationChecked = false);
              _checkLocation();
            },
          ),
        ],
      ),
    );
  }

  // ── Current Activity Card (stopwatch) ─────────────────────
  Widget _buildCurrentActivityCard() {
    final isBreak = _state == AttendanceState.onBreak;
    final isBreakEnded = _state == AttendanceState.breakEnded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isBreak
            ? AppColors.warning.withOpacity(0.08)
            : AppColors.brandNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBreak
              ? AppColors.warning.withOpacity(0.3)
              : AppColors.brandNavy.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isBreak ? '☕' : (isBreakEnded ? '💪' : '⏱️'),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Text(
                isBreak
                    ? 'ISTIRAHAT AKTIF'
                    : (isBreakEnded ? 'SELESAI ISTIRAHAT' : 'AKTIVITAS SAAT INI'),
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: isBreak ? AppColors.warning : AppColors.brandNavy,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (!isBreakEnded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isBreak
                        ? AppColors.warning.withOpacity(0.15)
                        : AppColors.brandLime.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: isBreak ? AppColors.warning : AppColors.brandLimeDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waktu Kerja',
                      style: AppText.caption),
                  Text(
                    _fmtDur(_workDur),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              if (isBreak || isBreakEnded)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Waktu Istirahat', style: AppText.caption),
                    Text(
                      _fmtDur(_breakDur),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Attendance Section ────────────────────────────────────
  Widget _buildAttendanceSection() {
    switch (_state) {
      case AttendanceState.notCheckedIn:
        if (!_isWorkDay)
          return SectionCard(
            color: AppColors.warning.withOpacity(0.07),
            borderColor: AppColors.warning.withOpacity(0.3),
            child: Column(
              children: [
                const Icon(Icons.weekend_rounded,
                    color: AppColors.warning, size: 36),
                const SizedBox(height: 8),
                Text('Hari Libur',
                    style: AppText.headline3
                        .copyWith(color: AppColors.warning)),
                const SizedBox(height: 4),
                Text('Check-in hanya tersedia pada hari kerja (Senin–Jumat)',
                    style: AppText.body2, textAlign: TextAlign.center),
              ],
            ),
          );
        else
          if(_autoCheckType == 'checkout')
            return _buildCheckoutCard();
          else
            return _buildCheckinCard();

      case AttendanceState.checkedIn:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Check-Out button
            GestureDetector(
              onTap: _canCheckout ? _checkout : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: _canCheckout
                      ? AppColors.brandNavy
                      : AppColors.slate200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: _canCheckout ? Colors.white : AppColors.slate400,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check-Out',
                      style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w800,
                        color: _canCheckout ? Colors.white : AppColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _canCheckout
                          ? 'Tap untuk merekam kepulangan'
                          : 'Belum waktunya pulang',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _canCheckout
                            ? Colors.white.withOpacity(0.75)
                            : AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Break button
            GestureDetector(
              onTap: _startBreak,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.free_breakfast_rounded,
                            color: AppColors.slate600, size: 20),
                        const SizedBox(width: 8),
                        Text('Istirahat / Break',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.slate700)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case AttendanceState.onBreak:
        return SectionCard(
          color: AppColors.warning.withOpacity(0.06),
          borderColor: AppColors.warning.withOpacity(0.3),
          child: Row(
            children: [
              const Text('☕', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sedang Istirahat',
                        style: AppText.label.copyWith(color: AppColors.slate900)),
                    Text('Tap untuk kembali ke layar istirahat',
                        style: AppText.body2),
                  ],
                ),
              ),
              TextButton(
                onPressed: _startBreak,
                child: const Text('Buka'),
              ),
            ],
          ),
        );

      case AttendanceState.breakEnded:
        return GradientButton(
          label: '▶  Kembali Bekerja',
          color: AppColors.brandLimeDark,
          height: 52,
          onTap: _returnFromBreak,
        );

      case AttendanceState.checkedOut:
        return SectionCard(
          color: AppColors.brandNavy.withOpacity(0.04),
          borderColor: AppColors.brandNavy.withOpacity(0.15),
          child: Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sudah Check-out', style: AppText.label),
                    Text('Kerja hari ini selesai. Sampai besok!',
                        style: AppText.body2),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  // ── Check-in Card ─────────────────────────────────────────
  Widget _buildCheckinCard() {
    final bool canCheckin = _locationOn && !_fakeLocation && _locationChecked;
    return GestureDetector(
      onTap: canCheckin ? _doCheckin : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: canCheckin ? AppColors.brandNavy : AppColors.slate300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: canCheckin
                    ? AppColors.brandLime
                    : AppColors.slate200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fingerprint_rounded,
                  color: canCheckin
                      ? AppColors.brandNavyDark
                      : AppColors.slate700,
                  size: 40),
            ),
            const SizedBox(height: 14),
            Text('Check-In',
                style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
            const SizedBox(height: 4),
            Text(
              canCheckin
                  ? 'Sudah di sini? Tap untuk check-in 👇'
                  : 'Aktifkan GPS untuk mulai check-in',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.75)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${user.currentShift.name} · ${user.currentShift.startTimeStr} – ${user.currentShift.endTimeStr}',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutCard() {
    final bool canCheckout = _locationOn && !_fakeLocation && _locationChecked;
    return GestureDetector(
      onTap: canCheckout ? _checkout : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: canCheckout ? const Color.fromARGB(255, 160, 24, 24) : AppColors.slate300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: canCheckout
                    ? AppColors.brandLime
                    : AppColors.slate200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fingerprint_rounded,
                  color: canCheckout
                      ? const Color.fromARGB(255, 116, 37, 37)
                      : AppColors.slate700,
                  size: 40),
            ),
            const SizedBox(height: 14),
            Text('Check-Out',
                style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text('Kamu sudah melewati waktu check-in. Jangan lupa check-out ya!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75)),),
            ),
            Text(
              canCheckout
                  ? 'Sudah di sini? Tap untuk check-out 👇'
                  : 'Aktifkan GPS untuk mulai check-out',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.75)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${user.currentShift.name} · ${user.currentShift.startTimeStr} – ${user.currentShift.endTimeStr}',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's Timeline ──────────────────────────────────────
  Widget _buildTimeline() {
    final shiftEnd = user.currentShift.endTimeStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Timeline Hari Ini",
            style: AppText.headline3.copyWith(color: AppColors.slate900)),
        const SizedBox(height: 10),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _TimelineItem(
                icon: Icons.login_rounded,
                iconColor: _isCheckedIn
                    ? AppColors.brandLimeDark : AppColors.slate400,
                iconBg: _isCheckedIn
                    ? AppColors.brandLime.withOpacity(0.2) : AppColors.slate100,
                title: 'Check-In',
                subtitle: _isCheckedIn
                    ? 'Kehadiran tercatat' : 'Belum check-in',
                time: (_isCheckedIn && _checkInTime != null)
                    ? _fmtHM(_checkInTime!) : '--:--',
                ampm: (_isCheckedIn && _checkInTime != null)
                    ? (_checkInTime!.hour < 12 ? 'AM' : 'PM') : '',
                status: _isCheckedIn ? 'HADIR' : 'MENUNGGU',
                statusColor: _isCheckedIn
                    ? AppColors.brandLimeDark : AppColors.slate400,
                showDivider: true,
              ),
              _TimelineItem(
                icon: Icons.free_breakfast_rounded,
                iconColor: _state == AttendanceState.onBreak ||
                        _state == AttendanceState.breakEnded
                    ? AppColors.warning : AppColors.slate400,
                iconBg: _state == AttendanceState.onBreak ||
                        _state == AttendanceState.breakEnded
                    ? AppColors.warning.withOpacity(0.15) : AppColors.slate100,
                title: 'Istirahat',
                subtitle: _state == AttendanceState.onBreak
                    ? 'Sedang istirahat'
                    : (_state == AttendanceState.breakEnded
                        ? 'Selesai: ${_fmtDur(_breakDur)}'
                        : 'Belum istirahat'),
                time: _breakStartTime != null
                    ? _fmtHM(_breakStartTime!) : '--:--',
                ampm: _breakStartTime != null
                    ? (_breakStartTime!.hour < 12 ? 'AM' : 'PM') : '',
                status: _state == AttendanceState.onBreak
                    ? 'LIVE'
                    : (_state == AttendanceState.breakEnded ? 'SELESAI' : '-'),
                statusColor: _state == AttendanceState.onBreak
                    ? AppColors.warning
                    : (_state == AttendanceState.breakEnded
                        ? AppColors.brandLimeDark : AppColors.slate400),
                showDivider: true,
              ),
              _TimelineItem(
                icon: Icons.logout_rounded,
                iconColor: _state == AttendanceState.checkedOut
                    ? AppColors.brandNavy : AppColors.slate400,
                iconBg: _state == AttendanceState.checkedOut
                    ? AppColors.brandNavy.withOpacity(0.1) : AppColors.slate100,
                title: 'Check-Out',
                subtitle: _state == AttendanceState.checkedOut
                    ? 'Pekerjaan selesai hari ini' : 'Terjadwal',
                time: shiftEnd.substring(0, 5),
                ampm: 'PM',
                status: _state == AttendanceState.checkedOut ? 'SELESAI' : 'TERJADWAL',
                statusColor: _state == AttendanceState.checkedOut
                    ? AppColors.brandLimeDark : AppColors.slate400,
                showDivider: true,
              ),
              _TimelineItem(
                icon: Icons.timer_outlined,
                iconColor: _workDur.inMinutes > 0
                    ? AppColors.brandCyanDark : AppColors.slate400,
                iconBg: _workDur.inMinutes > 0
                    ? AppColors.brandCyan.withOpacity(0.15) : AppColors.slate100,
                title: 'Jam Kerja',
                subtitle: _workDur.inMinutes > 0
                    ? 'Waktu kerja aktif hari ini' : 'Belum mulai bekerja',
                time: _workDur.inMinutes > 0
                    ? '${_workDur.inHours}j ${_workDur.inMinutes % 60}m' : '--',
                ampm: '',
                status: _workDur.inMinutes > 0 ? 'LIVE' : '-',
                statusColor: _workDur.inMinutes > 0
                    ? AppColors.brandCyanDark : AppColors.slate400,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Attendance History ─────────────────────────────────────
  Widget _buildAttendanceHistory() {
    final history = SampleData.recentAttendance.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Riwayat Kehadiran',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
              child: Text('Lihat Semua',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy, letterSpacing: 0.3,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...history.asMap().entries.map((e) {
                final rec = e.value;
                final isLast = e.key == history.length - 1;
                final isLate = rec.checkIn != null &&
                    rec.checkIn!.hour > user.currentShift.startTime.hour;
                final dot = rec.checkIn != null
                    ? (isLate ? '🟡' : '🟢')
                    : '🔴';
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Text(dot, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE, dd MMM', 'id_ID')
                                      .format(rec.date),
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.slate900),
                                ),
                                Text(
                                  rec.checkIn != null
                                      ? '${_fmtHM24(rec.checkIn!)} – ${rec.checkOut != null ? _fmtHM24(rec.checkOut!) : "–"}'
                                      : 'Tidak hadir',
                                  style: AppText.body2.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rec.checkIn == null
                                  ? AppColors.danger.withOpacity(0.1)
                                  : (isLate
                                      ? AppColors.warning.withOpacity(0.1)
                                      : AppColors.brandLime.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              rec.checkIn == null
                                  ? 'ABSEN'
                                  : (isLate ? 'TERLAMBAT' : 'TEPAT WAKTU'),
                              style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: rec.checkIn == null
                                    ? AppColors.danger
                                    : (isLate
                                        ? AppColors.warning
                                        : AppColors.brandLimeDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const AppDivider(),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Timeline Item ─────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle, time, ampm, status;
  final Color statusColor;
  final bool showDivider;

  const _TimelineItem({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle,
    required this.time, required this.ampm,
    required this.status, required this.statusColor,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.slate900)),
                    Text(subtitle,
                        style: AppText.body2.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time,
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      )),
                  if (ampm.isNotEmpty)
                    Text(ampm,
                        style: GoogleFonts.inter(
                            fontSize: 9, color: AppColors.slate700)),
                  Text(status,
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: statusColor,
                      )),
                ],
              ),
            ],
          ),
        ),
        if (showDivider) const AppDivider(),
      ],
    );
  }
}

// placeholder quick profile view
class _ProfileQuickView extends StatelessWidget {
  const _ProfileQuickView();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Profile')));
}
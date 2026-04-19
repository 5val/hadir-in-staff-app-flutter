import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import 'break_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'landing_screen.dart';
import 'login_screen.dart';
import 'checkin_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final user = SampleData.currentUser;

  // Selalu mulai dari notCheckedIn setiap kali dibuka (untuk testing)
  AttendanceState _state       = AttendanceState.notCheckedIn;
  DateTime        _now         = DateTime.now();
  DateTime?       _checkInTime;
  Duration        _workDur     = Duration.zero;
  bool            _showMascot  = false;
  String          _mascotMsg   = '';
  int             _points      = 1250;
  int             _msgIdx      = 0;

  Timer? _clockTimer, _workTimer;

  static const _officeName    = 'Current Office Location';
  static const _officeAddress = 'Jl. Sudirman No. 1, Jakarta Pusat, Gambir';
  static const _consistency   = 0.85;

  @override
  void initState() {
    super.initState();
    _msgIdx = DateTime.now().second % SampleData.motivationalMessages.length;

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == AttendanceState.checkedIn && _checkInTime != null) {
        setState(() => _workDur = _now.difference(_checkInTime!));
      }
    });
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

  String _formatHM(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2, '0')}';
  }

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
      _state  = AttendanceState.checkedOut;
      _points += 10;
      _showMascot = true;
      _mascotMsg  = SampleData.checkoutMessages[_now.second % 3];
    });
  }

  void _startBreak() {
    setState(() => _state = AttendanceState.onBreak);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreakScreen(
          onBreakEnd: () => setState(() => _state = AttendanceState.breakEnded),
        ),
      ),
    );
  }

  void _returnFromBreak() {
    setState(() {
      _state  = AttendanceState.checkedIn;
      _points += 5;
      _showMascot = true;
      _mascotMsg  = 'Semangat Kembali! 💪\nLanjut produktif!';
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

  void _goToLanding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderInfo(),
                        const SizedBox(height: 14),
                        _buildLocationCard(),
                        const SizedBox(height: 16),
                        _buildAttendanceSection(),
                        const SizedBox(height: 18),
                        if (_isCheckedIn) ...[
                          _buildStatusCard(),
                          const SizedBox(height: 18),
                        ],
                        _buildTimeline(),
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
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        children: [
          // Back to landing
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.slate600),
            tooltip: 'Kembali ke Beranda',
            onPressed: _goToLanding,
          ),
          // Avatar → profile
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.brandNavy,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.brandNavy.withOpacity(0.2), width: 2),
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
          const SizedBox(width: 8),
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
          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 13),
                const SizedBox(width: 4),
                Text(
                  '${NumberFormat('#,###').format(_points)} Points',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Notif
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
      ],
    );
  }

  // ── Location Card ─────────────────────────────────────────
  Widget _buildLocationCard() {
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
            child: const Icon(Icons.location_on_outlined,
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
                          color: AppColors.brandLimeDark, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('VERIFIED WITHIN PERIMETER',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.brandLimeDark, letterSpacing: 0.5,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Attendance Section ────────────────────────────────────
  Widget _buildAttendanceSection() {
    switch (_state) {
      case AttendanceState.notCheckedIn:
        return _buildCheckinCard();

      case AttendanceState.checkedIn:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShiftTimer(),
            const SizedBox(height: 14),
            _buildRestButton(),
            const SizedBox(height: 10),
            GradientButton(
              label: 'Check-Out',
              color: _canCheckout ? AppColors.brandNavy : AppColors.slate300,
              textColor: _canCheckout ? Colors.white : const Color(0xFF64748B),
              icon: Icons.logout_rounded,
              height: 50,
              onTap: _canCheckout ? _checkout : null,
            ),
          ],
        );

      case AttendanceState.onBreak:
        return Column(
          children: [
            _buildShiftTimer(),
            const SizedBox(height: 12),
            SectionCard(
              color: AppColors.warning.withOpacity(0.06),
              borderColor: AppColors.warning.withOpacity(0.3),
              child: Row(
                children: [
                  const Text('☕', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sedang Istirahat',
                            style: AppText.label
                                .copyWith(color: AppColors.slate900)),
                        Text('Kembali ke layar istirahat',
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
            ),
          ],
        );

      case AttendanceState.breakEnded:
        return Column(
          children: [
            _buildShiftTimer(),
            const SizedBox(height: 12),
            GradientButton(
              label: '▶  Kembali Bekerja (IN)',
              color: AppColors.brandLimeDark,
              height: 52,
              onTap: _returnFromBreak,
            ),
          ],
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
    return GestureDetector(
      onTap: _doCheckin,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.brandNavy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.brandLime, shape: BoxShape.circle),
              child: const Icon(Icons.fingerprint_rounded,
                  color: AppColors.brandNavyDark, size: 40),
            ),
            const SizedBox(height: 14),
            Text('Check-In',
                style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
            const SizedBox(height: 3),
            Text('Tap to record attendance',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  // ── Shift Timer ───────────────────────────────────────────
  Widget _buildShiftTimer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACTIVE SHIFT',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.slate400, letterSpacing: 1.0,
                )),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_fmtDur(_workDur),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 30, fontWeight: FontWeight.w800,
                      color: AppColors.brandNavy,
                    )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandLime.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: AppColors.brandLimeDark,
                      )),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Rest Button ───────────────────────────────────────────
  Widget _buildRestButton() {
    return GestureDetector(
      onTap: _startBreak,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.free_breakfast_rounded,
                color: AppColors.slate600, size: 18),
            const SizedBox(width: 8),
            Text('Start Rest Now',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.slate700)),
          ],
        ),
      ),
    );
  }

  // ── Status Card ───────────────────────────────────────────
  Widget _buildStatusCard() {
    return SectionCard(
      child: Column(
        children: [
          const Text('😊', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          Text('On Time!',
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.slate900)),
          const SizedBox(height: 2),
          Text(
            "You're doing great, ${user.name.split(' ').first}. Keep up the punctuality!",
            style: AppText.body2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // ClipRRect(
          //   borderRadius: BorderRadius.circular(6),
          //   child: LinearProgressIndicator(
          //     value: _consistency,
          //     backgroundColor: AppColors.slate100,
          //     valueColor:
          //         const AlwaysStoppedAnimation(AppColors.brandLime),
          //     minHeight: 7,
          //   ),
          // ),
          // const SizedBox(height: 5),
          // Text('${(_consistency * 100).toInt()}% WEEKLY CONSISTENCY',
          //     style: GoogleFonts.inter(
          //       fontSize: 10, fontWeight: FontWeight.w700,
          //       color: AppColors.slate400, letterSpacing: 0.8,
          //     )),
        ],
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────
  Widget _buildTimeline() {
    final records    = SampleData.recentAttendance;
    final todayRec   = records.isNotEmpty ? records.first : null;
    final shiftEnd   = user.currentShift.endTimeStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's Timeline",
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            TextButton(
              onPressed: () {},
              child: Text('VIEW HISTORY',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy, letterSpacing: 0.5,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _TimelineItem(
                iconColor: _isCheckedIn
                    ? AppColors.brandLimeDark
                    : AppColors.slate400,
                iconBg: _isCheckedIn
                    ? AppColors.brandLime.withOpacity(0.2)
                    : AppColors.slate100,
                icon: Icons.login_rounded,
                title: 'Office Entry',
                subtitle: _isCheckedIn
                    ? 'Managed to beat the morning rush'
                    : 'Not yet checked in',
                time: (_isCheckedIn && _checkInTime != null)
                    ? _formatHM(_checkInTime!)
                    : '--:--',
                ampm: (_isCheckedIn && _checkInTime != null)
                    ? (_checkInTime!.hour < 12 ? 'AM' : 'PM')
                    : '',
                status: _isCheckedIn ? 'SUCCESS' : 'PENDING',
                statusColor: _isCheckedIn
                    ? AppColors.brandLimeDark
                    : AppColors.slate400,
                showDivider: true,
              ),
              _TimelineItem(
                icon: Icons.logout_rounded,
                iconColor: AppColors.slate400,
                iconBg: AppColors.slate100,
                title: 'End Shift',
                subtitle: _state == AttendanceState.checkedOut
                    ? 'Completed successfully'
                    : 'Scheduled for later',
                time: shiftEnd.substring(0, 5),
                ampm: 'PM',
                status: _state == AttendanceState.checkedOut
                    ? 'SUCCESS'
                    : 'PENDING',
                statusColor: _state == AttendanceState.checkedOut
                    ? AppColors.brandLimeDark
                    : AppColors.slate400,
                showDivider: false,
              ),
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
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.ampm,
    required this.status,
    required this.statusColor,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.slate900)),
                    Text(subtitle,
                        style: AppText.body2.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time,
                      style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      )),
                  if (ampm.isNotEmpty)
                    Text(ampm,
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: AppColors.slate600)),
                  Text(status,
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
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
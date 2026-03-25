import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'break_screen.dart';
import 'salary_screen.dart';
import 'leave_request_screen.dart';
import 'notification_screen.dart';
import 'landing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final UserProfile user = SampleData.currentUser;

  AttendanceState _state      = AttendanceState.checkedIn;
  DateTime        _now        = DateTime.now();
  DateTime?       _checkInTime;
  Duration        _workDuration = Duration.zero;
  bool            _showForgotDialog = false;
  bool            _showMascot = false;
  String          _mascotMsg  = '';
  bool            _mascotWave = true;
  int             _currentPoints = 420;
  int             _msgIndex   = 0;

  Timer? _clockTimer, _workTimer;

  late AnimationController _stateCtrl;
  late Animation<double>   _stateFade;

  @override
  void initState() {
    super.initState();
    _checkInTime = DateTime.now().subtract(const Duration(hours: 2));
    _msgIndex    = DateTime.now().second % SampleData.motivationalMessages.length;

    _stateCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _stateFade = CurvedAnimation(parent: _stateCtrl, curve: Curves.easeIn);
    _stateCtrl.forward();

    _clockTimer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
    _workTimer  = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == AttendanceState.checkedIn && _checkInTime != null) {
        setState(() => _workDuration = _now.difference(_checkInTime!));
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel(); _workTimer?.cancel(); _stateCtrl.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2,'0')}:${(d.inMinutes%60).toString().padLeft(2,'0')}:${(d.inSeconds%60).toString().padLeft(2,'0')}';

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  String _greet() {
    final h = _now.hour;
    if (h < 12) return 'Selamat Pagi 🌅';
    if (h < 15) return 'Selamat Siang ☀️';
    if (h < 18) return 'Selamat Sore 🌤';
    return 'Selamat Malam 🌙';
  }

  bool get _canCheckout {
    if (_state != AttendanceState.checkedIn) return false;
    final shiftEnd = DateTime(_now.year, _now.month, _now.day,
        user.currentShift.endTime.hour, user.currentShift.endTime.minute);
    return _now.isAfter(shiftEnd.subtract(
        Duration(minutes: user.position.earlyCheckoutToleranceMinutes)));
  }

  int get _overtimeMinutes {
    if (_checkInTime == null) return 0;
    final shiftEnd = DateTime(_now.year, _now.month, _now.day,
        user.currentShift.endTime.hour, user.currentShift.endTime.minute);
    return _now.isAfter(shiftEnd) ? _now.difference(shiftEnd).inMinutes : 0;
  }

  // ── State actions ─────────────────────────────────────────
  void _startBreak() {
    _stateCtrl.reset();
    setState(() => _state = AttendanceState.onBreak);
    _stateCtrl.forward();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BreakScreen(
        onBreakEnd: () {
          setState(() => _state = AttendanceState.breakEnded);
          _stateCtrl..reset()..forward();
        },
      ),
    ));
  }

  void _returnFromBreak() {
    _stateCtrl.reset();
    setState(() { _state = AttendanceState.checkedIn; _currentPoints += 5; });
    _stateCtrl.forward();
    // Show mascot for return from break
    setState(() {
      _showMascot = true;
      _mascotMsg  = 'Semangat Kembali! 💪\nLanjut produktif ya!';
      _mascotWave = true;
    });
  }

  Future<void> _checkout() async {
    if (!_canCheckout) {
      _infoDialog(
        title: 'Belum Bisa Check-out',
        message: 'Check-out diizinkan dalam '
            '${user.position.earlyCheckoutToleranceMinutes} menit '
            'sebelum akhir shift (${user.currentShift.endTimeStr}).',
        icon: Icons.lock_clock_rounded,
        iconColor: AppColors.warning,
      );
      return;
    }
    if (_state == AttendanceState.breakEnded) {
      _snack('Tekan tombol "IN" setelah istirahat terlebih dahulu');
      return;
    }
    final shiftEnd = DateTime(_now.year, _now.month, _now.day,
        user.currentShift.endTime.hour, user.currentShift.endTime.minute);
    if (_now.isBefore(shiftEnd)) {
      final ok = await _confirmDialog('Pulang Lebih Awal?',
          'Shift berakhir pukul ${user.currentShift.endTimeStr}. Yakin check-out sekarang?');
      if (ok != true) return;
    }
    _stateCtrl.reset();
    setState(() { _state = AttendanceState.checkedOut; _currentPoints += 10; });
    _stateCtrl.forward();
    // Show mascot after checkout
    setState(() {
      _showMascot = true;
      _mascotMsg  = SampleData.checkoutMessages[_now.second % 3];
      _mascotWave = true;
    });
  }

  void _snack(String msg, {Color? bg}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: bg ?? AppColors.brandNavyDark,
    ));
  }

  Future<bool?> _confirmDialog(String title, String msg) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(msg, style: AppText.body2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Ya, Check-out')),
          ],
        ),
      );

  void _infoDialog({required String title, required String message,
      required IconData icon, Color iconColor = AppColors.brandCyan}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(icon, color: iconColor, size: 36),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 195,
                pinned: true,
                backgroundColor: AppColors.white,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(),
                  collapseMode: CollapseMode.pin,
                ),
                title: _buildCollapsedBar(),
                titleSpacing: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.slate200),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      FadeTransition(opacity: _stateFade, child: _buildStateCard()),

                      const SizedBox(height: 14),

                      if (_state == AttendanceState.checkedIn) ...[
                        _buildWorkTimer(),
                        const SizedBox(height: 14),
                      ],

                      Text('Menu', style: AppText.headline3),
                      const SizedBox(height: 12),
                      _buildQuickMenu(),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Riwayat Kehadiran', style: AppText.headline3),
                          TextButton(
                            onPressed: () {},
                            child: Text('Lihat Semua',
                                style: TextStyle(color: AppColors.brandNavy, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...SampleData.recentAttendance.take(5).map((r) => _AttendanceRow(record: r)),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_showForgotDialog) _buildForgotCheckoutOverlay(),

          if (_showMascot)
            Positioned.fill(
              child: MascotOverlay(
                wave: _mascotWave,
                message: _mascotMsg,
                onDismiss: () => setState(() => _showMascot = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsedBar() {
    return Row(
      children: [
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppColors.slate700),
          tooltip: 'Kembali ke Beranda',
          onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const LandingScreen())),
        ),
        Image.asset(AppAssets.logoIcon, height: 24),
        const SizedBox(width: 6),
        Expanded(child: Text('Hadir-In', style: AppText.headline3)),
        _notifBtn(),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _notifBtn() => Stack(
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_outlined, color: AppColors.slate700),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationScreen())),
      ),
      Positioned(
        right: 8, top: 8,
        child: Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
              color: AppColors.danger, shape: BoxShape.circle),
        ),
      ),
    ],
  );

  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              // Avatar
              Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.brandNavy, shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(user.name[0],
                      style: GoogleFonts.inter(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greet(), style: AppText.body2),
                    Text(user.name,
                        style: AppText.headline3.copyWith(color: AppColors.brandNavy)),
                    Text('${user.position.name} · ${user.employeeId}',
                        style: AppText.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandNavy.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.brandNavy, size: 13),
                        const SizedBox(width: 4),
                        Text('$_currentPoints pts',
                            style: GoogleFonts.inter(
                              color: AppColors.brandNavy, fontWeight: FontWeight.w700,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.brandNavy.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.brandNavy, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${user.currentShift.name}: ${user.currentShift.startTimeStr} – ${user.currentShift.endTimeStr}',
                  style: AppText.body2.copyWith(
                      color: AppColors.brandNavy, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const Spacer(),
                _stateChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateChip() {
    Color c; String label;
    switch (_state) {
      case AttendanceState.notCheckedIn: c = AppColors.slate400;      label = 'Belum Masuk';     break;
      case AttendanceState.checkedIn:    c = AppColors.brandLimeDark;  label = 'Sedang Kerja';    break;
      case AttendanceState.onBreak:      c = AppColors.warning;        label = 'Istirahat';       break;
      case AttendanceState.breakEnded:   c = AppColors.brandCyanDark;  label = 'Selesai Istirahat'; break;
      case AttendanceState.checkedOut:   c = AppColors.brandNavyLight; label = 'Sudah Pulang';   break;
    }
    return StatusBadge(label: label, color: c);
  }

  // ── State Card ────────────────────────────────────────────
  Widget _buildStateCard() {
    switch (_state) {
      case AttendanceState.notCheckedIn:
        return SectionCard(
          child: Column(
            children: [
              const Icon(Icons.login_rounded, color: AppColors.slate300, size: 36),
              const SizedBox(height: 10),
              Text('Belum Check-in', style: AppText.headline3),
              const SizedBox(height: 4),
              Text('Kamu belum check-in hari ini', style: AppText.body2),
            ],
          ),
        );

      case AttendanceState.checkedIn:
        return Column(
          children: [
            SectionCard(
              color: AppColors.brandLime.withOpacity(0.07),
              borderColor: AppColors.brandLime.withOpacity(0.3),
              child: Row(
                children: [
                  const Text('💪', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(SampleData.motivationalMessages[_msgIndex],
                        style: AppText.body1.copyWith(fontWeight: FontWeight.w500,
                            color: AppColors.slate800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GradientButton(
              label: '☕  Mulai Istirahat',
              color: AppColors.warning,
              textColor: AppColors.brandNavyDark,
              height: 52,
              icon: Icons.free_breakfast_rounded,
              onTap: _startBreak,
            ),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Check-out',
              color: _canCheckout ? AppColors.brandNavy : AppColors.slate200,
              textColor: _canCheckout ? Colors.white : AppColors.slate400,
              height: 48,
              icon: Icons.logout_rounded,
              onTap: _checkout,
            ),
          ],
        );

      case AttendanceState.onBreak:
        return SectionCard(
          color: AppColors.warning.withOpacity(0.05),
          borderColor: AppColors.warning.withOpacity(0.3),
          child: Column(
            children: [
              const Text('☕', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Sedang Istirahat', style: AppText.headline3),
              const SizedBox(height: 4),
              Text('Kamu sedang dalam sesi istirahat.',
                  style: AppText.body2, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              GradientButton(
                label: 'Kembali ke Layar Istirahat',
                color: AppColors.warning,
                textColor: AppColors.brandNavyDark,
                height: 44, onTap: _startBreak,
              ),
            ],
          ),
        );

      case AttendanceState.breakEnded:
        return SectionCard(
          color: AppColors.brandCyan.withOpacity(0.06),
          borderColor: AppColors.brandCyan.withOpacity(0.3),
          child: Column(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Istirahat Selesai!', style: AppText.headline3),
              const SizedBox(height: 4),
              Text('Tekan tombol IN untuk kembali bekerja',
                  style: AppText.body2, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              GradientButton(
                label: '▶  Kembali Bekerja (IN)',
                color: AppColors.brandLimeDark,
                height: 48, onTap: _returnFromBreak,
              ),
            ],
          ),
        );

      case AttendanceState.checkedOut:
        return SectionCard(
          color: AppColors.brandNavy.withOpacity(0.04),
          borderColor: AppColors.brandNavy.withOpacity(0.2),
          child: Column(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Sudah Check-out', style: AppText.headline3),
              const SizedBox(height: 4),
              Text('Kerja hari ini selesai. Sampai jumpa besok!',
                  style: AppText.body2, textAlign: TextAlign.center),
              if (_overtimeMinutes > 0) ...[
                const SizedBox(height: 8),
                StatusBadge(
                  label: 'Lembur: ${_overtimeMinutes ~/ 60}j ${_overtimeMinutes % 60}m',
                  color: AppColors.brandNavy,
                ),
              ],
            ],
          ),
        );
    }
  }

  // ── Work Timer ────────────────────────────────────────────
  Widget _buildWorkTimer() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.timer_outlined, color: AppColors.brandNavy, size: 15),
              ),
              const SizedBox(width: 8),
              Text('Timer Kerja', style: AppText.label),
              const Spacer(),
              if (_checkInTime != null)
                Text('Masuk: ${_fmtTime(_checkInTime!)}', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _fmtDuration(_workDuration),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.brandNavy,
              ),
            ),
          ),
          if (_overtimeMinutes > 0) ...[
            const SizedBox(height: 6),
            Center(child: StatusBadge(
              label: '⏰ Lembur: ${_overtimeMinutes ~/ 60}j ${_overtimeMinutes % 60}m',
              color: AppColors.warning,
            )),
          ],
        ],
      ),
    );
  }

  // ── Quick Menu ────────────────────────────────────────────
  Widget _buildQuickMenu() {
    final items = [
      _MenuItem(icon: Icons.receipt_long_rounded,    label: 'Slip Gaji',    color: AppColors.brandCyanDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen()))),
      _MenuItem(icon: Icons.event_available_rounded, label: 'Cuti',         color: AppColors.brandLimeDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const LeaveRequestScreen(user: SampleData.currentUser, initialTab: 0)))),
      _MenuItem(icon: Icons.sick_rounded,            label: 'Izin / Sakit', color: AppColors.danger,
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const LeaveRequestScreen(user: SampleData.currentUser, initialTab: 1)))),
      _MenuItem(icon: Icons.notifications_outlined,  label: 'Notifikasi',   color: AppColors.warning,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()))),
    ];

    return GridView.count(
      crossAxisCount: 4, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      children: items.map(_buildMenuItem).toList(),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.color.withOpacity(0.2)),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(item.label,
              style: AppText.caption.copyWith(
                  fontSize: 10, color: AppColors.slate700),
              textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }

  // ── Forgot Checkout Overlay ───────────────────────────────
  Widget _buildForgotCheckoutOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SectionCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🤔', style: TextStyle(fontSize: 46)),
                  const SizedBox(height: 10),
                  Text('Are you still at work?', style: AppText.headline3,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Shift kamu sudah berakhir. Apakah kamu masih di tempat kerja?',
                      style: AppText.body2, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Tidak', outlined: true, color: AppColors.slate400,
                          textColor: AppColors.slate600,
                          onTap: () => setState(() => _showForgotDialog = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientButton(
                          label: 'Ya, Masih', color: AppColors.brandNavy,
                          onTap: () {
                            setState(() => _showForgotDialog = false);
                            _snack('✅ Lembur dicatat. Tetap semangat!');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper classes ────────────────────────────────────────────
class _MenuItem {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});
}

// ── Attendance Row ────────────────────────────────────────────
class _AttendanceRow extends StatelessWidget {
  final AttendanceRecord record;
  const _AttendanceRow({required this.record});

  String _fmtDate(DateTime dt) {
    const days = ['','Sen','Sel','Rab','Kam','Jum','Sab','Min'];
    const months = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]}';
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    Color c; String label; IconData icon;
    switch (record.status) {
      case AttendanceStatus.present: c = AppColors.brandLimeDark; label = 'Hadir';    icon = Icons.check_circle_rounded;    break;
      case AttendanceStatus.late:    c = AppColors.warning;       label = 'Terlambat'; icon = Icons.schedule_rounded;        break;
      case AttendanceStatus.absent:  c = AppColors.danger;        label = 'Absen';    icon = Icons.cancel_rounded;          break;
      case AttendanceStatus.leave:   c = AppColors.brandNavy;     label = 'Cuti';     icon = Icons.event_available_rounded;  break;
      case AttendanceStatus.holiday: c = AppColors.brandCyanDark; label = 'Libur';    icon = Icons.beach_access_rounded;    break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: c, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDate(record.date),
                      style: AppText.body1.copyWith(fontWeight: FontWeight.w600,
                          color: AppColors.slate900)),
                  const SizedBox(height: 2),
                  Text(
                    record.checkIn != null
                        ? 'Masuk: ${_fmtTime(record.checkIn)} · Keluar: ${_fmtTime(record.checkOut)}'
                        : label,
                    style: AppText.body2,
                  ),
                  if ((record.lateMinutes ?? 0) > 0)
                    Text('Terlambat ${record.lateMinutes} menit',
                        style: AppText.caption.copyWith(color: AppColors.warning)),
                  if ((record.overtimeMinutes ?? 0) > 0)
                    Text('Lembur ${record.overtimeMinutes} menit',
                        style: AppText.caption.copyWith(color: AppColors.brandNavy)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: label, color: c),
                if (record.pointsEarned > 0) ...[
                  const SizedBox(height: 4),
                  Text('+${record.pointsEarned} pts',
                      style: AppText.caption.copyWith(color: AppColors.brandNavy)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
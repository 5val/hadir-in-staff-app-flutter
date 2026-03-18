import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'break_screen.dart';
import 'salary_screen.dart';
import 'leave_request_screen.dart';
import 'permission_screen.dart';
import 'notification_screen.dart';
import 'landing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final UserProfile user = SampleData.currentUser;

  AttendanceState _state = AttendanceState.checkedIn;
  DateTime _now = DateTime.now();
  DateTime? _checkInTime;
  Duration _workDuration = Duration.zero;

  Timer? _clockTimer;
  Timer? _workTimer;

  bool _showForgotDialog = false;
  int _currentPoints = 420;
  int _msgIndex = 0;

  late AnimationController _stateCtrl;
  late Animation<double> _stateFade;

  @override
  void initState() {
    super.initState();
    _checkInTime = DateTime.now().subtract(const Duration(hours: 2));
    _msgIndex = DateTime.now().second % SampleData.motivationalMessages.length;

    _stateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _stateFade = CurvedAnimation(parent: _stateCtrl, curve: Curves.easeIn);
    _stateCtrl.forward();

    _clockTimer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));

    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == AttendanceState.checkedIn && _checkInTime != null) {
        setState(() => _workDuration = _now.difference(_checkInTime!));
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _workTimer?.cancel();
    _stateCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────
  String _formatDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:'
      '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _greet() {
    final h = _now.hour;
    if (h < 12) return 'Selamat Pagi 🌅';
    if (h < 15) return 'Selamat Siang ☀️';
    if (h < 18) return 'Selamat Sore 🌤';
    return 'Selamat Malam 🌙';
  }

  bool get _canCheckout {
    if (_state != AttendanceState.checkedIn &&
        _state != AttendanceState.breakEnded) return false;
    if (_state == AttendanceState.breakEnded) return false;
    final shift = user.currentShift;
    final shiftEnd = DateTime(_now.year, _now.month, _now.day,
        shift.endTime.hour, shift.endTime.minute);
    return _now.isAfter(
        shiftEnd.subtract(Duration(minutes: user.position.earlyCheckoutToleranceMinutes)));
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreakScreen(
          onBreakEnd: () {
            setState(() => _state = AttendanceState.breakEnded);
            _stateCtrl
              ..reset()
              ..forward();
          },
        ),
      ),
    );
  }

  void _returnFromBreak() {
    _stateCtrl.reset();
    setState(() {
      _state = AttendanceState.checkedIn;
      _currentPoints += 5;
    });
    _stateCtrl.forward();
    _snack('Selamat kembali! Semangat lanjut kerja 💪', AppColors.success);
  }

  Future<void> _checkout() async {
    if (!_canCheckout) {
      final tolerance = user.position.earlyCheckoutToleranceMinutes;
      _infoDialog(
        title: 'Belum Bisa Check-out',
        message:
            'Check-out diizinkan dalam $tolerance menit sebelum akhir shift '
            '(${user.currentShift.endTimeStr}).\n\nHubungi supervisor jika ada keperluan mendesak.',
        icon: Icons.lock_clock_rounded,
        iconColor: AppColors.warning,
      );
      return;
    }
    if (_state == AttendanceState.breakEnded) {
      _snack('Tekan tombol "IN" setelah istirahat terlebih dahulu', AppColors.warning);
      return;
    }
    final shiftEnd = DateTime(_now.year, _now.month, _now.day,
        user.currentShift.endTime.hour, user.currentShift.endTime.minute);
    if (_now.isBefore(shiftEnd)) {
      final ok = await _confirmDialog(
        'Pulang Lebih Awal?',
        'Shift berakhir pukul ${user.currentShift.endTimeStr}. Yakin ingin check-out sekarang?',
      );
      if (ok != true) return;
    }
    _stateCtrl.reset();
    setState(() {
      _state = AttendanceState.checkedOut;
      _currentPoints += 10;
    });
    _stateCtrl.forward();
    _snack(SampleData.checkoutMessages[_now.second % 3], AppColors.success);
  }

  // ── Dialogs ───────────────────────────────────────────────
  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<bool?> _confirmDialog(String title, String msg) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(msg, style: AppText.body2),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, Check-out'),
            ),
          ],
        ),
      );

  void _infoDialog({
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = AppColors.info,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(icon, color: iconColor, size: 36),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Sliver App Bar ────────────────────────────
              SliverAppBar(
                expandedHeight: 190,
                pinned: true,
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(),
                  collapseMode: CollapseMode.pin,
                ),
                // Collapsed bar — shown when scrolled
                title: _buildCollapsedBar(),
                titleSpacing: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.border),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      FadeTransition(
                        opacity: _stateFade,
                        child: _buildStateCard(),
                      ),

                      const SizedBox(height: 16),

                      if (_state == AttendanceState.checkedIn)
                        _buildWorkTimer(),

                      if (_state == AttendanceState.checkedIn)
                        const SizedBox(height: 16),

                      // ── Quick Menu ────────────────────────
                      Text('Menu', style: AppText.headline3),
                      const SizedBox(height: 12),
                      _buildQuickMenu(),

                      const SizedBox(height: 20),

                      // ── Attendance history ────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Riwayat Kehadiran', style: AppText.headline3),
                          TextButton(
                            onPressed: () {},
                            child: Text('Lihat Semua',
                                style: TextStyle(
                                    color: AppColors.primary, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...SampleData.recentAttendance
                          .take(5)
                          .map((r) => _AttendanceRow(record: r)),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_showForgotDialog) _buildForgotCheckoutOverlay(),
        ],
      ),
    );
  }

  // ── Collapsed AppBar bar ──────────────────────────────────
  Widget _buildCollapsedBar() {
    return Row(
      children: [
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppColors.textPrimary),
          tooltip: 'Kembali ke Beranda',
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LandingScreen()),
          ),
        ),
        Expanded(
          child: Text('HadirIn', style: AppText.headline3),
        ),
        _notifButton(),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _notifButton() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Back button (small) ──
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 15, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.name[0],
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greet(), style: AppText.body2),
                    Text(user.name, style: AppText.headline3),
                    Text(
                      '${user.position.name} · ${user.employeeId}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              // Notif + Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _notifButton(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.primary, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentPoints pts',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Shift bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${user.currentShift.name}: '
                  '${user.currentShift.startTimeStr} – ${user.currentShift.endTimeStr}',
                  style: AppText.body2
                      .copyWith(color: AppColors.primary, fontSize: 12),
                ),
                const Spacer(),
                _buildStateChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateChip() {
    Color color;
    String label;
    switch (_state) {
      case AttendanceState.notCheckedIn:
        color = AppColors.textMuted;
        label = 'Belum Masuk';
        break;
      case AttendanceState.checkedIn:
        color = AppColors.success;
        label = 'Sedang Kerja';
        break;
      case AttendanceState.onBreak:
        color = AppColors.warning;
        label = 'Istirahat';
        break;
      case AttendanceState.breakEnded:
        color = AppColors.info;
        label = 'Selesai Istirahat';
        break;
      case AttendanceState.checkedOut:
        color = AppColors.teal;
        label = 'Sudah Pulang';
        break;
    }
    return StatusBadge(label: label, color: color);
  }

  // ── State Card ────────────────────────────────────────────
  Widget _buildStateCard() {
    switch (_state) {
      case AttendanceState.notCheckedIn:
        return SectionCard(
          child: Column(
            children: [
              Icon(Icons.login_rounded,
                  color: AppColors.textMuted, size: 36),
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
            // Motivational banner
            SectionCard(
              borderColor: AppColors.success.withOpacity(0.3),
              color: AppColors.success.withOpacity(0.06),
              child: Row(
                children: [
                  const Text('💪', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      SampleData.motivationalMessages[_msgIndex],
                      style: AppText.body1.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Break button
            GradientButton(
              label: '☕  Mulai Istirahat',
              color: AppColors.warning,
              height: 56,
              icon: Icons.free_breakfast_rounded,
              onTap: _startBreak,
            ),
            const SizedBox(height: 10),
            // Checkout button
            GradientButton(
              label: 'Check-out',
              color: _canCheckout ? AppColors.teal : AppColors.surfaceVariant,
              height: 52,
              icon: Icons.logout_rounded,
              onTap: _checkout,
            ),
          ],
        );

      case AttendanceState.onBreak:
        return SectionCard(
          borderColor: AppColors.warning.withOpacity(0.3),
          color: AppColors.warning.withOpacity(0.06),
          child: Column(
            children: [
              const Text('☕', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 10),
              Text('Sedang Istirahat', style: AppText.headline3),
              const SizedBox(height: 4),
              Text(
                'Kamu sedang dalam sesi istirahat.\nKembali ke layar istirahat untuk melanjutkan.',
                style: AppText.body2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              GradientButton(
                label: 'Kembali ke Layar Istirahat',
                color: AppColors.warning,
                height: 44,
                onTap: _startBreak,
              ),
            ],
          ),
        );

      case AttendanceState.breakEnded:
        return SectionCard(
          borderColor: AppColors.primary.withOpacity(0.3),
          color: AppColors.primary.withOpacity(0.06),
          child: Column(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 10),
              Text('Istirahat Selesai!', style: AppText.headline3),
              const SizedBox(height: 4),
              Text(
                'Tekan tombol IN untuk kembali bekerja',
                style: AppText.body2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              GradientButton(
                label: '▶  Kembali Bekerja (IN)',
                color: AppColors.success,
                height: 52,
                onTap: _returnFromBreak,
              ),
            ],
          ),
        );

      case AttendanceState.checkedOut:
        return SectionCard(
          borderColor: AppColors.teal.withOpacity(0.3),
          color: AppColors.teal.withOpacity(0.06),
          child: Column(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 10),
              Text('Sudah Check-out', style: AppText.headline3),
              const SizedBox(height: 4),
              Text(
                'Kerja hari ini sudah selesai.\nSampai jumpa besok!',
                style: AppText.body2,
                textAlign: TextAlign.center,
              ),
              if (_overtimeMinutes > 0) ...[
                const SizedBox(height: 10),
                StatusBadge(
                  label: 'Lembur: ${_overtimeMinutes ~/ 60}j ${_overtimeMinutes % 60}m',
                  color: AppColors.primary,
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
              Icon(Icons.timer_outlined, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text('Timer Kerja', style: AppText.label),
              const Spacer(),
              if (_checkInTime != null)
                Text('Masuk: ${_formatTime(_checkInTime!)}',
                    style: AppText.caption),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _formatDuration(_workDuration),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          if (_overtimeMinutes > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: StatusBadge(
                label: '⏰ Lembur: ${_overtimeMinutes ~/ 60}j ${_overtimeMinutes % 60}m',
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick Menu ────────────────────────────────────────────
  Widget _buildQuickMenu() {
    final items = [
      _MenuItem(icon: Icons.receipt_long_rounded, label: 'Slip Gaji',
          color: AppColors.teal,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SalaryScreen()))),
      _MenuItem(icon: Icons.event_available_rounded, label: 'Cuti',
          color: AppColors.success,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) =>
                  const LeaveRequestScreen(user: SampleData.currentUser)))),
      _MenuItem(icon: Icons.sick_rounded, label: 'Izin / Sakit',
          color: AppColors.danger,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PermissionScreen()))),
      _MenuItem(icon: Icons.notifications_outlined, label: 'Notifikasi',
          color: AppColors.warning,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()))),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.color.withOpacity(0.25)),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: AppText.caption.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Forgot Checkout Overlay ───────────────────────────────
  Widget _buildForgotCheckoutOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SectionCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🤔', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('Are you still at work?', style: AppText.headline3,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Shift kamu sudah berakhir. Apakah kamu masih di tempat kerja?',
                    style: AppText.body2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _showForgotDialog = false),
                          child: const Text('Tidak'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _showForgotDialog = false);
                            _snack('✅ Lembur dicatat. Tetap semangat!',
                                AppColors.success);
                          },
                          child: const Text('Ya, Masih'),
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
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

// ── Attendance Row ────────────────────────────────────────────
class _AttendanceRow extends StatelessWidget {
  final AttendanceRecord record;
  const _AttendanceRow({required this.record});

  String _fmtDate(DateTime dt) {
    const days = ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]}';
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    IconData icon;
    switch (record.status) {
      case AttendanceStatus.present:
        c = AppColors.success; label = 'Hadir'; icon = Icons.check_circle_rounded; break;
      case AttendanceStatus.late:
        c = AppColors.warning; label = 'Terlambat'; icon = Icons.schedule_rounded; break;
      case AttendanceStatus.absent:
        c = AppColors.danger; label = 'Absen'; icon = Icons.cancel_rounded; break;
      case AttendanceStatus.leave:
        c = AppColors.primary; label = 'Cuti'; icon = Icons.event_available_rounded; break;
      case AttendanceStatus.holiday:
        c = AppColors.teal; label = 'Libur'; icon = Icons.beach_access_rounded; break;
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
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: c, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDate(record.date),
                      style: AppText.body1.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    record.checkIn != null
                        ? 'Masuk: ${_fmtTime(record.checkIn)} · Keluar: ${_fmtTime(record.checkOut)}'
                        : label,
                    style: AppText.body2,
                  ),
                  if (record.lateMinutes != null && record.lateMinutes! > 0)
                    Text('Terlambat ${record.lateMinutes} menit',
                        style: AppText.caption.copyWith(color: AppColors.warning)),
                  if (record.overtimeMinutes != null && record.overtimeMinutes! > 0)
                    Text('Lembur ${record.overtimeMinutes} menit',
                        style: AppText.caption.copyWith(color: AppColors.primary)),
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
                      style: AppText.caption.copyWith(color: AppColors.primary)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
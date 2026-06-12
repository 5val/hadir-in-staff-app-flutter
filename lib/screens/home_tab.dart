import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:hadirin_staff_app/screens/account_tab.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import '../services/attendance_provider.dart';
import '../screens/camera_checkin_screen.dart';
import 'break_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'all_attendance_history_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToAccount;
  final AttendanceProvider attendance;

  const HomeTab({
    super.key,
    required this.onNavigateToAccount,
    required this.attendance,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final user = SampleData.currentUser;

  DateTime _now        = DateTime.now();
  Duration _workDur    = Duration.zero;
  Duration _breakDur   = Duration.zero;
  bool     _showMascot = false;
  String   _mascotMsg  = '';

  bool get _isWorkDay => true;

  AttendanceProvider get _att    => widget.attendance;
  AttendanceProviderStatus   get _status => _att.status;

  // Jam istirahat & checkout dari AttendanceRules
  bool get _canStartBreak => AttendanceRules.canStartBreak;      // 12:00–13:00
  bool get _canCheckout   => AttendanceRules.canCheckout;         // after 12:00

  // Location
  bool _locationChecked = false;
  bool _locationOn      = false;
  bool _fakeLocation    = false;
  bool _checkingLoc     = false;
  bool _locationInRange  = false;

  Timer? _clockTimer, _workTimer;

  static const _officeName    = 'Kantor Pusat Hadir-In';
  static const _officeAddress = 'Jl. Sudirman No. 1, Jakarta Pusat';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if ((_status == AttendanceProviderStatus.checkedIn ||
               _status == AttendanceProviderStatus.breakEnded) &&
          _att.checkInTime != null) {
        setState(() => _workDur = _now.difference(_att.checkInTime!));
      }
      if (_status == AttendanceProviderStatus.onBreak &&
          _att.breakStartTime != null) {
        setState(() => _breakDur = _now.difference(_att.breakStartTime!));
      }
    });
    _att.addListener(_onAttChanged);
    Future.delayed(const Duration(milliseconds: 800), _checkLocation);
  }

  void _onAttChanged() => setState(() {});

  @override
  void dispose() {
    _clockTimer?.cancel();
    _workTimer?.cancel();
    _att.removeListener(_onAttChanged);
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _fmtDur(Duration d) =>
      '${d.inHours.toString().padLeft(2,'0')}:'
      '${(d.inMinutes % 60).toString().padLeft(2,'0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2,'0')}';

  String _fmtHM(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2,'0')}';
  }

  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  bool get _isCheckedIn =>
      _status == AttendanceProviderStatus.checkedIn ||
      _status == AttendanceProviderStatus.onBreak   ||
      _status == AttendanceProviderStatus.breakEnded ||
      _status == AttendanceProviderStatus.checkedOut;

  // ── Greeting ──────────────────────────────────────────────────
  String get _greetingMsg {
    final h = _now.hour;
    if (_status == AttendanceProviderStatus.checkedOut) return 'Kerja hari ini selesai. Sampai besok! 🌙';
    if (_status == AttendanceProviderStatus.checkedIn || _status == AttendanceProviderStatus.breakEnded)
      return 'Kamu sudah check-in. Semangat terus! 💪';
    if (_status == AttendanceProviderStatus.onBreak) return 'Selamat beristirahat! Kembali segar ya ☕';
    final shiftStart = DateTime(_now.year, _now.month, _now.day,
        user.currentShift.startTime.hour, user.currentShift.startTime.minute);
    if (_now.isAfter(shiftStart.add(const Duration(minutes: 15))))
      return 'Kamu sudah terlambat! Segera check-in sekarang 🏃';
    if (h < 9) return 'Selamat pagi! Sudah siap memulai hari? 🌅';
    if (h < 12) return 'Selamat pagi! Waktunya check-in sekarang ⏰';
    if (h < 15) return 'Selamat siang! Jangan lupa check-in ya 🌤️';
    return 'Selamat sore! Segera check-in sebelum terlambat 🕐';
  }

  // ── Location check ─────────────────────────────────────────────
  Future<void> _checkLocation() async {
    setState(() => _checkingLoc = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _checkingLoc     = false;
      _locationChecked = true;
      _locationOn      = true;
      _fakeLocation    = false;
      _locationInRange  = Random().nextBool(); // Simulasi random lokasi
    });
  }

  // ── Camera navigation ─────────────────────────────────────────
  // ── Check-in detail state ──────────────────────────────────────
  String?   _checkInPhotoPath;
  String?   _checkInLocation;
  DateTime? _checkInDisplayTime;

  Future<void> _openCameraForCheckIn() async {
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCheckinScreen(
            actionType: CameraActionType.checkIn),
      ),
    );
    if (!mounted || result == null || !result.confirmed) return;
    _att.doCheckIn();
    setState(() {
      _checkInPhotoPath   = result.imagePath;
      _checkInLocation    = result.address ?? _officeAddress;
      _checkInDisplayTime = DateTime.now();
    });
    _showSnackbar('Check-in berhasil! Selamat bekerja 💪');
  }

  Future<void> _openCameraForCheckOut() async {
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCheckinScreen(
            actionType: CameraActionType.checkOut),
      ),
    );
    if (!mounted || result == null || !result.confirmed) return;
    _att.doCheckOut();
    setState(() {
      _showMascot = true;
      _mascotMsg  = 'Kerja hari ini selesai!\nGood job! 🎉';
    });
  }

  // ── Break ──────────────────────────────────────────────────────
  void _startBreak() {
    if (!_canStartBreak) {
      _showBreakNotAllowedSnackbar();
      return;
    }
    _att.startBreak();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreakScreen(onBreakEnd: () => _att.endBreak()),
      ),
    );
  }

  void _returnFromBreak() {
    _att.returnToWork();
    setState(() {
      _showMascot = true;
      _mascotMsg  = 'Selamat bekerja kembali! 💪\nLanjut produktif!';
    });
  }

  // ── Snackbars ──────────────────────────────────────────────────
  void _showSnackbar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: Colors.white)),
      backgroundColor: color ?? AppColors.brandNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showBreakNotAllowedSnackbar() {
    final now = DateTime.now();
    final breakStart = DateTime(now.year, now.month, now.day,
        AttendanceRules.breakStartHour, AttendanceRules.breakStartMinute);
    final isBeforeBreak = now.isBefore(breakStart);

    _showSnackbar(
      isBeforeBreak
          ? '⏰ Jam istirahat belum mulai. Istirahat tersedia pukul ${AttendanceRules.breakWindowLabel}.'
          : '✅ Jam istirahat sudah selesai (${AttendanceRules.breakWindowLabel}).',
      color: AppColors.warning,
    );
  }

  void _showCheckoutBlockedSnackbar() {
    _showSnackbar(
      '🕐 Check-out hanya tersedia setelah pukul '
      '${AttendanceRules.checkoutCutoffHour.toString().padLeft(2,'0')}:00 siang.',
      color: AppColors.slate700,
    );
  }

  // ── Logout ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: Text('Kamu perlu login ulang lain kali.', style: AppText.body2),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
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
          builder: (_) =>
              const LoginScreen(destination: LoginDestination.landing)),
      (r) => false,
    );
  }

  // ── SOS Call ──────────────────────────────────────────────────
  void _showSosDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded,
                  color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Hubungi Atasan',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.slate900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kamu akan menghubungi atasan langsung untuk situasi darurat atau mendesak.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.brandNavy, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Budi Santoso',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.slate900)),
                      Text('Supervisor · +62 812-3456-7890',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.slate700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.inter(color: AppColors.slate700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.call_rounded, size: 16),
            label: Text('Hubungi Sekarang',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.pop(context);
              _showSnackbar('📞 Menghubungi atasan...', color: AppColors.danger);
            },
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isCheckedOut = _status == AttendanceProviderStatus.checkedOut;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.slate50,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showSosDialog,
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.phone, size: 22),
            label: Text('SOS',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            elevation: 4,
          ),
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
                        const SizedBox(height: 8),
                        _buildLocationStatus(),
                        const SizedBox(height: 8),
                        if (_status == AttendanceProviderStatus.checkedIn ||
                            _status == AttendanceProviderStatus.onBreak ||
                            _status == AttendanceProviderStatus.breakEnded) ...[
                          _buildCurrentActivityCard(),
                          const SizedBox(height: 8),
                        ],
                        _buildAttendanceSection(),
                        if (_checkInDisplayTime != null &&
                            _status != AttendanceProviderStatus.notCheckedIn) ...[
                          const SizedBox(height: 14),
                          _buildCheckInDetailCard(),
                        ],
                        // Timeline hanya tampil jika belum checkout
                        if (_isWorkDay && !isCheckedOut) ...[
                          const SizedBox(height: 14),
                          _buildTimeline(),
                        ],
                        // const SizedBox(height: 14),
                        // _buildAttendanceHistoryPreview(),
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

  // ── Check-In Detail Card ───────────────────────────────────────
  Widget _buildCheckInDetailCard() {
    final time = _checkInDisplayTime;
    if (time == null) return const SizedBox.shrink();
    final timeStr = '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(time);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandLime.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandLime.withOpacity(0.15),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.brandLime.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandLimeDark, size: 16),
              ),
              const SizedBox(width: 8),
              Text('DETAIL CHECK-IN',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: AppColors.brandLimeDark, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto preview
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: _checkInPhotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: kIsWeb
                            ? Image.network(
                                _checkInPhotoPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.slate400, size: 32),
                              )
                            : Image.file(
                                File(_checkInPhotoPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.slate400, size: 32),
                              ),
                      )
                    : const Icon(Icons.person_rounded,
                        color: AppColors.slate400, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waktu
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppColors.slate400),
                        const SizedBox(width: 5),
                        Text('$timeStr · $dateStr',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: AppColors.slate700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Lokasi
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppColors.slate400),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_officeName,
                                  style: GoogleFonts.inter(
                                      fontSize: 11, fontWeight: FontWeight.w700,
                                      color: AppColors.slate800)),
                              Text(_checkInLocation ?? _officeAddress,
                                  style: GoogleFonts.inter(
                                      fontSize: 10, color: AppColors.slate700),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.brandLime.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('✓  TERVERIFIKASI',
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: AppColors.brandLimeDark, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: AppColors.brandNavy,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Image.asset(
            AppAssets.logoIcon,
            height: 28,
            // color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text('Hadir-In',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white)),
          const Spacer(),
          IconButton(
                icon: const Icon(Icons.history_outlined,
                    color: AppColors.white, size: 22),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AttendanceHistoryFullScreen())),
              ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.white, size: 22),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationScreen())),
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

  // ── Header Info ───────────────────────────────────────────────
  Widget _buildHeaderInfo() {
    final isLateAndNotCheckedIn = _status == AttendanceProviderStatus.notCheckedIn &&
        _now.isAfter(DateTime(_now.year, _now.month, _now.day,
            user.currentShift.startTime.hour,
            user.currentShift.startTime.minute + 15));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WELCOME BACK',
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.brandNavy, letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(user.name,
            style: GoogleFonts.inter(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: AppColors.slate900)),
        Text(user.position.name, style: AppText.body2),
        const SizedBox(height: 10),
        if (_isWorkDay)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _status == AttendanceProviderStatus.checkedOut
                  ? AppColors.brandNavy.withOpacity(0.06)
                  : (isLateAndNotCheckedIn
                      ? AppColors.danger.withOpacity(0.07)
                      : AppColors.brandLime.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  _status == AttendanceProviderStatus.checkedOut
                      ? '🌙'
                      : (isLateAndNotCheckedIn ? '🚨' : '👋'),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_greetingMsg,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: AppColors.slate800)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Location Status ───────────────────────────────────────────
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
            const Icon(Icons.gps_not_fixed_rounded,
                color: AppColors.slate400, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Lokasi belum diperiksa', style: AppText.body2)),
            TextButton(onPressed: _checkLocation, child: const Text('Periksa')),
          ],
        ),
      );
    }
    if (!_locationOn) {
      return SectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.gps_off_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text('GPS tidak aktif. Aktifkan GPS untuk check-in.',
                    style: AppText.body2)),
            TextButton(onPressed: _checkLocation, child: const Text('Aktifkan')),
          ],
        ),
      );
    }
    if (_fakeLocation) {
      return SectionCard(
        color: AppColors.danger.withOpacity(0.06),
        borderColor: AppColors.danger.withOpacity(0.3),
        padding: const EdgeInsets.all(14),
        child: const Row(
          children: [
            Icon(Icons.gps_off_rounded, color: AppColors.danger, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fake location terdeteksi!',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger, fontSize: 13)),
                  Text('Matikan aplikasi mock GPS untuk melanjutkan.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.slate600)),
                ],
              ),
            ),
          ],
        ),
      );
    }
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
                      decoration: BoxDecoration(
                          color: _locationInRange
                              ? AppColors.brandLimeDark
                              : AppColors.danger,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                        _locationInRange
                            ? 'TERVERIFIKASI · DALAM AREA'
                            : 'DI LUAR JANGKAUAN AREA',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _locationInRange
                                ? AppColors.brandLimeDark
                                : AppColors.danger,
                            letterSpacing: 0.5)),
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

  // ── Current Activity Card ─────────────────────────────────────
  Widget _buildCurrentActivityCard() {
    final isBreak      = _status == AttendanceProviderStatus.onBreak;
    final isBreakEnded = _status == AttendanceProviderStatus.breakEnded;

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
              Text(isBreak ? '☕' : (isBreakEnded ? '💪' : '⏱️'),
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                isBreak
                    ? 'ISTIRAHAT AKTIF'
                    : (isBreakEnded ? 'SELESAI ISTIRAHAT' : 'AKTIVITAS SAAT INI'),
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: isBreak ? AppColors.warning : AppColors.brandNavy,
                    letterSpacing: 1.0),
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
                  child: Text('LIVE',
                      style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: isBreak
                              ? AppColors.warning
                              : AppColors.brandLimeDark)),
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
                  Text('Waktu Kerja', style: AppText.caption),
                  Text(_fmtDur(_workDur),
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: AppColors.slate900)),
                ],
              ),
              if (isBreak || isBreakEnded)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Waktu Istirahat', style: AppText.caption),
                    Text(_fmtDur(_breakDur),
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 22, fontWeight: FontWeight.w700,
                            color: AppColors.warning)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Attendance Section ────────────────────────────────────────
  Widget _buildAttendanceSection() {
    final canGpsAction = _locationOn &&
        !_fakeLocation &&
        _locationChecked &&
        _locationInRange;

    switch (_status) {
      // ── Belum check-in ────────────────────────────────────────
      case AttendanceProviderStatus.notCheckedIn:
        if (!_isWorkDay) {
          return SectionCard(
            color: AppColors.warning.withOpacity(0.07),
            borderColor: AppColors.warning.withOpacity(0.3),
            child: Column(
              children: [
                const Icon(Icons.weekend_rounded,
                    color: AppColors.warning, size: 36),
                const SizedBox(height: 8),
                Text('Hari Libur',
                    style: AppText.headline3.copyWith(color: AppColors.warning)),
                const SizedBox(height: 4),
                Text('Check-in hanya tersedia pada hari kerja (Senin–Jumat)',
                    style: AppText.body2, textAlign: TextAlign.center),
              ],
            ),
          );
        }
        // Setelah jam 12: check-in tidak diizinkan, tampilkan pesan
        if (_canCheckout) {
          return _buildCheckinBlockedAfterNoon();
        }
        return _buildCheckinCard(canGpsAction);

      // ── Sudah check-in ────────────────────────────────────────
      case AttendanceProviderStatus.checkedIn:
        final checkoutActive = _canCheckout && canGpsAction;
        // final checkoutActive = true;
        final breakActive    = _canStartBreak;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Check-Out button
            GestureDetector(
              onTap: checkoutActive ? _openCameraForCheckOut : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: checkoutActive ? AppColors.brandNavy : AppColors.slate200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: checkoutActive ? Colors.white : AppColors.slate400,
                        size: 28),
                    const SizedBox(height: 8),
                    Text('Check-Out',
                        style: GoogleFonts.inter(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: checkoutActive
                                ? Colors.white : AppColors.slate700)),
                    const SizedBox(height: 4),
                    if (checkoutActive && !_canCheckout)
                      Text('Tersedia setelah pukul ${AttendanceRules.checkoutCutoffHour.toString().padLeft(2, '0')}:00',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: checkoutActive
                              ? Colors.white.withOpacity(0.75)
                              : AppColors.slate400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Istirahat / Break button
            _buildBreakButton(breakActive),
          ],
        );

      // ── Sedang istirahat ──────────────────────────────────────
      case AttendanceProviderStatus.onBreak:
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
                    Text('Jam istirahat: ${AttendanceRules.breakWindowLabel}',
                        style: AppText.body2),
                  ],
                ),
              ),
              TextButton(onPressed: _startBreak, child: const Text('Buka')),
            ],
          ),
        );

      // ── Istirahat selesai ─────────────────────────────────────
      case AttendanceProviderStatus.breakEnded:
        final checkoutActive = _canCheckout && canGpsAction;
        return Column(
          children: [
            GradientButton(
              label: '▶  Kembali Bekerja',
              color: AppColors.brandLimeDark,
              height: 52,
              onTap: _returnFromBreak,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: checkoutActive ? _openCameraForCheckOut : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: checkoutActive
                      ? const Color(0xFFB01E1E)
                      : AppColors.slate200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('Check-Out Sekarang',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: checkoutActive
                              ? Colors.white : AppColors.slate700)),
                ),
              ),
            ),
          ],
        );

      // ── Sudah check-out ───────────────────────────────────────
      case AttendanceProviderStatus.checkedOut:
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

  // ── Break button dengan jam window ────────────────────────────
  Widget _buildBreakButton(bool breakActive) {
    // Tentukan pesan hint berdasarkan jam
    final String hint;
    if (AttendanceRules.isBeforeBreakTime) {
      hint = 'Istirahat tersedia pukul ${AttendanceRules.breakWindowLabel}';
    } else if (AttendanceRules.isAfterBreakTime) {
      hint = 'Jam istirahat sudah lewat (${AttendanceRules.breakWindowLabel})';
    } else {
      hint = 'Jam istirahat: ${AttendanceRules.breakWindowLabel}';
    }

    return Tooltip(
      message: !breakActive ? hint : '',
      child: GestureDetector(
        onTap: breakActive ? _startBreak : () => _showBreakNotAllowedSnackbar(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: breakActive ? AppColors.brandLimeDark : AppColors.slate50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: breakActive ? AppColors.slate200 : AppColors.slate100,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.free_breakfast_rounded,
                    color: breakActive
                        ? AppColors.slate50
                        : AppColors.slate700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Istirahat / Break',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: breakActive
                            ? AppColors.slate50
                            : AppColors.slate700),
                  ),
                  if (!breakActive) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_rounded,
                        size: 12, color: AppColors.slate50),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: breakActive
                        ? AppColors.slate50
                        : AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Check-in Blocked (setelah jam 12) ─────────────────────────
  Widget _buildCheckinBlockedAfterNoon() {
    final canGpsAction = _locationOn &&
        !_fakeLocation &&
        _locationChecked &&
        _locationInRange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.slate200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE8E8E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block_rounded,
                color: AppColors.slate400, size: 20),
          ),
          const SizedBox(height: 6),
          Text('Check-In Tidak Tersedia',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.slate700)),
          const SizedBox(height: 6),
          Text(
            'Sudah lewat pukul 12:00 siang',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.slate700,
                height: 1.5),
          ),
          const SizedBox(height: 12),
                GestureDetector(
                  onTap: canGpsAction ? _openCameraForCheckOut : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: canGpsAction
                          ? AppColors.brandNavy
                          : AppColors.slate300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon(Icons.logout_rounded,
                        //     color: canGpsAction
                        //         ? Colors.white
                        //         : AppColors.slate700,
                        //     size: 18),
                        // const SizedBox(width: 8),
                        Text(
                          'Check-Out',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: canGpsAction
                                  ? Colors.white
                                  : AppColors.slate700),
                        ),
                      ],
                    ),
                  ),
                ),
          // const SizedBox(height: 6),
          // ── Arahkan ke checkout jika belum checkin tapi sudah lewat jam 12 ──
          // Tunjukkan info bahwa seharusnya mereka melakukan checkout
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.all(14),
          //   decoration: BoxDecoration(
          //     color: AppColors.brandNavy.withOpacity(0.07),
          //     borderRadius: BorderRadius.circular(14),
          //     border: Border.all(color: AppColors.brandNavy.withOpacity(0.2)),
          //   ),
          //   child: Column(
          //     children: [
          //       Row(
          //         mainAxisAlignment: MainAxisAlignment.center,
          //         children: [
          //           const Icon(Icons.info_outline_rounded,
          //               size: 16, color: AppColors.brandNavy),
          //           const SizedBox(width: 6),
          //           Text(
          //             'Sudah ada di kantor?',
          //             style: GoogleFonts.inter(
          //                 fontSize: 13, fontWeight: FontWeight.w700,
          //                 color: AppColors.brandNavy),
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 6),
          //       Text(
          //         'Jika kamu sudah hadir sebelumnya, langsung lakukan check-out untuk merekam kepulangan.',
          //         textAlign: TextAlign.center,
          //         style: GoogleFonts.inter(
          //             fontSize: 11, color: AppColors.slate600, height: 1.4),
          //       ),
                
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   decoration: BoxDecoration(
          //     color: AppColors.textSecondary.withOpacity(0.12),
          //     borderRadius: BorderRadius.circular(20),
          //     border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
          //   ),
          //   child: Text(
          //     'Hubungi HRD jika ada kendala',
          //     style: GoogleFonts.inter(
          //         fontSize: 12, fontWeight: FontWeight.w600,
          //         color: AppColors.textSecondary),
          //   ),
          // ),
        ],
      ),
    );
  }

  // ── Check-in Card ─────────────────────────────────────────────
  Widget _buildCheckinCard(bool canAction) {
    return GestureDetector(
      onTap: canAction ? _openCameraForCheckIn : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: canAction ? AppColors.brandNavy : AppColors.slate300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: canAction ? AppColors.brandLime : AppColors.slate200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fingerprint_rounded,
                  color: canAction ? AppColors.brandNavyDark : AppColors.slate700,
                  size: 40),
            ),
            const SizedBox(height: 14),
            Text('Check-In',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            // const SizedBox(height: 4),
            // Text(
            //   canAction
            //       ? 'Sudah di sini? Tap untuk check-in 👇'
            //       : 'Aktifkan GPS untuk mulai check-in',
            //   style: GoogleFonts.inter(
            //       fontSize: 13, color: Colors.white.withOpacity(0.75)),
            // ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${user.currentShift.name} · '
                '${user.currentShift.startTimeStr} – ${user.currentShift.endTimeStr}',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's Timeline (2×2 Grid) ──────────────────────────────
  Widget _buildTimeline() {
    final hasBreak   = _att.breakStartTime != null;
    final isOnBreak  = _status == AttendanceProviderStatus.onBreak;
    final breakDone  = _status == AttendanceProviderStatus.breakEnded;

    // Hitung jam kerja tampilan
    final workHours  = _workDur.inHours;
    final workMins   = _workDur.inMinutes % 60;
    final workLabel  = _workDur.inMinutes > 0
        ? '${workHours}j ${workMins}m'
        : '--';

    // Durasi istirahat
    final breakLabel = hasBreak
        ? (isOnBreak
            ? _fmtDur(_breakDur)
            : '${_breakDur.inMinutes}m')
        : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline Hari Ini',
            style: AppText.headline3.copyWith(color: AppColors.slate900)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            // ── Check-In ──────────────────────────────────
            _TimelineGridCard(
              icon: Icons.login_rounded,
              iconColor: _isCheckedIn ? AppColors.brandLimeDark : AppColors.slate400,
              iconBg: _isCheckedIn
                  ? AppColors.brandLime.withOpacity(0.18) : AppColors.slate100,
              label: 'Check-In',
              value: (_isCheckedIn && _att.checkInTime != null)
                  ? _fmtHM24(_att.checkInTime!) : '--:--',
              sub: _isCheckedIn ? 'Kehadiran tercatat' : 'Belum check-in',
              badge: _isCheckedIn ? 'HADIR' : 'MENUNGGU',
              badgeColor: _isCheckedIn ? AppColors.brandLimeDark : AppColors.slate400,
              badgeBg: _isCheckedIn
                  ? AppColors.brandLime.withOpacity(0.15) : AppColors.slate100,
            ),
            // ── Check-Out ─────────────────────────────────
            // _TimelineGridCard(
            //   icon: Icons.logout_rounded,
            //   iconColor: _status == AttendanceProviderStatus.checkedOut
            //       ? AppColors.brandNavy : AppColors.slate400,
            //   iconBg: _status == AttendanceProviderStatus.checkedOut
            //       ? AppColors.brandNavy.withOpacity(0.1) : AppColors.slate100,
            //   label: 'Check-Out',
            //   value: _att.checkOutTime != null
            //       ? _fmtHM24(_att.checkOutTime!) : '--:--',
            //   sub: _status == AttendanceProviderStatus.checkedOut
            //       ? 'Selesai hari ini' : 'Terjadwal: ${user.currentShift.endTimeStr}',
            //   badge: _status == AttendanceProviderStatus.checkedOut
            //       ? 'SELESAI' : 'TERJADWAL',
            //   badgeColor: _status == AttendanceProviderStatus.checkedOut
            //       ? AppColors.brandNavy : AppColors.slate400,
            //   badgeBg: _status == AttendanceProviderStatus.checkedOut
            //       ? AppColors.brandNavy.withOpacity(0.1) : AppColors.slate100,
            // ),
            // ── Istirahat ─────────────────────────────────
            _TimelineGridCard(
              icon: Icons.free_breakfast_rounded,
              iconColor: isOnBreak
                  ? AppColors.warning
                  : (breakDone ? AppColors.brandLimeDark : AppColors.slate400),
              iconBg: isOnBreak
                  ? AppColors.warning.withOpacity(0.15)
                  : (breakDone
                      ? AppColors.brandLime.withOpacity(0.15) : AppColors.slate100),
              label: 'Istirahat',
              value: _att.breakStartTime != null
                  ? _fmtHM24(_att.breakStartTime!) : '--:--',
              sub: isOnBreak
                  ? 'Sedang istirahat'
                  : (breakDone
                      ? 'Durasi: $breakLabel'
                      : AttendanceRules.breakWindowLabel),
              badge: isOnBreak ? 'LIVE' : (breakDone ? 'SELESAI' : 'JAM ${AttendanceRules.breakWindowLabel.split(' ').first}'),
              badgeColor: isOnBreak
                  ? AppColors.warning
                  : (breakDone ? AppColors.brandLimeDark : AppColors.slate400),
              badgeBg: isOnBreak
                  ? AppColors.warning.withOpacity(0.12)
                  : (breakDone
                      ? AppColors.brandLime.withOpacity(0.12) : AppColors.slate100),
            ),
            // ── Jam Kerja ─────────────────────────────────
            _TimelineGridCard(
              icon: Icons.timer_rounded,
              iconColor: _workDur.inMinutes > 0
                  ? AppColors.brandCyanDark : AppColors.slate400,
              iconBg: _workDur.inMinutes > 0
                  ? AppColors.brandCyan.withOpacity(0.15) : AppColors.slate100,
              label: 'Jam Kerja',
              value: workLabel,
              sub: _workDur.inMinutes > 0
                  ? 'Waktu kerja aktif' : 'Belum mulai bekerja',
              badge: _workDur.inMinutes > 0 ? 'LIVE' : '-',
              badgeColor: _workDur.inMinutes > 0
                  ? AppColors.brandCyanDark : AppColors.slate400,
              badgeBg: _workDur.inMinutes > 0
                  ? AppColors.brandCyan.withOpacity(0.12) : AppColors.slate100,
            ),
          ],
        ),
      ],
    );
  }

  // ── Attendance History Preview (home - navigate to full page) ─
  Widget _buildAttendanceHistoryPreview() {
    final history = SampleData.recentAttendance.take(3).toList();
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
                  MaterialPageRoute(builder: (_) => const AttendanceHistoryFullScreen())),
              child: Text('Lihat Semua',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.brandNavy, letterSpacing: 0.3)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: history.map((rec) { // Keep the existing logic for the preview
              final isHoliday = rec.status == AttendanceStatus.holiday;
              final isLate = !isHoliday && rec.checkIn != null &&
                  rec.checkIn!.hour > user.currentShift.startTime.hour; // Only late if not holiday
              final absent = !isHoliday && rec.checkIn == null; // Only absent if not holiday

              Color statusColor;
              Color statusBg;
              String statusLabel;

              if (isHoliday) {
                statusColor = AppColors.brandNavy;
                statusBg = AppColors.brandNavy.withOpacity(0.08);
                statusLabel = 'LIBUR';
              } else if (absent) {
                statusColor = AppColors.danger;
                statusBg = AppColors.danger.withOpacity(0.08);
                statusLabel = 'ABSEN';
              } else if (isLate) {
                statusColor = AppColors.warning;
                statusBg = AppColors.warning.withOpacity(0.08);
                statusLabel = 'TERLAMBAT';
              } else {
                statusColor = AppColors.brandLimeDark;
                statusBg = AppColors.brandLime.withOpacity(0.15);
                statusLabel = 'TEPAT WAKTU';
              }

              // If it's a holiday, check-in/out times are not relevant
              final checkInTime = isHoliday ? '--:--' : (rec.checkIn != null ? _fmtHM24(rec.checkIn!) : '--:--');
              final checkOutTime = isHoliday ? '--:--' : (rec.checkOut != null ? _fmtHM24(rec.checkOut!) : '--:--');


              // Hitung total jam kerja
              String totalWork = '--:--';
              if (rec.checkIn != null && rec.checkOut != null) {
                final dur = rec.checkOut!.difference(rec.checkIn!);
                totalWork = '${dur.inHours.toString().padLeft(2,'0')}:${(dur.inMinutes % 60).toString().padLeft(2,'0')}';
              }

              // Tanggal
              final day = DateFormat('d', 'id_ID').format(rec.date);
              final dayName = DateFormat('EEE', 'id_ID').format(rec.date).toUpperCase();
              final monthYear = DateFormat('MMM', 'id_ID').format(rec.date);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate100),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate200.withOpacity(0.5),
                      blurRadius: 4, offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // ── Tanggal kotak ─────────────────────────
                      Container(
                        width: 48, height: 52,
                        decoration: BoxDecoration( // Use the new status colors
                          color: isHoliday
                              ? AppColors.brandNavy.withOpacity(0.08)
                              : (absent ? AppColors.danger.withOpacity(0.08) : AppColors.brandNavy),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dayName,
                                style: GoogleFonts.inter(
                                    fontSize: 8, fontWeight: FontWeight.w700,
                                    color: isHoliday
                                        ? AppColors.brandNavy.withOpacity(0.6)
                                        : (absent ? AppColors.danger.withOpacity(0.6) : Colors.white.withOpacity(0.7)),
                                    letterSpacing: 0.5)),
                            Text(day,
                                style: GoogleFonts.inter(
                                    fontSize: 20, fontWeight: FontWeight.w800,
                                    color: isHoliday ? AppColors.brandNavy : (absent ? AppColors.danger : Colors.white),
                                    height: 1.0)),
                            Text(monthYear,
                                style: GoogleFonts.inter(
                                    fontSize: 8,
                                    color: isHoliday
                                        ? AppColors.brandNavy.withOpacity(0.5)
                                        : (absent ? AppColors.danger.withOpacity(0.5) : Colors.white.withOpacity(0.55)))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ── Info waktu ────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [ // Adjust content based on holiday status
                            if (!isHoliday && !absent) ...[
                              Row(
                                children: [
                                  _HistoryTimeCol(
                                    label: 'Check In',
                                    value: checkInTime,
                                  ),
                                  const SizedBox(width: 14),
                                  _HistoryTimeCol(
                                    label: 'Check Out',
                                    value: checkOutTime,
                                  ),
                                  const SizedBox(width: 14),
                                  _HistoryTimeCol(
                                    label: 'Total Jam',
                                    value: totalWork,
                                    highlight: true,
                                  ),
                                ],
                              ),
                            ] else if (isHoliday) ...[
                              Text('Hari Libur', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.brandNavy)),
                            ] else if (absent) ...[
                              Text('Tidak Hadir',
                                  style: GoogleFonts.inter(
                                      fontSize: 14, fontWeight: FontWeight.w700, // This is for absent
                                      color: AppColors.danger)),
                            ],
                            const SizedBox(height: 6),
                            // Baris 2: Lokasi
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 11, color: AppColors.slate400),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text( // Adjust location text for holiday
                                    isHoliday ? 'Tidak ada aktivitas' : 'Office, West Jakarta, Indonesia',
                                    style: GoogleFonts.inter(
                                        fontSize: 10, color: AppColors.slate400),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Status badge ──────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(statusLabel,
                            style: GoogleFonts.inter(
                                fontSize: 8, fontWeight: FontWeight.w800,
                                color: statusColor, letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Timeline Grid Card (2×2) ──────────────────────────────────────
class _TimelineGridCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor, iconBg;
  final String   label, value, sub, badge;
  final Color    badgeColor, badgeBg;

  const _TimelineGridCard({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.label, required this.value, required this.sub,
    required this.badge, required this.badgeColor, required this.badgeBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate200.withOpacity(0.4),
            blurRadius: 4, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge,
                    style: GoogleFonts.inter(
                        fontSize: 7, fontWeight: FontWeight.w800,
                        color: badgeColor, letterSpacing: 0.3)),
              ),
            ],
          ),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.slate900, height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.slate700)),
          Text(sub,
              style: GoogleFonts.inter(
                  fontSize: 9, color: AppColors.slate400),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── History Time Column ───────────────────────────────────────────
class _HistoryTimeCol extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _HistoryTimeCol({
    required this.label, required this.value, this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: AppColors.slate400, letterSpacing: 0.3)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: highlight ? AppColors.brandNavy : AppColors.slate800)),
      ],
    );
  }
}

class _ProfileQuickView extends StatelessWidget {
  const _ProfileQuickView();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Profile')));
}

// ── Full Attendance History Screen ────────────────────────────────
class AttendanceHistoryFullScreen extends StatefulWidget {
  const AttendanceHistoryFullScreen({super.key});
  @override
  State<AttendanceHistoryFullScreen> createState() =>
      _AttendanceHistoryFullScreenState();
}

class _AttendanceHistoryFullScreenState
    extends State<AttendanceHistoryFullScreen> {
  final _user = SampleData.currentUser;

  // Batas 3 bulan terakhir
  late final DateTime _cutoff;
  late final List<_HistoryDay> _days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cutoff = DateTime(now.year, now.month - 2, 1); // 3 bulan terakhir
    _days = _buildDayList(now);
  }

  List<_HistoryDay> _buildDayList(DateTime now) {
    final List<_HistoryDay> result = [];
    // Dari hari ini mundur ke cutoff
    DateTime cursor = DateTime(now.year, now.month, now.day);
    while (!cursor.isBefore(_cutoff)) {
      final weekday = cursor.weekday; // 6=Sat, 7=Sun
      final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;

      if (isWeekend) {
        result.add(_HistoryDay(date: cursor, isWeekend: true, record: null));
      } else {
        // Cari record dari SampleData
        final rec = SampleData.recentAttendance.cast<AttendanceRecord?>()
            .firstWhere(
              (r) => r != null &&
                  r.date.year == cursor.year &&
                  r.date.month == cursor.month &&
                  r.date.day == cursor.day,
              orElse: () => null,
            );
        result.add(_HistoryDay(date: cursor, isWeekend: false, record: rec));
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return result;
  }

  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    // Group by month for section headers
    final Map<String, List<_HistoryDay>> grouped = {};
    for (final day in _days) {
      final key = DateFormat('MMMM yyyy', 'id_ID').format(day.date);
      grouped.putIfAbsent(key, () => []).add(day);
    }

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text('Riwayat Kehadiran',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: Colors.white)),
        // bottom: PreferredSize(
        //   preferredSize: const Size.fromHeight(36),
        //   child: Container(
        //     color: AppColors.brandNavy,
        //     padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        //     child: Row(
        //       children: [
        //         const Icon(Icons.history_rounded,
        //             size: 13, color: Colors.white54),
        //         const SizedBox(width: 5),
        //         Text(
        //           '3 bulan terakhir · ${DateFormat('d MMM', 'id_ID').format(_cutoff)} – sekarang',
        //           style: GoogleFonts.inter(
        //               fontSize: 11, color: Colors.white60),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  entry.key.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: AppColors.brandNavy, letterSpacing: 1.2),
                ),
              ),
              ...entry.value.map((day) => _buildDayTile(day)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayTile(_HistoryDay day) {
    final rec       = day.record;
    final isWeekend = day.isWeekend;
    final isHoliday = rec?.status == AttendanceStatus.holiday;
    final isLibur   = isWeekend || isHoliday;
    final absent    = !isLibur && rec == null;
    final isLate    = !isLibur && !absent && rec!.checkIn != null &&
        rec.checkIn!.hour > _user.currentShift.startTime.hour;

    // Status
    final String statusLabel;
    final Color  statusColor, statusBg;
    if (isWeekend) {
      statusLabel = 'LIBUR';
      statusColor = AppColors.brandNavy;
      statusBg    = AppColors.brandNavy.withOpacity(0.08);
    } else if (isHoliday) {
      statusLabel = 'LIBUR';
      statusColor = AppColors.brandNavy;
      statusBg    = AppColors.brandNavy.withOpacity(0.08);
    } else if (absent) {
      statusLabel = 'ABSEN';
      statusColor = AppColors.danger;
      statusBg    = AppColors.danger.withOpacity(0.08);
    } else if (isLate) {
      statusLabel = 'TERLAMBAT';
      statusColor = AppColors.warning;
      statusBg    = AppColors.warning.withOpacity(0.08);
    } else {
      statusLabel = 'TEPAT WAKTU';
      statusColor = AppColors.brandLimeDark;
      statusBg    = AppColors.brandLime.withOpacity(0.15);
    }

    final dayName  = DateFormat('EEE', 'id_ID').format(day.date).toUpperCase();
    final dayNum   = DateFormat('d', 'id_ID').format(day.date);
    final monthStr = DateFormat('MMM', 'id_ID').format(day.date);

    final checkInStr  = rec?.checkIn  != null ? _fmtHM24(rec!.checkIn!)  : '--:--';
    final checkOutStr = rec?.checkOut != null ? _fmtHM24(rec!.checkOut!) : '--:--';
    String totalWork = '--:--';
    if (rec?.checkIn != null && rec?.checkOut != null) {
      final dur = rec!.checkOut!.difference(rec.checkIn!);
      totalWork = '${dur.inHours.toString().padLeft(2,'0')}:${(dur.inMinutes % 60).toString().padLeft(2,'0')}';
    }

    final dateBoxColor = isLibur
        ? AppColors.brandNavy.withOpacity(0.08)
        : (absent ? AppColors.danger.withOpacity(0.08) : AppColors.brandNavy);
    final dateTextColor = isLibur
        ? AppColors.brandNavy
        : (absent ? AppColors.danger : Colors.white);
    final dateSubColor = isLibur
        ? AppColors.brandNavy.withOpacity(0.5)
        : (absent ? AppColors.danger.withOpacity(0.5) : Colors.white.withOpacity(0.55));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate200.withOpacity(0.5),
            blurRadius: 4, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Date box
            Container(
              width: 48, height: 52,
              decoration: BoxDecoration(
                color: dateBoxColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName,
                      style: GoogleFonts.inter(
                          fontSize: 8, fontWeight: FontWeight.w700,
                          color: dateSubColor.withOpacity(0.8),
                          letterSpacing: 0.5)),
                  Text(dayNum,
                      style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: dateTextColor, height: 1.0)),
                  Text(monthStr,
                      style: GoogleFonts.inter(
                          fontSize: 8, color: dateSubColor)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLibur) ...[
                    Text(
                      isWeekend ? (day.date.weekday == DateTime.saturday ? 'Sabtu' : 'Minggu') : 'Hari Libur',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.brandNavy),
                    ),
                  ] else if (absent) ...[
                    Text('Tidak Hadir',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.danger)),
                  ] else ...[
                    Row(
                      children: [
                        _HistoryTimeCol(label: 'Check In',  value: checkInStr),
                        const SizedBox(width: 14),
                        _HistoryTimeCol(label: 'Check Out', value: checkOutStr),
                        const SizedBox(width: 14),
                        _HistoryTimeCol(label: 'Total Jam', value: totalWork, highlight: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: AppColors.slate400),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          isLibur
                              ? 'Tidak ada aktivitas'
                              : (absent ? '-' : 'Kantor Pusat Hadir-In, Jakarta'),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.slate400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: GoogleFonts.inter(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: statusColor, letterSpacing: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDay {
  final DateTime       date;
  final bool           isWeekend;
  final AttendanceRecord? record;
  const _HistoryDay({required this.date, required this.isWeekend, required this.record});
}
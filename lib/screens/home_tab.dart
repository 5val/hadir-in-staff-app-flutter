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
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../services/attendance_service.dart';
import '../services/calendar_service.dart';
import 'package:geolocator/geolocator.dart' show Position;
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

  DateTime _now = DateTime.now();
  bool _showMascot = false;
  String _mascotMsg = '';

  bool get _isWorkDay => true;

  AttendanceProvider get _att => widget.attendance;
  AttendanceProviderStatus get _status => _att.status;

  /// Durasi kerja & istirahat kini dihitung provider dari data DB
  /// (`Attendance.breakDurasi` + jam check-in server), bukan dari timer lokal
  /// yang dulu hanya menghitung `now - checkInTime` tanpa memotong istirahat.
  Duration get _workDur => _att.workDuration;
  Duration get _breakDur => _att.currentBreakDuration;

  /// Fase 8: istirahat tidak lagi dibatasi jendela jam karangan (dulu hanya
  /// aktif 12:00–13:00). Staff boleh istirahat kapan pun selama sudah
  /// check-in dan belum check-out — yang dicatat hanya DURASI-nya.
  bool get _canStartBreak =>
      _status == AttendanceProviderStatus.checkedIn ||
      _status == AttendanceProviderStatus.breakEnded;

  /// Check-out boleh dilakukan kapan pun setelah check-in.
  ///
  /// Dulu digerbangi `AttendanceRules.canCheckout` yang berpatokan
  /// `checkoutCutoffHour = 24` — artinya "setelah pukul 24", yang tidak
  /// pernah tercapai dalam satu hari kerja, sehingga tombol check-out
  /// praktis selalu mati dan teksnya berbunyi "Tersedia setelah pukul 24:00".
  bool get _canCheckout =>
      _status != AttendanceProviderStatus.notCheckedIn &&
      _status != AttendanceProviderStatus.checkedOut;

  // Location (GPS nyata — lihat _checkLocation)
  bool _locationChecked = false;
  bool _locationOn = false;
  /// Fase 8: kini benar-benar terisi, dari `Position.isMocked` milik
  /// geolocator (Android). Sebelumnya kartu peringatan "fake location
  /// terdeteksi" ada di UI tapi flag-nya tidak pernah di-set oleh siapa pun,
  /// jadi peringatan itu mustahil muncul.
  bool _fakeLocation = false;
  bool _checkingLoc = false;
  bool _locationInRange = false;
  String _locationMessage = '';
  Position? _lastPosition;

  /// Lokasi kerja staff dari database (nama + alamat), bukan teks hardcode.
  String get _officeName => AppSession.staff?.lokasiNama ?? 'Lokasi Kerja';
  String get _officeAddress => AppSession.staff?.lokasiAlamat ?? '-';

  Timer? _clockTimer, _workTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
    // Timer hanya memicu repaint; angkanya dihitung provider dari data DB.
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status != AttendanceProviderStatus.notCheckedIn &&
          _status != AttendanceProviderStatus.checkedOut) {
        setState(() {});
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
  /// Format rupiah sederhana (tanpa paket intl currency) — dipakai kartu
  /// uang makan yang angkanya datang dari `Attendance.uangMakan`.
  static String _rupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  String _fmtDur(Duration d) => '${d.inHours.toString().padLeft(2, '0')}:'
      '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _fmtHM(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  bool get _isCheckedIn =>
      _status == AttendanceProviderStatus.checkedIn ||
      _status == AttendanceProviderStatus.onBreak ||
      _status == AttendanceProviderStatus.breakEnded ||
      _status == AttendanceProviderStatus.checkedOut;

  // ── Greeting ──────────────────────────────────────────────────
  String get _greetingMsg {
    final h = _now.hour;
    if (_status == AttendanceProviderStatus.checkedOut)
      return 'Kerja hari ini selesai. Sampai besok! 🌙';
    if (_status == AttendanceProviderStatus.checkedIn ||
        _status == AttendanceProviderStatus.breakEnded)
      return 'Kamu sudah check-in. Semangat terus! 💪';
    if (_status == AttendanceProviderStatus.onBreak)
      return 'Selamat beristirahat! Kembali segar ya ☕';
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
  //
  // Fase 8 — dulu baris ini berbunyi:
  //     _locationInRange = Random().nextBool(); // Simulasi random lokasi
  // yang secara harfiah MENGUNDI apakah staff dianggap berada di kantor.
  // Sekarang koordinat asli dibaca dari GPS HP, lalu dibandingkan dengan
  // titik & radius Lokasi staff dari database.
  //
  // Perlu ditegaskan: hasil di sini hanya untuk TAMPILAN (mengaktifkan
  // tombol & memberi tahu staff kalau ia di luar area). Keputusan yang
  // mengikat dibuat SERVER saat check-in/check-out — app yang memutuskan
  // sendiri selalu bisa dilewati dengan memanggil API secara langsung.
  Future<void> _checkLocation() async {
    setState(() => _checkingLoc = true);

    final result = await LocationService.current();
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _checkingLoc = false;
        _locationChecked = true;
        _locationOn = false;
        _fakeLocation = false;
        _locationInRange = false;
        _lastPosition = null;
        _locationMessage = result.failure!.message;
      });
      return;
    }

    final pos = result.position!;
    final lat = AppSession.staff?.lokasiLatitude;
    final lng = AppSession.staff?.lokasiLongitude;
    final radius = AppSession.staff?.lokasiRadius ?? 100;

    // Staff tanpa lokasi kerja (mis. staff lapangan yang belum ditempatkan):
    // tidak ada geofence untuk dilanggar — server pun melewati pengecekannya.
    if (lat == null || lng == null) {
      setState(() {
        _checkingLoc = false;
        _locationChecked = true;
        _locationOn = true;
        _fakeLocation = pos.isMocked;
        _locationInRange = !pos.isMocked;
        _lastPosition = pos;
        _locationMessage = 'Lokasi kerja belum ditetapkan admin.';
      });
      return;
    }

    final distance = LocationService.distanceMeters(
      lat1: pos.latitude,
      lon1: pos.longitude,
      lat2: lat,
      lon2: lng,
    ).round();
    final inRange = distance <= radius + pos.accuracy.round().clamp(0, 50);

    setState(() {
      _checkingLoc = false;
      _locationChecked = true;
      _locationOn = true;
      _fakeLocation = pos.isMocked;
      _lastPosition = pos;
      _locationInRange = inRange && !pos.isMocked;
      _locationMessage = inRange
          ? 'Berada di area $_officeName (~$distance m dari titik kantor).'
          : 'Anda $distance m dari $_officeName, di luar radius $radius m.';
    });
  }

  // ── Camera navigation ─────────────────────────────────────────
  // ── Check-in detail state ──────────────────────────────────────
  String? _checkInPhotoPath;
  String? _checkInLocation;
  DateTime? _checkInDisplayTime;

  Future<void> _openCameraForCheckIn() async {
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            const CameraCheckinScreen(actionType: CameraActionType.checkIn),
      ),
    );
    if (!mounted || result == null || !result.confirmed) return;

    // Ambil fix GPS SEGAR tepat saat absen — bukan memakai hasil pengecekan
    // beberapa menit lalu, karena staff bisa saja sudah berpindah.
    final gps = await LocationService.current();
    if (!mounted) return;
    if (!gps.ok) {
      _showSnackbar(gps.failure!.message, color: AppColors.danger);
      return;
    }

    try {
      await _att.checkInRemote(
        fotoPath: result.imagePath,
        latitude: gps.position!.latitude,
        longitude: gps.position!.longitude,
        accuracy: gps.position!.accuracy,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Termasuk penolakan geofence dari server (HTTP 403) — pesannya sudah
      // menyebutkan jarak & radius, jadi ditampilkan apa adanya.
      _showSnackbar(e.message, color: AppColors.danger);
      return;
    }
    if (!mounted) return;
    setState(() {
      _checkInPhotoPath = result.imagePath;
      _checkInLocation = _att.today?.locationLabel ?? _officeAddress;
      _checkInDisplayTime = _att.checkInTime ?? DateTime.now();
    });
    _showSnackbar('Check-in berhasil! Selamat bekerja 💪');
    _checkLocation();
  }

  Future<void> _openCameraForCheckOut() async {
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            const CameraCheckinScreen(actionType: CameraActionType.checkOut),
      ),
    );
    if (!mounted || result == null || !result.confirmed) return;
    try {
      await _att.checkOutRemote(fotoPath: result.imagePath);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackbar(e.message, color: AppColors.danger);
      return;
    }
    if (!mounted) return;
    setState(() {
      _showMascot = true;
      _mascotMsg = 'Kerja hari ini selesai!\nGood job! 🎉';
    });
  }

  // ── Break ──────────────────────────────────────────────────────
  // Fase 8: istirahat tercatat di DB lewat endpoint break-in/break-out.
  // Sebelumnya hanya state di memori app: hilang begitu app ditutup, tidak
  // pernah sampai ke database, dan durasinya tidak masuk laporan mana pun.
  Future<void> _startBreak() async {
    if (!_canStartBreak) {
      _showBreakNotAllowedSnackbar();
      return;
    }
    try {
      await _att.startBreakRemote();
      if (!mounted) return;
      _showSnackbar('Istirahat dimulai, jangan lupa kembali!');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackbar(e.message, color: AppColors.danger);
    }
  }

  Future<void> _returnFromBreak() async {
    try {
      await _att.endBreakRemote();
      if (!mounted) return;
      setState(() {
        _showMascot = true;
        _mascotMsg = 'Selamat bekerja kembali! 💪\nTotal istirahat: '
            '${_att.breakMinutes} menit';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackbar(e.message, color: AppColors.danger);
    }
  }

  // ── Snackbars ──────────────────────────────────────────────────
  void _showSnackbar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: color ?? AppColors.brandNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showBreakNotAllowedSnackbar() {
    _showSnackbar(
      _status == AttendanceProviderStatus.notCheckedIn
          ? '⏰ Anda belum check-in hari ini.'
          : '✅ Anda sudah check-out hari ini.',
      color: AppColors.warning,
    );
  }

  void _showCheckoutBlockedSnackbar() {
    _showSnackbar('🕐 Anda belum check-in hari ini.',
        color: AppColors.slate700);
  }

  // ── Logout ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content:
            Text('Kamu perlu login ulang lain kali.', style: AppText.body2),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandLimeDark.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded,
                  color: AppColors.brandLimeDark, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Hubungi Admin/HR',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Kamu akan menghubungi admin/hr langsung untuk situasi darurat atau mendesak.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.slate600, height: 1.4)),
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
                    width: 38,
                    height: 38,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900)),
                      Text('Admin HR · +62 811-122-2333',
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
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.call_rounded, size: 16),
            label: Text('Hubungi WhatsApp',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.pop(context);
              _showSnackbar('🟢 Menghubungi via WhatsApp...',
                  color: const Color(0xFF25D366));
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
            backgroundColor: AppColors.brandLimeDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.phone, size: 22),
            label: Text('SOS',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
                            _status !=
                                AttendanceProviderStatus.notCheckedIn) ...[
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
  final timeStr =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandLimeDark,
                    letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FOTO PREVIEW (Rasio Dikunci ke 3/4) ──
            Container(
              width: 72, // Lebar tetap 72
              // height dihapus agar tingginya ditentukan secara alami oleh AspectRatio (72 * 4/3 = 96)
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
              ),
              child: AspectRatio(
                aspectRatio: 3 / 4, // <── KUNCINYA: Mengunci rasio portrait foto HP
                child: _checkInPhotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: kIsWeb
                            ? Image.network(
                                _checkInPhotoPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.slate400,
                                    size: 32),
                              )
                            : Image.file(
                                File(_checkInPhotoPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.slate400,
                                    size: 32),
                              ),
                      )
                    : const Icon(Icons.person_rounded,
                        color: AppColors.slate400, size: 32),
              ),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandLime.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('✓  TERVERIFIKASI',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandLimeDark,
                            letterSpacing: 0.5)),
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
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AllAttendanceHistoryScreen())),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.white, size: 22),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationScreen())),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 7,
                  height: 7,
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
    final isLateAndNotCheckedIn =
        _status == AttendanceProviderStatus.notCheckedIn &&
            _now.isAfter(DateTime(
                _now.year,
                _now.month,
                _now.day,
                user.currentShift.startTime.hour,
                user.currentShift.startTime.minute + 15));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WELCOME BACK',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.brandNavy,
                letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(user.name,
            style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
              width: 18,
              height: 18,
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
            TextButton(
                onPressed: _checkLocation, child: const Text('Aktifkan')),
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
                          color: AppColors.danger,
                          fontSize: 13)),
                  Text('Matikan aplikasi mock GPS untuk melanjutkan.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.slate600)),
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
            width: 38,
            height: 38,
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
                      width: 7,
                      height: 7,
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
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _locationInRange
                                ? AppColors.brandLimeDark
                                : AppColors.danger,
                            letterSpacing: 0.5)),
                  ],
                ),
                // Jarak nyata ke titik kantor (dari GPS + master Lokasi),
                // supaya staff tahu seberapa jauh ia harus mendekat.
                if (_locationMessage.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_locationMessage, style: AppText.caption),
                ],
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
    final isBreak = _status == AttendanceProviderStatus.onBreak;
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
                    : (isBreakEnded
                        ? 'SELESAI ISTIRAHAT'
                        : 'AKTIVITAS SAAT INI'),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isBreak ? AppColors.warning : AppColors.brandNavy,
                    letterSpacing: 1.0),
              ),
              const Spacer(),
              if (!isBreakEnded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isBreak
                        ? AppColors.warning.withOpacity(0.15)
                        : AppColors.brandLime.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('LIVE',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900)),
                ],
              ),
              if (isBreak || isBreakEnded)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Status Istirahat', style: AppText.caption),
                    Text(isBreak ? 'Sedang Istirahat' : 'Selesai',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
    // Pengingat check-out dibandingkan dengan jam pulang SHIFT staff dari
    // database (AttendanceRules dihidrasi dari kalender kerja), bukan lagi
    // konstanta `normalCheckoutHour = 24` yang tidak pernah tercapai.
    final showCheckoutReminder =
        _status != AttendanceProviderStatus.checkedOut &&
            _status != AttendanceProviderStatus.notCheckedIn &&
            AttendanceRules.isAfterNormalCheckout;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCheckoutReminder)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waktunya check-out! Jangan lupa absen pulang.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildAttendanceContent(),
      ],
    );
  }

  Widget _buildAttendanceContent() {
    final canGpsAction =
        _locationOn && _locationChecked && _locationInRange;

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
                    style:
                        AppText.headline3.copyWith(color: AppColors.warning)),
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
        final breakActive = _canStartBreak;

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
                  color:
                      checkoutActive ? AppColors.brandNavy : AppColors.slate200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        color:
                            checkoutActive ? Colors.white : AppColors.slate400,
                        size: 28),
                    const SizedBox(height: 8),
                    Text('Check-Out',
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: checkoutActive
                                ? Colors.white
                                : AppColors.slate700)),
                    const SizedBox(height: 4),
                    Text(
                      'Jam pulang shift: ${AttendanceRules.jamPulangLabel}',
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
                        style:
                            AppText.label.copyWith(color: AppColors.slate900)),
                    // Fase 8: yang ditampilkan DURASI, bukan jam istirahat —
                    // di database memang hanya durasi yang disimpan.
                    Text('Durasi: ${_fmtDur(_breakDur)}',
                        style: AppText.body2),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning),
                  onPressed: _returnFromBreak,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text('Break Out',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: checkoutActive
                              ? Colors.white
                              : AppColors.slate700)),
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

  // ── Tombol Break In ───────────────────────────────────────────
  //
  // Fase 8: tidak ada lagi jendela jam. Tombolnya aktif selama staff sudah
  // check-in & belum check-out; yang tercatat hanya durasinya.
  Widget _buildBreakButton(bool breakActive) {
    final hint = breakActive
        ? 'Tekan untuk mulai istirahat'
        : 'Anda belum check-in / sudah check-out';

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
                    color: breakActive ? AppColors.slate50 : AppColors.slate700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Istirahat / Break',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
                    color:
                        breakActive ? AppColors.slate50 : AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Check-in Blocked (setelah jam 12) ─────────────────────────
  Widget _buildCheckinBlockedAfterNoon() {
    final canGpsAction =
        _locationOn && _locationChecked && _locationInRange;
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
            width: 80,
            height: 80,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate700)),
          const SizedBox(height: 6),
          Text(
            'Sudah lewat pukul 12:00 siang',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.slate700, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: canGpsAction ? _openCameraForCheckOut : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: canGpsAction ? AppColors.brandNavy : AppColors.slate300,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            canGpsAction ? Colors.white : AppColors.slate700),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: canAction ? AppColors.brandLime : AppColors.slate200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt_outlined,
                  color:
                      canAction ? AppColors.brandNavyDark : AppColors.slate700,
                  size: 40),
            ),
            const SizedBox(height: 14),
            Text('Check-In',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
    final hasBreak = _att.breakMinutes > 0 || _att.isOnBreak;
    final isOnBreak = _status == AttendanceProviderStatus.onBreak;

    // Jam kerja tampilan. Fase 8: _workDur sudah bersih (dikurangi
    // istirahat) dan tidak pernah negatif, jadi tampilannya mulai dari
    // 00:00:00 saat baru check-in — bukan 24:00:00 seperti sebelumnya.
    final workHours = _workDur.inHours;
    final workMins = _workDur.inMinutes % 60;
    final workLabel = _att.checkInTime == null
        ? '--'
        : '${workHours}j ${workMins}m';

    // Durasi istirahat
    final breakLabel =
        hasBreak ? (isOnBreak ? _fmtDur(_breakDur) : '${_breakDur.inMinutes}m') : '--';

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
              iconColor:
                  _isCheckedIn ? AppColors.brandLimeDark : AppColors.slate400,
              iconBg: _isCheckedIn
                  ? AppColors.brandLime.withOpacity(0.18)
                  : AppColors.slate100,
              label: 'Check-In',
              value: (_isCheckedIn && _att.checkInTime != null)
                  ? _fmtHM24(_att.checkInTime!)
                  : '--:--',
              sub: _isCheckedIn ? 'Kehadiran tercatat' : 'Belum check-in',
              badge: _isCheckedIn ? 'HADIR' : 'MENUNGGU',
              badgeColor:
                  _isCheckedIn ? AppColors.brandLimeDark : AppColors.slate400,
              badgeBg: _isCheckedIn
                  ? AppColors.brandLime.withOpacity(0.15)
                  : AppColors.slate100,
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
            // _TimelineGridCard(
            //   icon: Icons.free_breakfast_rounded,
            //   iconColor: isOnBreak
            //       ? AppColors.warning
            //       : (breakDone ? AppColors.brandLimeDark : AppColors.slate400),
            //   iconBg: isOnBreak
            //       ? AppColors.warning.withOpacity(0.15)
            //       : (breakDone
            //           ? AppColors.brandLime.withOpacity(0.15)
            //           : AppColors.slate100),
            //   label: 'Istirahat',
            //   value: _att.breakStartTime != null
            //       ? _fmtHM24(_att.breakStartTime!)
            //       : '--:--',
            //   sub: isOnBreak
            //       ? 'Sedang istirahat'
            //       : (breakDone
            //           ? 'Durasi: $breakLabel'
            //           : AttendanceRules.breakWindowLabel),
            //   badge: isOnBreak
            //       ? 'LIVE'
            //       : (breakDone
            //           ? 'SELESAI'
            //           : 'JAM ${AttendanceRules.breakWindowLabel.split(' ').first}'),
            //   badgeColor: isOnBreak
            //       ? AppColors.warning
            //       : (breakDone ? AppColors.brandLimeDark : AppColors.slate400),
            //   badgeBg: isOnBreak
            //       ? AppColors.warning.withOpacity(0.12)
            //       : (breakDone
            //           ? AppColors.brandLime.withOpacity(0.12)
            //           : AppColors.slate100),
            // ),
            // ── Istirahat ─────────────────────────────────
            //
            // Fase 8: kartu ini dulu dikomentari seluruhnya karena satu-
            // satunya data yang bisa ditampilkan adalah "jam istirahat"
            // dari state lokal yang tak pernah terisi. Sekarang yang
            // ditampilkan DURASI dari `Attendance.breakDurasi` — sesuai
            // keputusan bahwa di database memang hanya durasi yang ada.
            _TimelineGridCard(
              icon: Icons.free_breakfast_rounded,
              iconColor: isOnBreak
                  ? AppColors.warning
                  : (hasBreak ? AppColors.brandLimeDark : AppColors.slate400),
              iconBg: isOnBreak
                  ? AppColors.warning.withOpacity(0.15)
                  : (hasBreak
                      ? AppColors.brandLime.withOpacity(0.15)
                      : AppColors.slate100),
              label: 'Istirahat',
              value: breakLabel,
              sub: isOnBreak
                  ? 'Sedang istirahat'
                  : (hasBreak ? 'Total hari ini' : 'Belum istirahat'),
              badge: isOnBreak ? 'LIVE' : (hasBreak ? 'SELESAI' : '-'),
              badgeColor: isOnBreak
                  ? AppColors.warning
                  : (hasBreak ? AppColors.brandLimeDark : AppColors.slate400),
              badgeBg: isOnBreak
                  ? AppColors.warning.withOpacity(0.12)
                  : (hasBreak
                      ? AppColors.brandLime.withOpacity(0.12)
                      : AppColors.slate100),
            ),
            // ── Jam Kerja ─────────────────────────────────
            _TimelineGridCard(
              icon: Icons.timer_rounded,
              iconColor: _workDur.inMinutes > 0
                  ? AppColors.brandCyanDark
                  : AppColors.slate400,
              iconBg: _workDur.inMinutes > 0
                  ? AppColors.brandCyan.withOpacity(0.15)
                  : AppColors.slate100,
              label: 'Jam Kerja',
              value: workLabel,
              sub: _workDur.inMinutes > 0
                  ? 'Waktu kerja aktif'
                  : 'Belum mulai bekerja',
              badge: _workDur.inMinutes > 0 ? 'LIVE' : '-',
              badgeColor: _workDur.inMinutes > 0
                  ? AppColors.brandCyanDark
                  : AppColors.slate400,
              badgeBg: _workDur.inMinutes > 0
                  ? AppColors.brandCyan.withOpacity(0.12)
                  : AppColors.slate100,
            ),
            // ── Uang Makan ────────────────────────────────
            //
            // Fase 8: diisi server saat check-out (Attendance.uangMakan) bila
            // check-in tepat waktu DAN pulang tidak lebih awal.
            _TimelineGridCard(
              icon: Icons.restaurant_rounded,
              iconColor: _att.uangMakan > 0
                  ? AppColors.brandLimeDark
                  : AppColors.slate400,
              iconBg: _att.uangMakan > 0
                  ? AppColors.brandLime.withOpacity(0.15)
                  : AppColors.slate100,
              label: 'Uang Makan',
              value: _att.uangMakan > 0 ? _rupiah(_att.uangMakan) : '--',
              sub: _att.uangMakan > 0
                  ? 'Didapat hari ini'
                  : (_status == AttendanceProviderStatus.checkedOut
                      ? 'Tidak memenuhi syarat'
                      : 'Dihitung saat check-out'),
              badge: _att.uangMakan > 0 ? 'DIDAPAT' : '-',
              badgeColor: _att.uangMakan > 0
                  ? AppColors.brandLimeDark
                  : AppColors.slate400,
              badgeBg: _att.uangMakan > 0
                  ? AppColors.brandLime.withOpacity(0.12)
                  : AppColors.slate100,
            ),
          ],
        ),
      ],
    );
  }
}

/// Kartu kecil di grid "Timeline Hari Ini" (Check-In, Istirahat, Jam Kerja,
/// Uang Makan).
class _TimelineGridCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String sub;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;

  const _TimelineGridCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.sub,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
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
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
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
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        letterSpacing: 0.3)),
              ),
            ],
          ),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate700)),
          Text(sub,
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.slate400),
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
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
                letterSpacing: 0.3)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.brandNavy : AppColors.slate800)),
      ],
    );
  }
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
  List<_HistoryDay> _days = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cutoff = DateTime(now.year, now.month - 2, 1); // 3 bulan terakhir
    _load();
  }

  /// Fase 8: riwayat kehadiran dibaca dari DATABASE.
  ///
  /// Sebelumnya layar ini mencocokkan tiap tanggal dengan
  /// `SampleData.recentAttendance` — daftar absensi karangan — sehingga
  /// "Riwayat Kehadiran" 3 bulan yang dilihat staff tidak ada hubungannya
  /// dengan absensinya yang sebenarnya.
  ///
  /// Hari non-kerja juga tidak lagi ditebak dari akhir pekan saja: hari
  /// kerja mengikuti `Shift.hariKerja` dan tanggal merah mengikuti master
  /// `hari_libur` (keduanya dari [AppCalendar]).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      // Ambil per bulan agar mencakup seluruh rentang 3 bulan.
      final months = <String>{
        for (var i = 0; i < 3; i++)
          '${DateTime(now.year, now.month - i).year.toString().padLeft(4, '0')}-'
              '${DateTime(now.year, now.month - i).month.toString().padLeft(2, '0')}',
      };

      final records = <AttendanceRecord>[];
      for (final month in months) {
        records.addAll(await AttendanceService.history(month: month, limit: 100));
      }

      if (!mounted) return;
      setState(() {
        _days = _buildDayList(now, records);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<_HistoryDay> _buildDayList(DateTime now, List<AttendanceRecord> records) {
    final byDate = <String, AttendanceRecord>{
      for (final r in records) WorkCalendar.dateKey(r.date): r,
    };
    final calendar = AppCalendar.instance;

    final List<_HistoryDay> result = [];
    DateTime cursor = DateTime(now.year, now.month, now.day);
    while (!cursor.isBefore(_cutoff)) {
      final rec = byDate[WorkCalendar.dateKey(cursor)];
      // "isWeekend" di sini berarti "bukan hari kerja" — termasuk tanggal
      // merah. Tetap tampilkan record bila ternyata staff memang absen di
      // hari itu (mis. lembur di hari libur).
      final bukanHariKerja = !calendar.isSelectable(cursor);
      result.add(_HistoryDay(
        date: cursor,
        isWeekend: bukanHariKerja && rec == null,
        record: rec,
      ));
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return result;
  }

  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
                fontSize: 17,
                fontWeight: FontWeight.w800,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 44, color: AppColors.slate400),
                        const SizedBox(height: 10),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: AppText.body2),
                        const SizedBox(height: 14),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              : ListView(
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
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandNavy,
                      letterSpacing: 1.2),
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
    final rec = day.record;
    final isWeekend = day.isWeekend;
    final isHoliday = rec?.status == AttendanceStatus.holiday;
    final isLibur = isWeekend || isHoliday;
    final absent = !isLibur && rec == null;
    final isLate = !isLibur &&
        !absent &&
        rec!.checkIn != null &&
        rec.checkIn!.hour > _user.currentShift.startTime.hour;

    // Status
    final String statusLabel;
    final Color statusColor, statusBg;
    if (isWeekend) {
      statusLabel = 'LIBUR';
      statusColor = AppColors.brandNavy;
      statusBg = AppColors.brandNavy.withOpacity(0.08);
    } else if (isHoliday) {
      statusLabel = 'LIBUR';
      statusColor = AppColors.brandNavy;
      statusBg = AppColors.brandNavy.withOpacity(0.08);
    } else if (absent) {
      statusLabel = 'ABSEN';
      statusColor = AppColors.danger;
      statusBg = AppColors.danger.withOpacity(0.08);
    } else if (isLate) {
      statusLabel = 'TERLAMBAT';
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withOpacity(0.08);
    } else {
      statusLabel = 'TEPAT WAKTU';
      statusColor = AppColors.brandLimeDark;
      statusBg = AppColors.brandLime.withOpacity(0.15);
    }

    final dayName = DateFormat('EEE', 'id_ID').format(day.date).toUpperCase();
    final dayNum = DateFormat('d', 'id_ID').format(day.date);
    final monthStr = DateFormat('MMM', 'id_ID').format(day.date);

    final checkInStr = rec?.checkIn != null ? _fmtHM24(rec!.checkIn!) : '--:--';
    final checkOutStr =
        rec?.checkOut != null ? _fmtHM24(rec!.checkOut!) : '--:--';
    String totalWork = '--:--';
    if (rec?.checkIn != null && rec?.checkOut != null) {
      final dur = rec!.checkOut!.difference(rec.checkIn!);
      totalWork =
          '${dur.inHours.toString().padLeft(2, '0')}:${(dur.inMinutes % 60).toString().padLeft(2, '0')}';
    }

    final dateBoxColor = isLibur
        ? AppColors.brandNavy.withOpacity(0.08)
        : (absent ? AppColors.danger.withOpacity(0.08) : AppColors.brandNavy);
    final dateTextColor = isLibur
        ? AppColors.brandNavy
        : (absent ? AppColors.danger : Colors.white);
    final dateSubColor = isLibur
        ? AppColors.brandNavy.withOpacity(0.5)
        : (absent
            ? AppColors.danger.withOpacity(0.5)
            : Colors.white.withOpacity(0.55));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate200.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Date box
            Container(
              width: 48,
              height: 52,
              decoration: BoxDecoration(
                color: dateBoxColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName,
                      style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: dateSubColor.withOpacity(0.8),
                          letterSpacing: 0.5)),
                  Text(dayNum,
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: dateTextColor,
                          height: 1.0)),
                  Text(monthStr,
                      style:
                          GoogleFonts.inter(fontSize: 8, color: dateSubColor)),
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
                      isWeekend
                          ? (day.date.weekday == DateTime.saturday
                              ? 'Sabtu'
                              : 'Minggu')
                          : 'Hari Libur',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandNavy),
                    ),
                  ] else if (absent) ...[
                    Text('Tidak Hadir',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger)),
                  ] else ...[
                    Row(
                      children: [
                        _HistoryTimeCol(label: 'Check In', value: checkInStr),
                        const SizedBox(width: 14),
                        _HistoryTimeCol(label: 'Check Out', value: checkOutStr),
                        const SizedBox(width: 14),
                        _HistoryTimeCol(
                            label: 'Total Jam',
                            value: totalWork,
                            highlight: true),
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
                              : (absent
                                  ? '-'
                                  : 'Kantor Pusat Hadir-In, Jakarta'),
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
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDay {
  final DateTime date;
  final bool isWeekend;
  final AttendanceRecord? record;
  const _HistoryDay(
      {required this.date, required this.isWeekend, required this.record});
}

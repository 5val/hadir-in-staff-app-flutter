import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/attendance_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ---------------------------------------------------------------------------
// Pastikan di pubspec.yaml:
//   dependencies:
//     camera: ^0.11.0   # atau versi terbaru
//
// Android  → android/app/src/main/AndroidManifest.xml:
//   <uses-permission android:name="android.permission.CAMERA"/>
//
// iOS      → ios/Runner/Info.plist:
//   <key>NSCameraUsageDescription</key>
//   <string>Diperlukan untuk verifikasi kehadiran</string>
// ---------------------------------------------------------------------------

/// Tipe aksi yang dibuka dari kamera
enum CameraActionType { checkIn, checkOut }

/// Hasil dari halaman kamera — dikembalikan ke pemanggil
class CameraResult {
  final bool confirmed;
  final CameraActionType actionType;
  /// Path foto yang diambil (null jika kamera tidak tersedia/gagal)
  final String? imagePath;
  /// Alamat lokasi saat check-in/out
  final String? address;

  CameraResult({
    required this.confirmed,
    required this.actionType,
    this.imagePath,
    this.address,
  });
}

class CameraCheckinScreen extends StatefulWidget {
  final CameraActionType actionType;
  const CameraCheckinScreen({super.key, required this.actionType});

  @override
  State<CameraCheckinScreen> createState() => _CameraCheckinScreenState();
}

class _CameraCheckinScreenState extends State<CameraCheckinScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ── Kamera ──────────────────────────────────────────────────────
  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady    = false;
  bool _cameraError    = false;
  String _cameraErrMsg = '';
  XFile? _capturedFile;

  // ── Checkout guard ──────────────────────────────────────────────
  /// Berlaku hanya untuk actionType == checkOut
  bool get _checkoutAllowed => AttendanceRules.canCheckout;
  // bool get _checkoutAllowed => true;

  /// Check-in hanya diizinkan sebelum jam 12:00
  bool get _checkinAllowed => !AttendanceRules.canCheckout;
  // bool get _checkinAllowed => true;

  // ── Lokasi (simulasi) ───────────────────────────────────────────
  bool   _checkingLocation = false;
  bool   _locationChecked  = false;
  bool   _locationInRange  = false;
  String _currentAddress   = '';
  double _distanceMeters   = 0;
  static const double _officeRadiusMeters = 200;

  // ── Clock ───────────────────────────────────────────────────────
  DateTime _now = DateTime.now();
  Timer?   _clockTimer;

  // ── Overlay ─────────────────────────────────────────────────────
  bool _showConfirmOverlay = false;
  bool _processingCapture  = false;

  late AnimationController _shutterCtrl;
  late AnimationController _resultCtrl;
  late Animation<double>   _resultScale;

  // ── Lifecycle ───────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _shutterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _resultScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut));

    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));

    _initCamera();
    _fetchLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _shutterCtrl.dispose();
    _resultCtrl.dispose();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  // ── Inisialisasi kamera depan ───────────────────────────────────
  Future<void> _initCamera() async {
    setState(() { _cameraReady = false; _cameraError = false; });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraError  = true;
          _cameraErrMsg = 'Tidak ada kamera yang tersedia.';
        });
        return;
      }

      // Pilih kamera depan; fallback ke kamera pertama
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      final ctrl = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await ctrl.initialize();
      if (!mounted) return;

      setState(() {
        _cameraCtrl  = ctrl;
        _cameraReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError  = true;
        _cameraErrMsg = e.toString();
      });
    }
  }

  // ── Lokasi (simulasi acak) ──────────────────────────────────────
  Future<void> _fetchLocation() async {
    setState(() { _checkingLocation = true; _locationChecked = false; });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final rng     = Random();
    final inRange = rng.nextBool(); // 50/50 untuk testing
    const addresses = [
      'Jl. Sudirman No. 1, Kel. Karet Tengsin, Jakarta Pusat',
      'Jl. Gatot Subroto No. 5, Kel. Menteng Atas, Jakarta Selatan',
      'Jl. HR Rasuna Said Kav. 1, Kel. Kuningan Timur, Jakarta',
    ];

    setState(() {
      _checkingLocation = false;
      _locationChecked  = true;
      _currentAddress   = addresses[rng.nextInt(addresses.length)];
      _distanceMeters   = inRange
          ? (rng.nextDouble() * _officeRadiusMeters * 0.9).roundToDouble()
          : (_officeRadiusMeters + rng.nextDouble() * 300 + 50).roundToDouble();
      _locationInRange  = inRange;
    });
  }

  // ── Ambil foto ──────────────────────────────────────────────────
  Future<void> _capturePhoto() async {
    if (_processingCapture) return;

    // Guard: checkout hanya setelah jam 12
    if (widget.actionType == CameraActionType.checkOut && !_checkoutAllowed) {
      _showCheckoutBlockedDialog();
      return;
    }

    // Guard: check-in hanya sebelum jam 12
    if (widget.actionType == CameraActionType.checkIn && !_checkinAllowed) {
      _showCheckinBlockedDialog();
      return;
    }

    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;

    setState(() => _processingCapture = true);

    // Shutter flash
    await _shutterCtrl.forward();
    await _shutterCtrl.reverse();

    try {
      _capturedFile = await _cameraCtrl!.takePicture();
    } catch (_) {
      // Jika gagal ambil foto tetap lanjut (untuk demo / device tanpa kamera)
    }

    if (!_locationChecked) await _fetchLocation();
    if (!mounted) return;

    setState(() {
      _processingCapture  = false;
      _showConfirmOverlay = true;
    });
    _resultCtrl.forward();
  }

  // ── Dialog checkout terlalu awal ────────────────────────────────
  void _showCheckoutBlockedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🕐', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Belum Waktunya',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          'Check-out hanya tersedia setelah pukul '
          '${AttendanceRules.checkoutCutoffHour.toString().padLeft(2,'0')}:'
          '${AttendanceRules.checkoutCutoffMinute.toString().padLeft(2,'0')} siang.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Mengerti',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Dialog check-in setelah jam 12 — tawarkan redirect ke checkout ─
  void _showCheckinBlockedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🚫', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Check-In Ditutup',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check-in hanya tersedia sebelum pukul '
              '${AttendanceRules.checkoutCutoffHour.toString().padLeft(2,'0')}:00 siang. '
              'Sudah lewat tengah hari.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 10),
            Text(
              'Ingin langsung melakukan check-out?',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.slate800),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup',
                style: GoogleFonts.inter(color: AppColors.slate700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
            onPressed: () {
              // Tutup dialog, lalu ganti layar ini dengan checkout
              Navigator.pop(context); // tutup dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const CameraCheckinScreen(
                      actionType: CameraActionType.checkOut),
                ),
              );
            },
            label: Text('Lakukan Check-Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Konfirmasi → kirim hasil ────────────────────────────────────
  void _confirm() {
    // Khusus checkout: cek apakah perlu peringatan pulang awal
    if (widget.actionType == CameraActionType.checkOut &&
        !AttendanceRules.canCheckoutWithoutWarning) {
      _showEarlyCheckoutWarningDialog();
      return;
    }
    Navigator.pop(context, CameraResult(
      confirmed:  true,
      actionType: widget.actionType,
      imagePath:  _capturedFile?.path,
      address:    _currentAddress.isNotEmpty ? _currentAddress : null,
    ));
  }

  // ── Dialog peringatan pulang awal ───────────────────────────────
  void _showEarlyCheckoutWarningDialog() {
    final normalHour = AttendanceRules.normalCheckoutHour
        .toString().padLeft(2, '0');
    final normalMinute = AttendanceRules.normalCheckoutMinute
        .toString().padLeft(2, '0');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Belum Jam Pulang!',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          'Jam pulang normal adalah pukul $normalHour:$normalMinute. '
          'Apakah Anda yakin ingin check-out sekarang?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.inter(color: AppColors.slate700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB01E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context); // tutup dialog
              Navigator.pop(context, CameraResult(
                confirmed:  true,
                actionType: widget.actionType,
                imagePath:  _capturedFile?.path,
                address:    _currentAddress.isNotEmpty ? _currentAddress : null,
              ));
            },
            child: Text('Ya, Check-Out Sekarang',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _retake() {
    _resultCtrl.reset();
    setState(() {
      _capturedFile       = null;
      _showConfirmOverlay = false;
    });
    _fetchLocation();
  }

  // ── Styling helpers ─────────────────────────────────────────────
  Color get _actionColor => widget.actionType == CameraActionType.checkIn
      ? AppColors.brandNavy
      : const Color(0xFFB01E1E);

  String get _actionLabel => widget.actionType == CameraActionType.checkIn
      ? 'Check-In'
      : 'Check-Out';

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:'
      '${dt.minute.toString().padLeft(2,'0')}:'
      '${dt.second.toString().padLeft(2,'0')}';

  String _fmtDate(DateTime dt) {
    const days   = ['','Sen','Sel','Rab','Kam','Jum','Sab','Min'];
    const months = ['','Jan','Feb','Mar','Apr','Mei','Jun',
                    'Jul','Ags','Sep','Okt','Nov','Des'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildViewfinder(),
          _buildOverlay(),
          // Shutter flash
          AnimatedBuilder(
            animation: _shutterCtrl,
            builder: (_, __) => _shutterCtrl.value > 0
                ? Positioned.fill(
                    child: Container(
                        color: Colors.white
                            .withOpacity(_shutterCtrl.value * 0.85)))
                : const SizedBox.shrink(),
          ),
          if (_showConfirmOverlay) _buildConfirmOverlay(),
        ],
      ),
    );
  }

  // ── Viewfinder ──────────────────────────────────────────────────
  Widget _buildViewfinder() {
    // ── Error state ─────────────────────────────────────────
    if (_cameraError) {
      return Positioned.fill(
        child: Container(
          color: const Color(0xFF0D0D1A),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_rounded,
                    color: Colors.white38, size: 56),
                const SizedBox(height: 14),
                Text('Kamera tidak dapat dibuka',
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(_cameraErrMsg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: Colors.white30, fontSize: 11)),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white60),
                  label: Text('Coba Lagi',
                      style: GoogleFonts.inter(color: Colors.white60)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Loading state ───────────────────────────────────────
    if (!_cameraReady || _cameraCtrl == null) {
      return Positioned.fill(
        child: Container(
          color: const Color(0xFF0D0D1A),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white38),
                const SizedBox(height: 16),
                Text('Membuka kamera depan...',
                    style: GoogleFonts.inter(color: Colors.white38)),
              ],
            ),
          ),
        ),
      );
    }

    // ── Live preview ────────────────────────────────────────
    return Positioned.fill(
      child: _capturedFile != null
          // Tampilkan foto yang sudah diambil: bedakan Web dan Mobile
          ? (kIsWeb 
              ? Image.network(_capturedFile!.path, fit: BoxFit.cover)
              : Image.file(File(_capturedFile!.path), fit: BoxFit.cover))
          // Live camera preview
          : OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraCtrl!.value.previewSize!.height,
                  height: _cameraCtrl!.value.previewSize!.width,
                  child: CameraPreview(_cameraCtrl!),
                ),
              ),
            ),
    );
  }

  // ── Camera UI Overlay ───────────────────────────────────────────
  Widget _buildOverlay() {
    final bool checkoutBlocked =
        widget.actionType == CameraActionType.checkOut && !_checkoutAllowed;
    final bool checkinBlocked =
        widget.actionType == CameraActionType.checkIn && !_checkinAllowed;

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.72), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_actionLabel,
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Selfie untuk verifikasi kehadiran',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.65))),
                    ],
                  ),
                ),
                // Badge aksi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: checkoutBlocked
                        ? Colors.orange.withOpacity(0.85)
                        : _actionColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    checkoutBlocked ? 'TERLALU AWAL' : checkinBlocked ? 'DITUTUP' : _actionLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // ── Face guide oval (tengah) ─────────────────────
          Expanded(
            child: Center(
              child: Container(
                width: 210, height: 255,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: checkoutBlocked || checkinBlocked
                        ? Colors.orange.withOpacity(0.7)
                        : Colors.white.withOpacity(0.5),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(130),
                ),
                child: checkoutBlocked
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_clock_rounded,
                                color: Colors.orange, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Check-out tersedia\nsetelah pukul '
                              '${AttendanceRules.checkoutCutoffHour.toString().padLeft(2,'0')}:00',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.orange,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : checkinBlocked
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.block_rounded,
                                    color: Colors.orange, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  'Check-in ditutup\nsetelah pukul 12:00',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: Colors.orange,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (_) => const CameraCheckinScreen(
                                          actionType: CameraActionType.checkOut),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.logout_rounded,
                                            color: Colors.white, size: 13),
                                        const SizedBox(width: 5),
                                        Text('Check-Out',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
              ),
            ),
          ),

          // ── Bottom: info bar + shutter ───────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.82), Colors.transparent],
              ),
            ),
            child: Column(
              children: [
                // Info: waktu + lokasi
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      // Clock
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: Colors.white54, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fmtTime(_now),
                                      style: GoogleFonts.jetBrainsMono(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                  Text(_fmtDate(_now),
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: Colors.white54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                          width: 1, height: 34,
                          color: Colors.white.withOpacity(0.15)),
                      const SizedBox(width: 12),
                      // Location
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _checkingLocation
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white54))
                                : Icon(
                                    _locationInRange
                                        ? Icons.location_on_rounded
                                        : Icons.location_off_rounded,
                                    size: 14,
                                    color: _locationChecked
                                        ? (_locationInRange
                                            ? Colors.greenAccent
                                            : Colors.redAccent)
                                        : Colors.white54,
                                  ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _checkingLocation
                                        ? 'Mendeteksi...'
                                        : (_locationChecked
                                            ? (_locationInRange
                                                ? '✓ Dalam area'
                                                : '✗ Di luar area')
                                            : 'GPS...'),
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _locationChecked
                                            ? (_locationInRange
                                                ? Colors.greenAccent
                                                : Colors.redAccent)
                                            : Colors.white54),
                                  ),
                                  if (_locationChecked &&
                                      _currentAddress.isNotEmpty)
                                    Text(_currentAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                            fontSize: 9,
                                            color: Colors.white38)),
                                  if (_locationChecked)
                                    Text(
                                      '${_distanceMeters.toStringAsFixed(0)} m dari kantor',
                                      style: GoogleFonts.inter(
                                          fontSize: 9, color: Colors.white38),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Shutter row ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Refresh lokasi
                    GestureDetector(
                      onTap: (!_checkingLocation && !_processingCapture)
                          ? _fetchLocation
                          : null,
                      child: AnimatedOpacity(
                        opacity: (!_checkingLocation && !_processingCapture)
                            ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location_rounded,
                              color: Colors.white70, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),

                    // Shutter button
                    GestureDetector(
                      onTap: checkinBlocked
                          ? _showCheckinBlockedDialog
                          : (!_processingCapture && _cameraReady &&
                                  !_showConfirmOverlay)
                              ? _capturePhoto
                              : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: _processingCapture
                              ? Colors.white.withOpacity(0.45)
                              : checkoutBlocked
                                  ? Colors.orange.withOpacity(0.6)
                                  : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 16, spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _processingCapture
                            ? const Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black54),
                                ))
                            : Icon(
                                (checkoutBlocked || checkinBlocked)
                                    ? Icons.lock_rounded
                                    : Icons.camera_alt_rounded,
                                color: (checkoutBlocked || checkinBlocked)
                                    ? Colors.orange
                                    : _actionColor,
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(width: 32),

                    // Spacer simetri
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  checkoutBlocked
                      ? 'Check-out terkunci hingga pukul ${AttendanceRules.checkoutCutoffHour.toString().padLeft(2,'0')}:00'
                      : checkinBlocked
                          ? 'Check-in ditutup — tap tombol kunci atau tap oval untuk Check-Out'
                          : (_cameraReady
                              ? 'Posisikan wajah di dalam oval, lalu tap tombol kamera'
                              : 'Menginisialisasi kamera depan...'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: checkoutBlocked
                          ? Colors.orange.withOpacity(0.8)
                          : Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorContainer() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_rounded,
                color: AppColors.slate300, size: 36),
            const SizedBox(height: 6),
            Text('Foto tersimpan',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.slate400)),
          ],
        ),
      ),
    );
  }

  // ── Confirm / Retake overlay ────────────────────────────────────
  Widget _buildConfirmOverlay() {
    final inRange = _locationInRange;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.74),
        child: Center(
          child: ScaleTransition(
            scale: _resultScale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Preview foto yang diambil ─────────────
                  if (_capturedFile != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _capturedFile!.path,
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _errorContainer(),
                                )
                              : Image.file(
                                  File(_capturedFile!.path),
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _errorContainer(),
                                ),
                        ),
                        // Positioned(
                        //   top: 8, right: 8,
                        //   child: Container(
                        //     padding: const EdgeInsets.symmetric(
                        //         horizontal: 8, vertical: 4),
                        //     decoration: BoxDecoration(
                        //       color: Colors.black.withOpacity(0.55),
                        //       borderRadius: BorderRadius.circular(20),
                        //     ),
                        //     // child: Row(
                        //     //   mainAxisSize: MainAxisSize.min,
                        //     //   children: [
                        //     //     const Icon(Icons.camera_alt_rounded,
                        //     //         color: Colors.white, size: 10),
                        //     //     // const SizedBox(width: 4),
                        //     //     // Text('Foto Selfie',
                        //     //     //     style: GoogleFonts.inter(
                        //     //     //         fontSize: 9, fontWeight: FontWeight.w700,
                        //     //     //         color: Colors.white)),
                        //     //   ],
                        //     // ),
                        //   ),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Icon hasil
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: inRange
                          ? AppColors.brandLime.withOpacity(0.15)
                          : AppColors.danger.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      inRange
                          ? Icons.check_circle_rounded
                          : Icons.location_off_rounded,
                      color: inRange
                          ? AppColors.brandLimeDark
                          : AppColors.danger,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    inRange
                        ? 'Foto & Lokasi Terverifikasi'
                        : 'Di Luar Area Kantor',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: AppColors.slate900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Detail box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          color: AppColors.brandNavy,
                          label: 'Waktu',
                          value: _fmtTime(_now),
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          color: inRange
                              ? AppColors.brandLimeDark
                              : AppColors.danger,
                          label: 'Jarak ke kantor',
                          value:
                              '${_distanceMeters.toStringAsFixed(0)} m  '
                              '(radius ${_officeRadiusMeters.toInt()} m)',
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.place_rounded,
                          color: AppColors.slate700,
                          label: 'Lokasi saat ini',
                          value: _currentAddress,
                        ),
                      ],
                    ),
                  ),

                  if (!inRange) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Kamu berada di luar radius kantor. Foto ulang dari '
                        'lokasi yang benar, atau hubungi HRD jika ini kesalahan.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.danger,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _retake,
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Foto Ulang'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppColors.slate300),
                            foregroundColor: AppColors.slate700,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: inRange ? _confirm : null,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text(
                            inRange ? 'Konfirmasi' : 'Di Luar Area',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: inRange
                                ? _actionColor
                                : AppColors.slate300,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
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

// ── Info Row ────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, value;

  const _InfoRow({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w600,
                      color: AppColors.slate400, letterSpacing: 0.5)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.slate800)),
            ],
          ),
        ),
      ],
    );
  }
}
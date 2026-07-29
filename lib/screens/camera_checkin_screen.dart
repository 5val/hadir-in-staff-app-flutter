import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../theme/app_theme.dart';
import '../services/attendance_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ---------------------------------------------------------------------------
// Pastikan di pubspec.yaml:
//   dependencies:
//     camera: ^0.11.0
//     google_mlkit_face_detection: ^0.11.0
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
  // ── Kamera ──────────────────────────────────────────────────
  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _cameraError = false;
  String _cameraErrMsg = '';
  XFile? _capturedFile;

  // ── Face Detection ───────────────────────────────────────────
  FaceDetector? _faceDetector;
  bool _faceDetected = false;
  bool _faceInCenter = false;
  bool _processingFrame = false;
  // Warna oval: putih = idle/tidak ada wajah, hijau = wajah OK, kuning = wajah tapi tidak center
  Color get _ovalColor {
    if (_processingCapture || _showConfirmOverlay)
      return Colors.white.withOpacity(0.5);
    if (!_faceDetected) return Colors.white.withOpacity(0.5);
    if (_faceInCenter) return Colors.greenAccent;
    return Colors.orangeAccent;
  }

  // ── Checkout guard ──────────────────────────────────────────
  //
  // Fase 8: gerbang berbasis JAM di layar ini dihapus. Dulu:
  //   _checkoutAllowed = AttendanceRules.canCheckout   → "setelah pukul 24"
  //   _checkinAllowed  = !AttendanceRules.canCheckout  → "sebelum pukul 24"
  // Karena `checkoutCutoffHour` bernilai 24, check-out tidak pernah boleh
  // dan layar ini selalu menampilkan "Check-out terkunci hingga pukul 24:00".
  //
  // Yang menentukan boleh/tidaknya sekarang adalah STATUS ABSENSI hari ini
  // (sudah check-in atau belum), yang dipegang AttendanceProvider di layar
  // pemanggil, plus validasi server. Layar kamera tidak lagi punya aturan
  // jam sendiri — satu aturan, satu tempat.
  bool get _checkoutAllowed => true;
  bool get _checkinAllowed => true;

  // ── Lokasi (simulasi) ───────────────────────────────────────
  bool _checkingLocation = false;
  bool _locationChecked = false;
  bool _locationInRange = false;
  String _currentAddress = '';
  double _distanceMeters = 0;
  static const double _officeRadiusMeters = 200;

  // ── Clock ───────────────────────────────────────────────────
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  // ── Overlay ─────────────────────────────────────────────────
  bool _showConfirmOverlay = false;
  bool _processingCapture = false;

  late AnimationController _shutterCtrl;
  late AnimationController _resultCtrl;
  late Animation<double> _resultScale;

  // ── Lifecycle ───────────────────────────────────────────────
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

    _clockTimer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));

    // Inisialisasi face detector
    if (!kIsWeb) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: false,
          enableLandmarks: false,
          enableContours: false,
          enableTracking: false,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
    }

    _initCamera();
    _fetchLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopImageStream();
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
    _stopImageStream();
    _cameraCtrl?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  void _stopImageStream() {
    if (_cameraCtrl?.value.isStreamingImages == true) {
      _cameraCtrl?.stopImageStream();
    }
  }

  // ── Inisialisasi kamera depan ───────────────────────────────
  Future<void> _initCamera() async {
    setState(() {
      _cameraReady = false;
      _cameraError = false;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraError = true;
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
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await ctrl.initialize();
      if (!mounted) return;

      setState(() {
        _cameraCtrl = ctrl;
        _cameraReady = true;
      });

      // Mulai stream deteksi wajah (hanya di mobile, bukan web)
      if (!kIsWeb && _faceDetector != null) {
        _startFaceDetectionStream(ctrl, front);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _cameraErrMsg = e.toString();
      });
    }
  }

  // ── Face Detection Stream ────────────────────────────────────
  void _startFaceDetectionStream(
      CameraController ctrl, CameraDescription camDesc) {
    ctrl.startImageStream((CameraImage image) async {
      if (_processingFrame || _showConfirmOverlay || _processingCapture) return;
      _processingFrame = true;

      try {
        final inputImage = _buildInputImage(image, camDesc);
        if (inputImage == null) {
          _processingFrame = false;
          return;
        }

        final faces = await _faceDetector!.processImage(inputImage);
        if (!mounted) return;

        if (faces.isEmpty) {
          setState(() {
            _faceDetected = false;
            _faceInCenter = false;
          });
        } else {
          // Cek apakah wajah terbesar berada di tengah frame
          final largestFace = faces.reduce((a, b) =>
              (a.boundingBox.width * a.boundingBox.height >
                      b.boundingBox.width * b.boundingBox.height)
                  ? a
                  : b);

          final bool centered = _isFaceCentered(largestFace, image);
          setState(() {
            _faceDetected = true;
            _faceInCenter = centered;
          });
        }
      } catch (_) {
        // silent error — tidak hentikan stream
      } finally {
        _processingFrame = false;
      }
    });
  }

  /// Buat InputImage dari CameraImage untuk MLKit
  InputImage? _buildInputImage(CameraImage image, CameraDescription camDesc) {
    // Hanya support format NV21 & BGRA8888
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    final bytes = image.planes
        .map((p) => p.bytes)
        .reduce((a, b) => Uint8List.fromList([...a, ...b]));

    // Rotasi kamera ke device
    final sensorOrientation = camDesc.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation == 90
          ? 90
          : sensorOrientation == 270
              ? 270
              : 0);
    }
    if (rotation == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Cek apakah center wajah berada dalam 25% tengah dari frame
  bool _isFaceCentered(Face face, CameraImage image) {
    final faceCenter = Offset(
      face.boundingBox.left + face.boundingBox.width / 2,
      face.boundingBox.top + face.boundingBox.height / 2,
    );

    final frameWidth = image.width.toDouble();
    final frameHeight = image.height.toDouble();
    final frameCenterX = frameWidth / 2;
    final frameCenterY = frameHeight / 2;

    // Toleransi: wajah dianggap center jika dalam 28% dari center frame
    final toleranceX = frameWidth * 0.28;
    final toleranceY = frameHeight * 0.28;

    return (faceCenter.dx - frameCenterX).abs() < toleranceX &&
        (faceCenter.dy - frameCenterY).abs() < toleranceY;
  }

  // ── Lokasi (simulasi acak) ──────────────────────────────────
  Future<void> _fetchLocation() async {
    setState(() {
      _checkingLocation = true;
      _locationChecked = false;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final rng = Random();
    final inRange = rng.nextBool(); // 50/50 untuk testing
    const addresses = [
      'Jl. Sudirman No. 1, Kel. Karet Tengsin, Jakarta Pusat',
      'Jl. Gatot Subroto No. 5, Kel. Menteng Atas, Jakarta Selatan',
      'Jl. HR Rasuna Said Kav. 1, Kel. Kuningan Timur, Jakarta',
    ];

    setState(() {
      _checkingLocation = false;
      _locationChecked = true;
      _currentAddress = addresses[rng.nextInt(addresses.length)];
      _distanceMeters = inRange
          ? (rng.nextDouble() * _officeRadiusMeters * 0.9).roundToDouble()
          : (_officeRadiusMeters + rng.nextDouble() * 300 + 50).roundToDouble();
      _locationInRange = inRange;
    });
  }

  // ── Ambil foto ──────────────────────────────────────────────
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

    // Stop stream sebelum takePicture
    _stopImageStream();

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
      _processingCapture = false;
      _showConfirmOverlay = true;
    });
    _resultCtrl.forward();
  }

  // ── Dialog checkout terlalu awal ────────────────────────────
  void _showCheckoutBlockedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🕐', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Belum Waktunya',
              style:
                  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          'Anda belum check-in hari ini, jadi belum bisa check-out.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Mengerti',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Dialog check-in setelah jam 12 ──────────────────────────
  void _showCheckinBlockedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🚫', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Check-In Ditutup',
              style:
                  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda sudah check-in hari ini.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 10),
            Text(
              'Ingin langsung melakukan check-out?',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
            icon:
                const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
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
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Konfirmasi → kirim hasil ────────────────────────────────
  void _confirm() {
    // Peringatan pulang awal kini dibandingkan dengan jam pulang SHIFT staff
    // dari database (AttendanceRules dihidrasi dari kalender kerja), bukan
    // konstanta `normalCheckoutHour = 24`.
    if (widget.actionType == CameraActionType.checkOut &&
        !AttendanceRules.isAfterNormalCheckout) {
      _showEarlyCheckoutWarningDialog();
      return;
    }
    Navigator.pop(
        context,
        CameraResult(
          confirmed: true,
          actionType: widget.actionType,
          imagePath: _capturedFile?.path,
          address: _currentAddress.isNotEmpty ? _currentAddress : null,
        ));
  }

  // ── Dialog peringatan pulang awal ───────────────────────────
  void _showEarlyCheckoutWarningDialog() {
    final jamPulang = AttendanceRules.jamPulangLabel;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Belum Jam Pulang!',
              style:
                  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          'Jam pulang shift Anda pukul $jamPulang. '
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
              Navigator.pop(context);
              Navigator.pop(
                  context,
                  CameraResult(
                    confirmed: true,
                    actionType: widget.actionType,
                    imagePath: _capturedFile?.path,
                    address:
                        _currentAddress.isNotEmpty ? _currentAddress : null,
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
      _capturedFile = null;
      _showConfirmOverlay = false;
      _faceDetected = false;
      _faceInCenter = false;
    });
    _fetchLocation();
    // Restart image stream untuk face detection
    if (!kIsWeb &&
        _faceDetector != null &&
        _cameraCtrl != null &&
        _cameraReady) {
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      _startFaceDetectionStream(_cameraCtrl!, front);
    }
  }

  // ── Styling helpers ─────────────────────────────────────────
  Color get _actionColor => widget.actionType == CameraActionType.checkIn
      ? AppColors.brandNavy
      : const Color(0xFFB01E1E);

  String get _actionLabel =>
      widget.actionType == CameraActionType.checkIn ? 'Check-In' : 'Check-Out';

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) {
    const days = ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  // ── Build ───────────────────────────────────────────────────
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

  // ── Viewfinder ──────────────────────────────────────────────
  Widget _buildViewfinder() {
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
                  icon:
                      const Icon(Icons.refresh_rounded, color: Colors.white60),
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

    return Positioned.fill(
      child: _capturedFile != null
          ? (kIsWeb
              ? Image.network(_capturedFile!.path, fit: BoxFit.cover)
              : Image.file(File(_capturedFile!.path), fit: BoxFit.cover))
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

  // ── Camera UI Overlay ───────────────────────────────────────
  Widget _buildOverlay() {
    final bool checkoutBlocked =
        widget.actionType == CameraActionType.checkOut && !_checkoutAllowed;
    final bool checkinBlocked =
        widget.actionType == CameraActionType.checkIn && !_checkinAllowed;

    // Shutter hanya aktif jika:
    // 1. Kamera siap
    // 2. Wajah terdeteksi dan berada di tengah (atau di Web yg tidak ada face detect)
    // 3. Tidak sedang processing / blocking
    final bool shutterActive = _cameraReady &&
        !_processingCapture &&
        !_showConfirmOverlay &&
        !checkoutBlocked &&
        !checkinBlocked &&
        (kIsWeb || (_faceDetected && _faceInCenter));

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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Selfie untuk verifikasi kehadiran',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.65))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: checkoutBlocked
                        ? Colors.orange.withOpacity(0.85)
                        : _actionColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    checkoutBlocked
                        ? 'TERLALU AWAL'
                        : checkinBlocked
                            ? 'DITUTUP'
                            : _actionLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // ── Face guide oval ─────────────────────────────────
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Oval border dengan warna dinamis
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 210,
                    height: 255,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: checkoutBlocked || checkinBlocked
                            ? Colors.orange.withOpacity(0.7)
                            : _ovalColor,
                        width:
                            _faceInCenter && !checkoutBlocked && !checkinBlocked
                                ? 3.5
                                : 2.5,
                      ),
                      borderRadius: BorderRadius.circular(130),
                      // Glow effect saat wajah terdeteksi di tengah
                      boxShadow:
                          (_faceInCenter && !checkoutBlocked && !checkinBlocked)
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  )
                                ]
                              : [],
                    ),
                    child: _buildOvalContent(checkoutBlocked, checkinBlocked),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom bar ──────────────────────────────────────
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                          fontSize: 9, color: Colors.white54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 34,
                          color: Colors.white.withOpacity(0.15)),
                      const SizedBox(width: 12),
                      // Location
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _checkingLocation
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
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
                const SizedBox(height: 16),

                // Face detection status indicator
                if (!kIsWeb &&
                    !checkoutBlocked &&
                    !checkinBlocked &&
                    _cameraReady)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _faceInCenter
                          ? Colors.greenAccent.withOpacity(0.15)
                          : _faceDetected
                              ? Colors.orangeAccent.withOpacity(0.15)
                              : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _faceInCenter
                            ? Colors.greenAccent.withOpacity(0.5)
                            : _faceDetected
                                ? Colors.orangeAccent.withOpacity(0.5)
                                : Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _faceInCenter
                              ? Icons.face_retouching_natural_rounded
                              : _faceDetected
                                  ? Icons.face_rounded
                                  : Icons.face_retouching_off_rounded,
                          size: 14,
                          color: _faceInCenter
                              ? Colors.greenAccent
                              : _faceDetected
                                  ? Colors.orangeAccent
                                  : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _faceInCenter
                              ? 'Wajah terdeteksi — siap foto!'
                              : _faceDetected
                                  ? 'Wajah terdeteksi — pindahkan ke tengah'
                                  : 'Arahkan wajah ke kamera',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _faceInCenter
                                ? Colors.greenAccent
                                : _faceDetected
                                    ? Colors.orangeAccent
                                    : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                            ? 1.0
                            : 0.4,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 48,
                          height: 48,
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
                          : shutterActive
                              ? _capturePhoto
                              : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _processingCapture
                              ? Colors.white.withOpacity(0.45)
                              : checkoutBlocked
                                  ? Colors.orange.withOpacity(0.6)
                                  : shutterActive
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: shutterActive
                                  ? Colors.greenAccent.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.35),
                              width: shutterActive ? 4.5 : 4),
                          boxShadow: shutterActive
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.3),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: _processingCapture
                            ? const Center(
                                child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.black54),
                              ))
                            : Icon(
                                (checkoutBlocked || checkinBlocked)
                                    ? Icons.lock_rounded
                                    : Icons.camera_alt_rounded,
                                color: (checkoutBlocked || checkinBlocked)
                                    ? Colors.orange
                                    : shutterActive
                                        ? _actionColor
                                        : Colors.white54,
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(width: 32),

                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  checkoutBlocked
                      ? 'Anda belum check-in hari ini'
                      : checkinBlocked
                          ? 'Anda sudah check-in — tap oval untuk Check-Out'
                          : !_cameraReady
                              ? 'Menginisialisasi kamera depan...'
                              : kIsWeb
                                  ? 'Posisikan wajah di dalam oval, lalu tap tombol kamera'
                                  : _faceInCenter
                                      ? 'Sempurna! Tap tombol kamera untuk foto'
                                      : _faceDetected
                                          ? 'Geser wajah ke tengah oval'
                                          : 'Posisikan wajah di dalam oval',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: checkoutBlocked
                          ? Colors.orange.withOpacity(0.8)
                          : _faceInCenter && !kIsWeb
                              ? Colors.greenAccent.withOpacity(0.9)
                              : Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Change return type from Widget to Widget?
  Widget? _buildOvalContent(bool checkoutBlocked, bool checkinBlocked) {
    if (checkoutBlocked) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_rounded,
                color: Colors.orange, size: 32),
            const SizedBox(height: 8),
            Text(
              'Anda belum check-in\nhari ini',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (checkinBlocked) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, color: Colors.orange, size: 28),
            const SizedBox(height: 6),
            Text(
              'Check-in ditutup\nsetelah pukul 12:00',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.orange,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
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
      );
    }

    // Normal state — tampilkan indikator kecil deteksi wajah di tengah oval
    if (!kIsWeb && _faceInCenter) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent.withOpacity(0.8), size: 28),
            const SizedBox(height: 4),
            Text('Siap',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent.withOpacity(0.8))),
          ],
        ),
      );
    }

    // 2. Safely return regular null without the bang operator
    return null;
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
                style:
                    GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
          ],
        ),
      ),
    );
  }

  // ── Confirm / Retake overlay ────────────────────────────────────
  // Widget _buildConfirmOverlay() {
  //   final inRange = _locationInRange;

  //   return Positioned.fill(
  //     child: Container(
  //       color: Colors.black.withOpacity(0.74),
  //       child: Center(
  //         child: ScaleTransition(
  //           scale: _resultScale,
  //           child: Container(
  //             margin: const EdgeInsets.symmetric(horizontal: 24),
  //             padding: const EdgeInsets.all(24),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(24),
  //             ),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 // ── Preview foto yang diambil ─────────────
  //                 if (_capturedFile != null) ...[
  //                   ClipRRect(
  //                     borderRadius: BorderRadius.circular(12),
  //                     child: kIsWeb
  //                         ? Image.network(
  //                             _capturedFile!.path,
  //                             width: double.infinity,
  //                             height: 160,
  //                             fit: BoxFit.cover,
  //                             errorBuilder: (_, __, ___) => _errorContainer(),
  //                           )
  //                         : Image.file(
  //                             File(_capturedFile!.path),
  //                             width: double.infinity,
  //                             height: 160,
  //                             fit: BoxFit.cover,
  //                             errorBuilder: (_, __, ___) => _errorContainer(),
  //                           ),
  //                   ),
  //                   const SizedBox(height: 14),
  //                 ],

  //                 // Icon hasil
  //                 Container(
  //                   width: 64,
  //                   height: 64,
  //                   decoration: BoxDecoration(
  //                     color: inRange
  //                         ? AppColors.brandLime.withOpacity(0.15)
  //                         : AppColors.danger.withOpacity(0.1),
  //                     shape: BoxShape.circle,
  //                   ),
  //                   child: Icon(
  //                     inRange
  //                         ? Icons.check_circle_rounded
  //                         : Icons.location_off_rounded,
  //                     color:
  //                         inRange ? AppColors.brandLimeDark : AppColors.danger,
  //                     size: 36,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 14),

  //                 Text(
  //                   inRange
  //                       ? 'Foto & Lokasi Terverifikasi'
  //                       : 'Di Luar Area Kantor',
  //                   style: GoogleFonts.inter(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w800,
  //                       color: AppColors.slate900),
  //                   textAlign: TextAlign.center,
  //                 ),
  //                 const SizedBox(height: 10),

  //                 // Detail box
  //                 Container(
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: AppColors.slate50,
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       _InfoRow(
  //                         icon: Icons.access_time_rounded,
  //                         color: AppColors.brandNavy,
  //                         label: 'Waktu',
  //                         value: _fmtTime(_now),
  //                       ),
  //                       const SizedBox(height: 6),
  //                       _InfoRow(
  //                         icon: Icons.location_on_rounded,
  //                         color: inRange
  //                             ? AppColors.brandLimeDark
  //                             : AppColors.danger,
  //                         label: 'Jarak ke kantor',
  //                         value: '${_distanceMeters.toStringAsFixed(0)} m  '
  //                             '(radius ${_officeRadiusMeters.toInt()} m)',
  //                       ),
  //                       const SizedBox(height: 6),
  //                       _InfoRow(
  //                         icon: Icons.place_rounded,
  //                         color: AppColors.slate700,
  //                         label: 'Lokasi saat ini',
  //                         value: _currentAddress,
  //                       ),
  //                     ],
  //                   ),
  //                 ),

  //                 if (!inRange) ...[
  //                   const SizedBox(height: 10),
  //                   Container(
  //                     padding: const EdgeInsets.all(10),
  //                     decoration: BoxDecoration(
  //                       color: AppColors.danger.withOpacity(0.07),
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(
  //                           color: AppColors.danger.withOpacity(0.2)),
  //                     ),
  //                     child: Text(
  //                       'Kamu berada di luar radius kantor. Foto ulang dari '
  //                       'lokasi yang benar, atau hubungi HRD jika ini kesalahan.',
  //                       style: GoogleFonts.inter(
  //                           fontSize: 11,
  //                           color: AppColors.danger,
  //                           fontWeight: FontWeight.w500),
  //                       textAlign: TextAlign.center,
  //                     ),
  //                   ),
  //                 ],

  //                 const SizedBox(height: 18),
  //                 Row(
  //                   children: [
  //                     Expanded(
  //                       child: OutlinedButton.icon(
  //                         onPressed: _retake,
  //                         icon: const Icon(Icons.replay_rounded, size: 16),
  //                         label: const Text('Foto Ulang'),
  //                         style: OutlinedButton.styleFrom(
  //                           padding: const EdgeInsets.symmetric(vertical: 12),
  //                           side: BorderSide(color: AppColors.slate300),
  //                           foregroundColor: AppColors.slate700,
  //                           shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(12)),
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(width: 10),
  //                     Expanded(
  //                       child: ElevatedButton.icon(
  //                         onPressed: inRange ? _confirm : null,
  //                         icon: const Icon(Icons.check_rounded, size: 16),
  //                         label: Text(
  //                           inRange ? 'Konfirmasi' : 'Di Luar Area',
  //                           style: const TextStyle(fontSize: 13),
  //                         ),
  //                         style: ElevatedButton.styleFrom(
  //                           backgroundColor:
  //                               inRange ? _actionColor : AppColors.slate300,
  //                           foregroundColor: Colors.white,
  //                           padding: const EdgeInsets.symmetric(vertical: 12),
  //                           shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(12)),
  //                           elevation: 0,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildConfirmOverlay() {
  final inRange = _locationInRange;

  return Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.74),
      child: Center(
        child: ScaleTransition(
          scale: _resultScale,
          child: Container(
            // Menggunakan constraints maksimum agar dialog tidak terlalu melar di layar tablet/lebar
            constraints: const BoxConstraints(maxWidth: 550),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20), // Sedikit diperkecil dari 24 agar hemat ruang
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IntrinsicHeight( // SINKRONISASI TINGGI: Memaksa tinggi kiri dan kanan sama besar
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Mengisi ruang vertikal secara seimbang
                children: [
                  // ── BAGIAN KIRI: Preview foto yang diambil ──
                  if (_capturedFile != null) ...[
                    Expanded(
                      flex: 4,
                      child: Center( // <── KUNCINYA: Menahan agar AspectRatio tidak dipaksa stretch vertikal
                        child: AspectRatio(
                          aspectRatio: 3 / 5, // Mengunci rasio foto HP portrait biar tidak kemolo/panjang
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? Image.network(
                                    _capturedFile!.path,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _errorContainer(),
                                  )
                                : Image.file(
                                    File(_capturedFile!.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _errorContainer(),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  // ── BAGIAN KANAN: Keterangan & Action Buttons ──
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      // Menggunakan MainAxisAlignment.spaceBetween jika ingin tombol selalu presisi di bawah sejajar foto
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Kelompok Informasi Atas
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon hasil
                            Container(
                              width: 48, // Diperkecil dari 56 agar lebih hemat space vertikal
                              height: 48,
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
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              inRange
                                  ? 'Foto & Lokasi Terverifikasi'
                                  : 'Di Luar Area Kantor',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate900),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Detail box
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(10),
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
                                    label: 'Jarak',
                                    value: '${_distanceMeters.toStringAsFixed(0)}m (r:${_officeRadiusMeters.toInt()}m)',
                                  ),
                                  const SizedBox(height: 6),
                                  _InfoRow(
                                    icon: Icons.place_rounded,
                                    color: AppColors.slate700,
                                    label: 'Lokasi',
                                    value: _currentAddress,
                                  ),
                                ],
                              ),
                            ),

                            if (!inRange) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.danger.withOpacity(0.2)),
                                ),
                                child: Text(
                                  'Kamu di luar radius kantor. Silakan foto ulang.',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Tombol Action (Dibuat Row berdampingan agar hemat space vertikal)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _retake,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(color: AppColors.slate300),
                                  foregroundColor: AppColors.slate700,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Icon(Icons.replay_rounded, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2, // Tombol konfirmasi dibuat lebih lebar
                              child: ElevatedButton.icon(
                                onPressed: inRange ? _confirm : null,
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: Text(
                                  inRange ? 'Konfirmasi' : 'Di Luar Area',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: inRange
                                      ? _actionColor
                                      : AppColors.slate300,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
  final Color color;
  final String label, value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
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
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate400,
                      letterSpacing: 0.5)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800)),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../theme/app_theme.dart';
import '../services/google_drive_service.dart';

class AbsenScreen extends StatefulWidget {
  final VoidCallback? onAttendanceSuccess;

  const AbsenScreen({super.key, this.onAttendanceSuccess});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  // ── Camera ──────────────────────────────────
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _cameraPermissionGranted = false;
  bool _checkingPermission = true;

  // ── Location ────────────────────────────────
  Position? _location;
  String _locationAddress = 'Mengambil lokasi...';

  // ── Attendance flow ──────────────────────────
  String? _photoPath;
  bool _isSaving = false;

  // ── Time ─────────────────────────────────────
  DateTime _currentTime = DateTime.now();
  Timer? _timer;

  static const String _currentUser = 'angelina';
  static const String _apiUrl = 'http://192.168.43.57:8000/verify';

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted) setState(() => _currentTime = DateTime.now());
        });
    _initPermissionsAndCamera();
    _initLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Permissions & Camera Init ─────────────────
  Future<void> _initPermissionsAndCamera() async {
    setState(() => _checkingPermission = true);
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
      await _initCamera();
    } else {
      setState(() => _cameraPermissionGranted = false);
    }
    if (mounted) setState(() => _checkingPermission = false);
  }

  Future<void> _initCamera() async {
    List<CameraDescription> cameras = [];

    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint("Camera not available on web: $e");
    }
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Location Init ────────────────────────────
  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationAddress = 'GPS tidak aktif');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationAddress = 'Izin lokasi ditolak');
        return;
      }

      // Gunakan timeout lebih longgar untuk Web
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() => _location = pos);
        _updateAddress(pos);
      }
    } catch (e) {
      debugPrint("Location Error: $e");
      if (mounted) {
        setState(() => _locationAddress = 'Gagal mendeteksi lokasi (Timeout/Error)');
      }
    }
  }

  Future<void> _updateAddress(Position pos) async {
    // PENTING: geocoding package TIDAK jalan di Web
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _locationAddress = "Lokasi terdeteksi (Web)"; 
          _location = pos;
        });
      }
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final addr = placemarks.first;
        setState(() {
          _locationAddress = '${addr.street}, ${addr.subLocality}, ${addr.locality}';
          _location = pos;
        });
      }
    } catch (e) {
      debugPrint("Geocoding Error: $e");
    }
  }

  // ── Helpers ──────────────────────────────────
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) {
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371e3;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLam = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))
        ],
      ),
    );
  }

  // ── Capture ───────────────────────────────────
  Future<void> _handleCapture() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) return;
    try {
      final photo = await _cameraController!.takePicture();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _photoPath = photo.path;
          _location = pos;
        });
      }
    } catch (e) {
      _showAlert('Error', 'Gagal mengambil gambar. Silakan coba lagi.');
    }
  }

  // ── Save Attendance ───────────────────────────
   Future<void> _handleSaveAttendance() async {
      if (_photoPath == null || _location == null) return;

      // ── FIX #5: Restore the radius check that was accidentally removed ─────────
      final officeLoc = context.read<OfficeProvider>().location;
      final targetLat   = double.tryParse(officeLoc.lat)    ?? 0;
      final targetLng   = double.tryParse(officeLoc.lng)    ?? 0;
      final targetRadius = double.tryParse(officeLoc.radius) ?? 100;

      final distance = _calculateDistance(
         _location!.latitude,
         _location!.longitude,
         targetLat,
         targetLng,
      );

      if (distance > targetRadius) {
         _showAlert(
            'Di Luar Jangkauan ❌',
            'Jarak Anda ${distance.round()}m dari kantor.\n'
            'Maksimal radius adalah ${targetRadius.round()}m.',
         );
         return;
      }
      // ─────────────────────────────────────────────────────────────────────────

      setState(() => _isSaving = true);

      try {
         // 1. Face-verification API (unchanged)
         final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

         if (kIsWeb) {
            // Di Web, _photoPath sebenarnya adalah URL Blob (blob:http://...)
            // Kita harus mengambil bytes-nya terlebih dahulu
            final response = await http.get(Uri.parse(_photoPath!));
            final bytes = response.bodyBytes;
            
            request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'upload.jpg', // Beri nama file dummy
            ));
         } else {
            // UNTUK MOBILE (Android/iOS):
            request.files.add(await http.MultipartFile.fromPath('file', _photoPath!));
         }
         request.fields['expected_user'] = _currentUser;
         await request.send();

         // 2. Upload to Google Drive
         await GoogleDriveService.uploadToDrive(_photoPath!);

         if (!mounted) return;
         final timeStr = _formatTime(DateTime.now());
         final dateStr = _formatDate(DateTime.now());

         // 3. Update shared attendance state
         context.read<AttendanceProvider>().setAttendance(AttendanceData(
            time: timeStr,
            address: _locationAddress,
            date: dateStr,
         ));

         // 4. Success dialog
         showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
            title: const Text('Absensi Berhasil! ✅'),
            content: Text(
               'Foto absen berhasil diupload ke Google Drive.\n\n'
               '📍 $_locationAddress\n'
               '🕐 $timeStr',
            ),
            actions: [
               TextButton(
                  onPressed: () {
                  Navigator.pop(context);
                  setState(() => _photoPath = null);
                  widget.onAttendanceSuccess?.call();
                  },
                  child: const Text('Selesai'),
               ),
            ],
            ),
         );
      } catch (e) {
         debugPrint('Drive upload error: $e'); // real error visible in console

         // ── FIX #6: Show the ACTUAL error message so you can debug ─────────────
         _showAlert(
            'Upload Gagal ❌',
            // toString() gives the human-readable String we throw in the service
            e.toString(),
         );
      } finally {
         if (mounted) setState(() => _isSaving = false);
      }
      }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_checkingPermission) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: BrandColors.navy)),
      );
    }
    if (!_cameraPermissionGranted) return _buildPermissionScreen();
    if (_photoPath != null) return _buildPreviewScreen();
    return _buildCameraScreen();
  }

  // ── Permission Screen ─────────────────────────
  Widget _buildPermissionScreen() {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFF1F5F9),
                  Color(0xFFE0F7FA)
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: BrandColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 48, color: BrandColors.navy),
                  ),
                  const SizedBox(height: 24),
                  const Text('Izin Kamera Diperlukan',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NeutralColors.slate800)),
                  const SizedBox(height: 12),
                  const Text(
                    'Untuk melakukan absensi dengan foto, aplikasi memerlukan akses ke kamera Anda.',
                    style: TextStyle(
                        fontSize: 14,
                        color: NeutralColors.slate500,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _initPermissionsAndCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [BrandColors.navy, BrandColors.navyDark],
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Beri Izin Kamera',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Camera Screen ─────────────────────────────
  Widget _buildCameraScreen() {
    if (!_cameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview fills the screen
          CameraPreview(_cameraController!),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x99000000), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Absensi Foto',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(_formatTime(_currentTime),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xB3FFFFFF))),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Face guide oval
          Center(
            child: Container(
              width: 220,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(110),
                border: Border.all(
                    color: Colors.white.withOpacity(0.5), width: 2),
              ),
            ),
          ),

          // Bottom gradient overlay with controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xB3000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Location bar
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: BrandColors.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationAddress,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Capture button
                    GestureDetector(
                      onTap: _handleCapture,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  BrandColors.cyan,
                                  BrandColors.lime
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 32, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Posisikan wajah dalam bingkai, lalu tekan tombol',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xB3FFFFFF)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview Screen ────────────────────────────
  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: NeutralColors.slate50,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _photoPath = null),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: NeutralColors.slate100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back,
                            size: 24, color: NeutralColors.slate800),
                      ),
                    ),
                    const Expanded(
                      child: Text('Konfirmasi Absensi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: NeutralColors.slate800)),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Photo preview
                  ClipRRect(
                     borderRadius: BorderRadius.circular(24),
                     child: kIsWeb
                        ? Image.network(
                           _photoPath!, // Di Web menggunakan Image.network
                           width: double.infinity,
                           height: 340,
                           fit: BoxFit.cover,
                           )
                        : Image.file(
                           io.File(_photoPath!), // Di Mobile menggunakan Image.file
                           width: double.infinity,
                           height: 340,
                           fit: BoxFit.cover,
                           ),
                  ),
                  const SizedBox(height: 20),

                  // Info card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Location row
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: SemanticColors.infoBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.location_on,
                                  size: 18, color: SemanticColors.info),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Lokasi',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: NeutralColors.slate500)),
                                  const SizedBox(height: 2),
                                  Text(_locationAddress,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: NeutralColors.slate800)),
                                  if (_location != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_location!.latitude.toStringAsFixed(6)}, ${_location!.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: NeutralColors.slate400),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(
                            height: 24, color: NeutralColors.slate100),
                        // Time row
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: SemanticColors.successBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.access_time,
                                  size: 18,
                                  color: SemanticColors.success),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('Waktu',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: NeutralColors.slate500)),
                                const SizedBox(height: 2),
                                Text(_formatTime(_currentTime),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: NeutralColors.slate800)),
                                Text(_formatDate(_currentTime),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: NeutralColors.slate400)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  if (_isSaving)
                    const Column(
                      children: [
                        CircularProgressIndicator(
                            color: BrandColors.navy),
                        SizedBox(height: 12),
                        Text('Menyimpan absensi...',
                            style: TextStyle(
                                fontSize: 14,
                                color: NeutralColors.slate500)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        // Retake
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photoPath = null),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: NeutralColors.slate100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh,
                                      size: 20,
                                      color: NeutralColors.slate700),
                                  SizedBox(width: 8),
                                  Text('Foto Ulang',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: NeutralColors.slate700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Confirm
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _handleSaveAttendance,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    SemanticColors.success,
                                    Color(0xFF16A34A)
                                  ],
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 20, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Simpan Absensi',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

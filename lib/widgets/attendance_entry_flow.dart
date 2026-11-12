import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/attendance_policy.dart';
import '../screens/camera_checkin_screen.dart';
import '../services/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../services/calendar_service.dart';
import '../services/liveness_challenge.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'early_checkout_dialog.dart';
import 'open_session_dialog.dart';

/// Hasil gerbang absensi yang lolos: foto dari kamera (bila kebijakan
/// mewajibkan) + fix GPS segar (null bila GPS tidak wajib dan tidak terbaca)
/// + kebijakan yang dipakai.
class AttendanceEntryResult {
  final CameraResult camera;
  final Position? position;
  final AttendancePolicy policy;
  const AttendanceEntryResult(this.camera, this.position,
      [this.policy = AttendancePolicy.strictDefault]);

  /// Path foto, null bila kebijakan tidak mewajibkan foto.
  String? get fotoPath => camera.imagePath;

  /// Dikirim ke server HANYA bila GPS terbaca (null = jangan kirim).
  bool? get lokasiPalsu => position?.isMocked;

  /// Hasil liveness untuk body; null bila tantangan tidak dijalankan.
  LivenessReport? get liveness => camera.liveness;
}

/// Titik sambung ke dunia luar untuk [runAttendanceEntry]. Defaultnya
/// ([AttendanceEntryHooks.live]) memakai provider/kalender/kamera/GPS asli;
/// test mengganti sebagian saja.
class AttendanceEntryHooks {
  final Future<OpenAttendanceSession?> Function() findOpenSession;
  final Future<void> Function() refreshTodayAndSnapshot;
  final bool Function() isHolidayWork;
  final bool Function() isAfterEarliestCheckout;
  final Future<CameraResult?> Function(
          BuildContext, CameraActionType, AttendancePolicy)
      openCamera;

  /// Argumen: blokir lokasi palsu? (kebijakan `deteksiMockGps` + GPS wajib),
  /// dan batas tunggu fix GPS (pendek bila GPS tidak wajib).
  final Future<GpsResult> Function(bool blockMocked, Duration timeLimit)
      readGps;

  /// Kebijakan efektif; tidak pernah melempar (cache -> strict default).
  /// Null = selalu [AttendancePolicy.strictDefault] (tes lama).
  final Future<AttendancePolicy> Function()? fetchPolicy;
  final Future<bool> Function(BuildContext, OpenAttendanceSession)
      closeOpenSession;

  const AttendanceEntryHooks({
    required this.findOpenSession,
    required this.refreshTodayAndSnapshot,
    required this.isHolidayWork,
    required this.isAfterEarliestCheckout,
    required this.openCamera,
    required this.readGps,
    required this.closeOpenSession,
    this.fetchPolicy,
  });

  factory AttendanceEntryHooks.live(AttendanceProvider att) =>
      AttendanceEntryHooks(
        findOpenSession: () async {
          await att.refreshOpenSession();
          return att.openSession;
        },
        refreshTodayAndSnapshot: () async {
          // Tarik ulang `attendance/today` sesegar mungkin persis sebelum
          // gerbang "Belum Jam Pulang!" memutuskan, supaya snapshot shift
          // (jam pulang & toleransi saat check-in) tidak basi bila admin
          // mengedit Shift di tengah hari. Best-effort.
          try {
            await att.refreshToday();
          } catch (_) {}
          final rec = att.today;
          AttendanceRules.hydrateTodaySnapshot(
            jamMasukShiftSnapshot: rec?.jamMasukShiftSnapshot,
            jamPulangShiftSnapshot: rec?.jamPulangShiftSnapshot,
            toleransiPulangSnapshot: rec?.toleransiPulangSnapshot,
          );
        },
        isHolidayWork: () => AppCalendar.instance.hariIni.kerjaHariLibur,
        isAfterEarliestCheckout: () => AttendanceRules.isAfterEarliestCheckout,
        openCamera: (ctx, type, policy) => Navigator.push<CameraResult>(
          ctx,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CameraCheckinScreen(actionType: type, policy: policy),
          ),
        ),
        readGps: (blockMocked, timeLimit) => LocationService.current(
            blockMocked: blockMocked, timeLimit: timeLimit),
        fetchPolicy: AttendanceService.policy,
        closeOpenSession: (ctx, open) => showOpenSessionDialog(ctx, att, open),
      );
}

/// SATU alur masuk untuk check-in/check-out (F5), dipakai FAB `MainScreen`
/// dan kartu Home -- sebelumnya kartu Home melewati dialog "Belum Jam
/// Pulang!" dan konfirmasi hari libur yang hanya ada di FAB. Urutan:
///
///  check-in : kebijakan -> absensi menggantung -> konfirmasi hari libur -> kamera -> GPS
///  check-out: kebijakan -> "Belum Jam Pulang!" (kecuali hari libur) -> kamera -> GPS
///
/// Foto/GPS/radius/mock/liveness mengikuti Kebijakan Absensi efektif
/// (`GET .../attendance/policy`, [AttendanceService.policy]; gagal -> cache ->
/// strict default). GPS dibaca lewat [LocationService.current], yang menolak
/// lokasi palsu (F4) hanya bila kebijakan `deteksiMockGps` + GPS wajib.
/// Bila kebijakan mewajibkan foto: kamera yang mengembalikan `confirmed`
/// tanpa path ditolak di sini (F3). Bila tidak: kamera dilewati sama sekali.
/// Server tetap menghitung ulang semuanya.
///
/// Mengembalikan null bila dibatalkan/ditolak; alasannya (bila perlu
/// diberitahukan) lewat [onMessage]. Pemanggil lalu mengirim ke server.
Future<AttendanceEntryResult?> runAttendanceEntry({
  required BuildContext context,
  required CameraActionType actionType,
  required AttendanceEntryHooks hooks,
  required void Function(String message, {bool error}) onMessage,
}) async {
  final isCheckIn = actionType == CameraActionType.checkIn;

  final policy = hooks.fetchPolicy == null
      ? AttendancePolicy.strictDefault
      : await hooks.fetchPolicy!();
  if (!context.mounted) return null;

  if (isCheckIn) {
    // Server menolak check-in baru (409) selama absensi lama menggantung.
    final open = await hooks.findOpenSession();
    if (!context.mounted) return null;
    if (open != null) {
      final closed = await hooks.closeOpenSession(context, open);
      if (!context.mounted) return null;
      if (closed) {
        onMessage('Absensi ${open.tanggal} ditutup pada ${open.jamPulangShift}. '
            'Sekarang Anda bisa check-in kembali.');
      }
      return null;
    }
  }

  // Kerja di hari libur (lembur yang sudah disetujui): semua jam kerja
  // dihitung lembur. Konfirmasi SEBELUM kamera supaya yang batal tidak
  // perlu berfoto.
  final holidayWork = hooks.isHolidayWork();
  if (isCheckIn && holidayWork) {
    final proceed = await _confirmHolidayWorkCheckIn(context);
    if (!context.mounted || !proceed) return null;
  }

  if (!isCheckIn) {
    await hooks.refreshTodayAndSnapshot();
    if (!context.mounted) return null;
    // Hari libur tidak punya jam pulang shift untuk ditunggu.
    if (!holidayWork && !hooks.isAfterEarliestCheckout()) {
      final proceed = await showEarlyCheckoutDialog(context);
      if (!context.mounted || !proceed) return null;
    }
  }

  CameraResult camera;
  if (policy.wajibFoto) {
    final shot = await hooks.openCamera(context, actionType, policy);
    if (!context.mounted || shot == null || !shot.confirmed) return null;
    final path = shot.imagePath;
    if (path == null || path.isEmpty) {
      onMessage('Foto wajah tidak tersimpan. Silakan ambil foto ulang.',
          error: true);
      return null;
    }
    camera = shot;
  } else {
    // Kebijakan tidak mewajibkan foto: tanpa kamera, tanpa foto terkirim.
    camera = CameraResult(confirmed: true, actionType: actionType);
  }

  // Fix GPS SEGAR tepat saat absen (staff bisa saja sudah berpindah). GPS
  // tidak wajib: gagal baca tidak memblokir (koordinat dikirim bila ada).
  final gps = await hooks.readGps(
      policy.blocksMockedGps,
      LocationService.timeLimitFor(wajibGps: policy.wajibGps));
  if (!context.mounted) return null;
  if (!gps.ok && policy.wajibGps) {
    onMessage(gps.failure!.message, error: true);
    return null;
  }

  return AttendanceEntryResult(camera, gps.position, policy);
}

/// Popup konfirmasi check-in di hari libur. True bila staff melanjutkan.
Future<bool> _confirmHolidayWorkCheckIn(BuildContext context) async {
  final hariIni = AppCalendar.instance.hariIni;
  final window =
      (hariIni.lemburJamMulai != null && hariIni.lemburJamSelesai != null)
          ? '\nRencana yang disetujui: ${hariIni.lemburJamMulai} - ${hariIni.lemburJamSelesai}.'
          : '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.event_available_rounded,
          color: AppColors.brandOrange, size: 36),
      title: Text(
          'Hari libur${hariIni.namaLibur != null ? ': ${hariIni.namaLibur}' : ''}'),
      content: Text(
        'Anda bekerja di hari libur dengan lembur yang sudah disetujui.$window\n\n'
        'Seluruh jam kerja Anda hari ini, dari check-in sampai check-out, '
        'dihitung sebagai lembur. Uang makan dan tunjangan harian tidak '
        'berlaku di hari libur.\n\nLanjut check-in?',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, check-in')),
      ],
    ),
  );
  return ok == true;
}

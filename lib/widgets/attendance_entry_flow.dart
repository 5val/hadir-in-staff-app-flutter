import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../screens/camera_checkin_screen.dart';
import '../services/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../services/calendar_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'early_checkout_dialog.dart';
import 'open_session_dialog.dart';

/// Hasil gerbang absensi yang lolos: foto dari kamera + fix GPS segar.
class AttendanceEntryResult {
  final CameraResult camera;
  final Position position;
  const AttendanceEntryResult(this.camera, this.position);
}

/// Titik sambung ke dunia luar untuk [runAttendanceEntry]. Defaultnya
/// ([AttendanceEntryHooks.live]) memakai provider/kalender/kamera/GPS asli;
/// test mengganti sebagian saja.
class AttendanceEntryHooks {
  final Future<OpenAttendanceSession?> Function() findOpenSession;
  final Future<void> Function() refreshTodayAndSnapshot;
  final bool Function() isHolidayWork;
  final bool Function() isAfterEarliestCheckout;
  final Future<CameraResult?> Function(BuildContext, CameraActionType)
      openCamera;
  final Future<GpsResult> Function() readGps;
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
        openCamera: (ctx, type) => Navigator.push<CameraResult>(
          ctx,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CameraCheckinScreen(actionType: type),
          ),
        ),
        readGps: LocationService.current,
        closeOpenSession: (ctx, open) => showOpenSessionDialog(ctx, att, open),
      );
}

/// SATU alur masuk untuk check-in/check-out (F5), dipakai FAB `MainScreen`
/// dan kartu Home -- sebelumnya kartu Home melewati dialog "Belum Jam
/// Pulang!" dan konfirmasi hari libur yang hanya ada di FAB. Urutan:
///
///  check-in : absensi menggantung -> konfirmasi hari libur -> kamera -> GPS
///  check-out: "Belum Jam Pulang!" (kecuali hari libur) -> kamera -> GPS
///
/// GPS dibaca lewat [LocationService.current], yang juga menolak lokasi palsu
/// (F4). Foto wajib: kamera yang mengembalikan `confirmed` tanpa path
/// ditolak di sini (F3) -- foto wajah adalah bukti absensi di sisi app,
/// walau server menganggap foto opsional.
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

  final camera = await hooks.openCamera(context, actionType);
  if (!context.mounted || camera == null || !camera.confirmed) return null;

  final path = camera.imagePath;
  if (path == null || path.isEmpty) {
    onMessage('Foto wajah tidak tersimpan. Silakan ambil foto ulang.',
        error: true);
    return null;
  }

  // Fix GPS SEGAR tepat saat absen (staff bisa saja sudah berpindah).
  final gps = await hooks.readGps();
  if (!context.mounted) return null;
  if (!gps.ok) {
    onMessage(gps.failure!.message, error: true);
    return null;
  }

  return AttendanceEntryResult(camera, gps.position!);
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

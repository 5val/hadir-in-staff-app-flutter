import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_client.dart';
import '../services/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';

/// Dialog "Belum Check-Out" — penutup absensi yang menggantung.
///
/// Muncul untuk dua skenario yang sebelumnya tidak tertangani sama sekali:
///   1. staff break-in lalu lupa break-out sampai melewati jam pulang +
///      batas maksimal lembur, dan
///   2. hal yang sama tapi dibiarkan sampai HARI BERIKUTNYA.
///
/// Keduanya diselesaikan sama: server menutup istirahat DAN check-out di
/// `Shift.jamPulang` hari itu dengan lembur 0 — staff-nya lupa menutup
/// absensi, bukan bekerja sampai larut.
///
/// Dialognya sengaja TIDAK bisa ditutup dengan mengetuk latar dan tidak
/// punya tombol "nanti": selama absensi itu terbuka, check-in berikutnya
/// ditolak server (HTTP 409), jadi menawarkan penundaan hanya membuat staff
/// berputar di tombol check-in yang selalu gagal.
///
/// Dipakai dua tempat — FAB di `MainScreen` dan kartu check-in di `HomeTab` —
/// karena keduanya adalah pintu menuju check-in.
Future<bool> showOpenSessionDialog(
  BuildContext context,
  AttendanceProvider attendance,
  OpenAttendanceSession open,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Belum Check-Out',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      content: Text(
        openSessionExplanation(open),
        style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.slate600, height: 1.5),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandNavy,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Check-Out Sekarang',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (ok != true || !context.mounted) return false;

  try {
    await attendance.autoCheckoutRemote();
    return true;
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
    );
    return false;
  }
}

/// Penjelasan yang sama dipakai dialog dan notifikasi HP, supaya staff tidak
/// membaca dua versi cerita untuk kejadian yang sama.
String openSessionExplanation(OpenAttendanceSession open) {
  final pembuka = open.lupaBreakOut
      ? 'Absensi tanggal ${open.tanggal} masih terbuka: istirahat dan '
          'check-out Anda belum ditutup.'
      : 'Absensi tanggal ${open.tanggal} masih terbuka: Anda belum check-out.';
  final aturan = open.lupaBreakOut
      ? 'Selesai istirahat dan check-out akan dicatat pukul '
          '${open.jamPulangShift} (jam pulang shift), tanpa lembur — karena '
          'Anda lupa menutupnya, bukan bekerja lembur.'
      : 'Check-out akan dicatat pukul ${open.jamPulangShift} '
          '(jam pulang shift), tanpa lembur.';
  return '$pembuka\n\n$aturan\n\n'
      'Anda harus check-out dulu sebelum bisa check-in kembali.';
}

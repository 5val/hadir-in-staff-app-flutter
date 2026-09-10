import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/attendance_provider.dart';
import '../theme/app_theme.dart';

/// Dialog "Belum Jam Pulang!" — peringatan check-out sebelum jam paling awal
/// yang diizinkan shift (`AttendanceRules.earliestCheckoutTarget`, jam pulang
/// dikurangi toleransi pulang awal).
///
/// Pindah ke sini (2026-09-09) dari dalam `camera_checkin_screen.dart`'s
/// `_confirm()`, yang sebelumnya baru mengecek SETELAH staff mengambil foto
/// -- staff yang membatalkan jadi sudah kehilangan usaha foto+GPS untuk
/// apa-apa. Sekarang dipanggil dari FAB check-out (`main_screen.dart`)
/// SEBELUM kamera dibuka sama sekali: kalau staff batal, kamera tidak
/// pernah terbuka.
///
/// Mengembalikan `true` kalau staff memilih lanjut check-out sekarang,
/// `false` (termasuk dismiss dengan tombol back) kalau batal.
Future<bool> showEarlyCheckoutDialog(BuildContext context) async {
  final jamPulang = AttendanceRules.jamPulangLabel;

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Text('Belum Jam Pulang!',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      content: Text(
        'Jam pulang shift Anda pukul $jamPulang. '
        'Apakah Anda yakin ingin check-out sekarang?',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.slate700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB01E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Ya, Check-Out Sekarang',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    ),
  );

  return ok ?? false;
}

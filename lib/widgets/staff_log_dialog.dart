import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/staff_log_service.dart';

/// Popup untuk satu baris `log_pesan` yang belum dibaca — Fase 8.
///
/// Dua kejadian yang diminta PRD dilayani widget yang sama, hanya beda
/// tampilan: ucapan selamat naik jabatan (meriah) dan surat peringatan
/// (serius). Popup ditutup → log ditandai read → tidak muncul lagi di login
/// berikutnya, karena endpoint hanya mengembalikan yang `readAt`-nya null.
class StaffLogDialog extends StatelessWidget {
  final StaffLog log;

  const StaffLogDialog({super.key, required this.log});

  /// Tampilkan semua log yang belum dibaca satu per satu, lalu tandai read.
  ///
  /// Ditandai read hanya SETELAH popup benar-benar ditutup pengguna — kalau
  /// app tertutup di tengah jalan, log yang belum sempat dilihat tetap
  /// menunggu di login berikutnya.
  static Future<void> showAll(
      BuildContext context, List<StaffLog> logs) async {
    for (final log in logs) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StaffLogDialog(log: log),
      );
      try {
        await StaffLogService.markRead(log.id);
      } catch (_) {
        // Gagal menandai read bukan alasan menghentikan antrean popup —
        // paling buruk log-nya muncul lagi nanti, bukan hilang.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPromosi = log.isPromosi;
    final accent = isPromosi ? AppColors.brandLimeDark : AppColors.danger;
    final tanggal = DateFormat('d MMMM yyyy', 'id_ID').format(log.tanggal);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPromosi
                  ? Icons.emoji_events_rounded
                  : Icons.warning_amber_rounded,
              color: accent,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            log.judul,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isPromosi ? AppColors.slate900 : accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            log.pesan,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tanggal,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(context),
            child: Text(
              isPromosi ? 'Terima Kasih!' : 'Saya Mengerti',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

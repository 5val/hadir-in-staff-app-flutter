import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/calendar_service.dart';

/// Date picker yang MENGHORMATI master hari libur — Fase 8.
///
/// PRD: "pilihan filter tanggal juga hanya bisa memilih tanggal di luar hari
/// libur pada pengajuan izin, cuti, lembur".
///
/// Sebelumnya setiap layar memanggil `showDatePicker` polos tanpa
/// `selectableDayPredicate`, sehingga tanggal merah — yang datanya sudah ada
/// di tabel `hari_libur` sejak lama — tetap bisa dipilih staff.
///
/// Sumber datanya [AppCalendar.instance], dimuat sekali saat app dibuka.
/// Kalau kalender gagal dimuat, [WorkCalendar.empty] membuat semua tanggal
/// tetap bisa dipilih — pilihan yang disengaja: lebih baik picker permisif
/// lalu ditolak server dengan pesan jelas, daripada staff terkunci tidak
/// bisa mengajukan apa pun gara-gara satu request gagal.
Future<DateTime?> showWorkDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,

  /// Set false untuk picker yang hanya memfilter riwayat (bukan pengajuan) —
  /// di sana hari libur tetap boleh dipilih, karena tujuannya melihat data,
  /// bukan mengajukan sesuatu di tanggal tersebut.
  bool blockHolidays = true,
}) async {
  final calendar = AppCalendar.instance;

  DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  bool selectable(DateTime d) =>
      !blockHolidays || calendar.isSelectable(d);

  // `initialDate` wajib lolos predikat, kalau tidak Flutter melempar assert.
  var initial = normalize(initialDate);
  if (blockHolidays) {
    var guard = 0;
    while (!selectable(initial) &&
        !initial.isAfter(normalize(lastDate)) &&
        guard < 400) {
      initial = initial.add(const Duration(days: 1));
      guard++;
    }
    if (!selectable(initial)) initial = normalize(initialDate);
  }

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: normalize(firstDate),
    lastDate: normalize(lastDate),
    selectableDayPredicate: blockHolidays ? selectable : null,
    helpText: blockHolidays ? 'Pilih tanggal hari kerja' : null,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.brandNavy,
          onPrimary: Colors.white,
          onSurface: AppColors.slate900,
        ),
      ),
      child: child!,
    ),
  );
}

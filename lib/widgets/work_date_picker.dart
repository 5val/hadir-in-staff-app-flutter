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
      !blockHolidays || calendar.isSelectableForSubmission(d);

  final first = normalize(firstDate);
  final last = normalize(lastDate);

  // `initialDate` wajib berada di [firstDate, lastDate] DAN lolos predikat,
  // kalau tidak Flutter melempar assert. Dijepit dulu ke rentang, lalu dicari
  // hari kerja terdekat ke depan; kalau tidak ada (mis. rentang izin yang
  // berakhir kemarin), dicari ke belakang.
  var initial = normalize(initialDate);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  // Tidak ada satu pun tanggal yang boleh dipilih: jangan buka picker (tanpa
  // predikat semua tanggal, termasuk yang tertutup, jadi bisa dipilih).
  if (blockHolidays && !calendar.hasSelectableForSubmission(first, last)) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(calendar.noSelectableMessage(first, last))));
    return null;
  }

  if (blockHolidays && !selectable(initial)) {
    DateTime? found;
    for (var d = initial; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      if (selectable(d)) {
        found = d;
        break;
      }
    }
    if (found == null) {
      for (var d = initial;
          !d.isBefore(first);
          d = d.subtract(const Duration(days: 1))) {
        if (selectable(d)) {
          found = d;
          break;
        }
      }
    }
    // Pasti ketemu: rentang tanpa tanggal terpilih sudah ditangani di atas.
    if (found != null) initial = found;
  }

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    selectableDayPredicate: blockHolidays ? selectable : null,
    helpText: blockHolidays
        ? (calendar.periodeTertutup.isEmpty
            ? 'Pilih tanggal hari kerja'
            : 'Pilih tanggal hari kerja. ${WorkCalendar.pesanPeriodeTertutup}')
        : null,
    builder: _theme,
  );
}

Widget _theme(BuildContext context, Widget? child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.brandNavy,
          onPrimary: Colors.white,
          onSurface: AppColors.slate900,
        ),
      ),
      child: child!,
    );

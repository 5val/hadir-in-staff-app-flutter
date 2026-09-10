// Sprint 3 Fase 6 (2026-09-07) -- regression for AttendanceRules'
// overnight-shift wrap fix.
//
// Before this fix, `isAfterNormalCheckout`/`timeUntilCheckout` always
// compared `now` against TODAY's jam pulang, no matter what. That's correct
// for a same-day shift, but wrong for an overnight shift (e.g. 21:00-06:00):
//   - At 15:00 (daytime, shift hasn't started tonight yet), today's 06:00
//     target is already in the past -> falsely reported "past checkout".
//   - At 23:00 (mid-shift, before midnight), today's 06:00 target is also
//     in the past -> `timeUntilCheckout` wrongly returned null instead of
//     counting down to TOMORROW's 06:00.
//
// `computePulangTarget` is the pure (no TestingConfig/static-state)
// extraction of that logic -- see its doc comment for why the split was
// necessary to test this at all (`flutter test` never receives
// `--dart-define=TESTING_MODE`, so `TestingConfig.now()` can't be
// overridden from a test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/attendance_provider.dart';

void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 9, 7, hour, minute);

  group('same-day shift (08:00-17:00) -- unaffected by the overnight fix', () {
    const masuk = TimeOfDay(hour: 8, minute: 0);
    const pulang = TimeOfDay(hour: 17, minute: 0);

    test('before shift starts -> target is today 17:00', () {
      final target = AttendanceRules.computePulangTarget(
          now: at(7, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 7, 17, 0));
      expect(target!.isAfter(at(7, 0)), isTrue);
    });

    test('mid-shift -> target is still today 17:00', () {
      final target = AttendanceRules.computePulangTarget(
          now: at(10, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 7, 17, 0));
    });

    test('after shift ends -> target is today 17:00, already past', () {
      final target = AttendanceRules.computePulangTarget(
          now: at(18, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 7, 17, 0));
      expect(target!.isBefore(at(18, 0)), isTrue);
    });
  });

  group('overnight shift (21:00-06:00) -- the fixed behavior', () {
    const masuk = TimeOfDay(hour: 21, minute: 0);
    const pulang = TimeOfDay(hour: 6, minute: 0);

    test(
        'daytime gap before tonight\'s shift starts, by clock time (15:00) -> target is TODAY 06:00 (already past)',
        () {
      // Deliberate, conservative choice for this inherently ambiguous
      // window: [jamPulang, jamMasuk) by clock time alone can't tell apart
      // "forgot to check out for hours" from "checked in unusually early
      // for tonight's shift" -- AttendanceRules only knows the shift's
      // static TimeOfDay-of-day, not the actual check-in timestamp. Same
      // "today's (possibly already-past) pulang" default the pre-fix code
      // always used for every `now`, kept here rather than guessing.
      final target = AttendanceRules.computePulangTarget(
          now: at(15, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 7, 6, 0));
      expect(target!.isBefore(at(15, 0)), isTrue);
    });

    test(
        'mid-shift before midnight (23:00) -> target is TOMORROW 06:00 (was wrongly null/past before the fix)',
        () {
      final target = AttendanceRules.computePulangTarget(
          now: at(23, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 8, 6, 0));
      expect(target!.difference(at(23, 0)), const Duration(hours: 7));
    });

    test(
        'mid-shift after midnight (03:00, tail of last night\'s shift) -> target is TODAY 06:00',
        () {
      final target = AttendanceRules.computePulangTarget(
          now: at(3, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 7, 6, 0));
      expect(target!.difference(at(3, 0)), const Duration(hours: 3));
    });

    test(
        'just after this morning\'s checkout (07:00, before tonight\'s masuk) -> target is TODAY 06:00, already past',
        () {
      final target = AttendanceRules.computePulangTarget(
          now: at(7, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 7, 6, 0));
      expect(target!.isBefore(at(7, 0)), isTrue);
    });

    test('exactly at masuk clock time (21:00) -> target is tomorrow 06:00',
        () {
      final target = AttendanceRules.computePulangTarget(
          now: at(21, 0), jamMasuk: masuk, jamPulang: pulang);
      expect(target, DateTime(2026, 9, 8, 6, 0));
    });
  });

  group('degenerate inputs', () {
    test('jamPulang null -> null regardless of jamMasuk', () {
      expect(
          AttendanceRules.computePulangTarget(
              now: at(10, 0),
              jamMasuk: const TimeOfDay(hour: 8, minute: 0),
              jamPulang: null),
          isNull);
    });

    test('jamMasuk null (calendar not fully loaded yet) -> falls back to today\'s pulang, same as before the fix', () {
      final target = AttendanceRules.computePulangTarget(
          now: at(10, 0),
          jamMasuk: null,
          jamPulang: const TimeOfDay(hour: 17, minute: 0));
      expect(target, DateTime(2026, 9, 7, 17, 0));
    });
  });

  // ── Countdown jam kerja (kartu "Aktivitas Saat Ini") ──────────────────
  //
  // Aturan yang diminta: countdown SELALU sepanjang jam masuk → jam pulang,
  // berapa pun jam staff check-in. Check-in 07:55 pada shift 08:00-17:00
  // tetap menampilkan 09:00:00 dan DIAM di situ sampai 08:00 -- datang lebih
  // awal tidak menambah sisa jam kerja, karena jam kerjanya belum mulai.
  //
  // `computeMasukTarget`/`computeRemainingWorkTime` adalah ekstraksi pure-nya,
  // dengan alasan yang sama seperti `computePulangTarget` di atas.
  group('jam masuk shift diturunkan MUNDUR dari jam pulang', () {
    test('shift sehari (08:00-17:00) -> masuk = pulang - 9 jam, hari yang sama',
        () {
      final masukTarget = AttendanceRules.computeMasukTarget(
        pulangTarget: DateTime(2026, 9, 7, 17, 0),
        jamMasuk: const TimeOfDay(hour: 8, minute: 0),
        jamPulang: const TimeOfDay(hour: 17, minute: 0),
      );
      expect(masukTarget, DateTime(2026, 9, 7, 8, 0));
    });

    test(
        'shift overnight (21:00-06:00) yang pulangnya BESOK -> masuk ada di hari ini, bukan besok',
        () {
      // Ini yang bikin perlu hitung mundur: merakit jam masuk dari tanggal
      // `pulangTarget` (8 Sep) akan memberi 8 Sep 21:00 -- SESUDAH jam
      // pulangnya sendiri, jadi rentang kerjanya negatif.
      final masukTarget = AttendanceRules.computeMasukTarget(
        pulangTarget: DateTime(2026, 9, 8, 6, 0),
        jamMasuk: const TimeOfDay(hour: 21, minute: 0),
        jamPulang: const TimeOfDay(hour: 6, minute: 0),
      );
      expect(masukTarget, DateTime(2026, 9, 7, 21, 0));
      expect(masukTarget!.isBefore(DateTime(2026, 9, 8, 6, 0)), isTrue);
    });

    test('jamMasuk/jamPulang belum termuat -> null (tidak mengarang rentang)',
        () {
      expect(
          AttendanceRules.computeMasukTarget(
              pulangTarget: DateTime(2026, 9, 7, 17, 0),
              jamMasuk: null,
              jamPulang: const TimeOfDay(hour: 17, minute: 0)),
          isNull);
      expect(
          AttendanceRules.computeMasukTarget(
              pulangTarget: null,
              jamMasuk: const TimeOfDay(hour: 8, minute: 0),
              jamPulang: const TimeOfDay(hour: 17, minute: 0)),
          isNull);
    });
  });

  group('sisa jam kerja dijepit ke jam masuk shift', () {
    final pulangTarget = DateTime(2026, 9, 7, 17, 0);
    final masukTarget = DateTime(2026, 9, 7, 8, 0);

    test('check-in 07:55 (lebih awal) -> tetap 09:00:00, bukan 09:05:00', () {
      expect(
        AttendanceRules.computeRemainingWorkTime(
            now: at(7, 55),
            pulangTarget: pulangTarget,
            masukTarget: masukTarget),
        const Duration(hours: 9),
      );
    });

    test('tepat jam masuk 08:00 -> 09:00:00 (countdown baru mulai berkurang)',
        () {
      expect(
        AttendanceRules.computeRemainingWorkTime(
            now: at(8, 0),
            pulangTarget: pulangTarget,
            masukTarget: masukTarget),
        const Duration(hours: 9),
      );
    });

    test('tengah shift 12:30 -> 04:30:00', () {
      expect(
        AttendanceRules.computeRemainingWorkTime(
            now: at(12, 30),
            pulangTarget: pulangTarget,
            masukTarget: masukTarget),
        const Duration(hours: 4, minutes: 30),
      );
    });

    test('lewat jam pulang -> Duration.zero, bukan negatif (sejak titik ini '
        'yang tampil adalah timer lembur yang menaik)', () {
      expect(
        AttendanceRules.computeRemainingWorkTime(
            now: at(19, 0),
            pulangTarget: pulangTarget,
            masukTarget: masukTarget),
        Duration.zero,
      );
    });

    test('jam shift belum termuat -> null, bukan 00:00:00 palsu', () {
      expect(
        AttendanceRules.computeRemainingWorkTime(
            now: at(12, 0), pulangTarget: null, masukTarget: null),
        isNull,
      );
    });
  });

  // ── Sprint 3 Fase 4 fix (2026-09-08, post-ship review) ────────────────
  //
  // Bug ditemukan lewat recheck: [jamMasukTarget]/[computeMasukTarget]
  // sengaja resolve ke masuk KEMARIN selagi masih di ekor shift overnight
  // (benar buat remainingWorkTime pasca check-in), tapi resolusi itu bikin
  // pengingat PRA-check-in (T-15/T-5/telat) salah nembak "sudah telat"
  // pas JEDA SIANG biasa sebelum shift overnight mulai, padahal
  // seharusnya kasih pengingat buat masuk NANTI MALAM.
  // [computeNextMasukTarget] adalah fix-nya -- sama seperti
  // [computeMasukTarget] di 2 dari 3 cabang, beda HANYA di jeda siang.
  group('computeNextMasukTarget -- jam masuk BERIKUTNYA (bukan pasangan jam pulang aktif)', () {
    const masukPagi = TimeOfDay(hour: 8, minute: 0);
    const pulangPagi = TimeOfDay(hour: 17, minute: 0);
    const masukMalam = TimeOfDay(hour: 21, minute: 0);
    const pulangMalam = TimeOfDay(hour: 6, minute: 0);

    test('shift sehari -> selalu masuk hari ini, gak peduli jam berapa sekarang', () {
      for (final hour in [7, 10, 18]) {
        final target = AttendanceRules.computeNextMasukTarget(
            now: at(hour, 0), jamMasuk: masukPagi, jamPulang: pulangPagi);
        expect(target, DateTime(2026, 9, 7, 8, 0), reason: 'now=$hour:00');
      }
    });

    test(
        'BUG YANG DIPERBAIKI: jeda siang sebelum shift overnight (14:00) -> masuk berikutnya HARI INI 21:00 (akan datang), BUKAN kemarin 21:00 (sudah lewat)',
        () {
      final target = AttendanceRules.computeNextMasukTarget(
          now: at(14, 0), jamMasuk: masukMalam, jamPulang: pulangMalam);
      expect(target, DateTime(2026, 9, 7, 21, 0));
      expect(target!.isAfter(at(14, 0)), isTrue,
          reason: 'target harus di MASA DEPAN relatif ke 14:00, bukan di masa lalu');
    });

    test('tepat awal jeda siang (06:00, baru saja checkout pagi) -> masuk berikutnya hari ini 21:00', () {
      final target = AttendanceRules.computeNextMasukTarget(
          now: at(6, 0), jamMasuk: masukMalam, jamPulang: pulangMalam);
      expect(target, DateTime(2026, 9, 7, 21, 0));
    });

    test('masih ekor shift overnight kemarin (03:00, belum sampai jam pulang sendiri) -> masuk KEMARIN 21:00 (memang telat sejak shift yang sedang berjalan)', () {
      final target = AttendanceRules.computeNextMasukTarget(
          now: at(3, 0), jamMasuk: masukMalam, jamPulang: pulangMalam);
      expect(target, DateTime(2026, 9, 6, 21, 0));
      expect(target!.isBefore(at(3, 0)), isTrue);
    });

    test('shift overnight sudah jalan malam ini (23:00) -> masuk hari ini 21:00 (sudah lewat 2 jam)', () {
      final target = AttendanceRules.computeNextMasukTarget(
          now: at(23, 0), jamMasuk: masukMalam, jamPulang: pulangMalam);
      expect(target, DateTime(2026, 9, 7, 21, 0));
    });

    test('tepat di jam masuk (21:00) -> masuk hari ini 21:00', () {
      final target = AttendanceRules.computeNextMasukTarget(
          now: at(21, 0), jamMasuk: masukMalam, jamPulang: pulangMalam);
      expect(target, DateTime(2026, 9, 7, 21, 0));
    });

    test('jamMasuk atau jamPulang null -> null', () {
      expect(
          AttendanceRules.computeNextMasukTarget(
              now: at(10, 0), jamMasuk: null, jamPulang: pulangPagi),
          isNull);
      expect(
          AttendanceRules.computeNextMasukTarget(
              now: at(10, 0), jamMasuk: masukPagi, jamPulang: null),
          isNull);
    });
  });

}

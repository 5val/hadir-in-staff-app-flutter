// Gerbang "belum mulai bekerja" (joinDate): parsing fail-open + predikat tanggal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/calendar_service.dart';
import 'package:hadirin_staff_app/widgets/work_date_picker.dart';

WorkCalendar cal({DateTime? join}) => WorkCalendar(
      holidayByDate: const {},
      hariKerja: const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'],
      shiftNama: 'Reguler',
      jamMasuk: '08:00',
      jamPulang: '17:00',
      joinDate: join,
    );

void main() {
  group('TodayHolidayStatus parsing', () {
    test('belumMulaiBekerja + mulaiBekerja parsed, bolehAbsen forced false', () {
      final s = TodayHolidayStatus.fromApi({
        'isLibur': false,
        'bolehAbsen': true, // even if server (wrongly) says true
        'belumMulaiBekerja': true,
        'mulaiBekerja': '2026-10-12',
      });
      expect(s.belumMulaiBekerja, isTrue);
      expect(s.mulaiBekerja, DateTime(2026, 10, 12));
      expect(s.bolehAbsen, isFalse);
    });

    test('old server (fields missing) is not gated', () {
      final s = TodayHolidayStatus.fromApi({'isLibur': false});
      expect(s.belumMulaiBekerja, isFalse);
      expect(s.mulaiBekerja, isNull);
      expect(s.bolehAbsen, isTrue);
    });

    test('garbage mulaiBekerja is ignored', () {
      final s = TodayHolidayStatus.fromApi({'mulaiBekerja': 'oops'});
      expect(s.mulaiBekerja, isNull);
    });

    test('WorkCalendar.fromApi carries hariIni gate', () {
      final c = WorkCalendar.fromApi({
        'hariIni': {
          'bolehAbsen': false,
          'belumMulaiBekerja': true,
          'mulaiBekerja': '2026-10-12',
        },
      });
      expect(c.canCheckInToday, isFalse);
      expect(c.hariIni.belumMulaiBekerja, isTrue);
    });
  });

  group('joinDate predicate', () {
    test('dates before joinDate are not selectable, joinDate itself is', () {
      final c = cal(join: DateTime(2026, 10, 14)); // Rabu
      expect(c.isSelectableForSubmission(DateTime(2026, 10, 13)), isFalse);
      expect(c.isSelectableForSubmission(DateTime(2026, 10, 14)), isTrue);
      expect(c.isSelectableForSubmission(DateTime(2026, 10, 15)), isTrue);
    });

    test('no joinDate stays permissive', () {
      expect(cal().isSelectableForSubmission(DateTime(2020, 1, 1)), isTrue);
    });

    test('withJoinDate strips time', () {
      final c = cal().withJoinDate(DateTime(2026, 10, 14, 17, 30));
      expect(c.joinDate, DateTime(2026, 10, 14));
    });

    test('range entirely before joinDate: nothing selectable + message', () {
      final c = cal(join: DateTime(2026, 10, 14));
      final a = DateTime(2026, 10, 5), b = DateTime(2026, 10, 9);
      expect(c.hasSelectableForSubmission(a, b), isFalse);
      expect(c.noSelectableMessage(a, b), contains('14 Okt 2026'));
    });

    test('upcomingHolidays drops holidays before joinDate', () {
      final c = WorkCalendar(
        holidayByDate: const {'2026-10-20': 'A', '2026-12-25': 'B'},
        hariKerja: const [],
        shiftNama: '',
        jamMasuk: '',
        jamPulang: '',
        joinDate: DateTime(2026, 11, 1),
      );
      final r = c.upcomingHolidays(today: DateTime(2026, 10, 9));
      expect(r.map((e) => e.nama), ['B']);
    });
  });

  group('showWorkDatePicker before joinDate', () {
    tearDown(() => AppCalendar.instance = WorkCalendar.empty);

    testWidgets('does not open, shows joinDate message', (tester) async {
      AppCalendar.instance = cal(join: DateTime(2026, 10, 14));
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
      final future = showWorkDatePicker(
        context: ctx,
        initialDate: DateTime(2026, 10, 5),
        firstDate: DateTime(2026, 10, 5),
        lastDate: DateTime(2026, 10, 9),
      );
      await tester.pump();
      expect(await future, isNull);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.textContaining('14 Okt 2026'), findsOneWidget);
    });
  });
}

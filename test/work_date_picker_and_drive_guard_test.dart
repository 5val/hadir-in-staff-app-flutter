// Review fixes (2026-10-05): the date picker must not open when nothing is
// selectable, and a slip must not be uploaded to Drive twice concurrently.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/calendar_service.dart';
import 'package:hadirin_staff_app/services/slip_drive_sync.dart';
import 'package:hadirin_staff_app/widgets/work_date_picker.dart';

WorkCalendar cal({List<PeriodeTertutup> closed = const []}) => WorkCalendar(
      holidayByDate: const {},
      hariKerja: const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'],
      shiftNama: 'Reguler',
      jamMasuk: '08:00',
      jamPulang: '17:00',
      periodeTertutup: closed,
    );

final septClosed = [
  PeriodeTertutup(
      periode: '2026-09',
      start: DateTime(2026, 9, 1),
      endExclusive: DateTime(2026, 10, 1)),
];

void main() {
  group('WorkCalendar.hasSelectableForSubmission', () {
    test('false when the whole range is inside a closed periode', () {
      final c = cal(closed: septClosed);
      expect(c.hasSelectableForSubmission(DateTime(2026, 9, 14), DateTime(2026, 9, 18)), isFalse);
      expect(c.noSelectableMessage(DateTime(2026, 9, 14), DateTime(2026, 9, 18)),
          WorkCalendar.pesanPeriodeTertutup);
    });

    test('true as soon as one open workday is in range (end-exclusive boundary)', () {
      final c = cal(closed: septClosed);
      // 30 Sep (Rabu) closed, 1 Okt (Kamis) open.
      expect(c.hasSelectableForSubmission(DateTime(2026, 9, 30), DateTime(2026, 9, 30)), isFalse);
      expect(c.hasSelectableForSubmission(DateTime(2026, 9, 30), DateTime(2026, 10, 1)), isTrue);
    });

    test('weekend-only range: false with the generic message', () {
      final c = cal();
      final sat = DateTime(2026, 10, 3), sun = DateTime(2026, 10, 4);
      expect(c.hasSelectableForSubmission(sat, sun), isFalse);
      expect(c.noSelectableMessage(sat, sun), isNot(WorkCalendar.pesanPeriodeTertutup));
    });

    test('empty calendar / no closed periods stays permissive', () {
      expect(WorkCalendar.empty.hasSelectableForSubmission(DateTime(2026, 9, 14), DateTime(2026, 9, 14)), isTrue);
    });
  });

  group('showWorkDatePicker with nothing selectable', () {
    tearDown(() => AppCalendar.instance = WorkCalendar.empty);

    testWidgets('does not open the picker, shows the closed-periode message, returns null', (tester) async {
      AppCalendar.instance = cal(closed: septClosed);
      DateTime? result = DateTime(1999);
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
      final future = showWorkDatePicker(
        context: ctx,
        initialDate: DateTime(2026, 9, 14),
        firstDate: DateTime(2026, 9, 14),
        lastDate: DateTime(2026, 9, 18),
      ).then((v) => result = v);
      await tester.pump();
      await future;
      await tester.pump();
      expect(result, isNull);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text(WorkCalendar.pesanPeriodeTertutup), findsOneWidget);
    });
  });

  group('SlipDriveSync in-flight guard', () {
    test('a second claim for the same slip is refused until released', () {
      expect(SlipDriveSync.claimUpload('slip-a'), isTrue);
      expect(SlipDriveSync.claimUpload('slip-a'), isFalse);
      expect(SlipDriveSync.claimUpload('slip-b'), isTrue); // other slips unaffected
      SlipDriveSync.releaseUpload('slip-a');
      expect(SlipDriveSync.claimUpload('slip-a'), isTrue);
      SlipDriveSync.releaseUpload('slip-a');
      SlipDriveSync.releaseUpload('slip-b');
    });
  });
}

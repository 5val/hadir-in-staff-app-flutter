// Lembur hari libur (2026-09-20): parsing status hari ini dari server dan
// daftar hari libur mendatang untuk form pengajuan di muka.
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/calendar_service.dart';
import 'package:hadirin_staff_app/services/overtime_service.dart';

WorkCalendar calendarWith(Map<String, String> holidays) => WorkCalendar(
      holidayByDate: holidays,
      hariKerja: const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'],
      shiftNama: 'Reguler',
      jamMasuk: '08:00',
      jamPulang: '17:00',
    );

const Object _absent = Object();

void main() {
  group('TodayHolidayStatus.fromApi', () {
    test('holiday worked under an approved overtime request', () {
      final s = TodayHolidayStatus.fromApi({
        'isLibur': true,
        'namaLibur': 'Hari Kemerdekaan',
        'bolehAbsen': true,
        'dikecualikanLembur': true,
        'lemburHariLibur': {'jamMulai': '08:00', 'jamSelesai': '16:00'},
      });
      expect(s.kerjaHariLibur, isTrue);
      expect(s.lemburJamMulai, '08:00');
      expect(s.lemburJamSelesai, '16:00');
    });

    test('holiday without approval is not work: check-in stays blocked', () {
      final s = TodayHolidayStatus.fromApi({
        'isLibur': true,
        'bolehAbsen': false,
        'dikecualikanLembur': false,
        'lemburHariLibur': null,
      });
      expect(s.kerjaHariLibur, isFalse);
      expect(s.bolehAbsen, isFalse);
      expect(s.lemburJamMulai, isNull);
    });

    test('an ordinary day, or an old server without the new field, is never holiday work', () {
      expect(TodayHolidayStatus.fromApi({'isLibur': false, 'bolehAbsen': true}).kerjaHariLibur, isFalse);
      expect(TodayHolidayStatus.unknown.kerjaHariLibur, isFalse);
      expect(
        TodayHolidayStatus.fromApi({'isLibur': true, 'dikecualikanLembur': true}).lemburJamMulai,
        isNull,
      );
    });
  });

  group('WorkCalendar.upcomingHolidays', () {
    final today = DateTime(2026, 9, 20);

    test('keeps today and later, nearest first, drops the past', () {
      final cal = calendarWith({
        '2026-12-25': 'Natal',
        '2026-09-10': 'Sudah lewat',
        '2026-09-20': 'Hari ini',
        '2026-10-05': 'Libur Uji',
      });
      final names = cal.upcomingHolidays(today: today).map((h) => h.nama).toList();
      expect(names, ['Hari ini', 'Libur Uji', 'Natal']);
    });

    test('empty calendar gives an empty list', () {
      expect(WorkCalendar.empty.upcomingHolidays(today: today), isEmpty);
    });
  });

  group('periodeTertutup (periode gaji sudah dihitung)', () {
    Map<String, dynamic> payload({Object? tertutup = _absent}) => {
          'hariLibur': [
            {'tanggal': '2026-09-17', 'nama': 'Libur Uji', 'tipe': 'nasional'},
          ],
          'hariKerja': ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'],
          'shift': {'nama': 'Reguler', 'jamMasuk': '08:00', 'jamPulang': '17:00'},
          if (tertutup != _absent) 'periodeTertutup': tertutup,
        };

    final closed = [
      {'periode': '2026-09', 'start': '2026-09-01', 'endExclusive': '2026-10-01'},
    ];

    test('parses the list from the hari-libur response', () {
      final cal = WorkCalendar.fromApi(payload(tertutup: closed));
      expect(cal.periodeTertutup, hasLength(1));
      expect(cal.periodeTertutup.first.periode, '2026-09');
      expect(cal.periodeTertutup.first.start, DateTime(2026, 9, 1));
      expect(cal.periodeTertutup.first.endExclusive, DateTime(2026, 10, 1));
    });

    test('end is EXCLUSIVE: first and last day in, day before and endExclusive out', () {
      final cal = WorkCalendar.fromApi(payload(tertutup: closed));
      expect(cal.isPeriodeTertutup(DateTime(2026, 8, 31)), isFalse);
      expect(cal.isPeriodeTertutup(DateTime(2026, 9, 1)), isTrue);
      expect(cal.isPeriodeTertutup(DateTime(2026, 9, 30)), isTrue);
      expect(cal.isPeriodeTertutup(DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(cal.isPeriodeTertutup(DateTime(2026, 10, 1)), isFalse);
    });

    test('closed workdays are not selectable for submission, but stay workdays', () {
      final cal = WorkCalendar.fromApi(payload(tertutup: closed));
      final wed = DateTime(2026, 9, 16);
      expect(cal.isSelectableForSubmission(wed), isFalse);
      expect(cal.isSelectable(wed), isTrue);
      expect(cal.isSelectableForSubmission(DateTime(2026, 10, 5)), isTrue);
    });

    test('missing field (old server) behaves as before: nothing closed', () {
      final cal = WorkCalendar.fromApi(payload());
      expect(cal.periodeTertutup, isEmpty);
      expect(cal.isPeriodeTertutup(DateTime(2026, 9, 16)), isFalse);
      expect(cal.isSelectableForSubmission(DateTime(2026, 9, 16)), isTrue);
      expect(WorkCalendar.empty.isSelectableForSubmission(DateTime(2026, 9, 16)), isTrue);
    });

    test('malformed entries are ignored (fail-open)', () {
      final cal = WorkCalendar.fromApi(payload(tertutup: [
        'x',
        {'periode': '2026-09', 'start': 'bogus', 'endExclusive': '2026-10-01'},
        {'periode': '2026-08', 'start': '2026-08-01', 'endExclusive': '2026-09-01'},
      ]));
      expect(cal.periodeTertutup, hasLength(1));
      expect(cal.isPeriodeTertutup(DateTime(2026, 9, 16)), isFalse);
    });

    test('the user-facing reason is the agreed copy', () {
      expect(WorkCalendar.pesanPeriodeTertutup,
          'Gaji periode ini sudah dihitung, pengajuan ditutup');
      expect(WorkCalendar.pesanPeriodeLemburTertutup,
          'Gaji periode ini sudah dikunci, pengajuan lembur ditutup');
    });
  });

  group('periodeLemburTertutup (periode gaji sudah dikunci)', () {
    final closed = [
      {'periode': '2026-09', 'start': '2026-09-01', 'endExclusive': '2026-10-01'},
    ];
    Map<String, dynamic> payload(Map<String, Object?> extra) => {
          'hariKerja': ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'],
          'shift': {'nama': 'Reguler', 'jamMasuk': '08:00', 'jamPulang': '17:00'},
          ...extra,
        };

    test('calculated but not locked: closed for cuti/izin, open for lembur', () {
      final cal = WorkCalendar.fromApi(
          payload({'periodeTertutup': closed, 'periodeLemburTertutup': []}));
      final wed = DateTime(2026, 9, 16);
      expect(cal.isPeriodeTertutup(wed), isTrue);
      expect(cal.isSelectableForSubmission(wed), isFalse);
      expect(cal.isPeriodeLemburTertutup(wed), isFalse);
    });

    test('locked: closed for lembur too', () {
      final cal = WorkCalendar.fromApi(
          payload({'periodeTertutup': closed, 'periodeLemburTertutup': closed}));
      expect(cal.isPeriodeLemburTertutup(DateTime(2026, 9, 16)), isTrue);
      expect(cal.isPeriodeLemburTertutup(DateTime(2026, 10, 1)), isFalse);
    });

    test('old server without the field falls back to periodeTertutup', () {
      final cal = WorkCalendar.fromApi(payload({'periodeTertutup': closed}));
      expect(cal.isPeriodeLemburTertutup(DateTime(2026, 9, 16)), isTrue);
      expect(WorkCalendar.empty.isPeriodeLemburTertutup(DateTime(2026, 9, 16)),
          isFalse);
    });
  });

  group('OvertimeRequestRecord.fromApi', () {
    Map<String, dynamic> row({bool? isHariLibur}) => {
          'id': 'o1',
          'tanggal': '2026-10-05T00:00:00.000Z',
          'jamMulai': '08:00',
          'jamSelesai': '16:00',
          'alasan': 'Jaga',
          'status': 'pending',
          'durasiJam': 8,
          if (isHariLibur != null) 'isHariLibur': isHariLibur,
        };

    test('A6: reads the rejection reason (incl. the system auto-reject text), null when blank', () {
      final r = OvertimeRequestRecord.fromApi({
        ...row(),
        'status': 'rejected',
        'alasanTolak': 'Tidak diproses: gaji periode ini sudah dihitung',
      });
      expect(r.alasanTolak, 'Tidak diproses: gaji periode ini sudah dihitung');
      expect(OvertimeRequestRecord.fromApi(row()).alasanTolak, isNull);
      expect(OvertimeRequestRecord.fromApi({...row(), 'alasanTolak': '  '}).alasanTolak, isNull);
    });

    test('reads isHariLibur, defaults to false for old rows', () {
      expect(OvertimeRequestRecord.fromApi(row(isHariLibur: true)).isHariLibur, isTrue);
      expect(OvertimeRequestRecord.fromApi(row()).isHariLibur, isFalse);
    });
  });
}

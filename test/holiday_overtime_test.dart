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

    test('reads isHariLibur, defaults to false for old rows', () {
      expect(OvertimeRequestRecord.fromApi(row(isHariLibur: true)).isHariLibur, isTrue);
      expect(OvertimeRequestRecord.fromApi(row()).isHariLibur, isFalse);
    });
  });
}

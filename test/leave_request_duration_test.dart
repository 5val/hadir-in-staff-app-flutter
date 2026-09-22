// 2026-09-22 -- teammate testing found the app's leave DETAIL screen showing
// a bigger duration than web for a pengajuan that crosses a hari libur: web
// reads the server's `jumlahHari` (holidays excluded, lib/leave-days.ts),
// the app's `LeaveRequest.dayCount` used to always compute the naive
// calendar-day span, which includes the holiday. Pins the fix: `dayCount`
// prefers the server value when present.
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/models/models.dart';

Map<String, dynamic> payload({int? jumlahHari}) => {
      'id': 'leave-1',
      'tipe': 'Cuti',
      'tanggalMulai': '2026-09-07', // Monday
      'tanggalSelesai': '2026-09-11', // Friday -- 5 calendar days
      'status': 'approved',
      'alasan': 'Liburan',
      'diajukanPada': '2026-09-01T00:00:00.000Z',
      if (jumlahHari != null) 'jumlahHari': jumlahHari,
    };

void main() {
  group('LeaveRequest.dayCount', () {
    test('uses the server jumlahHari when present, not the raw calendar span', () {
      // A holiday fell on the Wednesday in between -- server excluded it (4
      // working days), the naive calendar span would say 5.
      final r = LeaveRequest.fromApi(payload(jumlahHari: 4));
      expect(r.jumlahHari, 4);
      expect(r.dayCount, 4);
    });

    test('falls back to the calendar span only when jumlahHari is absent (old server/cache)', () {
      final r = LeaveRequest.fromApi(payload());
      expect(r.jumlahHari, isNull);
      expect(r.dayCount, 5); // Mon-Fri inclusive
    });

    test('a jumlahHari of 0 is still trusted over the calendar span (not treated as missing)', () {
      final r = LeaveRequest.fromApi(payload(jumlahHari: 0));
      expect(r.dayCount, 0);
    });
  });
}

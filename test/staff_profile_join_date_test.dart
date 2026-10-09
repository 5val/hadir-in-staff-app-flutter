import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/models/models.dart';

void main() {
  test('StaffProfile.joinDate parsed from ISO, date part only', () {
    final p = StaffProfile.fromJson({'id': '1', 'joinDate': '2026-10-12T00:00:00.000Z'});
    expect(p.joinDate, DateTime(2026, 10, 12));
  });

  test('StaffProfile.joinDate null when missing/invalid (fail-open)', () {
    expect(StaffProfile.fromJson({'id': '1'}).joinDate, isNull);
    expect(StaffProfile.fromJson({'id': '1', 'joinDate': 'x'}).joinDate, isNull);
  });

  test('copyWithRekening keeps joinDate', () {
    final p = StaffProfile.fromJson({'id': '1', 'joinDate': '2026-10-12'});
    final q = p.copyWithRekening(
        namaBank: 'BCA', nomorRekening: '123', namaPemilikRekening: 'A');
    expect(q.joinDate, DateTime(2026, 10, 12));
  });
}

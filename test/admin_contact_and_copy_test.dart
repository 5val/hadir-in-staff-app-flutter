import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/screens/rekening_screen.dart';
import 'package:hadirin_staff_app/services/admin_contact.dart';

/// F8: kontak admin berasal dari nomor kantor (bukan hardcode) dan peringatan
/// ganti rekening menyebut pencabutan "Setujui Cair" (rekening.ts A9).
void main() {
  group('AdminContact', () {
    test('normalizeToWa: 08..., +62..., 62... semuanya jadi 62...', () {
      expect(AdminContact.normalizeToWa('0811-122-2333'), '628111222333');
      expect(AdminContact.normalizeToWa('+62 811 1222 333'), '628111222333');
      expect(AdminContact.normalizeToWa('628111222333'), '628111222333');
    });

    test('waUri menunjuk wa.me dengan nomor ternormalisasi', () {
      expect(AdminContact.waUri('08123456789').toString(),
          'https://wa.me/628123456789');
    });
  });

  test('peringatan ganti rekening menjelaskan persetujuan cair dicabut', () {
    expect(rekeningReplaceWarning, contains('disetujui untuk dicairkan'));
    expect(rekeningReplaceWarning, contains('belum'));
    expect(rekeningReplaceWarning, contains('dibatalkan persetujuan cairnya'));
  });
}

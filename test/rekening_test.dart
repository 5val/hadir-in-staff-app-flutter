import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/models/models.dart';
import 'package:hadirin_staff_app/services/rekening_service.dart';

StaffProfile profile({String bank = '', String nomor = '', String pemilik = ''}) =>
    StaffProfile.fromJson({
      'id': 's1',
      'nama': 'Budi Santoso',
      'namaBank': bank,
      'nomorRekening': nomor,
      'namaPemilikRekening': pemilik,
    });

void main() {
  group('RekeningValidator', () {
    test('nomor: accepts 5-20 digits, tolerates spaces and dashes', () {
      expect(RekeningValidator.nomor('12345'), isNull);
      expect(RekeningValidator.nomor('1' * 20), isNull);
      expect(RekeningValidator.nomor('123-456 7890'), isNull);
    });

    test('nomor: rejects empty, too short, too long and letters', () {
      expect(RekeningValidator.nomor(''), isNotNull);
      expect(RekeningValidator.nomor('   '), isNotNull);
      expect(RekeningValidator.nomor('1234'), isNotNull);
      expect(RekeningValidator.nomor('1' * 21), isNotNull);
      expect(RekeningValidator.nomor('12345abc'), isNotNull);
    });

    test('normalizeNomor strips spaces and dashes only', () {
      expect(RekeningValidator.normalizeNomor(' 123-456 789 '), '123456789');
    });

    test('bank and pemilik: required, trimmed, length-capped', () {
      expect(RekeningValidator.bank('  '), isNotNull);
      expect(RekeningValidator.bank('BCA'), isNull);
      expect(RekeningValidator.bank('x' * 101), isNotNull);
      expect(RekeningValidator.pemilik(''), isNotNull);
      expect(RekeningValidator.pemilik('Budi'), isNull);
      expect(RekeningValidator.pemilik('x' * 151), isNotNull);
    });
  });

  group('StaffProfile rekening', () {
    test('rekeningLengkap needs bank, number and owner', () {
      expect(profile().rekeningLengkap, isFalse);
      expect(profile(bank: 'BCA', nomor: '12345').rekeningLengkap, isFalse);
      expect(profile(bank: 'BCA', nomor: '12345', pemilik: 'Budi').rekeningLengkap, isTrue);
      expect(profile(bank: ' ', nomor: '12345', pemilik: 'Budi').rekeningLengkap, isFalse);
    });

    test('nomorRekeningMasked shows only the last 4 digits', () {
      expect(profile(nomor: '1234567890').nomorRekeningMasked, '******7890');
      expect(profile(nomor: '1234').nomorRekeningMasked, '1234');
      expect(profile().nomorRekeningMasked, '');
    });

    test('copyWithRekening replaces only the rekening', () {
      final before = profile();
      final after = before.copyWithRekening(
          namaBank: 'BRI', nomorRekening: '9876543210', namaPemilikRekening: 'Budi');
      expect(after.rekeningLengkap, isTrue);
      expect(after.namaBank, 'BRI');
      expect(after.id, before.id);
      expect(after.nama, before.nama);
      expect(before.rekeningLengkap, isFalse);
    });
  });
}

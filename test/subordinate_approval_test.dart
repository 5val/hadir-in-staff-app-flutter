import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/screens/subordinate_requests_screen.dart';
import 'package:hadirin_staff_app/services/subordinate_service.dart';

/// F6: persetujuan lembur oleh atasan + alasan tolak.
void main() {
  group('SubordinateService.respondBody', () {
    test('setuju tidak membawa alasan walau diisi', () {
      expect(SubordinateService.respondBody(approve: true, alasanTolak: 'x'),
          {'action': 'approve'});
    });

    test('tolak membawa alasan yang di-trim; kosong = tidak dikirim', () {
      expect(
          SubordinateService.respondBody(approve: false, alasanTolak: '  Bentrok  '),
          {'action': 'reject', 'alasanTolak': 'Bentrok'});
      expect(SubordinateService.respondBody(approve: false, alasanTolak: '  '),
          {'action': 'reject'});
      expect(SubordinateService.respondBody(approve: false), {'action': 'reject'});
    });

    test('alasan dipotong ke batas server 500', () {
      final body = SubordinateService.respondBody(
          approve: false, alasanTolak: 'a' * 600);
      expect((body['alasanTolak'] as String).length, 500);
    });
  });

  group('SubordinateOvertime.fromApi', () {
    test('mem-parse pengajuan lembur bawahan', () {
      final o = SubordinateOvertime.fromApi({
        'id': 'l1',
        'tanggal': '2026-11-03T00:00:00.000Z',
        'jamMulai': '17:00',
        'jamSelesai': '20:00',
        'alasan': 'Tutup buku',
        'status': 'pending',
        'staff': {'id': 's1', 'nama': 'Budi', 'jabatan': {'nama': 'Kasir'}},
      });
      expect(o.staffNama, 'Budi');
      expect(o.jabatan, 'Kasir');
      expect(o.jamMulai, '17:00');
    });
  });

  group('showSubordinateDecisionDialog', () {
    Future<void> open(WidgetTester tester, bool approve,
        void Function(({String? alasan})?) onResult) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => onResult(await showSubordinateDecisionDialog(
                ctx,
                approve: approve,
                name: 'Budi',
                kind: 'lembur')),
            child: const Text('buka'),
          ),
        ),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    testWidgets('tolak: ada kolom alasan dan nilainya dikembalikan', (tester) async {
      ({String? alasan})? res;
      await open(tester, false, (r) => res = r);
      expect(find.byKey(const Key('alasan-tolak')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('alasan-tolak')), ' Bentrok jadwal ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tolak'));
      await tester.pumpAndSettle();
      expect(res?.alasan, 'Bentrok jadwal');
    });

    testWidgets('setuju: tidak ada kolom alasan', (tester) async {
      ({String? alasan})? res;
      await open(tester, true, (r) => res = r);
      expect(find.byKey(const Key('alasan-tolak')), findsNothing);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Setujui'));
      await tester.pumpAndSettle();
      expect(res, isNotNull);
      expect(res!.alasan, isNull);
    });

    testWidgets('batal mengembalikan null', (tester) async {
      var called = false;
      ({String? alasan})? res;
      await open(tester, false, (r) {
        called = true;
        res = r;
      });
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(res, isNull);
    });
  });
}

// Widget tests for the screens added in F4 (2026-09-20) that could not be run on
// a device: slip detail (confirm / reject / download gating) and the rekening
// form. They exercise only what renders and validates locally -- no network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadirin_staff_app/models/models.dart';
import 'package:hadirin_staff_app/screens/rekening_screen.dart';
import 'package:hadirin_staff_app/screens/salary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

SalarySlip slipWith(String statusSlip, {bool? bisaUnduh, String? alasanTolak}) =>
    SalarySlip.fromApi({
      'id': 'slip-1',
      'staffId': 'staff-1',
      'periode': '2026-08',
      'gajiPokok': 5000000,
      'gajiNetto': 5000000,
      'statusSlip': statusSlip,
      'statusBayar': 'unpaid',
      'bisaUnduh': bisaUnduh ?? statusSlip == 'terkunci',
      if (alasanTolak != null) 'alasanTolak': alasanTolak,
    });

Future<void> pumpDetail(WidgetTester tester, SalarySlip slip) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: SalaryDetailScreen(slip: slip, user: AppSession.currentUser),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SalaryDetailScreen -- status drives what the staff can do', () {
    testWidgets('menunggu_konfirmasi: confirm/reject bar, review banner, NO download', (tester) async {
      await pumpDetail(tester, slipWith('menunggu_konfirmasi'));
      expect(find.text('Konfirmasi, sudah benar'), findsOneWidget);
      expect(find.text('Ada yang salah'), findsOneWidget);
      expect(find.text('Mohon periksa slip ini'), findsOneWidget);
      expect(find.text('Unduh PDF'), findsNothing);
      expect(find.text('Simpan ke Google Drive'), findsNothing);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
    });

    testWidgets('dikonfirmasi: waiting-for-lock banner, no action bar, no download', (tester) async {
      await pumpDetail(tester, slipWith('dikonfirmasi'));
      expect(find.text('Sudah Anda konfirmasi'), findsOneWidget);
      expect(find.text('Konfirmasi, sudah benar'), findsNothing);
      expect(find.text('Unduh PDF'), findsNothing);
    });

    testWidgets('ditolak: shows the staff\'s own reason back to them', (tester) async {
      await pumpDetail(tester, slipWith('ditolak', alasanTolak: 'Lembur saya kurang 2 jam'));
      expect(find.text('Anda menolak slip ini'), findsOneWidget);
      expect(find.textContaining('Lembur saya kurang 2 jam'), findsOneWidget);
      expect(find.text('Konfirmasi, sudah benar'), findsNothing);
    });

    testWidgets('terkunci: download + Google Drive available, no confirm bar', (tester) async {
      await pumpDetail(tester, slipWith('terkunci'));
      expect(find.text('Slip final'), findsOneWidget);
      expect(find.text('Unduh PDF'), findsOneWidget);
      expect(find.text('Simpan ke Google Drive'), findsOneWidget);
      expect(find.text('Konfirmasi, sudah benar'), findsNothing);
      expect(find.text('Ada yang salah'), findsNothing);
    });

    testWidgets('terkunci banner buttons sit in a Wrap so they drop to a second line on a narrow phone', (tester) async {
      // Not an overflow assertion: flutter_test's fallback font is far wider than
      // Inter, so it would also trip on hero-card rows that pre-date F4. What
      // matters is that the two side-by-side buttons (~340dp of real text)
      // cannot be a fixed Row inside a ~290dp banner.
      await pumpDetail(tester, slipWith('terkunci'));
      expect(find.ancestor(of: find.text('Unduh PDF'), matching: find.byType(Wrap)), findsOneWidget);
      expect(find.ancestor(of: find.text('Simpan ke Google Drive'), matching: find.byType(Wrap)), findsOneWidget);
    });

    testWidgets('the server flag decides: a locked-looking status without bisaUnduh gets no download', (tester) async {
      await pumpDetail(tester, slipWith('terkunci', bisaUnduh: false));
      expect(find.text('Unduh PDF'), findsNothing);
    });
  });

  group('SalaryDetailScreen -- reject dialog', () {
    testWidgets('"Kirim ke HR" stays disabled until the reason has at least 5 characters', (tester) async {
      await pumpDetail(tester, slipWith('menunggu_konfirmasi'));
      await tester.tap(find.text('Ada yang salah'));
      await tester.pumpAndSettle();
      expect(find.text('Apa yang salah?'), findsOneWidget);

      FilledButton send() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kirim ke HR'));
      expect(send().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'sala');
      await tester.pump();
      expect(send().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  sala  ');
      await tester.pump();
      expect(send().onPressed, isNull, reason: 'spaces must not count toward the minimum');

      await tester.enterText(find.byType(TextField), 'salah');
      await tester.pump();
      expect(send().onPressed, isNotNull, reason: 'exactly 5 real characters is enough');

      await tester.enterText(find.byType(TextField), 'lembur kurang');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    });

    testWidgets('cancelling the reject dialog changes nothing', (tester) async {
      await pumpDetail(tester, slipWith('menunggu_konfirmasi'));
      await tester.tap(find.text('Ada yang salah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Apa yang salah?'), findsNothing);
      expect(find.text('Konfirmasi, sudah benar'), findsOneWidget);
    });
  });

  group('SalaryDetailScreen -- confirm dialog', () {
    testWidgets('asks before confirming; cancelling leaves the slip awaiting confirmation', (tester) async {
      await pumpDetail(tester, slipWith('menunggu_konfirmasi'));
      await tester.tap(find.text('Konfirmasi, sudah benar'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi slip gaji?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi slip gaji?'), findsNothing);
      expect(find.text('Mohon periksa slip ini'), findsOneWidget);
    });
  });

  group('RekeningScreen', () {
    Future<void> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RekeningScreen()));
      await tester.pump();
    }

    testWidgets('empty submit shows every required-field message and saves nothing', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Simpan Rekening'));
      await tester.pump();
      expect(find.text('Nama bank wajib diisi'), findsOneWidget);
      expect(find.text('Nomor rekening wajib diisi'), findsOneWidget);
      expect(find.text('Nama pemilik rekening wajib diisi'), findsOneWidget);
    });

    testWidgets('the number field only accepts digits, spaces and dashes', (tester) async {
      await pumpForm(tester);
      // The hint lives in the decoration, so locate the field by it.
      final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Hanya angka, 5-20 digit');
      expect(field, findsOneWidget);
      await tester.enterText(field, 'ab12-3 4x');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '12-3 4');
    });

    testWidgets('a too-short number is rejected with the 5-20 digit message', (tester) async {
      await pumpForm(tester);
      final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Hanya angka, 5-20 digit');
      await tester.enterText(field, '1234');
      await tester.tap(find.text('Simpan Rekening'));
      await tester.pump();
      expect(find.text('Nomor rekening harus 5-20 digit'), findsOneWidget);
    });

    testWidgets('a bank chip fills the bank field', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.widgetWithText(ActionChip, 'Mandiri'));
      await tester.pump();
      final bank = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'mis. BCA');
      expect(tester.widget<TextField>(bank).controller!.text, 'Mandiri');
    });
  });
}

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

SalarySlip slipWith(String statusSlip,
        {bool? bisaUnduh,
        String? alasanTolak,
        String statusBayar = 'unpaid',
        String? siapDicairkanAt,
        Map<String, dynamic> extra = const {}}) =>
    SalarySlip.fromApi({
      'id': 'slip-1',
      'staffId': 'staff-1',
      'periode': '2026-08',
      'gajiPokok': 5000000,
      'gajiNetto': 5000000,
      'statusSlip': statusSlip,
      'statusBayar': statusBayar,
      if (siapDicairkanAt != null) 'siapDicairkanAt': siapDicairkanAt,
      'bisaUnduh': bisaUnduh ?? statusSlip == 'terkunci',
      if (alasanTolak != null) 'alasanTolak': alasanTolak,
      ...extra,
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
      expect(find.text('Disetujui'), findsOneWidget);
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
      expect(find.text('Anda menyetujui slip ini'), findsOneWidget);
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

  group('SalaryDetailScreen -- tolak dialog with per-part checkboxes', () {
    testWidgets('lists slip parts, submit disabled until a part is checked or a note is typed', (tester) async {
      await pumpDetail(tester, slipWith('menunggu_konfirmasi'));
      await tester.tap(find.text('Ada yang salah'));
      await tester.pumpAndSettle();

      expect(find.text('Apa yang salah?'), findsOneWidget);
      // Hanya gaji pokok, lembur, tunjangan & fasilitas yang bisa ditolak.
      expect(find.text('Data kehadiran / absensi'), findsNothing);
      expect(find.text('Total / Take Home Pay'), findsNothing);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      final gajiPokok = find.byKey(const ValueKey('tolak-item-0'));
      expect(find.descendant(of: gajiPokok, matching: find.text('Gaji Pokok')), findsOneWidget);

      FilledButton send() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kirim ke HR'));
      expect(send().onPressed, isNull);

      await tester.tap(gajiPokok);
      await tester.pump();
      expect(send().onPressed, isNotNull);

      await tester.tap(gajiPokok);
      await tester.pump();
      expect(send().onPressed, isNull);

      await tester.enterText(find.byKey(const Key('tolak-catatan')), 'salah hitung');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    });
  });

  group('SalaryDetailScreen -- pencairan state', () {
    testWidgets('terkunci + siapDicairkanAt: "Sedang diproses pencairan"', (tester) async {
      await pumpDetail(tester,
          slipWith('terkunci', siapDicairkanAt: '2026-10-01T03:00:00.000Z'));
      // Banner + baris di kartu atas.
      expect(find.text('Sedang diproses pencairan'), findsNWidgets(2));
      expect(find.text('Sudah dicairkan'), findsNothing);
      expect(find.text('Anda menyetujui slip ini'), findsOneWidget);
    });

    testWidgets('paid: "Sudah dicairkan"', (tester) async {
      await pumpDetail(
          tester,
          slipWith('terkunci',
              statusBayar: 'paid', siapDicairkanAt: '2026-10-01T03:00:00.000Z'));
      expect(find.text('Sudah dicairkan'), findsOneWidget);
      expect(find.text('Sedang diproses pencairan'), findsNothing);
    });

    testWidgets('terkunci but not approved to pay: no pencairan banner', (tester) async {
      await pumpDetail(tester, slipWith('terkunci'));
      expect(find.text('Sedang diproses pencairan'), findsNothing);
      expect(find.text('Sudah dicairkan'), findsNothing);
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

  group('SalaryDetailScreen -- penolakan sekali, tanda revisi, pencairan', () {
    testWidgets('slip yang sudah pernah ditolak & dikirim ulang: tidak bisa ditolak lagi', (tester) async {
      await pumpDetail(
          tester,
          slipWith('menunggu_konfirmasi', alasanTolak: 'Gaji pokok salah', extra: {
            'ditolakAt': '2026-09-02T03:00:00.000Z',
            'bisaTolak': false,
          }));
      expect(find.text('Konfirmasi, sudah benar'), findsOneWidget);
      expect(find.text('Ada yang salah'), findsNothing);
      expect(find.text('Slip sudah direvisi HR'), findsOneWidget);
    });

    testWidgets('ikon merah di bagian yang ditolak, hijau di hasil revisi', (tester) async {
      await pumpDetail(
          tester,
          slipWith('menunggu_konfirmasi', alasanTolak: 'Gaji pokok salah', extra: {
            'ditolakAt': '2026-09-02T03:00:00.000Z',
            'bisaTolak': false,
            'bagianTolak': ['col:gajiPokok'],
            'revisions': [
              {
                'editedAt': '2026-09-03T03:00:00.000Z',
                'editedByNama': 'Rina',
                'perubahan': [
                  {'key': 'col:gajiPokok', 'label': 'Gaji Pokok', 'sebelum': 4800000, 'sesudah': 5000000}
                ],
              }
            ],
          }));
      // Baris yang ditolak SEKALIGUS direvisi: satu ikon saja, hijau.
      expect(find.byKey(const ValueKey('marker-revisi-col:gajiPokok')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-tolak-col:gajiPokok')), findsNothing);
      expect(find.byKey(const Key('slip-revisi-list')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('marker-revisi-col:gajiPokok')));
      await tester.pumpAndSettle();
      expect(find.text('Direvisi: Gaji Pokok'), findsOneWidget);
      expect(find.textContaining('oleh Rina'), findsOneWidget);
      expect(find.textContaining('sebelumnya Anda tolak'), findsOneWidget);
    });

    testWidgets('sudah dicairkan: nama admin, waktu & tombol bukti transfer', (tester) async {
      await pumpDetail(
          tester,
          slipWith('terkunci', statusBayar: 'paid', extra: {
            'paidAt': '2026-10-12T07:05:00.000Z',
            'paidOleh': 'Rina Admin',
            'adaBuktiBayar': true,
          }));
      expect(find.textContaining('Dicairkan oleh: Rina Admin'), findsOneWidget);
      expect(find.byKey(const Key('btn-lihat-bukti')), findsOneWidget);
      expect(find.textContaining('Ditransfer via'), findsNothing);
    });

    testWidgets('belum dicairkan: tidak ada tulisan "Ditransfer"/pencairan', (tester) async {
      await pumpDetail(tester, slipWith('menunggu_konfirmasi'));
      expect(find.textContaining('Ditransfer'), findsNothing);
      expect(find.byKey(const Key('slip-hero-pencairan')), findsNothing);
      expect(find.byKey(const Key('btn-lihat-bukti')), findsNothing);
    });
  });

  group('Popup tahapan status slip', () {
    test('posisi tahap mengikuti status slip', () {
      expect(slipCurrentStep(null), isNull);
      expect(slipCurrentStep(slipWith('menunggu_konfirmasi')), 1);
      expect(slipCurrentStep(slipWith('ditolak')), 2);
      expect(slipCurrentStep(slipWith('terkunci')), 3);
      expect(slipCurrentStep(slipWith('terkunci', siapDicairkanAt: '2026-10-01T03:00:00.000Z')), 4);
      expect(slipCurrentStep(slipWith('terkunci', statusBayar: 'paid')), 5);
    });

    testWidgets('menampilkan semua tahap dengan tahap sekarang disorot', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSlipStatusGuide(context, slipWith('menunggu_konfirmasi')),
            child: const Text('help'),
          ),
        ),
      ));
      await tester.tap(find.text('help'));
      await tester.pumpAndSettle();
      expect(find.text('Tahapan Slip Gaji'), findsOneWidget);
      expect(find.byKey(const ValueKey('slip-step-1-current')), findsOneWidget);
      expect(find.text('Sekarang'), findsOneWidget);
    });
  });

  group('filterSlipsByMonths', () {
    SalarySlip weekly(String key, String status) => SalarySlip.fromApi({
          'id': key,
          'periode': key,
          'gajiNetto': 1,
          'statusSlip': status,
        });
    SalarySlip monthly(String key, String status) => SalarySlip.fromApi({
          'id': key,
          'periode': key,
          'gajiNetto': 1,
          'statusSlip': status,
        });

    test('filter 3 bulan menampilkan W35 & W36 walau ada slip yang lebih baru', () {
      final slips = [
        weekly('2026-W40', 'terkunci'),
        weekly('2026-W38', 'terkunci'),
        weekly('2026-W37', 'terkunci'),
        weekly('2026-W36', 'menunggu_konfirmasi'),
        weekly('2026-W35', 'menunggu_konfirmasi'),
        weekly('2026-W32', 'terkunci'),
      ];
      final ids = filterSlipsByMonths(slips, 3, now: DateTime(2026, 10, 16))
          .map((s) => s.id)
          .toList();
      expect(ids, ['2026-W40', '2026-W38', '2026-W37', '2026-W36', '2026-W35', '2026-W32']);
    });

    test('N bulan memotong berdasarkan tanggal, bukan jumlah slip', () {
      final slips = [
        weekly('2026-W40', 'terkunci'),
        weekly('2026-W35', 'terkunci'),
        weekly('2026-W32', 'terkunci'),
      ];
      final ids = filterSlipsByMonths(slips, 1, now: DateTime(2026, 10, 16))
          .map((s) => s.id)
          .toList();
      expect(ids, ['2026-W40']);
    });

    test('urutan: bulanan baru di atas mingguan lama; menunggu konfirmasi selalu ikut', () {
      final slips = [
        weekly('2026-W32', 'menunggu_konfirmasi'),
        weekly('2026-W40', 'terkunci'),
        monthly('2026-10', 'terkunci'),
      ];
      final ids = filterSlipsByMonths(slips, 1, now: DateTime(2026, 10, 16))
          .map((s) => s.id)
          .toList();
      expect(ids.first, '2026-10');
      expect(ids, contains('2026-W32'));
    });
  });

  group('Tombol bantuan di detail slip', () {
    testWidgets('membuka legend dengan tahap sesuai status slip yang dibuka', (tester) async {
      await pumpDetail(tester, slipWith('ditolak', alasanTolak: 'Gaji pokok salah'));
      await tester.tap(find.byKey(const Key('slip-status-help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slip-status-guide')), findsOneWidget);
      expect(find.byKey(const ValueKey('slip-step-2-current')), findsOneWidget);
    });

    testWidgets('slip terkunci & sudah dicairkan menyorot tahap terakhir', (tester) async {
      await pumpDetail(tester, slipWith('terkunci', statusBayar: 'paid'));
      await tester.tap(find.byKey(const Key('slip-status-help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('slip-step-5-current')), findsOneWidget);
    });
  });

  group('Slip ditolak lalu direvisi HR (draft) & posisi ikon', () {
    testWidgets('draft setelah ditolak: banner "HR sedang merevisi", tanpa tombol aksi', (tester) async {
      await pumpDetail(
          tester,
          slipWith('draft', alasanTolak: 'Gaji pokok salah', extra: {
            'ditolakAt': '2026-09-02T03:00:00.000Z',
            'bagianTolak': ['col:gajiPokok'],
          }));
      expect(find.text('Anda menolak slip ini, HR sedang merevisi'), findsOneWidget);
      expect(find.text('Konfirmasi, sudah benar'), findsNothing);
      expect(find.text('Ada yang salah'), findsNothing);
      expect(find.byKey(const ValueKey('marker-tolak-col:gajiPokok')), findsOneWidget);
    });

    test('draft yang pernah ditolak berlabel "Anda menolak" dan di tahap 3', () {
      final s = slipWith('draft', extra: {'ditolakAt': '2026-09-02T03:00:00.000Z'});
      expect(s.statusLabel, 'Anda menolak — menunggu perbaikan HR');
      expect(s.bisaTolak, isFalse);
      expect(slipCurrentStep(s), 2);
    });

    testWidgets('ikon ⓘ berada di sebelah KIRI teks komponen, sejajar vertikal', (tester) async {
      await pumpDetail(
          tester,
          slipWith('menunggu_konfirmasi', extra: {
            'ditolakAt': '2026-09-02T03:00:00.000Z',
            'bisaTolak': false,
            'bagianTolak': ['col:gajiPokok'],
          }));
      final marker = tester.getRect(find.byKey(const ValueKey('marker-tolak-col:gajiPokok')));
      final label = tester.getRect(find.text('Gaji Pokok').first);
      expect(marker.right, lessThanOrEqualTo(label.left + 0.5));
      expect((marker.center.dy - label.center.dy).abs(), lessThan(marker.height));
    });
  });
}

// Sprint 3 follow-up (2026-10-16): filter periode, label status, parsing tipe
// periode, deep-link notifikasi slip, animasi perhatian, batal-setuju & bukti.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadirin_staff_app/models/models.dart';
import 'package:hadirin_staff_app/models/slip_filter.dart';
import 'package:hadirin_staff_app/screens/salary_screen.dart';
import 'package:hadirin_staff_app/screens/slip_bukti_screen.dart';
import 'package:hadirin_staff_app/services/api_client.dart';
import 'package:hadirin_staff_app/services/notification_menu_hints.dart';
import 'package:hadirin_staff_app/services/salary_service.dart';
import 'package:hadirin_staff_app/services/slip_deep_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

SalarySlip slip(String periode,
        {String id = 's1',
        String status = 'terkunci',
        String statusBayar = 'unpaid',
        String? siapCair,
        Map<String, dynamic> extra = const {}}) =>
    SalarySlip.fromApi({
      'id': id,
      'periode': periode,
      'gajiNetto': 1000000,
      'statusSlip': status,
      'statusBayar': statusBayar,
      if (siapCair != null) 'siapDicairkanAt': siapCair,
      ...extra,
    });

// 1x1 PNG.
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tipe & label periode', () {
    test('tipe diturunkan dari bentuk kunci bila server tidak mengirim', () {
      expect(slip('2026-10').periodeType, 'bulanan');
      expect(slip('2026-W40').periodeType, 'mingguan');
      expect(slip('2026-10-05').periodeType, 'harian');
    });

    test('periodeType dari server dipakai; nilai asing jatuh ke turunan', () {
      expect(slip('2026-10', extra: {'periodeType': 'mingguan'}).periodeType,
          'mingguan');
      expect(slip('2026-W40', extra: {'periodeType': 'ngawur'}).periodeType,
          'mingguan');
    });

    test('label sesuai tipe', () {
      expect(slip('2026-10-05').periodeLabel, 'Senin, 5 Okt 2026');
      expect(slip('2026-W40').periodeLabel,
          'Minggu 40 · 28 Sep–4 Okt');
      expect(slip('2026-10').periodeLabel, 'Oktober 2026');
    });
  });

  group('SlipFilter', () {
    final slips = [
      slip('2026-09', id: 'a'),
      slip('2026-W40', id: 'b'),
      slip('2026-W39', id: 'c'),
      slip('2026-W40', id: 'd'), // duplikat kunci
    ];

    test('opsi mengikuti tipe terbaru (mingguan) tanpa duplikat', () {
      final opts = SlipFilter.periodeOptions(slips);
      expect(opts.map((o) => o.key), ['2026-W40', '2026-W39']);
      expect(opts.first.label, startsWith('Minggu 40'));
    });

    test('"Semua periode" (null) memuat slip tipe lama juga, terbaru dulu', () {
      final all = SlipFilter.apply(slips, null);
      expect(all.length, 4);
      expect(all.map((s) => s.id), contains('a'));
      expect(all.first.periodeKey, '2026-W40');
    });

    test('memilih satu periode menyaring', () {
      expect(SlipFilter.apply(slips, '2026-W39').map((s) => s.id), ['c']);
    });

    test('tanpa slip: tidak ada opsi', () {
      expect(SlipFilter.periodeOptions(const []), isEmpty);
    });
  });

  group('label status kartu', () {
    test('menunggu_konfirmasi', () {
      final s = slip('2026-10', status: 'menunggu_konfirmasi');
      expect(s.statusLabel, 'Perlu konfirmasi Anda');
      expect(s.perluAksi, isTrue);
    });
    test('ditolak', () {
      expect(slip('2026-10', status: 'ditolak').statusLabel,
          'Anda menolak — menunggu perbaikan HR');
    });
    test('terkunci = Disetujui; legacy dikonfirmasi = Disetujui', () {
      expect(slip('2026-10').statusLabel, 'Disetujui');
      expect(slip('2026-10', status: 'dikonfirmasi').statusLabel, 'Disetujui');
    });
    test('terkunci + siap cair', () {
      expect(slip('2026-10', siapCair: '2026-10-10T00:00:00Z').statusLabel,
          'Sedang diproses pencairan');
    });
    test('paid', () {
      expect(
          slip('2026-10',
                  siapCair: '2026-10-10T00:00:00Z', statusBayar: 'paid')
              .statusLabel,
          'Sudah dicairkan');
    });
    test('perluAksi dari server menang atas turunan', () {
      expect(slip('2026-10', extra: {'perluAksi': true}).perluAksi, isTrue);
    });
  });

  group('batal-setuju & bukti (flag server + turunan)', () {
    test('flag server dipakai', () {
      expect(
          slip('2026-10', extra: {'bisaBatalSetuju': false})
              .bisaBatalSetujuEfektif,
          isFalse);
      expect(
          slip('2026-10', status: 'ditolak', extra: {'bisaBatalSetuju': true})
              .bisaBatalSetujuEfektif,
          isTrue);
    });
    test('tanpa flag: terkunci belum siap cair boleh; siap cair/paid/ditolak tidak', () {
      expect(slip('2026-10').bisaBatalSetujuEfektif, isTrue);
      expect(slip('2026-10', status: 'dikonfirmasi').bisaBatalSetujuEfektif,
          isTrue);
      expect(
          slip('2026-10', siapCair: '2026-10-10T00:00:00Z')
              .bisaBatalSetujuEfektif,
          isFalse);
      expect(
          slip('2026-10', statusBayar: 'paid').bisaBatalSetujuEfektif, isFalse);
      expect(
          slip('2026-10', status: 'ditolak').bisaBatalSetujuEfektif, isFalse);
    });
    test('bukti hanya untuk paid dan bila server tidak menyatakan tidak ada', () {
      expect(slip('2026-10').adaBuktiBayar, isFalse);
      expect(slip('2026-10', statusBayar: 'paid').adaBuktiBayar, isTrue);
      expect(
          slip('2026-10', statusBayar: 'paid', extra: {'adaBuktiBayar': false})
              .adaBuktiBayar,
          isFalse);
    });
    test('body batal-setuju & deteksi PDF', () {
      expect(SalaryService.batalSetujuBody('  salah angka ', 'T'),
          {'alasan': 'salah angka', 'dikirimKonfirmasiAt': 'T'});
      expect(
          SalaryService.batalSetujuBody('x', null)
              .containsKey('dikirimKonfirmasiAt'),
          isFalse);
      expect(
          SalaryService.isPdfBytes(
              Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1])),
          isTrue);
      expect(SalaryService.isPdfBytes(_png), isFalse);
    });
  });

  group('notifikasi slip', () {
    test('semua tipe slip_/gaji_/pencairan_ menuju tab Gaji (index 3)', () {
      for (final t in [
        'slip_konfirmasi_diminta',
        'slip_ditarik',
        'slip_terkunci',
        'slip_siap_cair',
        'slip_batal_setuju',
        'slip_tipe_masa_depan',
        'gaji_dicairkan',
        'pencairan_dibatalkan',
      ]) {
        final target = notificationTargetFromRawType(t);
        expect(target, NotificationTarget.gaji, reason: t);
        expect(target.staffTabIndex, 3, reason: t);
      }
    });
    test('tipe lain tidak ikut; cuti tetap', () {
      expect(notificationTargetFromRawType('document_rejected'),
          NotificationTarget.none);
      expect(notificationTargetFromRawType('leave_approved'),
          NotificationTarget.leave);
    });
    test('judul kosong dari server -> fallback terbaca', () {
      final n = AppNotification.fromApi({
        'id': '1',
        'type': 'slip_tipe_masa_depan',
        'title': '',
        'body': 'Sesuatu terjadi pada slip Anda.',
        'metadata': {'slipId': 'x'},
      });
      expect(n.title, 'Slip gaji');
      expect(n.target, NotificationTarget.gaji);
      expect(n.metadata['slipId'], 'x');
      expect(
          notificationFallbackTitle('tak_dikenal', body: 'Halo dunia. Lagi.'),
          'Halo dunia');
      expect(notificationFallbackTitle('tak_dikenal'), 'Notifikasi');
      expect(notificationFallbackTitle('slip_x', title: 'Judul asli'),
          'Judul asli');
    });
    test('petunjuk menu untuk tipe slip yang belum terdaftar', () {
      expect(NotificationMenuHints.menuPath('slip_tipe_masa_depan'),
          'Gaji > Slip Gaji');
      expect(NotificationMenuHints.menuPath('pencairan_dibatalkan'),
          'Gaji > Slip Gaji');
    });
  });

  group('AttentionPulse', () {
    Future<List<double>> scales(WidgetTester t, {required bool play}) async {
      final out = <double>[];
      await t.pumpWidget(MaterialApp(
        home: AttentionPulse(
            play: play,
            child: const SizedBox(key: Key('c'), width: 10, height: 10)),
      ));
      for (var ms = 0; ms <= 3200; ms += 100) {
        final tr = t.widget<ScaleTransition>(find.byType(ScaleTransition));
        out.add(tr.scale.value);
        await t.pump(const Duration(milliseconds: 100));
      }
      return out;
    }

    testWidgets('1.0 -> ~1.08 -> 1.0, dua kali, lalu diam sebelum 3 s',
        (t) async {
      final s = await scales(t, play: true);
      expect(s.first, 1.0);
      expect(s.reduce((a, b) => a > b ? a : b), closeTo(1.08, 0.005));
      expect(s.last, 1.0);
      var peaks = 0;
      for (var i = 1; i < s.length - 1; i++) {
        if (s[i] > 1.06 && s[i] >= s[i - 1] && s[i] > s[i + 1]) peaks++;
      }
      expect(peaks, 2);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('play=false tidak beranimasi', (t) async {
      final s = await scales(t, play: false);
      expect(s.every((v) => v == 1.0), isTrue);
    });

    testWidgets('rebuild tidak mengulang animasi', (t) async {
      await scales(t, play: true);
      await t.pumpWidget(MaterialApp(
        home: AttentionPulse(
            play: true,
            child: const SizedBox(key: Key('c'), width: 10, height: 10)),
      ));
      await t.pump(const Duration(milliseconds: 600));
      expect(t.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value,
          1.0);
    });
  });

  group('detail slip: batalkan persetujuan & bukti', () {
    Future<void> pump(WidgetTester t, SalarySlip s) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          home: SalaryDetailScreen(slip: s, user: AppSession.currentUser)));
      await t.pump();
    }

    testWidgets('tombol Batalkan persetujuan tampil saat bisaBatalSetuju',
        (t) async {
      await pump(t, slip('2026-10', extra: {'bisaBatalSetuju': true}));
      expect(find.byKey(const Key('btn-batal-setuju')), findsOneWidget);
    });

    testWidgets('tidak tampil saat server bilang tidak boleh', (t) async {
      await pump(t, slip('2026-10', extra: {'bisaBatalSetuju': false}));
      expect(find.byKey(const Key('btn-batal-setuju')), findsNothing);
    });

    testWidgets('dialog alasan: kirim aktif hanya >= 5 karakter', (t) async {
      String? result;
      await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (ctx) => TextButton(
                onPressed: () async => result = await showDialog<String>(
                    context: ctx, builder: (_) => const BatalSetujuDialog()),
                child: const Text('buka'))),
      ));
      await t.tap(find.text('buka'));
      await t.pumpAndSettle();
      FilledButton btn() =>
          t.widget<FilledButton>(find.byKey(const Key('batal-kirim')));
      expect(btn().onPressed, isNull);
      await t.enterText(find.byKey(const Key('batal-alasan')), 'abc');
      await t.pump();
      expect(btn().onPressed, isNull);
      await t.enterText(find.byKey(const Key('batal-alasan')), ' angka salah ');
      await t.pump();
      expect(btn().onPressed, isNotNull);
      await t.tap(find.byKey(const Key('batal-kirim')));
      await t.pumpAndSettle();
      expect(result, 'angka salah');
    });

    testWidgets('paid: tombol Lihat bukti pembayaran', (t) async {
      await pump(t, slip('2026-10', statusBayar: 'paid'));
      expect(find.byKey(const Key('btn-lihat-bukti')), findsOneWidget);
      expect(find.byKey(const Key('btn-batal-setuju')), findsNothing);
    });

    testWidgets('paid tapi adaBuktiBayar=false: tombol disembunyikan',
        (t) async {
      await pump(t,
          slip('2026-10', statusBayar: 'paid', extra: {'adaBuktiBayar': false}));
      expect(find.byKey(const Key('btn-lihat-bukti')), findsNothing);
    });
  });

  slipDeepLinkTests();

  group('SlipBuktiScreen', () {
    testWidgets('gambar tampil di InteractiveViewer (zoom)', (t) async {
      await t.pumpWidget(MaterialApp(
          home: SlipBuktiScreen(title: 'Bukti', loader: () async => BuktiFile(_png))));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('bukti-image')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('error server ditampilkan apa adanya', (t) async {
      await t.pumpWidget(MaterialApp(
          home: SlipBuktiScreen(
              title: 'Bukti',
              loader: () async =>
                  throw ApiException('Bukti belum diunggah', statusCode: 404))));
      await t.pump();
      await t.pump();
      expect(find.text('Bukti belum diunggah'), findsOneWidget);
    });
  });

  group('review fixes', () {
    test('tipe periode terkini: dikirimKonfirmasiAt terbaru, bukan periodeStart terbaru', () {
      final slips = [
        // periode paling baru, tetapi dikirim lebih dulu (tipe lama)
        slip('2026-10', id: 'old', extra: {
          'dikirimKonfirmasiAt': '2026-10-01T00:00:00.000Z'
        }),
        // periode lebih lama, tetapi dikirim belakangan (tipe baru)
        slip('2026-W30', id: 'new', extra: {
          'dikirimKonfirmasiAt': '2026-10-15T00:00:00.000Z'
        }),
      ];
      expect(SlipFilter.currentType(slips), 'mingguan');
      expect(SlipFilter.periodeOptions(slips).map((o) => o.key), ['2026-W30']);
    });

    test('fallback ke createdAt, lalu profil jabatan didahulukan', () {
      final slips = [
        slip('2026-10', id: 'a', extra: {'createdAt': '2026-10-01T00:00:00.000Z'}),
        slip('2026-W30', id: 'b', extra: {'createdAt': '2026-10-10T00:00:00.000Z'}),
      ];
      expect(SlipFilter.currentType(slips), 'mingguan');
      expect(SlipFilter.currentType(slips, profileType: 'Bulanan'), 'bulanan');
      expect(SlipFilter.currentType(const [], profileType: 'harian'), 'harian');
      expect(SlipFilter.currentType(slips, profileType: 'ngawur'), 'mingguan');
    });

    test('limit slip = 500 (maks server)', () {
      expect(SalaryService.maxSlipLimit, 500);
    });

    test('paid menang atas status legacy; siap cair untuk dikonfirmasi', () {
      expect(slip('2026-10', status: 'dikonfirmasi', statusBayar: 'paid').statusLabel,
          'Sudah dicairkan');
      expect(slip('2026-10', status: 'menunggu_konfirmasi', statusBayar: 'paid').statusLabel,
          'Sudah dicairkan');
      expect(
          slip('2026-10', status: 'dikonfirmasi', siapCair: '2026-10-10T00:00:00Z')
              .statusLabel,
          'Sedang diproses pencairan');
    });

    test('PDF terdeteksi di 1024 byte pertama; content-type didahulukan', () {
      final junk = Uint8List(300)..setAll(0, [1, 2, 3]);
      final pdf = Uint8List.fromList([...junk, 0x25, 0x50, 0x44, 0x46, 0x2d]);
      expect(SalaryService.isPdfBytes(pdf), isTrue);
      final far = Uint8List.fromList([...Uint8List(2000), 0x25, 0x50, 0x44, 0x46]);
      expect(SalaryService.isPdfBytes(far), isFalse);
      expect(BuktiFile(_png, 'application/pdf').isPdf, isTrue);
      expect(BuktiFile(pdf, 'image/png').isPdf, isFalse);
      expect(BuktiFile(pdf).isPdf, isTrue);
    });

    test('Utf16LengthLimitingFormatter memotong per unit UTF-16 tanpa belah surrogate', () {
      final f = Utf16LengthLimitingFormatter(5);
      TextEditingValue v(String t) => TextEditingValue(text: t);
      expect(f.formatEditUpdate(v(''), v('abcdefg')).text, 'abcde');
      // 4 huruf + emoji (2 unit) = 6 unit > 5 -> emoji dibuang utuh.
      expect(f.formatEditUpdate(v(''), v('abcd\u{1F600}')).text, 'abcd');
      expect('\u{1F600}'.length, 2);
    });

    testWidgets('dialog: emoji dihitung 2 unit; counter = angka yang divalidasi', (t) async {
      await t.pumpWidget(MaterialApp(
          home: Builder(
              builder: (c) => TextButton(
                  onPressed: () => showDialog<String>(
                      context: c, builder: (_) => const BatalSetujuDialog()),
                  child: const Text('buka')))));
      await t.tap(find.text('buka'));
      await t.pumpAndSettle();
      // 3 emoji = 6 unit UTF-16 (>= 5) walau hanya 3 grapheme.
      await t.enterText(find.byKey(const Key('batal-alasan')), '\u{1F600}\u{1F600}\u{1F600}');
      await t.pump();
      expect(find.text('6/300'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byKey(const Key('batal-kirim'))).onPressed,
          isNotNull);
      // 200 emoji = 400 unit -> dipotong ke 300.
      await t.enterText(find.byKey(const Key('batal-alasan')), '\u{1F600}' * 200);
      await t.pump();
      expect(find.text('300/300'), findsOneWidget);
    });

    testWidgets('batal-setuju 409: tetap di layar, pesan server, status disegarkan', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final fresh = slip('2026-10',
          siapCair: '2026-10-10T00:00:00Z', extra: {'bisaBatalSetuju': false});
      await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                    builder: (_) => SalaryDetailScreen(
                          slip: slip('2026-10', extra: {'bisaBatalSetuju': true}),
                          user: AppSession.currentUser,
                          batalSetujuCall: (id, a, {dikirimKonfirmasiAt}) async =>
                              throw ApiException(
                                  'Slip sudah disetujui untuk dicairkan, persetujuan tidak bisa dibatalkan lagi.',
                                  statusCode: 409),
                          slipLoader: (_) async => fresh,
                        ))),
                child: const Text('buka'))),
      ));
      await t.tap(find.text('buka'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('btn-batal-setuju')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('batal-alasan')), 'angka salah');
      await t.pump();
      await t.tap(find.byKey(const Key('batal-kirim')));
      await t.pumpAndSettle();
      expect(find.byType(SalaryDetailScreen), findsOneWidget); // tidak ter-pop
      expect(find.textContaining('sudah disetujui untuk dicairkan'), findsOneWidget);
      expect(find.byKey(const Key('btn-batal-setuju')), findsNothing); // disegarkan
    });

    testWidgets('banner legacy dikonfirmasi = "Disetujui"', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          home: SalaryDetailScreen(
              slip: slip('2026-10', status: 'dikonfirmasi'),
              user: AppSession.currentUser)));
      await t.pump();
      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.text('Sudah Anda konfirmasi'), findsNothing);
    });

    testWidgets('bukti: byte bukan gambar/PDF -> pesan jelas + Coba Lagi', (t) async {
      var calls = 0;
      await t.pumpWidget(MaterialApp(
          home: SlipBuktiScreen(
              title: 'Bukti',
              loader: () async {
                calls++;
                return BuktiFile(Uint8List.fromList(List.filled(64, 7)));
              })));
      await t.pump();
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump();
      await t.pump();
      expect(find.text('Bukti tidak bisa ditampilkan'), findsOneWidget);
      await t.tap(find.byKey(const Key('bukti-retry')));
      await t.pump();
      expect(calls, 2);
    });
  });

  group('bukti gabungan', () {
    test('buktiGabungan menyembunyikan bukti walau flag lain true', () {
      final s = slip('2026-10',
          statusBayar: 'paid',
          extra: {'buktiGabungan': true, 'adaBuktiBayar': true});
      expect(s.adaBuktiBayar, isFalse);
      expect(s.tampilCatatanBuktiGabungan, isTrue);
      expect(slip('2026-10', statusBayar: 'paid').buktiGabungan, isFalse);
      expect(slip('2026-10', statusBayar: 'paid').adaBuktiBayar, isTrue);
    });

    testWidgets('banner: tanpa tombol, ada catatan; field absen = perilaku lama', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      Future<void> pumpSlip(SalarySlip s) async {
        await t.pumpWidget(const SizedBox()); // paksa State baru
        await t.pumpWidget(MaterialApp(
            home: SalaryDetailScreen(slip: s, user: AppSession.currentUser)));
        await t.pump();
      }

      await pumpSlip(slip('2026-10',
          statusBayar: 'paid',
          extra: {'buktiGabungan': true, 'adaBuktiBayar': false}));
      expect(find.byKey(const Key('btn-lihat-bukti')), findsNothing);
      expect(find.text('Bukti transfer gabungan disimpan oleh HR'), findsOneWidget);

      await pumpSlip(slip('2026-10', statusBayar: 'paid'));
      expect(find.byKey(const Key('btn-lihat-bukti')), findsOneWidget);
      expect(find.byKey(const Key('bukti-gabungan-note')), findsNothing);
    });
  });

  group('AttentionPulse visibility', () {
    Widget host(Widget child,
            {bool tickers = true, ScrollController? sc, double gap = 0}) =>
        MaterialApp(
          home: TickerMode(
            enabled: tickers,
            child: Scaffold(
              body: ListView(controller: sc, children: [
                if (gap > 0) SizedBox(height: gap),
                child,
                const SizedBox(height: 2000),
              ]),
            ),
          ),
        );

    testWidgets('tab tersembunyi (TickerMode off): tidak beranimasi; saat aktif baru mulai', (t) async {
      var played = 0;
      final card = AttentionPulse(
          onPlayed: () => played++,
          child: const SizedBox(width: 100, height: 60));
      await t.pumpWidget(host(card, tickers: false));
      await t.pump(const Duration(milliseconds: 500));
      expect(played, 0);
      await t.pumpWidget(host(card, tickers: true));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(played, 1);
      await t.pump(const Duration(milliseconds: 3000));
    });

    testWidgets('kartu di luar layar baru beranimasi setelah di-scroll terlihat', (t) async {
      var played = 0;
      final sc = ScrollController();
      addTearDown(sc.dispose);
      await t.pumpWidget(host(
          AttentionPulse(
              onPlayed: () => played++,
              child: const SizedBox(width: 100, height: 60)),
          sc: sc,
          gap: 3000));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(played, 0);
      sc.jumpTo(2900);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(played, 1);
      await t.pump(const Duration(milliseconds: 3000));
    });
  });
}

// Deep-link notifikasi -> detail slip.
void slipDeepLinkTests() {
  group('SlipDeepLink', () {
    test('slipId dibaca dari metadata ATAU data push', () {
      expect(SlipDeepLink.slipIdFrom(metadata: {'slipId': 'a1'}), 'a1');
      expect(SlipDeepLink.slipIdFrom(data: {'slipId': 'b2'}), 'b2');
      expect(
          SlipDeepLink.slipIdFrom(metadata: {'slipId': 'a1'}, data: {'slipId': 'b2'}),
          'a1');
      expect(SlipDeepLink.slipIdFrom(metadata: {}, data: {'slipId': ''}), isNull);
      expect(SlipDeepLink.slipIdFrom(), isNull);
    });

    test('payload ketukan round-trip; format lama tanpa slipId tetap terbaca', () {
      final p = SlipDeepLink.buildPayload('slip_terkunci', 'n1', slipId: 's9');
      expect(p, 'notification:slip_terkunci:n1:s9');
      final r = SlipDeepLink.parsePayload(p)!;
      expect((r.rawType, r.id, r.slipId), ('slip_terkunci', 'n1', 's9'));
      final old = SlipDeepLink.parsePayload('notification:leave_approved:n2')!;
      expect(old.slipId, isNull);
      expect(SlipDeepLink.buildPayload('x', 'n3'), 'notification:x:n3');
      expect(SlipDeepLink.parsePayload('local:abc'), isNull);
      expect(SlipDeepLink.parsePayload(null), isNull);
    });

    test('keputusan routing: ketemu -> slip itu; tidak ketemu/tanpa id -> null', () {
      final slips = [slip('2026-10', id: 'a'), slip('2026-09', id: 'b')];
      expect(SlipDeepLink.resolve(slips, 'b')!.id, 'b');
      expect(SlipDeepLink.resolve(slips, 'zzz'), isNull);
      expect(SlipDeepLink.resolve(slips, null), isNull);
      expect(SlipDeepLink.resolve(slips, ' '), isNull);
    });

    test('request mengisi pending hanya untuk id valid', () {
      SlipDeepLink.pending.value = null;
      SlipDeepLink.request(null);
      expect(SlipDeepLink.pending.value, isNull);
      SlipDeepLink.request('s1');
      expect(SlipDeepLink.pending.value, 's1');
      SlipDeepLink.pending.value = null;
    });
  });
}

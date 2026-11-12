// 2026-11-12 -- Aturan lampiran bukti per jenis + Dinas dari app (kontrak
// sprint3.md "Aturan lampiran bukti per jenis + Dinas dari app"). Mengunci:
// parsing aturan + fallback, batas wajib(N), pemetaan Dinas (tipe Dinas,
// subTipe ""), jendela tanggal Dinas, gating tombol kirim, label riwayat
// Dinas, dan kolom foto di form Cuti/Izin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/models/aturan_lampiran.dart';
import 'package:hadirin_staff_app/models/models.dart';
import 'package:hadirin_staff_app/screens/leave_tab.dart';
import 'package:hadirin_staff_app/services/calendar_service.dart';
import 'package:intl/date_symbol_data_local.dart';

AturanLampiran rules({
  AturanLampiranJenis cuti = AturanLampiranJenis.tidakPerlu,
  AturanLampiranJenis sakit = AturanLampiranJenis.opsional,
  AturanLampiranJenis dinas = AturanLampiranJenis.opsional,
}) =>
    AturanLampiran(jenis: {
      ...AturanLampiran.fallback.jenis,
      LampiranJenis.cutiTahunan: cuti,
      LampiranJenis.sakit: sakit,
      LampiranJenis.dinas: dinas,
    });

void main() {
  group('AturanLampiran.fromApi', () {
    test('parses all five jenis, lebihDariHari only kept for wajib', () {
      final r = AturanLampiran.fromApi({
        'jenis': {
          'sakit': {'mode': 'wajib', 'lebihDariHari': 2},
          'izin_seminar': {'mode': 'opsional', 'lebihDariHari': null},
          'izin_lainnya': {'mode': 'tidak_perlu', 'lebihDariHari': 5},
          'dinas': {'mode': 'wajib', 'lebihDariHari': null},
          'cuti_tahunan': {'mode': 'opsional', 'lebihDariHari': null},
        },
        'maxLampiran': 3,
      });
      expect(r.untuk('sakit').mode, LampiranMode.wajib);
      expect(r.untuk('sakit').lebihDariHari, 2);
      expect(r.untuk('izin_seminar').mode, LampiranMode.opsional);
      expect(r.untuk('izin_lainnya').mode, LampiranMode.tidakPerlu);
      expect(r.untuk('izin_lainnya').lebihDariHari, isNull);
      expect(r.untuk('dinas').wajib(1), isTrue);
      expect(r.untuk('cuti_tahunan').mode, LampiranMode.opsional);
      expect(r.maxLampiran, 3);
    });

    test('missing / garbled entries fall back to server defaults', () {
      final r = AturanLampiran.fromApi({
        'jenis': {
          'sakit': {'mode': 'ngawur'},
          'dinas': 'x',
        },
      });
      expect(r.untuk('sakit').mode, LampiranMode.opsional);
      expect(r.untuk('dinas').mode, LampiranMode.opsional);
      expect(r.untuk('cuti_tahunan').mode, LampiranMode.tidakPerlu);
      expect(r.maxLampiran, 3);
      expect(AturanLampiran.fromApi({}).untuk('cuti_tahunan').mode,
          LampiranMode.tidakPerlu);
    });

    test('fallback = current behaviour (izin opsional, cuti tidak perlu)', () {
      const f = AturanLampiran.fallback;
      for (final k in ['sakit', 'izin_seminar', 'izin_lainnya', 'dinas']) {
        expect(f.untuk(k).mode, LampiranMode.opsional, reason: k);
      }
      expect(f.untuk('cuti_tahunan').mode, LampiranMode.tidakPerlu);
      expect(f.untuk('cuti_tahunan').tampil, isFalse);
    });
  });

  group('wajib(jumlahHari) boundary', () {
    test('wajib with N: false at N, true at N+1', () {
      const r = AturanLampiranJenis(LampiranMode.wajib, 2);
      expect(r.wajib(1), isFalse);
      expect(r.wajib(2), isFalse);
      expect(r.wajib(3), isTrue);
    });

    test('wajib without N is always required; opsional/tidak_perlu never', () {
      const r = AturanLampiranJenis(LampiranMode.wajib);
      expect(r.wajib(1), isTrue);
      expect(AturanLampiranJenis.opsional.wajib(99), isFalse);
      expect(AturanLampiranJenis.tidakPerlu.wajib(99), isFalse);
    });

    test('judul explains the rule', () {
      expect(AturanLampiranJenis.opsional.judul, 'Foto Bukti (opsional)');
      expect(const AturanLampiranJenis(LampiranMode.wajib).judul,
          'Foto Bukti (wajib)');
      expect(const AturanLampiranJenis(LampiranMode.wajib, 2).judul,
          'Foto Bukti (wajib bila lebih dari 2 hari)');
    });
  });

  group('lampiranTerpenuhi (gating tombol kirim)', () {
    test('wajib: needs >= 1 photo', () {
      const r = AturanLampiranJenis(LampiranMode.wajib);
      expect(lampiranTerpenuhi(r, 1, 0), isFalse);
      expect(lampiranTerpenuhi(r, 1, 1), isTrue);
    });

    test('wajib lebih dari N: photo only needed past N days', () {
      const r = AturanLampiranJenis(LampiranMode.wajib, 2);
      expect(lampiranTerpenuhi(r, 2, 0), isTrue);
      expect(lampiranTerpenuhi(r, 3, 0), isFalse);
      expect(lampiranTerpenuhi(r, 3, 1), isTrue);
    });

    test('opsional / tidak_perlu never block', () {
      expect(lampiranTerpenuhi(AturanLampiranJenis.opsional, 5, 0), isTrue);
      expect(lampiranTerpenuhi(AturanLampiranJenis.tidakPerlu, 5, 0), isTrue);
    });
  });

  group('Dinas mapping', () {
    test('Dinas -> tipe Dinas, subTipe empty (NOT Izin)', () {
      final m = izinTypeToApi('Dinas');
      expect(m.tipe, 'Dinas');
      expect(m.subTipe, '');
    });

    test('other Izin types unchanged', () {
      expect(izinTypeToApi('Sakit'), (tipe: 'Sakit', subTipe: ''));
      expect(izinTypeToApi('Seminar'), (tipe: 'Izin', subTipe: 'Seminar'));
      expect(izinTypeToApi('Lainnya'), (tipe: 'Izin', subTipe: 'Lainnya'));
    });

    test('rule key per UI type', () {
      expect(LampiranJenis.forIzinType('Sakit'), 'sakit');
      expect(LampiranJenis.forIzinType('Seminar'), 'izin_seminar');
      expect(LampiranJenis.forIzinType('Lainnya'), 'izin_lainnya');
      expect(LampiranJenis.forIzinType('Dinas'), 'dinas');
    });

    test('history: a Dinas row is LeaveType.dinas, not seminar', () {
      final r = LeaveRequest.fromApi({
        'id': '1',
        'tipe': 'Dinas',
        'subTipe': '',
        'tanggalMulai': '2026-11-16',
        'tanggalSelesai': '2026-11-17',
        'status': 'pending',
        'alasan': 'Kunjungan klien',
        'diajukanPada': '2026-11-12T00:00:00.000Z',
      });
      expect(r.type, LeaveType.dinas);
      // Izin Seminar stays seminar.
      final s = LeaveRequest.fromApi({
        'id': '2',
        'tipe': 'Izin',
        'subTipe': 'Seminar',
        'tanggalMulai': '2026-11-10',
        'tanggalSelesai': '2026-11-10',
        'status': 'approved',
        'diajukanPada': '2026-11-12T00:00:00.000Z',
      });
      expect(s.type, LeaveType.seminar);
    });
  });

  group('dinasRange (today -1 month .. today +1 month, inclusive)', () {
    test('plain date', () {
      final r = dinasRange(DateTime(2026, 11, 12, 15, 30));
      expect(r.first, DateTime(2026, 10, 12));
      expect(r.last, DateTime(2026, 12, 12));
    });

    test('month clamp like backend (31 Mar -> 28 Feb / 30 Apr)', () {
      final r = dinasRange(DateTime(2026, 3, 31));
      expect(r.first, DateTime(2026, 2, 28));
      expect(r.last, DateTime(2026, 4, 30));
    });

    test('year boundary and leap year', () {
      final r = dinasRange(DateTime(2027, 1, 31));
      expect(r.first, DateTime(2026, 12, 31));
      expect(r.last, DateTime(2027, 2, 28));
      expect(dinasRange(DateTime(2028, 3, 31)).first, DateTime(2028, 2, 29));
    });
  });

  group('forms', () {
    setUpAll(() => initializeDateFormatting('id_ID'));
    setUp(() => AppCalendar.instance = WorkCalendar.empty);

    Future<void> pump(WidgetTester t, Widget form) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: form)),
      ));
    }

    testWidgets('Cuti: tidak_perlu -> no photo field (unchanged)', (t) async {
      await pump(t, CutiForm(rules: rules()));
      expect(find.textContaining('Foto Bukti'), findsNothing);
    });

    testWidgets('Cuti: opsional -> photo field shown', (t) async {
      await pump(
          t, CutiForm(rules: rules(cuti: AturanLampiranJenis.opsional)));
      expect(find.text('Foto Bukti (opsional)'), findsOneWidget);
    });

    testWidgets('Cuti: wajib lebih dari 3 hari -> explained title', (t) async {
      await pump(
          t,
          CutiForm(
              rules: rules(
                  cuti: const AturanLampiranJenis(LampiranMode.wajib, 3))));
      expect(find.text('Foto Bukti (wajib bila lebih dari 3 hari)'),
          findsOneWidget);
    });

    testWidgets('Izin: Dinas chip exists; photo title follows picked jenis',
        (t) async {
      await pump(
          t,
          IzinForm(
              rules: rules(
                  sakit: AturanLampiranJenis.tidakPerlu,
                  dinas: const AturanLampiranJenis(LampiranMode.wajib))));
      expect(find.text('Dinas'), findsOneWidget);
      // No jenis chosen yet -> no photo field.
      expect(find.textContaining('Foto Bukti'), findsNothing);

      await t.tap(find.text('Sakit'));
      await t.pump();
      expect(find.textContaining('Foto Bukti'), findsNothing); // tidak_perlu

      await t.tap(find.text('Seminar'));
      await t.pump();
      expect(find.text('Foto Bukti (opsional)'), findsOneWidget);

      await t.tap(find.text('Dinas'));
      await t.pump();
      expect(find.text('Foto Bukti (wajib)'), findsOneWidget);
    });
  });
}

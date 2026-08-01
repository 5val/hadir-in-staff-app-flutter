// Sprint 2 EPIC 9 — mengunci perilaku SalarySlip.fromApi terhadap bentuk data
// asli dari DB.
//
// Payload di bawah menyalin kolom tabel `slip_gaji` (lihat
// hadir-in-api-backend-express-js/prisma/schema.prisma) ditambah statistik
// kehadiran yang di-merge endpoint mobile
// (`GET /api/mobile/staff/:staffId/gaji/slip`, routes/mobile/gaji.ts:307
// mengembalikan `{ ...slip, ...stats }`).
//
// Yang dijaga: Take Home Pay yang tampil di app HARUS sama persis dengan
// `gajiNetto` yang dihitung server (payroll-calc.ts), bukan hasil hitung ulang
// di client.

import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/models/models.dart';

/// Slip realistis: punya tunjangan bentuk barang, fasilitas, uang makan, DAN
/// potongan BPJS staff — persis kombinasi yang dulu bikin angka client meleset.
///
/// Rekonstruksi angka server (payroll-calc.ts):
///   grossForTax     = 5.000.000 + 200.000 + 250.000 + 450.000 + 0 = 5.900.000
///   totalPotongan   = 100.000 + 50.000 + 250.000 + 150.000        =   550.000
///   totalPendapatan = 5.900.000 − 550.000                         = 5.350.000
///   gajiNetto       = 5.350.000 + 500.000 (tunjangan uang saja)   = 5.850.000
Map<String, dynamic> _slipPayload() => {
      'id': 'clslip0001',
      'staffId': 'clstaff0001',
      'periode': '2026-07',
      'gajiPokok': 5000000,
      'bonusTepat': 200000,
      'bonusKehadiran': 250000,
      // Kolom lama yang backend tandai DEPRECATED — selalu 0.
      'tunjanganTransport': 0,
      'tunjanganMakan': 0,
      'tunjanganKesehatan': 0,
      'tunjanganTambahan': 0,
      'tunjanganBreakdown': [
        {
          'nama': 'Transport',
          'jumlah': 500000,
          'periode': 'bulanan',
          'bentuk': 'uang',
        },
        {
          'nama': 'Sepatu Kerja',
          'jumlah': 300000,
          'periode': 'bulanan',
          'bentuk': 'barang',
        },
      ],
      'totalTunjangan': 800000,
      'totalTunjanganUang': 500000,
      'fasilitasBreakdown': [
        {'kategori': 'MakananMinuman', 'periode': 'harian', 'nominal': 50000},
      ],
      'totalFasilitas': 50000,
      'lemburJam': 3,
      'lemburRate': 150000,
      'lemburTotal': 450000,
      'thrAmount': 0,
      'dendaTerlambat': 100000,
      'potonganAlpha': 50000,
      'potonganBPJS': 150000,
      'pajakPPh21': 250000,
      'totalPendapatan': 5350000,
      'totalPotongan': 550000,
      'gajiNetto': 5850000,
      'statusSlip': 'sent',
      'statusBayar': 'paid',
      // ── statistik yang di-merge routes/mobile/gaji.ts ──
      'workingDays': 22,
      'presentDays': 20,
      'lateDays': 2,
      'overtimeHours': 3,
      'leaveDays': 1,
      'permissionDays': 1,
      'holidayDays': 1,
      'uangMakan': 300000,
      'uangMakanDays': 15,
      'leaveHistory': [],
      'permissionHistory': [],
    };

void main() {
  group('SalarySlip.fromApi — Take Home Pay', () {
    test('takeHomePay & netSalary memakai gajiNetto server apa adanya', () {
      final slip = SalarySlip.fromApi(_slipPayload());

      expect(slip.gajiNetto, 5850000);
      expect(slip.takeHomePay, 5850000);
      expect(slip.netSalary, 5850000);
    });

    test('TIDAK memakai hitungan lama yang menjumlah komponen non-tunai', () {
      final slip = SalarySlip.fromApi(_slipPayload());

      // Formula lama: gajiBersih + totalTunjangan(tampilan) − totalPotongan
      //             = 5.650.000 + 1.150.000 − 300.000 = 6.500.000
      // yaitu 650.000 LEBIH BESAR dari yang benar-benar ditransfer.
      final formulaLama =
          slip.gajiBersih + slip.totalTunjangan - slip.totalPotongan;
      expect(formulaLama, 6500000);
      expect(slip.takeHomePay, isNot(formulaLama));
    });

    test('ringkasan layar & PDF menjumlah tepat ke gajiNetto', () {
      final slip = SalarySlip.fromApi(_slipPayload());

      // Identitas yang ditampilkan kartu ringkasan:
      //   Pendapatan Pokok − Total Potongan + Tunjangan Tunai = Take Home Pay
      expect(slip.pendapatanPokok, 5900000); // == grossForTax server
      expect(slip.totalDeduction, 550000); // == totalPotongan server
      expect(slip.totalTunjanganUang, 500000);
      expect(
        slip.pendapatanPokok - slip.totalDeduction + slip.totalTunjanganUang,
        slip.gajiNetto,
      );
    });

    test('gajiNetto default 0 kalau field-nya tidak ada (slip lama)', () {
      final payload = _slipPayload()..remove('gajiNetto');
      expect(SalarySlip.fromApi(payload).takeHomePay, 0);
    });
  });

  group('SalarySlip.fromApi — komponen di luar THP', () {
    test('tunjangan bentuk barang tetap tampil dan ditandai', () {
      final slip = SalarySlip.fromApi(_slipPayload());
      final barang =
          slip.components.firstWhere((c) => c.label == 'Sepatu Kerja');

      expect(barang.amount, 300000);
      expect(barang.excludedFromThp, isTrue);
      expect(barang.noteWithThpNotice, contains('tidak termasuk Take Home Pay'));
    });

    test('tunjangan bentuk uang TIDAK ditandai di luar THP', () {
      final slip = SalarySlip.fromApi(_slipPayload());
      final uang = slip.components.firstWhere((c) => c.label == 'Transport');

      expect(uang.amount, 500000);
      expect(uang.excludedFromThp, isFalse);
      expect(uang.noteWithThpNotice, uang.note);
    });

    test('bentuk default "uang" kalau field bentuk tidak dikirim', () {
      final payload = _slipPayload();
      payload['tunjanganBreakdown'] = [
        {'nama': 'Tunjangan Lama', 'jumlah': 100000, 'periode': 'bulanan'},
      ];
      final slip = SalarySlip.fromApi(payload);

      expect(
        slip.components.firstWhere((c) => c.label == 'Tunjangan Lama')
            .excludedFromThp,
        isFalse,
      );
    });

    test('fasilitas tampil sebagai natura dan tidak masuk THP', () {
      final slip = SalarySlip.fromApi(_slipPayload());
      final fasilitas =
          slip.components.firstWhere((c) => c.label == 'MakananMinuman');

      expect(fasilitas.amount, 50000);
      expect(fasilitas.excludedFromThp, isTrue);
    });

    test('uang makan tampil tapi ditandai belum masuk THP', () {
      final slip = SalarySlip.fromApi(_slipPayload());
      final uangMakan =
          slip.components.firstWhere((c) => c.label == 'Uang Makan');

      expect(uangMakan.amount, 300000);
      expect(uangMakan.note, contains('15 hari'));
      expect(uangMakan.excludedFromThp, isTrue);
    });

    test('tunjanganDiluarThp = barang + fasilitas + uang makan', () {
      final slip = SalarySlip.fromApi(_slipPayload());
      expect(slip.tunjanganDiluarThp, 300000 + 50000 + 300000);
    });
  });

  group('SalarySlip.fromApi — potongan BPJS (EPIC 9c)', () {
    test('baris potongan BPJS muncul saat nilainya nonzero', () {
      final slip = SalarySlip.fromApi(_slipPayload());
      final bpjs = slip.components
          .where((c) => c.label == 'Potongan BPJS')
          .toList();

      expect(bpjs, hasLength(1));
      expect(bpjs.single.amount, 150000);
      expect(bpjs.single.group, SalaryGroup.potongan);
      expect(bpjs.single.isDeduction, isTrue);
    });

    test('office tanpa BPJS split: barisnya tidak dipaksa tampil', () {
      final payload = _slipPayload();
      payload['potonganBPJS'] = 0;
      payload['totalPotongan'] = 400000;
      payload['totalPendapatan'] = 5500000;
      payload['gajiNetto'] = 6000000;

      final slip = SalarySlip.fromApi(payload);

      expect(slip.components.where((c) => c.label == 'Potongan BPJS'), isEmpty);
      expect(slip.takeHomePay, 6000000);
      expect(
        slip.pendapatanPokok - slip.totalDeduction + slip.totalTunjanganUang,
        slip.gajiNetto,
      );
    });
  });

  group('SalarySlip.fromApi — statistik kehadiran', () {
    test('periode & rincian hari dibaca dari respons server', () {
      final slip = SalarySlip.fromApi(_slipPayload());

      expect(slip.period, 'Juli 2026');
      expect(slip.periodStart, DateTime(2026, 7, 1));
      expect(slip.periodEnd, DateTime(2026, 7, 31));
      expect(slip.workDays, 22);
      expect(slip.presentDays, 20);
      expect(slip.lateDays, 2);
      // 22 hari kerja − 20 hadir − 1 cuti − 1 izin = 0 alpha
      expect(slip.absentDays, 0);
    });
  });
}

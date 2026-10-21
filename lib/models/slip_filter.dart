import 'models.dart';

/// Satu pilihan di filter periode halaman Slip Gaji.
class SlipPeriodeOption {
  final String key; // `SalarySlip.periodeKey`
  final String label; // `SalarySlip.periodeLabel`
  const SlipPeriodeOption(this.key, this.label);
}

/// Logika murni filter periode halaman Slip Gaji (dipisah dari layar supaya
/// bisa diuji tanpa widget).
///
/// Aturan: pilihan filter = "Semua periode" (key null, menampilkan SEMUA slip
/// termasuk yang bertipe periode lama bila jabatan staff pernah berpindah
/// tipe) + satu pilihan per slip bertipe periode staff SAAT INI.
class SlipFilter {
  const SlipFilter._();

  /// Slip diurutkan terbaru dulu (berdasarkan awal periode).
  static List<SalarySlip> sorted(List<SalarySlip> slips) {
    final copy = [...slips];
    copy.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return copy;
  }

  /// Momen slip DIKIRIM/dibuat: `dikirimKonfirmasiAt`, lalu `createdAt`.
  static DateTime? _issuedAt(SalarySlip s) =>
      DateTime.tryParse(s.dikirimKonfirmasiAt ?? '') ?? s.createdAt;

  /// Tipe periode staff saat ini:
  /// 1. [profileType] (`Jabatan.periodeGaji` dari profil) bila valid;
  /// 2. slip dengan `dikirimKonfirmasiAt` terbaru, lalu `createdAt`;
  /// 3. (server lama tanpa keduanya) slip dengan awal periode terbaru.
  /// Null bila tidak ada slip & tidak ada profil.
  static String? currentType(List<SalarySlip> slips, {String? profileType}) {
    final p = (profileType ?? '').trim().toLowerCase();
    if (p == 'harian' || p == 'mingguan' || p == 'bulanan') return p;
    if (slips.isEmpty) return null;
    SalarySlip? best;
    for (final s in slips) {
      if (best == null) {
        best = s;
        continue;
      }
      final a = _issuedAt(s);
      final b = _issuedAt(best);
      if (a != null && b != null) {
        if (a.isAfter(b)) best = s;
      } else if (a != null) {
        best = s; // yang punya penanda waktu lebih bisa dipercaya
      } else if (b == null && s.periodStart.isAfter(best.periodStart)) {
        best = s;
      }
    }
    return best!.periodeType;
  }

  /// Pilihan periode (tanpa "Semua periode") untuk tipe periode saat ini.
  static List<SlipPeriodeOption> periodeOptions(List<SalarySlip> slips,
      {String? profileType}) {
    final type = currentType(slips, profileType: profileType);
    if (type == null) return const [];
    final seen = <String>{};
    final out = <SlipPeriodeOption>[];
    for (final s in sorted(slips)) {
      if (s.periodeType != type) continue;
      if (seen.add(s.periodeKey)) {
        out.add(SlipPeriodeOption(s.periodeKey, s.periodeLabel));
      }
    }
    return out;
  }

  /// Terapkan filter. [periodeKey] null = "Semua periode".
  static List<SalarySlip> apply(List<SalarySlip> slips, String? periodeKey) {
    final all = sorted(slips);
    if (periodeKey == null) return all;
    return all.where((s) => s.periodeKey == periodeKey).toList();
  }
}

/// Aturan lampiran (foto bukti) per jenis pengajuan, dari
/// `GET /api/mobile/staff/:staffId/leave/aturan-lampiran` (kontrak sprint3.md,
/// 2026-11-12). ADVISORY untuk UI -- server menegakkan ulang saat POST dan
/// menjawab 400 bila foto wajib tapi tidak ada.
library;

/// Kunci jenis (tetap, sama dengan backend `lib/aturan-lampiran.ts`).
class LampiranJenis {
  static const sakit = 'sakit';
  static const izinSeminar = 'izin_seminar';
  static const izinLainnya = 'izin_lainnya';
  static const dinas = 'dinas';
  static const cutiTahunan = 'cuti_tahunan';

  /// Pilihan jenis di form Izin (label UI) -> kunci aturan.
  static String forIzinType(String? uiType) {
    switch (uiType) {
      case 'Sakit':
        return sakit;
      case 'Seminar':
        return izinSeminar;
      case 'Dinas':
        return dinas;
      default:
        return izinLainnya;
    }
  }
}

enum LampiranMode { tidakPerlu, opsional, wajib }

class AturanLampiranJenis {
  final LampiranMode mode;

  /// Hanya berarti untuk [LampiranMode.wajib]: null = selalu wajib,
  /// N = wajib bila jumlah hari > N.
  final int? lebihDariHari;

  const AturanLampiranJenis(this.mode, [this.lebihDariHari]);

  static const tidakPerlu = AturanLampiranJenis(LampiranMode.tidakPerlu);
  static const opsional = AturanLampiranJenis(LampiranMode.opsional);

  factory AturanLampiranJenis.fromApi(dynamic j, AturanLampiranJenis fallback) {
    if (j is! Map) return fallback;
    final LampiranMode mode;
    switch (j['mode']) {
      case 'tidak_perlu':
        mode = LampiranMode.tidakPerlu;
        break;
      case 'opsional':
        mode = LampiranMode.opsional;
        break;
      case 'wajib':
        mode = LampiranMode.wajib;
        break;
      default:
        return fallback;
    }
    final n = j['lebihDariHari'];
    return AturanLampiranJenis(
      mode,
      mode == LampiranMode.wajib && n is num ? n.toInt() : null,
    );
  }

  /// Foto WAJIB untuk pengajuan sebanyak [jumlahHari] hari kerja?
  bool wajib(int jumlahHari) =>
      mode == LampiranMode.wajib &&
      (lebihDariHari == null || jumlahHari > lebihDariHari!);

  /// Kolom foto ditampilkan sama sekali?
  bool get tampil => mode != LampiranMode.tidakPerlu;

  /// Judul kolom foto: "Foto Bukti (opsional)" / "(wajib)" /
  /// "(wajib bila lebih dari N hari)".
  String get judul {
    switch (mode) {
      case LampiranMode.tidakPerlu:
        return 'Foto Bukti';
      case LampiranMode.opsional:
        return 'Foto Bukti (opsional)';
      case LampiranMode.wajib:
        return lebihDariHari == null
            ? 'Foto Bukti (wajib)'
            : 'Foto Bukti (wajib bila lebih dari $lebihDariHari hari)';
    }
  }
}

class AturanLampiran {
  final Map<String, AturanLampiranJenis> jenis;
  final int maxLampiran;

  const AturanLampiran({required this.jenis, this.maxLampiran = 3});

  /// Bawaan server tanpa baris aturan -- juga dipakai bila fetch gagal:
  /// izin (sakit/seminar/lainnya/dinas) opsional, cuti tahunan tidak perlu.
  /// Server tetap menegakkan aturan sebenarnya (400 saat submit).
  static const AturanLampiran fallback = AturanLampiran(jenis: {
    LampiranJenis.sakit: AturanLampiranJenis.opsional,
    LampiranJenis.izinSeminar: AturanLampiranJenis.opsional,
    LampiranJenis.izinLainnya: AturanLampiranJenis.opsional,
    LampiranJenis.dinas: AturanLampiranJenis.opsional,
    LampiranJenis.cutiTahunan: AturanLampiranJenis.tidakPerlu,
  });

  factory AturanLampiran.fromApi(Map<String, dynamic> j) {
    final raw = j['jenis'];
    final map = raw is Map ? raw : const {};
    return AturanLampiran(
      jenis: {
        for (final e in fallback.jenis.entries)
          e.key: AturanLampiranJenis.fromApi(map[e.key], e.value),
      },
      maxLampiran: (j['maxLampiran'] as num?)?.toInt() ?? 3,
    );
  }

  AturanLampiranJenis untuk(String kunci) =>
      jenis[kunci] ?? fallback.jenis[kunci] ?? AturanLampiranJenis.opsional;
}

// ── Logika murni form pengajuan ─────────────────────────────────

/// Petakan pilihan jenis di form Izin -> (tipe, subTipe) untuk POST.
/// Dinas bertipe "Dinas" (bukan Izin) dengan subTipe kosong.
({String tipe, String subTipe}) izinTypeToApi(String uiType) {
  switch (uiType) {
    case 'Sakit':
      return (tipe: 'Sakit', subTipe: '');
    case 'Dinas':
      return (tipe: 'Dinas', subTipe: '');
    default:
      return (tipe: 'Izin', subTipe: uiType);
  }
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Geser [d] sebanyak [months] bulan; tanggal yang tidak ada di bulan tujuan
/// dijepit ke hari terakhirnya (31 Jan + 1 bulan = 28/29 Feb).
DateTime addMonthsClamped(DateTime d, int months) {
  final lastDay = DateTime(d.year, d.month + months + 1, 0).day;
  return DateTime(d.year, d.month + months, d.day < lastDay ? d.day : lastDay);
}

/// Dinas: hari ini - 1 bulan s/d hari ini + 1 bulan, inklusif (sama dengan
/// backend).
({DateTime first, DateTime last}) dinasRange(DateTime now) {
  final today = _d(now);
  return (first: addMonthsClamped(today, -1), last: addMonthsClamped(today, 1));
}

/// Tombol kirim form Izin/Dinas/Cuti boleh aktif dari sisi foto?
/// [fotoCount] foto terpilih, [jumlahHari] hari kerja pada rentang.
bool lampiranTerpenuhi(
        AturanLampiranJenis rule, int jumlahHari, int fotoCount) =>
    !rule.wajib(jumlahHari) || fotoCount >= 1;

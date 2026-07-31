import '../models/models.dart';

/// ============================================================================
/// MODE TESTING ABSENSI — SATU-SATUNYA FILE YANG PERLU DIUBAH
/// ============================================================================
///
/// Tujuan: bisa menguji siklus absensi (check-in → istirahat → check-out) dari
/// mana pun dan jam berapa pun, TANPA menghapus logika GPS & jam yang asli.
/// Semua kode nyata tetap ada di tempatnya — file ini hanya "membelokkan"
/// dua sumber data yang bikin susah dites di meja: posisi GPS dan jam.
///
/// ── CARA PAKAI ─────────────────────────────────────────────────────────────
///
///   SEDANG TESTING (data hardcode):
///     [enabled] = true
///
///   DATA REAL / PRODUKSI:
///     [enabled] = false      ← CUKUP SATU BARIS INI SAJA
///
/// Saat [enabled] = false, seluruh app otomatis kembali memakai GPS asli HP
/// dan jam asli perangkat; tidak ada baris lain yang perlu di-comment.
/// [fakeLocation] & [fakeTime] hanya untuk mengaktifkan sebagian saja
/// (mis. lokasi dipalsukan tapi jam tetap asli).
///
/// ── APA YANG DIPALSUKAN ────────────────────────────────────────────────────
///
/// 1. LOKASI ([fakeLocation])
///    `LocationService.current()` tidak membaca GPS HP, melainkan mengembalikan
///    koordinat kantor staff sendiri (`AppSession.staff.lokasiLatitude/
///    lokasiLongitude`) sehingga jarak ke kantor = 0 m → SELALU di dalam
///    radius, baik menurut app maupun menurut geofence server (lib/geo.ts).
///    Kalau staff belum punya lokasi kerja, dipakai [fallbackLatitude] /
///    [fallbackLongitude].
///
/// 2. JAM ([fakeTime])
///    Jam check-in & check-out yang DIKIRIM ke backend di-hardcode
///    ([checkInTime] / [checkOutTime]) lewat field `time` yang memang sudah
///    didukung endpoint `POST .../attendance/check-in` & `check-out`.
///    Selain itu [now] dipakai layar absensi sebagai "jam sekarang" supaya
///    peringatan "belum jam pulang" tidak menghalangi pengujian check-out.
///
/// CATATAN PENTING: geofence & perhitungan keterlambatan/lembur tetap dihitung
/// SERVER. Yang berubah hanya ANGKA YANG DIKIRIM app, bukan aturannya — jadi
/// hasil pengujian tetap melewati jalur kode yang sama dengan produksi.
class TestingConfig {
  const TestingConfig._();

  // ══════════════════════════════════════════════════════════════════════════
  // SAKELAR UTAMA — ubah HANYA baris ini untuk pindah mode.
  //   true  = MODE TESTING (lokasi & jam hardcode)
  //   false = DATA REAL (GPS asli + jam asli HP)
  // ══════════════════════════════════════════════════════════════════════════
  static const bool enabled = true;

  /// Sakelar per-bagian (hanya berlaku bila [enabled] = true).
  static const bool fakeLocation = true;
  static const bool fakeTime = true;

  // ── Hardcode LOKASI ───────────────────────────────────────────────────────

  /// true  = pakai koordinat kantor staff yang sedang login (paling aman,
  ///         otomatis lolos geofence kantor mana pun).
  /// false = selalu pakai [fallbackLatitude] / [fallbackLongitude] di bawah.
  static const bool useOfficeCoordinates = true;

  /// Dipakai bila [useOfficeCoordinates] = false, atau bila staff belum
  /// ditempatkan pada Lokasi mana pun. Default: Monas / Kantor Pusat Jakarta.
  static const double fallbackLatitude = -6.2088;
  static const double fallbackLongitude = 106.8456;

  /// Akurasi GPS palsu (meter). Kecil = seolah sinyal bagus.
  static const double fakeAccuracyMeters = 5;

  /// Label alamat yang ditampilkan layar kamera saat mode testing.
  static const String fakeAddressLabel = 'Titik kantor (koordinat testing)';

  // ── Hardcode JAM ──────────────────────────────────────────────────────────

  /// Jam yang dikirim ke backend saat check-in, format "HH:mm".
  /// Backend memakainya untuk menghitung keterlambatan terhadap
  /// `Shift.jamMasuk` + toleransi. Contoh: '08:00' → hadir tepat waktu,
  /// '09:30' → terlambat (buat menguji status "terlambat" & denda).
  static const String checkInTime = '08:00';

  /// Jam yang dikirim ke backend saat check-out, format "HH:mm".
  /// Contoh: '17:00' → pulang normal, '19:00' → lembur 2 jam.
  static const String checkOutTime = '17:00';

  /// "Jam sekarang" versi testing (format "HH:mm") — dipakai UI untuk
  /// menentukan apakah sudah lewat jam pulang, bukan untuk dikirim ke server.
  static const String clockTime = '17:30';

  // ── Turunan (jangan diubah) ───────────────────────────────────────────────

  static bool get locationOverrideActive => enabled && fakeLocation;
  static bool get timeOverrideActive => enabled && fakeTime;

  /// Jam check-in untuk dikirim ke backend; null = biarkan server memakai
  /// jam server (perilaku produksi).
  static String? get checkInTimeOverride =>
      timeOverrideActive ? checkInTime : null;

  /// Jam check-out untuk dikirim ke backend; null = jam server.
  static String? get checkOutTimeOverride =>
      timeOverrideActive ? checkOutTime : null;

  /// Koordinat yang dipakai sebagai "posisi HP" saat mode testing.
  static double get latitude {
    if (useOfficeCoordinates) {
      final lat = AppSession.staff?.lokasiLatitude;
      if (lat != null) return lat;
    }
    return fallbackLatitude;
  }

  static double get longitude {
    if (useOfficeCoordinates) {
      final lng = AppSession.staff?.lokasiLongitude;
      if (lng != null) return lng;
    }
    return fallbackLongitude;
  }

  /// Jam sekarang: hasil hardcode saat mode testing, jam asli saat tidak.
  static DateTime now() {
    if (!timeOverrideActive) return DateTime.now();
    final real = DateTime.now();
    final parts = clockTime.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (h == null || m == null) return real;
    return DateTime(real.year, real.month, real.day, h, m);
  }

  /// Teks banner yang ditampilkan di layar agar data testing tidak pernah
  /// tertukar dengan data sungguhan.
  static String get bannerLabel {
    final bagian = <String>[
      if (locationOverrideActive) 'lokasi',
      if (timeOverrideActive) 'jam',
    ];
    if (bagian.isEmpty) return 'MODE TESTING';
    return 'MODE TESTING · ${bagian.join(' & ')} di-hardcode';
  }
}

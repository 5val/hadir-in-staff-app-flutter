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
/// [enabled] BUKAN literal di source lagi — dibaca dari compile-time flag
/// `--dart-define=TESTING_MODE=true`, defaultnya SELALU `false`. Ini sengaja:
/// literal `true` yang ke-commit di source pernah bikin app kirim GPS & jam
/// palsu ke backend PRODUKSI tanpa disadari (Sprint 3 EPIC 1). Dengan
/// `bool.fromEnvironment`, `true` cuma bisa datang dari flag CLI eksplisit
/// saat build/run, gak pernah bisa "nyangkut" ke-commit sebagai `true`.
///
///   SEDANG TESTING (data hardcode):
///     flutter run --dart-define=TESTING_MODE=true
///
///   MEMILIH SKENARIO (lihat [TestingScenario] untuk daftar & artinya):
///     flutter run --dart-define=TESTING_MODE=true --dart-define=TESTING_SCENARIO=lembur
///
///   Tanpa TESTING_SCENARIO, skenario yang dipakai adalah `normal`
///   (08:00 → 17:00), sama persis dengan perilaku sebelum skenario ada.
///
///   DATA REAL / PRODUKSI (default, tanpa flag apa pun):
///     flutter run
///     flutter build apk
///
/// Saat [enabled] = false (default), seluruh app otomatis kembali memakai
/// GPS asli HP dan jam asli perangkat; tidak ada baris kode yang perlu
/// di-comment. [fakeLocation] & [fakeTime] hanya untuk mengaktifkan
/// sebagian saja (mis. lokasi dipalsukan tapi jam tetap asli) — literal ini
/// aman diubah karena cuma berlaku ketika [enabled] sudah diaktifkan lewat
/// flag di atas.
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
///    Angkanya ditentukan [scenario] — termasuk skenario LEMBUR, yang
///    memilih jam pulang jauh sesudah `Shift.jamPulang` supaya backend
///    benar-benar mencatat menit lembur dan harinya bisa diajukan sebagai
///    lembur.
///    Selain itu [now] dipakai layar absensi sebagai "jam sekarang" supaya
///    peringatan "belum jam pulang" tidak menghalangi pengujian check-out.
///
/// CATATAN PENTING: geofence & perhitungan keterlambatan/lembur tetap dihitung
/// SERVER. Yang berubah hanya ANGKA YANG DIKIRIM app, bukan aturannya — jadi
/// hasil pengujian tetap melewati jalur kode yang sama dengan produksi.
/// Skenario absensi yang sedang diuji.
///
/// Menggantikan cara lama "ubah literal jam di file ini lalu ingat sendiri
/// angka itu artinya apa". Tiap skenario adalah satu pasang jam check-in /
/// check-out yang sudah dipilih supaya menghasilkan KONDISI tertentu di
/// backend, dan namanya dipilih di CLI:
///
///   flutter run --dart-define=TESTING_MODE=true --dart-define=TESTING_SCENARIO=lembur
///
/// Angka lembur di bawah mengasumsikan `Shift.jamPulang` staff = 17:00.
/// Backend menghitungnya relatif terhadap jam pulang shift staff yang
/// bersangkutan (`lembur = checkOut - jamPulang`), jadi kalau shift-nya
/// berbeda, selisihnya ikut bergeser.
enum TestingScenario {
  /// 08:00 → 17:00. Hadir tepat waktu, pulang tepat waktu, lembur 0.
  normal,

  /// 09:30 → 17:00. Menguji status "terlambat" + denda keterlambatan.
  terlambat,

  /// 08:00 → 20:00. Lembur 3 jam penuh — inilah skenario untuk menguji
  /// DATA LEMBUR: baris absensi menyimpan `lembur = 180` menit, dan harinya
  /// menjadi layak diajukan sebagai lembur.
  lembur,

  /// 08:00 → 18:00. Sengaja PAS 60 menit lewat jam pulang.
  ///
  /// Sejak 2026-09-05 ada DUA gerbang berbeda di backend, dan skenario ini
  /// jatuh tepat di antara keduanya — itulah gunanya:
  ///   • PENGAJUAN (`isLemburRequestable`): cukup `Attendance.lembur > 0`,
  ///     jadi 60 menit ini LAYAK diajukan dan harinya muncul di menu Lembur;
  ///   • PENGGAJIAN (`isLemburEligible` + bulat ke bawah per jam): masih
  ///     `> 60` menit, jadi 60 menit ini dibayar 0 jam.
  ///
  /// Sebelumnya kedua gerbang itu satu dan sama, dan skenario ini dipakai
  /// untuk mengunci `>` vs `>=`. Sekarang ia mengunci hal yang lebih
  /// penting: bahwa melonggarkan sisi pengajuan TIDAK ikut menggeser sisi
  /// uang.
  lemburTepatBatas,

  /// 09:30 → 20:00. Terlambat DAN lembur sekaligus, untuk memastikan
  /// keduanya dihitung berdampingan tanpa saling menimpa.
  terlambatLembur,
}

class TestingConfig {
  const TestingConfig._();

  // ══════════════════════════════════════════════════════════════════════════
  // SAKELAR UTAMA — JANGAN ubah literal di sini. Aktifkan lewat CLI:
  //   flutter run --dart-define=TESTING_MODE=true
  // Default (tanpa flag) SELALU false — ini yang menjamin build release tidak
  // pernah membawa mode testing walau lupa dimatikan di source.
  // ══════════════════════════════════════════════════════════════════════════
  static const bool enabled = bool.fromEnvironment(
    'TESTING_MODE',
    defaultValue: false,
  );

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

  // ── Hardcode JAM (lewat SKENARIO) ─────────────────────────────────────────

  /// Skenario aktif, dipilih lewat `--dart-define=TESTING_SCENARIO=<nama>`.
  /// Nilai yang dikenali: normal | terlambat | lembur | lemburTepatBatas |
  /// terlambatLembur. Nama yang tidak dikenali jatuh ke [TestingScenario.normal]
  /// — sengaja diam-diam, bukan melempar: salah ketik saat menjalankan app
  /// tidak sepantasnya membuat app gagal start.
  ///
  /// Hanya berlaku ketika [enabled] true; tanpa `TESTING_MODE=true` seluruh
  /// blok ini tidak pernah dibaca siapa pun.
  static const String _scenarioName =
      String.fromEnvironment('TESTING_SCENARIO', defaultValue: 'lembur');

  static TestingScenario get scenario {
    switch (_scenarioName.toLowerCase()) {
      case 'terlambat':
        return TestingScenario.terlambat;
      case 'lembur':
        return TestingScenario.lembur;
      case 'lemburtepatbatas':
      case 'lembur_tepat_batas':
        return TestingScenario.lemburTepatBatas;
      case 'terlambatlembur':
      case 'terlambat_lembur':
        return TestingScenario.terlambatLembur;
      default:
        return TestingScenario.normal;
    }
  }

  /// Jam yang dikirim ke backend saat check-in, format "HH:mm".
  /// Backend memakainya untuk menghitung keterlambatan terhadap
  /// `Shift.jamMasuk` + toleransi.
  static String get checkInTime {
    switch (scenario) {
      case TestingScenario.terlambat:
      case TestingScenario.terlambatLembur:
        return '09:30';
      case TestingScenario.normal:
      case TestingScenario.lembur:
      case TestingScenario.lemburTepatBatas:
        return '08:00';
    }
  }

  /// Jam yang dikirim ke backend saat check-out, format "HH:mm".
  /// Backend memakainya untuk menghitung lembur terhadap `Shift.jamPulang`.
  static String get checkOutTime {
    switch (scenario) {
      case TestingScenario.lembur:
      case TestingScenario.terlambatLembur:
        return '20:00';
      case TestingScenario.lemburTepatBatas:
        return '18:00';
      case TestingScenario.normal:
      case TestingScenario.terlambat:
        return '17:00';
    }
  }

  /// "Jam sekarang" versi testing (format "HH:mm") — dipakai UI untuk
  /// menentukan apakah sudah lewat jam pulang, bukan untuk dikirim ke server.
  ///
  /// Selalu SESUDAH [checkOutTime]: kalau jam layar masih sebelum jam pulang,
  /// UI menahan tombol check-out dan skenario lembur tidak akan pernah bisa
  /// dijalankan sampai selesai.
  static String get clockTime {
    switch (scenario) {
      case TestingScenario.lembur:
      case TestingScenario.terlambatLembur:
        return '20:30';
      case TestingScenario.lemburTepatBatas:
        return '18:30';
      case TestingScenario.normal:
      case TestingScenario.terlambat:
        return '17:30';
    }
  }

  /// Nama skenario untuk ditampilkan di banner mode testing.
  static String get scenarioLabel {
    switch (scenario) {
      case TestingScenario.normal:
        return 'Normal';
      case TestingScenario.terlambat:
        return 'Terlambat';
      case TestingScenario.lembur:
        return 'Lembur';
      case TestingScenario.lemburTepatBatas:
        return 'Lembur tepat batas';
      case TestingScenario.terlambatLembur:
        return 'Terlambat + Lembur';
    }
  }

  /// Hasil yang SEHARUSNYA muncul di data setelah skenario dijalankan penuh.
  /// Ditampilkan di banner supaya penguji tidak perlu menghitung sendiri —
  /// dan langsung sadar kalau data yang tersimpan ternyata berbeda.
  ///
  /// Angkanya mengasumsikan `Shift.jamPulang` = 17:00 (lihat [TestingScenario]).
  static String get scenarioExpectation {
    switch (scenario) {
      case TestingScenario.normal:
        return 'Harapan: status hadir, lembur 0 menit.';
      case TestingScenario.terlambat:
        return 'Harapan: status terlambat 90 menit, lembur 0 menit.';
      case TestingScenario.lembur:
        return 'Harapan: lembur 180 menit (3 jam), hari ini layak diajukan lembur.';
      case TestingScenario.lemburTepatBatas:
        return 'Harapan: lembur 60 menit, BISA diajukan (menu Lembur), '
            'tapi dibayar 0 jam (payroll masih > 60 menit).';
      case TestingScenario.terlambatLembur:
        return 'Harapan: terlambat 90 menit DAN lembur 180 menit sekaligus.';
    }
  }

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
    if (bagian.isEmpty) return 'MODE TESTING · skenario $scenarioLabel';
    return 'MODE TESTING · $scenarioLabel · '
        '${bagian.join(' & ')} di-hardcode';
  }
}

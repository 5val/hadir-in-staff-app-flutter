// Sprint 3 EPIC 1 — regression: TestingConfig.enabled harus SELALU `false`
// saat app dibangun/dijalankan TANPA `--dart-define=TESTING_MODE=true`.
//
// Latar belakang: sebelumnya `enabled` adalah literal `static const bool
// enabled = true;` yang ke-commit langsung di source. Efeknya app mengirim
// GPS & jam absensi PALSU ke backend produksi tanpa disadari siapa pun yang
// build dari branch itu (lihat docs/TESTING-ABSENSI.md & CLAUDE.md).
//
// Fix: `enabled` sekarang dibaca dari compile-time flag
// `bool.fromEnvironment('TESTING_MODE', defaultValue: false)`. Test ini jalan
// di pipeline default (`flutter test`, tanpa --dart-define apa pun) sehingga
// secara langsung membuktikan default-nya `false` — persis kondisi build
// release yang tidak pernah diberi flag itu.
//
// Untuk memverifikasi jalur "true" secara manual (bukan lewat test ini,
// karena --dart-define tidak diteruskan otomatis ke `flutter test`):
//   flutter run --dart-define=TESTING_MODE=true
// lalu cek banner kuning "MODE TESTING" muncul di halaman Home.

import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/config/testing_config.dart';

void main() {
  test(
    'TestingConfig.enabled default ke false tanpa --dart-define=TESTING_MODE=true',
    () {
      expect(TestingConfig.enabled, isFalse);
    },
  );

  test(
    'override lokasi & jam ikut nonaktif ketika enabled=false (default)',
    () {
      expect(TestingConfig.locationOverrideActive, isFalse);
      expect(TestingConfig.timeOverrideActive, isFalse);
      expect(TestingConfig.checkInTimeOverride, isNull);
      expect(TestingConfig.checkOutTimeOverride, isNull);
    },
  );
}

import 'package:geolocator/geolocator.dart';

import '../config/testing_config.dart';

/// Hasil pembacaan GPS beserta alasannya bila gagal — dipakai layar absensi
/// untuk menampilkan pesan yang benar (GPS mati vs izin ditolak vs
/// izin ditolak permanen), bukan satu pesan generik.
class GpsResult {
  final Position? position;
  final GpsFailure? failure;

  const GpsResult.success(Position this.position) : failure = null;
  const GpsResult.failed(GpsFailure this.failure) : position = null;

  bool get ok => position != null;
}

enum GpsFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,

  /// Android mendeteksi lokasi palsu (`Position.isMocked`), mis. aplikasi
  /// fake GPS. Diblokir di app untuk SEMUA pintu absensi; server tidak ikut
  /// menimbang flag ini (hanya geofence), jadi ini pagar sisi-app saja.
  mockLocation,
}

extension GpsFailureMessage on GpsFailure {
  String get message {
    switch (this) {
      case GpsFailure.serviceDisabled:
        return 'Layanan lokasi (GPS) di HP Anda mati. Aktifkan GPS lalu coba lagi.';
      case GpsFailure.permissionDenied:
        return 'Izin lokasi belum diberikan. Aplikasi butuh lokasi untuk memastikan Anda absen di kantor.';
      case GpsFailure.permissionDeniedForever:
        return 'Izin lokasi diblokir permanen. Buka Pengaturan HP → Aplikasi → Hadir-In → Izin, lalu aktifkan Lokasi.';
      case GpsFailure.timeout:
        return 'Gagal mendapatkan sinyal GPS. Coba pindah ke area yang lebih terbuka.';
      case GpsFailure.unknown:
        return 'Gagal membaca lokasi GPS. Coba lagi.';
      case GpsFailure.mockLocation:
        return 'Lokasi palsu (fake GPS) terdeteksi. Matikan aplikasi lokasi palsu lalu coba lagi.';
    }
  }
}

/// Pembacaan lokasi GPS perangkat.
///
/// Fase 8 — menggantikan `_locationInRange = Random().nextBool()` di
/// `home_tab.dart`, yang secara harfiah mengundi apakah staff dianggap
/// berada di kantor. Sekarang koordinat asli dibaca di sini lalu dikirim ke
/// backend; KEPUTUSAN "di dalam radius atau tidak" dibuat SERVER
/// (`lib/geo.ts`), bukan di app — pengecekan di app saja bisa dilewati
/// siapa pun yang memanggil API-nya langsung.
class LocationService {
  const LocationService._();

  /// Batas tunggu fix GPS bila kebijakan MEWAJIBKAN GPS (perilaku lama).
  static const Duration requiredTimeLimit = Duration(seconds: 20);

  /// Batas tunggu fix GPS bila GPS TIDAK wajib (koordinat opsional, dikirim
  /// bila sempat terbaca) -- keputusan user 2026-11-12: tetap baca, maks ~5 dtk.
  static const Duration bestEffortTimeLimit = Duration(seconds: 5);

  /// Batas tunggu sesuai kebijakan `wajibGps`.
  static Duration timeLimitFor({required bool wajibGps}) =>
      wajibGps ? requiredTimeLimit : bestEffortTimeLimit;

  /// Membaca posisi sekarang, sekaligus mengurus service + izin.
  ///
  /// TESTING — bila `TestingConfig.locationOverrideActive` bernilai true,
  /// method ini TIDAK menyentuh GPS sama sekali dan langsung mengembalikan
  /// koordinat hardcode (lihat lib/config/testing_config.dart). Ini satu-
  /// satunya pintu masuk lokasi di seluruh app, jadi cukup dibelokkan di sini:
  /// home_tab, layar kamera, dan FAB di main_screen semuanya ikut.
  /// Matikan dengan `TestingConfig.enabled = false` — kode GPS asli di bawah
  /// tidak diubah sedikit pun dan langsung aktif kembali.
  ///
  /// [blockMocked] (kebijakan `deteksiMockGps`): true = tolak `isMocked`
  /// (perilaku F4, default); false = izinkan -- pemanggil wajib mengirim
  /// `lokasiPalsu: position.isMocked` ke server.
  ///
  /// [timeLimit]: batas tunggu fix GPS. Default 20 dtk (GPS wajib); alur absen
  /// memakai [bestEffortTimeLimit] bila kebijakan tidak mewajibkan GPS, supaya
  /// staff tidak menunggu lama hanya demi koordinat opsional.
  static Future<GpsResult> current({
    bool blockMocked = true,
    Duration timeLimit = requiredTimeLimit,
  }) async {
    if (TestingConfig.locationOverrideActive) {
      return GpsResult.success(fakePosition());
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const GpsResult.failed(GpsFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const GpsResult.failed(GpsFailure.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const GpsResult.failed(GpsFailure.permissionDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return blockMocked ? guardMocked(position) : GpsResult.success(position);
    } on LocationServiceDisabledException {
      return const GpsResult.failed(GpsFailure.serviceDisabled);
    } on PermissionDeniedException {
      return const GpsResult.failed(GpsFailure.permissionDenied);
    } catch (_) {
      return const GpsResult.failed(GpsFailure.timeout);
    }
  }

  /// Satu-satunya tempat keputusan "lokasi palsu = ditolak" (F4). Dipakai
  /// `current()` sehingga FAB, kartu Home, dan layar kamera semuanya ikut
  /// memblokir. Mode testing tidak melewati sini (posisinya `fakePosition()`,
  /// `isMocked: false`), jadi bypass TestingConfig tetap satu-satunya.
  static GpsResult guardMocked(Position position) => position.isMocked
      ? const GpsResult.failed(GpsFailure.mockLocation)
      : GpsResult.success(position);

  /// Posisi palsu untuk MODE TESTING (lihat [TestingConfig]).
  ///
  /// Dibuat dari koordinat kantor staff sendiri, jadi jarak ke titik kantor
  /// = 0 m dan geofence server ikut lolos tanpa perlu mengubah backend.
  /// `isMocked: false` disengaja — kalau true, kartu peringatan "fake location
  /// terdeteksi" di home_tab akan muncul dan justru memblokir pengujian.
  static Position fakePosition() => Position(
        latitude: TestingConfig.latitude,
        longitude: TestingConfig.longitude,
        timestamp: DateTime.now(),
        accuracy: TestingConfig.fakeAccuracyMeters,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  /// Jarak (meter) antara dua koordinat — dipakai HANYA untuk menampilkan
  /// perkiraan jarak di layar. Angka yang menentukan tetap milik server.
  static double distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
}

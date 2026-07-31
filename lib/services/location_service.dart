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

  /// Membaca posisi sekarang, sekaligus mengurus service + izin.
  ///
  /// TESTING — bila `TestingConfig.locationOverrideActive` bernilai true,
  /// method ini TIDAK menyentuh GPS sama sekali dan langsung mengembalikan
  /// koordinat hardcode (lihat lib/config/testing_config.dart). Ini satu-
  /// satunya pintu masuk lokasi di seluruh app, jadi cukup dibelokkan di sini:
  /// home_tab, layar kamera, dan FAB di main_screen semuanya ikut.
  /// Matikan dengan `TestingConfig.enabled = false` — kode GPS asli di bawah
  /// tidak diubah sedikit pun dan langsung aktif kembali.
  static Future<GpsResult> current() async {
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GpsResult.success(position);
    } on LocationServiceDisabledException {
      return const GpsResult.failed(GpsFailure.serviceDisabled);
    } on PermissionDeniedException {
      return const GpsResult.failed(GpsFailure.permissionDenied);
    } catch (_) {
      return const GpsResult.failed(GpsFailure.timeout);
    }
  }

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

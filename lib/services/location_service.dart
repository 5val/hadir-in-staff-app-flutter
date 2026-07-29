import 'package:geolocator/geolocator.dart';

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
  static Future<GpsResult> current() async {
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

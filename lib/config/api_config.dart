/// Konfigurasi koneksi ke backend Express.js (Hadir-In API).
///
/// PENTING (HP fisik): `host` harus berupa IP LAN komputer yang menjalankan
/// backend, dan HP wajib berada di jaringan WiFi yang sama.
/// Ganti nilai [host] bila IP komputer berubah (cek via `ipconfig`).
///
/// - Emulator Android : gunakan '10.0.2.2'
/// - iOS Simulator    : gunakan 'localhost'
/// - HP fisik         : gunakan IP LAN, mis. '192.168.1.18'
class ApiConfig {
  const ApiConfig._();

  /// IP komputer/dev-server di jaringan lokal.
  static const String host = '192.168.1.13';

  /// Port backend Express (lihat PORT di .env backend, default 4000).
  static const int port = 4000;

  /// Base URL seluruh endpoint. Semua route backend berada di bawah `/api`.
  static const String baseUrl = 'http://$host:$port/api';

  /// Batas waktu tiap request sebelum dianggap timeout.
  static const Duration timeout = Duration(seconds: 20);
}

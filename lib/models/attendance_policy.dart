/// Kebijakan Absensi efektif untuk satu staff, dari
/// `GET /api/mobile/staff/:staffId/attendance/policy` (kontrak sprint3.md,
/// 2026-11-12). Dihitung server (override staff -> default lokasi -> bawaan).
///
/// Ini ADVISORY untuk UI: check-in/out tetap dihitung ulang di server, jadi
/// bypass di sini tidak memberi apa pun ke staff.
class AttendancePolicy {
  /// "staff" | "lokasi" | "default"
  final String sumber;
  final String? kebijakanId;
  final String? nama;
  final bool wajibFoto;
  final bool wajibGps;
  final bool cekRadius;
  final bool deteksiMockGps;
  final bool wajibLiveness;

  const AttendancePolicy({
    this.sumber = 'default',
    this.kebijakanId,
    this.nama,
    required this.wajibFoto,
    required this.wajibGps,
    required this.cekRadius,
    required this.deteksiMockGps,
    required this.wajibLiveness,
  });

  /// Dipakai bila server tidak terjangkau DAN tidak ada cache: sama dengan
  /// kebijakan bawaan server (foto + GPS + radius + deteksi mock wajib,
  /// liveness tidak). Sengaja ketat -- server tetap yang memutuskan.
  static const AttendancePolicy strictDefault = AttendancePolicy(
    wajibFoto: true,
    wajibGps: true,
    cekRadius: true,
    deteksiMockGps: true,
    wajibLiveness: false,
  );

  /// Field boolean yang hilang/non-boolean jatuh ke nilai bawaan ketat.
  /// Normalisasi yang sama dengan server: wajibGps=false => cekRadius=false;
  /// wajibFoto=false => wajibLiveness=false.
  factory AttendancePolicy.fromApi(Map<String, dynamic> j) {
    bool b(String key, bool fallback) {
      final v = j[key];
      return v is bool ? v : fallback;
    }

    final wajibFoto = b('wajibFoto', true);
    final wajibGps = b('wajibGps', true);
    return AttendancePolicy(
      sumber: (j['sumber'] ?? 'default').toString(),
      kebijakanId: j['kebijakanId']?.toString(),
      nama: j['nama']?.toString(),
      wajibFoto: wajibFoto,
      wajibGps: wajibGps,
      cekRadius: wajibGps && b('cekRadius', true),
      deteksiMockGps: b('deteksiMockGps', true),
      wajibLiveness: wajibFoto && b('wajibLiveness', false),
    );
  }

  /// Liveness benar-benar dijalankan hanya bila ada foto yang diverifikasi.
  bool get livenessActive => wajibLiveness && wajibFoto;

  /// Radius benar-benar ditegakkan (server menolak di luar radius).
  bool get radiusEnforced => wajibGps && cekRadius;

  /// Lokasi palsu diblokir di sisi app hanya bila GPS dipakai sama sekali
  /// (server juga tidak menolak mock bila GPS tidak wajib).
  bool get blocksMockedGps => deteksiMockGps && wajibGps;

  @override
  bool operator ==(Object other) =>
      other is AttendancePolicy &&
      other.sumber == sumber &&
      other.kebijakanId == kebijakanId &&
      other.nama == nama &&
      other.wajibFoto == wajibFoto &&
      other.wajibGps == wajibGps &&
      other.cekRadius == cekRadius &&
      other.deteksiMockGps == deteksiMockGps &&
      other.wajibLiveness == wajibLiveness;

  @override
  int get hashCode => Object.hash(sumber, kebijakanId, nama, wajibFoto,
      wajibGps, cekRadius, deteksiMockGps, wajibLiveness);
}

/// Cache memori kebijakan terakhir yang BERHASIL diambil, per staffId.
/// Urutan resolusi: server -> cache -> [AttendancePolicy.strictDefault].
class AttendancePolicyCache {
  AttendancePolicyCache._();

  static final Map<String, AttendancePolicy> _byStaff = {};

  static AttendancePolicy? peek(String staffId) => _byStaff[staffId];

  static void put(String staffId, AttendancePolicy p) => _byStaff[staffId] = p;

  /// Dipanggil saat logout/ganti akun.
  static void clear() => _byStaff.clear();

  /// Ambil via [fetch]; gagal (exception apa pun) -> cache -> strict default.
  static Future<AttendancePolicy> resolve(
    String staffId,
    Future<AttendancePolicy> Function() fetch,
  ) async {
    try {
      final p = await fetch();
      _byStaff[staffId] = p;
      return p;
    } catch (_) {
      return _byStaff[staffId] ?? AttendancePolicy.strictDefault;
    }
  }

  /// Server menolak karena liveness diwajibkan padahal app mengira tidak
  /// (kebijakan berubah di tengah jalan atau cache basi).
  static bool isLivenessRequiredError(String message) =>
      message.toLowerCase().contains('perbarui aplikasi');
}

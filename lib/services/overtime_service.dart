import 'api_client.dart';
import 'session_service.dart';

/// Satu hari yang memenuhi syarat untuk diajukan lembur.
///
/// Semua nilai di sini datang dari backend (`GET .../lembur/eligible-days`),
/// termasuk keputusan boleh/tidaknya diajukan — app tidak menghitung ulang
/// aturan H-3 / hari libur / tutup gaji sendiri, supaya tidak ada dua versi
/// aturan yang bisa berbeda.
class OvertimeEligibleDay {
  final DateTime tanggal;
  final String? checkIn;
  final String? checkOut;
  final String jamPulangShift;
  final int menitLewatJamPulang;
  final int estimasiJamLembur;
  final bool sudahDiajukan;
  final String? statusPengajuan;
  final bool bisaDiajukan;
  final String? alasanTidakBisa;

  OvertimeEligibleDay({
    required this.tanggal,
    required this.checkIn,
    required this.checkOut,
    required this.jamPulangShift,
    required this.menitLewatJamPulang,
    required this.estimasiJamLembur,
    required this.sudahDiajukan,
    required this.statusPengajuan,
    required this.bisaDiajukan,
    required this.alasanTidakBisa,
  });

  factory OvertimeEligibleDay.fromApi(Map<String, dynamic> j) {
    return OvertimeEligibleDay(
      tanggal: DateTime.tryParse((j['tanggal'] ?? '').toString()) ?? DateTime.now(),
      checkIn: j['checkIn']?.toString(),
      checkOut: j['checkOut']?.toString(),
      jamPulangShift: (j['jamPulangShift'] ?? '').toString(),
      menitLewatJamPulang: (j['menitLewatJamPulang'] as num?)?.toInt() ?? 0,
      estimasiJamLembur: (j['estimasiJamLembur'] as num?)?.toInt() ?? 0,
      sudahDiajukan: j['sudahDiajukan'] == true,
      statusPengajuan: j['statusPengajuan']?.toString(),
      bisaDiajukan: j['bisaDiajukan'] == true,
      alasanTidakBisa: j['alasanTidakBisa']?.toString(),
    );
  }
}

/// Satu baris riwayat pengajuan lembur.
class OvertimeRequestRecord {
  final String id;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String alasan;

  /// pending | approved | rejected
  final String status;
  final double durasiJam;

  OvertimeRequestRecord({
    required this.id,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.alasan,
    required this.status,
    required this.durasiJam,
  });

  factory OvertimeRequestRecord.fromApi(Map<String, dynamic> j) {
    return OvertimeRequestRecord(
      id: (j['id'] ?? '').toString(),
      tanggal: DateTime.tryParse((j['tanggal'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      jamMulai: (j['jamMulai'] ?? '').toString(),
      jamSelesai: (j['jamSelesai'] ?? '').toString(),
      alasan: (j['alasan'] ?? '').toString(),
      status: (j['status'] ?? 'pending').toString(),
      durasiJam: (j['durasiJam'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Pengajuan & riwayat lembur staff yang sedang login.
class OvertimeService {
  const OvertimeService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// Hari-hari (maks. 3 hari kerja terakhir) yang checkout-nya melewati jam
  /// pulang shift. Kosong = memang tidak ada lembur untuk diajukan.
  static Future<List<OvertimeEligibleDay>> eligibleDays() async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/lembur/eligible-days');
    return res.asList.map(OvertimeEligibleDay.fromApi).toList();
  }

  static Future<List<OvertimeRequestRecord>> history({String? status}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/lembur',
      query: {if (status != null) 'status': status},
    );
    return res.asList.map(OvertimeRequestRecord.fromApi).toList();
  }

  /// Ajukan lembur. [tanggal] dikirim sebagai "YYYY-MM-DD".
  static Future<OvertimeRequestRecord> submit({
    required DateTime tanggal,
    required String jamMulai,
    required String jamSelesai,
    required String alasan,
  }) async {
    final id = await _staffId();
    final ymd = '${tanggal.year.toString().padLeft(4, '0')}-'
        '${tanggal.month.toString().padLeft(2, '0')}-'
        '${tanggal.day.toString().padLeft(2, '0')}';

    final res = await ApiClient.instance.post(
      '/mobile/staff/$id/lembur',
      body: {
        'tanggal': ymd,
        'jamMulai': jamMulai,
        'jamSelesai': jamSelesai,
        'alasan': alasan,
      },
    );
    return OvertimeRequestRecord.fromApi(res.asMap);
  }
}

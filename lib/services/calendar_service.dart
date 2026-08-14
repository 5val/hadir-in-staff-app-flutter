import 'api_client.dart';
import 'session_service.dart';

/// Satu hari libur dari master `hari_libur` di database.
class HariLibur {
  final DateTime tanggal;
  final String nama;

  /// nasional | perusahaan
  final String tipe;

  HariLibur({required this.tanggal, required this.nama, required this.tipe});

  factory HariLibur.fromApi(Map<String, dynamic> j) => HariLibur(
        tanggal: DateTime.tryParse((j['tanggal'] ?? '').toString()) ?? DateTime.now(),
        nama: (j['nama'] ?? '').toString(),
        tipe: (j['tipe'] ?? 'nasional').toString(),
      );
}

/// Kalender kerja staff: hari libur + hari kerja shift-nya.
///
/// Fase 8 — inilah yang membuat date picker pengajuan cuti/izin/lembur tidak
/// lagi mengizinkan tanggal merah. Sebelumnya semua `showDatePicker` di app
/// dipanggil polos tanpa `selectableDayPredicate`, sehingga staff bisa
/// mengajukan cuti pada hari yang memang sudah libur.
class WorkCalendar {
  /// Kunci "YYYY-MM-DD" → nama hari libur.
  final Map<String, String> holidayByDate;

  /// Nama hari kerja shift, mis. ["Senin","Selasa",...].
  final List<String> hariKerja;

  final String shiftNama;
  final String jamMasuk;
  final String jamPulang;

  /// Sprint 3: jam istirahat TETAP shift ("HH:mm"), null bila Shift tidak
  /// punya jam istirahat terkonfigurasi. `jamIstirahatSelesai` adalah target
  /// countdown istirahat (lihat `break_screen.dart`).
  final String? jamIstirahatMulai;
  final String? jamIstirahatSelesai;

  const WorkCalendar({
    required this.holidayByDate,
    required this.hariKerja,
    required this.shiftNama,
    required this.jamMasuk,
    required this.jamPulang,
    this.jamIstirahatMulai,
    this.jamIstirahatSelesai,
  });

  /// Kalender kosong — dipakai sebagai fallback aman bila data belum termuat:
  /// tidak ada tanggal yang di-disable, jadi app tidak pernah memblokir staff
  /// hanya karena gagal memuat kalender (server tetap memvalidasi ulang).
  static const empty = WorkCalendar(
    holidayByDate: {},
    hariKerja: [],
    shiftNama: '',
    jamMasuk: '',
    jamPulang: '',
  );

  static const _dayNames = [
    'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
  ];

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool isHoliday(DateTime d) => holidayByDate.containsKey(dateKey(d));

  String? holidayName(DateTime d) => holidayByDate[dateKey(d)];

  /// Hari kerja shift (mengabaikan hari libur). Bila `hariKerja` kosong
  /// (kalender belum termuat), semua hari dianggap hari kerja.
  bool isShiftWorkday(DateTime d) =>
      hariKerja.isEmpty || hariKerja.contains(_dayNames[d.weekday % 7]);

  /// Predikat untuk `showDatePicker(selectableDayPredicate: ...)`:
  /// tanggal bisa dipilih hanya bila hari kerja shift DAN bukan hari libur.
  bool isSelectable(DateTime d) => isShiftWorkday(d) && !isHoliday(d);
}

/// Kalender kerja yang berlaku untuk sesi ini.
///
/// Dimuat sekali di `MainScreen._hydrateProfile` lalu dibaca semua date
/// picker (cuti, izin, lembur, filter riwayat) sehingga tanggal libur bisa
/// di-disable tanpa masing-masing layar memanggil API sendiri.
class AppCalendar {
  AppCalendar._();
  static WorkCalendar instance = WorkCalendar.empty;
}

class CalendarService {
  const CalendarService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  static Future<WorkCalendar> load({DateTime? from, DateTime? to}) async {
    final id = await _staffId();
    final res = await ApiClient.instance.get(
      '/mobile/staff/$id/hari-libur',
      query: {
        if (from != null) 'from': WorkCalendar.dateKey(from),
        if (to != null) 'to': WorkCalendar.dateKey(to),
      },
    );

    final data = res.asMap;
    final holidays = <String, String>{};
    if (data['hariLibur'] is List) {
      for (final raw in data['hariLibur'] as List) {
        if (raw is! Map) continue;
        final entry = HariLibur.fromApi(Map<String, dynamic>.from(raw));
        holidays[(raw['tanggal'] ?? '').toString()] = entry.nama;
      }
    }

    final shift = data['shift'] is Map
        ? Map<String, dynamic>.from(data['shift'] as Map)
        : <String, dynamic>{};

    return WorkCalendar(
      holidayByDate: holidays,
      hariKerja: (data['hariKerja'] is List)
          ? (data['hariKerja'] as List).map((e) => e.toString()).toList()
          : const [],
      shiftNama: (shift['nama'] ?? '').toString(),
      jamMasuk: (shift['jamMasuk'] ?? '').toString(),
      jamPulang: (shift['jamPulang'] ?? '').toString(),
      jamIstirahatMulai: shift['jamIstirahatMulai']?.toString(),
      jamIstirahatSelesai: shift['jamIstirahatSelesai']?.toString(),
    );
  }
}

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

/// Status hari ini menurut SERVER: libur atau tidak, dan boleh absen atau
/// tidak.
///
/// Dua hal berbeda yang sengaja dipisah:
///  - [isLibur] = tanggal hari ini ada di master hari libur.
///  - [bolehAbsen] = server mengizinkan check-in hari ini.
/// Keduanya bisa sama-sama true: staff yang punya pengajuan LEMBUR berstatus
/// approved untuk tanggal itu tetap boleh absen walaupun hari libur
/// ([dikecualikanLembur]). Karena itu app tidak boleh menyimpulkan sendiri
/// "libur berarti tidak bisa absen" dari daftar tanggal — keputusannya
/// diambil dari server, memakai logika yang sama persis dengan gerbang
/// check-in di `POST .../attendance/check-in`.
class TodayHolidayStatus {
  final bool isLibur;
  final String? namaLibur;

  /// nasional | perusahaan | null
  final String? tipeLibur;

  final bool bolehAbsen;

  /// Pesan siap tampil dari server saat absensi diblokir (null bila boleh).
  final String? alasan;

  final bool dikecualikanLembur;

  const TodayHolidayStatus({
    this.isLibur = false,
    this.namaLibur,
    this.tipeLibur,
    this.bolehAbsen = true,
    this.alasan,
    this.dikecualikanLembur = false,
  });

  /// Default aman ketika data belum termuat / server versi lama tidak
  /// mengirim blok `hariIni`: bukan libur, absensi diizinkan. App tidak boleh
  /// memblokir staff hanya karena gagal memuat kalender — server tetap
  /// memvalidasi ulang saat check-in.
  static const unknown = TodayHolidayStatus();

  factory TodayHolidayStatus.fromApi(Map<String, dynamic> j) => TodayHolidayStatus(
        isLibur: j['isLibur'] == true,
        namaLibur: (j['namaLibur'] as Object?)?.toString(),
        tipeLibur: (j['tipeLibur'] as Object?)?.toString(),
        // Hanya `false` eksplisit yang memblokir; nilai hilang/aneh
        // diperlakukan sebagai boleh absen (fail-open, sama seperti
        // [unknown]).
        bolehAbsen: j['bolehAbsen'] != false,
        alasan: (j['alasan'] as Object?)?.toString(),
        dikecualikanLembur: j['dikecualikanLembur'] == true,
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

  /// 2026-09-09 -- toleransi pulang awal shift, dalam MENIT
  /// (`Shift.toleransiPulang`). Berapa menit sebelum `jamPulang` staff masih
  /// boleh check-out tanpa peringatan "Belum Jam Pulang!" (lihat
  /// `AttendanceRules.earliestCheckoutTarget`/`isAfterEarliestCheckout`).
  final int toleransiPulang;

  /// 2026-09-11 -- `Shift.jamPulangHariBerikutnya`: true = jam pulang shift
  /// jatuh di hari BERIKUTNYA (mis. masuk 22:00, pulang 05:00).
  ///
  /// Sebelum kolom ini ada, app menebaknya sendiri dari `jamPulang <=
  /// jamMasuk`. Tebakan itu benar untuk kasus lazim tapi tidak pernah bisa
  /// dipastikan; sekarang nilainya datang dari penyetelan admin di web.
  /// Default false supaya sebelum kalender termuat perilakunya konservatif
  /// (shift dianggap selesai di hari yang sama).
  final bool jamPulangHariBerikutnya;

  /// Status hari ini menurut server (lihat [TodayHolidayStatus]).
  final TodayHolidayStatus hariIni;

  const WorkCalendar({
    required this.holidayByDate,
    required this.hariKerja,
    required this.shiftNama,
    required this.jamMasuk,
    required this.jamPulang,
    this.jamIstirahatMulai,
    this.jamIstirahatSelesai,
    this.toleransiPulang = 0,
    this.jamPulangHariBerikutnya = false,
    this.hariIni = TodayHolidayStatus.unknown,
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

  /// Boleh check-in hari ini? Keputusan server ([TodayHolidayStatus]), bukan
  /// turunan dari [isHoliday], supaya pengecualian lembur-disetujui dan
  /// kill switch server ikut terhormati.
  bool get canCheckInToday => hariIni.bolehAbsen;

  /// Nama hari libur hari ini untuk ditampilkan di layar Home. Mengutamakan
  /// jawaban server, dan jatuh ke daftar tanggal lokal bila server tidak
  /// mengirimnya (mis. backend versi lama).
  String? get todayHolidayName =>
      hariIni.namaLibur ?? holidayName(DateTime.now());
}

/// Kalender kerja yang berlaku untuk sesi ini.
///
/// Dimuat sekali di `MainScreen._hydrateProfile` lalu dibaca semua date
/// picker (cuti, izin, lembur, filter riwayat) sehingga tanggal libur bisa
/// di-disable tanpa masing-masing layar memanggil API sendiri.
class AppCalendar {
  AppCalendar._();
  static WorkCalendar instance = WorkCalendar.empty;

  /// Kunci "YYYY-MM-DD" tanggal saat [instance] terakhir dimuat.
  ///
  /// Kalender ini memuat status HARI INI (libur/boleh absen), jadi ia basi
  /// begitu tanggal berganti — dan app staff biasa dibiarkan terbuka
  /// berhari-hari di HP. Tanpa penanda ini, staff yang membuka app pada hari
  /// libur setelah app-nya menginap dari hari kerja akan tetap melihat
  /// tombol Check-In (server tetap menolak, tapi staff-nya sudah terlanjur
  /// berfoto). Lihat `MainScreen._refreshCalendarIfStale`.
  static String? loadedForDate;

  static void set(WorkCalendar calendar) {
    instance = calendar;
    loadedForDate = WorkCalendar.dateKey(DateTime.now());
  }

  /// True bila kalender belum pernah dimuat, atau dimuat pada tanggal lain.
  static bool get isStale =>
      loadedForDate == null || loadedForDate != WorkCalendar.dateKey(DateTime.now());
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
      toleransiPulang: (shift['toleransiPulang'] as num?)?.toInt() ?? 0,
      jamPulangHariBerikutnya: shift['jamPulangHariBerikutnya'] == true,
      hariIni: data['hariIni'] is Map
          ? TodayHolidayStatus.fromApi(
              Map<String, dynamic>.from(data['hariIni'] as Map))
          : TodayHolidayStatus.unknown,
    );
  }
}

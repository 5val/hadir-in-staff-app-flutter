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

  /// Staff belum mulai bekerja (hari ini sebelum `joinDate`). Server juga
  /// mengirim `bolehAbsen: false` dalam kasus ini; flag-nya dipisah supaya UI
  /// menampilkan kartu "mulai bekerja" alih-alih kartu hari libur.
  final bool belumMulaiBekerja;

  /// Tanggal mulai bekerja (tanggal saja), null bila server tidak mengirim.
  final DateTime? mulaiBekerja;

  /// Jendela jam RENCANA pada pengajuan lembur hari libur yang disetujui untuk
  /// hari ini ("HH:mm"), null bila hari ini bukan kerja lembur hari libur.
  /// Dipakai popup konfirmasi sebelum check-in.
  final String? lemburJamMulai;
  final String? lemburJamSelesai;

  /// Hari ini staff bekerja di hari libur dengan lembur yang sudah disetujui:
  /// seluruh jam kerjanya dihitung lembur dan jadwal shift tidak berlaku.
  bool get kerjaHariLibur => isLibur && dikecualikanLembur;

  const TodayHolidayStatus({
    this.isLibur = false,
    this.namaLibur,
    this.tipeLibur,
    this.bolehAbsen = true,
    this.alasan,
    this.dikecualikanLembur = false,
    this.belumMulaiBekerja = false,
    this.mulaiBekerja,
    this.lemburJamMulai,
    this.lemburJamSelesai,
  });

  /// Default aman ketika data belum termuat / server versi lama tidak
  /// mengirim blok `hariIni`: bukan libur, absensi diizinkan. App tidak boleh
  /// memblokir staff hanya karena gagal memuat kalender — server tetap
  /// memvalidasi ulang saat check-in.
  static const unknown = TodayHolidayStatus();

  factory TodayHolidayStatus.fromApi(Map<String, dynamic> j) {
    final window = j['lemburHariLibur'] is Map
        ? Map<String, dynamic>.from(j['lemburHariLibur'] as Map)
        : const <String, dynamic>{};
    // Fail-open: hanya `true` eksplisit yang menggerbang (server lama tidak
    // mengirim field ini).
    final belum = j['belumMulaiBekerja'] == true;
    return TodayHolidayStatus(
      belumMulaiBekerja: belum,
      mulaiBekerja: WorkCalendar.parseDateOnly(j['mulaiBekerja']),
      isLibur: j['isLibur'] == true,
      namaLibur: (j['namaLibur'] as Object?)?.toString(),
      tipeLibur: (j['tipeLibur'] as Object?)?.toString(),
      // Hanya `false` eksplisit yang memblokir; nilai hilang/aneh
      // diperlakukan sebagai boleh absen (fail-open, sama seperti
      // [unknown]).
      bolehAbsen: j['bolehAbsen'] != false && !belum,
      alasan: (j['alasan'] as Object?)?.toString(),
      dikecualikanLembur: j['dikecualikanLembur'] == true,
      lemburJamMulai: window['jamMulai']?.toString(),
      lemburJamSelesai: window['jamSelesai']?.toString(),
    );
  }
}

/// Periode gaji yang sudah tertutup untuk staff ini (spec Sprint 3 §3.9).
/// Dipakai untuk dua daftar di [WorkCalendar]: [WorkCalendar.periodeTertutup]
/// (cuti/izin -- tertutup begitu gaji dihitung) dan
/// [WorkCalendar.periodeLemburTertutup] (lembur -- tertutup begitu dikunci).
/// [endExclusive] EKSKLUSIF: hari terakhir periode adalah `endExclusive - 1`.
class PeriodeTertutup {
  final String periode;
  final DateTime start;
  final DateTime endExclusive;

  const PeriodeTertutup({
    required this.periode,
    required this.start,
    required this.endExclusive,
  });

  /// Null bila tanggalnya tidak bisa dibaca (diabaikan, fail-open).
  static PeriodeTertutup? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final s = DateTime.tryParse((raw['start'] ?? '').toString());
    final e = DateTime.tryParse((raw['endExclusive'] ?? '').toString());
    if (s == null || e == null) return null;
    return PeriodeTertutup(
      periode: (raw['periode'] ?? '').toString(),
      start: DateTime(s.year, s.month, s.day),
      endExclusive: DateTime(e.year, e.month, e.day),
    );
  }

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }
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

  /// Periode gaji yang sudah DIHITUNG admin untuk staff ini (slip ada dalam
  /// status apa pun, meski belum dikunci) -- tertutup untuk pengajuan
  /// CUTI/IZIN. Kosong bila server versi lama tidak mengirim
  /// `periodeTertutup` (fail-open: server tetap menolak pengajuannya).
  final List<PeriodeTertutup> periodeTertutup;

  /// 2026-10-09 -- periode gaji yang sudah DIKUNCI (atau dibayar) -- baru
  /// tertutup untuk pengajuan LEMBUR. Selama gaji baru dihitung dan belum
  /// dikunci, staff masih boleh mengajukan lembur yang belum diajukan.
  /// Server lama tanpa `periodeLemburTertutup` -> jatuh ke [periodeTertutup]
  /// (aturan lama server tersebut).
  final List<PeriodeTertutup> periodeLemburTertutup;

  /// Tanggal mulai bekerja staff (`joinDate` profil, tanggal saja). Tanggal
  /// sebelum ini tidak boleh dipilih untuk cuti/izin/lembur. Null = tidak
  /// diketahui (fail-open; server tetap menolak dengan HTTP 400).
  final DateTime? joinDate;

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
    this.periodeTertutup = const [],
    this.periodeLemburTertutup = const [],
    this.joinDate,
  });

  /// Salinan dengan [joinDate] diisi (profil dimuat terpisah dari kalender).
  WorkCalendar withJoinDate(DateTime? joinDate) => WorkCalendar(
        holidayByDate: holidayByDate,
        hariKerja: hariKerja,
        shiftNama: shiftNama,
        jamMasuk: jamMasuk,
        jamPulang: jamPulang,
        jamIstirahatMulai: jamIstirahatMulai,
        jamIstirahatSelesai: jamIstirahatSelesai,
        toleransiPulang: toleransiPulang,
        jamPulangHariBerikutnya: jamPulangHariBerikutnya,
        hariIni: hariIni,
        periodeTertutup: periodeTertutup,
        periodeLemburTertutup: periodeLemburTertutup,
        joinDate: joinDate == null
            ? null
            : DateTime(joinDate.year, joinDate.month, joinDate.day),
      );

  /// Parse "YYYY-MM-DD" / ISO ke tanggal lokal tanpa jam; null bila tidak
  /// terbaca. Bagian tanggal diambil apa adanya dari string (tanpa konversi
  /// zona waktu) supaya "2026-10-12T00:00:00Z" tetap 12 Oktober.
  static DateTime? parseDateOnly(Object? raw) {
    final str = raw?.toString() ?? '';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str);
    if (m == null) return null;
    return DateTime(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// "dd MMM yyyy", mis. "12 Okt 2026".
  static String formatTanggal(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_bulan[d.month - 1]} ${d.year}';

  /// [d] jatuh sebelum tanggal mulai bekerja.
  bool isBeforeJoinDate(DateTime d) {
    final j = joinDate;
    if (j == null) return false;
    return DateTime(d.year, d.month, d.day).isBefore(j);
  }

  /// Alasan yang ditampilkan di tempat pengajuan cuti/izin ditutup.
  static const pesanPeriodeTertutup =
      'Gaji periode ini sudah dihitung, pengajuan ditutup';

  /// Alasan yang ditampilkan di tempat pengajuan lembur ditutup.
  static const pesanPeriodeLemburTertutup =
      'Gaji periode ini sudah dikunci, pengajuan lembur ditutup';

  static List<PeriodeTertutup> _parsePeriodeList(Object? raw) => raw is List
      ? raw.map(PeriodeTertutup.tryParse).whereType<PeriodeTertutup>().toList()
      : const [];

  /// Parsing respons `GET /mobile/staff/:id/hari-libur`.
  factory WorkCalendar.fromApi(Map<String, dynamic> data) {
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
      periodeTertutup: _parsePeriodeList(data['periodeTertutup']),
      periodeLemburTertutup: data.containsKey('periodeLemburTertutup')
          ? _parsePeriodeList(data['periodeLemburTertutup'])
          : _parsePeriodeList(data['periodeTertutup']),
    );
  }

  /// Tanggal [d] jatuh di periode gaji yang sudah dihitung -- tertutup untuk
  /// cuti/izin (end eksklusif).
  bool isPeriodeTertutup(DateTime d) => periodeTertutup.any((p) => p.contains(d));

  /// Tanggal [d] jatuh di periode gaji yang sudah dikunci -- tertutup untuk
  /// lembur (end eksklusif).
  bool isPeriodeLemburTertutup(DateTime d) =>
      periodeLemburTertutup.any((p) => p.contains(d));

  /// Tanggal ini boleh dipilih untuk PENGAJUAN cuti/izin: hari kerja
  /// non-libur DAN gaji periodenya belum dihitung. Berbeda dari
  /// [isSelectable], yang juga dipakai untuk menghitung hari kerja/riwayat.
  bool isSelectableForSubmission(DateTime d) =>
      isSelectable(d) && !isPeriodeTertutup(d) && !isBeforeJoinDate(d);

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

  /// Hari libur dari HARI INI ke depan (terdekat dulu), untuk memilih tanggal
  /// pengajuan lembur hari libur. Server tetap yang memvalidasi.
  List<({DateTime tanggal, String nama})> upcomingHolidays({DateTime? today}) {
    final now = today ?? DateTime.now();
    final todayKey = dateKey(now);
    final result = <({DateTime tanggal, String nama})>[];
    holidayByDate.forEach((key, nama) {
      if (key.compareTo(todayKey) < 0) return;
      final d = DateTime.tryParse(key);
      if (d != null && isBeforeJoinDate(d)) return;
      if (d != null) result.add((tanggal: d, nama: nama));
    });
    result.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return result;
  }

  String? holidayName(DateTime d) => holidayByDate[dateKey(d)];

  /// Hari kerja shift (mengabaikan hari libur). Bila `hariKerja` kosong
  /// (kalender belum termuat), semua hari dianggap hari kerja.
  bool isShiftWorkday(DateTime d) =>
      hariKerja.isEmpty || hariKerja.contains(_dayNames[d.weekday % 7]);

  /// Predikat untuk `showDatePicker(selectableDayPredicate: ...)`:
  /// tanggal bisa dipilih hanya bila hari kerja shift DAN bukan hari libur.
  bool isSelectable(DateTime d) => isShiftWorkday(d) && !isHoliday(d);

  /// Ada minimal satu tanggal di [first]..[last] (inklusif) yang boleh dipilih
  /// untuk pengajuan. Bila false, picker tidak boleh dibuka (tanpa predikat
  /// semua tanggal akan jadi bisa dipilih).
  bool hasSelectableForSubmission(DateTime first, DateTime last) {
    final end = DateTime(last.year, last.month, last.day);
    for (var d = DateTime(first.year, first.month, first.day);
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (isSelectableForSubmission(d)) return true;
    }
    return false;
  }

  /// Pesan bila [hasSelectableForSubmission] false: alasan periode tertutup
  /// bila ada tanggal di rentang yang tertutup, selain itu pesan umum.
  String noSelectableMessage(DateTime first, DateTime last) {
    final end = DateTime(last.year, last.month, last.day);
    for (var d = DateTime(first.year, first.month, first.day);
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (isPeriodeTertutup(d)) return pesanPeriodeTertutup;
    }
    final j = joinDate;
    if (j != null && isBeforeJoinDate(first)) {
      return 'Anda baru bisa mengajukan mulai ${formatTanggal(j)}.';
    }
    return 'Tidak ada hari kerja yang bisa dipilih pada rentang tanggal ini.';
  }

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

    return WorkCalendar.fromApi(res.asMap);
  }
}

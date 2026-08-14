import 'package:flutter/material.dart';

import '../config/testing_config.dart';
import '../models/models.dart';
import 'attendance_service.dart';
import 'calendar_service.dart';

/// Status kehadiran karyawan hari ini
enum AttendanceProviderStatus {
  notCheckedIn, // Belum check-in sama sekali
  checkedIn, // Sudah check-in, sedang bekerja
  onBreak, // Sedang istirahat
  breakEnded, // Selesai istirahat, kembali bekerja
  checkedOut, // Sudah check-out, selesai hari ini
}

/// Aturan jam kerja — Fase 8: seluruhnya berasal dari SHIFT staff di database.
///
/// Sebelumnya kelas ini berisi konstanta hardcode yang salah dan saling
/// bertentangan dengan data nyata:
///   - `breakStartHour = 12` / `breakEndHour = 13` — jendela istirahat
///     karangan yang tidak ada di database mana pun. Tombol istirahat hanya
///     aktif pukul 12:00–13:00, padahal shift staff bisa berbeda-beda.
///   - `checkoutCutoffHour = 24` dan `normalCheckoutHour = 24` — inilah
///     sumber bug "jam kerja mulai dari 24.00.00" yang dilaporkan: jam pulang
///     dianggap pukul 24, sehingga check-out praktis tidak pernah "boleh"
///     dan seluruh perhitungan sisa jam kerja meleset sehari penuh.
///
/// Sekarang jam masuk/pulang dibaca dari `Shift.jamMasuk`/`Shift.jamPulang`
/// (endpoint hari-libur mengembalikannya bersama kalender kerja), dan
/// istirahat tidak lagi dibatasi jendela jam apa pun — staff menekan
/// break-in/break-out kapan pun ia istirahat, yang dicatat hanyalah DURASI.
class AttendanceRules {
  AttendanceRules._();

  static TimeOfDay? _jamMasuk;
  static TimeOfDay? _jamPulang;

  // Sprint 3: jam istirahat TETAP shift (`Shift.jamIstirahatMulai`/
  // `jamIstirahatSelesai`). Null bila Shift tidak punya jam istirahat
  // terkonfigurasi — pemanggil (mis. `BreakScreen`) harus fallback ke durasi
  // hardcode, BUKAN memakai angka karangan.
  static TimeOfDay? _jamIstirahatMulai;
  static TimeOfDay? _jamIstirahatSelesai;

  /// Diisi dari [WorkCalendar] setelah kalender kerja termuat.
  static void hydrateFromShift({
    required String jamMasuk,
    required String jamPulang,
    String? jamIstirahatMulai,
    String? jamIstirahatSelesai,
  }) {
    _jamMasuk = _parse(jamMasuk) ?? _jamMasuk;
    _jamPulang = _parse(jamPulang) ?? _jamPulang;
    // Beda dari jamMasuk/jamPulang: null di sini artinya Shift MEMANG tidak
    // punya jam istirahat (bukan "kalender belum termuat"), jadi tidak
    // dijaga oleh `?? _jamIstirahatMulai` — nilai terbaru dari server selalu
    // menang, termasuk saat itu null.
    _jamIstirahatMulai = jamIstirahatMulai == null ? null : _parse(jamIstirahatMulai);
    _jamIstirahatSelesai =
        jamIstirahatSelesai == null ? null : _parse(jamIstirahatSelesai);
  }

  static TimeOfDay? _parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Jam pulang shift. Null bila kalender belum termuat — pemanggil harus
  /// memperlakukan itu sebagai "belum tahu", BUKAN memakai angka karangan.
  static TimeOfDay? get jamPulang => _jamPulang;
  static TimeOfDay? get jamMasuk => _jamMasuk;

  /// Jam istirahat TETAP shift. Null bila Shift tidak punya jam istirahat
  /// terkonfigurasi.
  static TimeOfDay? get jamIstirahatMulai => _jamIstirahatMulai;
  static TimeOfDay? get jamIstirahatSelesai => _jamIstirahatSelesai;

  static String get jamPulangLabel => _fmt(_jamPulang);
  static String get jamMasukLabel => _fmt(_jamMasuk);
  static String get jamIstirahatSelesaiLabel => _fmt(_jamIstirahatSelesai);

  /// Target countdown istirahat hari ini (tanggal SEKARANG + jam
  /// `jamIstirahatSelesai` shift) — SELALU mengarah ke jam selesai TETAP,
  /// berapa pun jam staff menekan "Mulai Istirahat". Null bila Shift tidak
  /// punya jam istirahat terkonfigurasi, pemanggil harus fallback ke durasi
  /// hardcode di kasus itu.
  static DateTime? get breakEndTargetToday {
    final t = _jamIstirahatSelesai;
    if (t == null) return null;
    final now = TestingConfig.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }

  /// Detik tersisa sampai [breakEndTargetToday] — NEGATIF berarti sudah lewat
  /// jam selesai istirahat (overtime), bukan berhenti di 0. Null bila Shift
  /// tidak punya jam istirahat terkonfigurasi; pemanggil harus fallback ke
  /// durasi hardcode di kasus itu (mis. `BreakScreen`).
  static int? get secondsUntilBreakEnd {
    final target = breakEndTargetToday;
    if (target == null) return null;
    return target.difference(TestingConfig.now()).inSeconds;
  }

  static String _fmt(TimeOfDay? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Sudah melewati jam pulang shift?
  ///
  /// TESTING — `TestingConfig.now()` mengembalikan jam asli HP di mode normal,
  /// dan `TestingConfig.clockTime` saat mode testing aktif. Dipakai supaya
  /// dialog "Belum Jam Pulang!" tidak menghalangi pengujian check-out.
  static bool get isAfterNormalCheckout {
    final pulang = _jamPulang;
    if (pulang == null) return false;
    final now = TestingConfig.now();
    final target = DateTime(now.year, now.month, now.day, pulang.hour, pulang.minute);
    return !now.isBefore(target);
  }

  /// Berapa lama lagi sampai jam pulang (null bila sudah lewat/belum diketahui).
  static Duration? get timeUntilCheckout {
    final pulang = _jamPulang;
    if (pulang == null) return null;
    final now = TestingConfig.now();
    final target = DateTime(now.year, now.month, now.day, pulang.hour, pulang.minute);
    return now.isBefore(target) ? target.difference(now) : null;
  }
}

/// Shared state untuk status absensi — dipakai HomeTab dan FAB di MainScreen.
///
/// Fase 8: state ini bukan lagi "kebenaran" — ia CERMIN dari baris
/// `attendance` hari ini di database. Setiap aksi (check-in/out, break)
/// memanggil backend dulu, lalu men-hidrasi ulang dari record yang dikembalikan.
/// Sebelumnya break murni hidup di memori app: hilang saat app ditutup, tidak
/// pernah sampai ke DB, dan durasinya tidak masuk laporan mana pun.
class AttendanceProvider extends ChangeNotifier {
  AttendanceProviderStatus _status = AttendanceProviderStatus.notCheckedIn;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;

  /// Record hari ini apa adanya dari server (null bila belum absen).
  AttendanceRecord? _today;

  AttendanceProviderStatus get status => _status;
  DateTime? get checkInTime => _checkInTime;
  DateTime? get checkOutTime => _checkOutTime;
  AttendanceRecord? get today => _today;

  bool get isNotCheckedIn => _status == AttendanceProviderStatus.notCheckedIn;
  bool get isCheckedIn => _status == AttendanceProviderStatus.checkedIn;
  bool get isOnBreak => _status == AttendanceProviderStatus.onBreak;
  bool get isBreakEnded => _status == AttendanceProviderStatus.breakEnded;
  bool get isCheckedOut => _status == AttendanceProviderStatus.checkedOut;

  /// Total menit istirahat hari ini yang sudah TERCATAT di DB
  /// (`Attendance.breakDurasi`) — belum termasuk istirahat yang sedang
  /// berjalan; untuk itu pakai [currentBreakDuration].
  int get breakMinutes => _today?.breakMinutes ?? 0;

  /// Uang makan hari ini (rupiah), 0 bila belum check-out / tidak memenuhi syarat.
  int get uangMakan => _today?.uangMakan ?? 0;

  /// Durasi istirahat yang harus DITAMPILKAN sekarang:
  /// akumulasi tersimpan + istirahat yang sedang berjalan (kalau ada).
  Duration get currentBreakDuration {
    var total = Duration(minutes: breakMinutes);
    final startedAt = _today?.breakStartedAt;
    if (startedAt != null) total += DateTime.now().difference(startedAt);
    return total;
  }

  /// Durasi kerja bersih yang berjalan (sudah dikurangi istirahat).
  ///
  /// Titik nolnya adalah MOMEN NYATA check-in (`Attendance.createdAt`, jam
  /// server) — BUKAN jam masuk yang tercatat (`checkIn` = "08:05").
  ///
  /// Kenapa: dua angka itu tidak selalu sama. Jam tercatat bisa berupa jam
  /// yang di-hardcode saat pengujian, entri manual admin, atau jam server yang
  /// berbeda beberapa menit dari jam HP. Dulu timer dihitung
  /// `now - jamMasukTercatat`, sehingga begitu selesai check-in angkanya
  /// langsung meloncat ke selisih jam itu (mis. "06:32:10") alih-alih mulai
  /// dari 00:00:00. Sekarang hitungannya benar-benar dari detik 0 saat tombol
  /// check-in ditekan, dan tetap benar walau app ditutup lalu dibuka lagi
  /// karena patokannya tersimpan di database, bukan di memori app.
  ///
  /// Setelah check-out timer dibekukan memakai `updatedAt` (momen baris ini
  /// terakhir diubah = momen check-out). Ini angka TAMPILAN; jam kerja resmi
  /// untuk penggajian tetap dihitung backend dari `checkIn`/`checkOut`.
  Duration get workDuration {
    final rec = _today;
    if (rec == null || rec.checkIn == null) return Duration.zero;

    // Fallback ke jam masuk tercatat hanya bila `createdAt` tidak terkirim
    // (mis. record lama / entri manual admin).
    final start = rec.recordedAt ?? _checkInTime;
    if (start == null) return Duration.zero;

    final end = _checkOutTime != null
        ? (rec.lastUpdatedAt ?? DateTime.now())
        : DateTime.now();

    final gross = end.difference(start);
    final net = gross - currentBreakDuration;
    return net.isNegative ? Duration.zero : net;
  }

  String get fabActionLabel {
    switch (_status) {
      case AttendanceProviderStatus.notCheckedIn:
        return 'Check-In';
      case AttendanceProviderStatus.checkedIn:
        return 'Check-Out / Istirahat';
      case AttendanceProviderStatus.onBreak:
        return 'Selesai Istirahat';
      case AttendanceProviderStatus.breakEnded:
        return 'Check-Out';
      case AttendanceProviderStatus.checkedOut:
        return 'Sudah Selesai';
    }
  }

  void reset() {
    _status = AttendanceProviderStatus.notCheckedIn;
    _checkInTime = null;
    _checkOutTime = null;
    _today = null;
    notifyListeners();
  }

  // ── Integrasi backend ─────────────────────────────────────────────

  /// Sinkronkan seluruh state dari record absensi hari ini (backend).
  /// Satu-satunya tempat status diturunkan — tidak ada jalur lain yang
  /// menetapkan status "dari tebakan app".
  void hydrateFromToday(AttendanceRecord? rec) {
    _today = rec;
    if (rec == null) {
      _status = AttendanceProviderStatus.notCheckedIn;
      _checkInTime = null;
      _checkOutTime = null;
    } else {
      _checkInTime = rec.checkIn;
      _checkOutTime = rec.checkOut;
      if (rec.checkOut != null) {
        _status = AttendanceProviderStatus.checkedOut;
      } else if (rec.isOnBreak) {
        _status = AttendanceProviderStatus.onBreak;
      } else if (rec.checkIn != null) {
        _status = rec.breakMinutes > 0
            ? AttendanceProviderStatus.breakEnded
            : AttendanceProviderStatus.checkedIn;
      } else {
        _status = AttendanceProviderStatus.notCheckedIn;
      }
    }
    notifyListeners();
  }

  /// Muat ulang record hari ini dari server.
  Future<void> refreshToday() async {
    hydrateFromToday(await AttendanceService.today());
  }

  /// Check-in ke backend lalu update state. Melempar [ApiException] bila gagal
  /// — termasuk saat koordinat GPS berada di luar radius lokasi kerja.
  Future<void> checkInRemote({
    String? fotoPath,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final rec = await AttendanceService.checkIn(
      fotoMasuk: fotoPath,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
    hydrateFromToday(rec);
  }

  /// Check-out ke backend lalu update state.
  Future<void> checkOutRemote({
    String? fotoPath,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final rec = await AttendanceService.checkOut(
      fotoKeluar: fotoPath,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
    hydrateFromToday(rec);
  }

  /// Mulai istirahat (tercatat di DB, bukan hanya di memori app).
  Future<void> startBreakRemote() async {
    hydrateFromToday(await AttendanceService.breakIn());
  }

  /// Selesai istirahat — server menghitung & menambah `breakDurasi`.
  Future<void> endBreakRemote() async {
    hydrateFromToday(await AttendanceService.breakOut());
  }
}

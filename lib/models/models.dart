// ============================================================
// STAFFSYNC MODELS
// ============================================================

import 'package:flutter/material.dart';

class AppSession {
  static UserProfile? _currentUser;

  static UserProfile get currentUser => _currentUser ?? SampleData._users.first;

  static bool get isSupervisor => currentUser.role == UserRole.supervisor;
  static bool get isAdmin => currentUser.role == UserRole.admin;

  static void setUser(String username, String password) {
    try {
      _currentUser = SampleData._users.firstWhere(
        (u) => u.username == username && u.password == password,
      );
    } catch (_) {}
  }

  static void setUserById(String id) {
    try {
      _currentUser = SampleData._users.firstWhere(
        (u) => u.id == id,
      );
    } catch (_) {}
  }

  static void setUserByPhone(String phone) {
    try {
      final user = findUserByPhone(phone);
      if (user != null) {
        _currentUser = user;
      }
    } catch (_) {}
  }

  /// Profil staff asli dari backend (diisi setelah hidrasi di MainScreen).
  static StaffProfile? staff;

  /// Set profil staff dari backend & sinkronkan [currentUser] agar seluruh
  /// layar yang membaca AppSession.currentUser menampilkan data asli.
  static void setStaff(StaffProfile profile) {
    staff = profile;
    _currentUser = profile.toUserProfile();
  }

  static void clearUser() {
    _currentUser = null;
    staff = null;
  }

  static void updateEmail(String newEmail) {
    final current = currentUser;
    final updated = current.copyWith(email: newEmail);
    _currentUser = updated;

    final index = SampleData._users.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      SampleData._users[index] = updated;
    }
  }

  static void updatePhoneNumber(String newPhone) {
    final current = currentUser;
    final updated = current.copyWith(phoneNumber: newPhone);
    _currentUser = updated;

    final index = SampleData._users.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      SampleData._users[index] = updated;
    }
  }

  /// Returns UserProfile if credentials valid, else null.
  static UserProfile? validateLogin(String username, String password) {
    try {
      return SampleData._users.firstWhere(
        (u) =>
            (u.employeeId.toLowerCase() == username.toLowerCase() ||
                u.username.toLowerCase() == username.toLowerCase()) &&
            u.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  static UserProfile? findUserByPhone(String phone) {
    try {
      final normalizedInput = phone.replaceAll(RegExp(r'\D'), '');
      if (normalizedInput.isEmpty) return null;
      return SampleData._users.firstWhere((u) {
        final normalizedUser = u.phoneNumber.replaceAll(RegExp(r'\D'), '');
        // Match exact or trailing suffix if length is sufficient (e.g. 0812... vs 62812...)
        if (normalizedInput == normalizedUser) return true;
        if (normalizedInput.length >= 9 && normalizedUser.length >= 9) {
          final suffixInput =
              normalizedInput.substring(normalizedInput.length - 9);
          final suffixUser =
              normalizedUser.substring(normalizedUser.length - 9);
          return suffixInput == suffixUser;
        }
        return false;
      });
    } catch (_) {
      return null;
    }
  }
}

// ── Position Master ──────────────────────────────────────────
class PositionModel {
  final String id;
  final String name;
  final String divisionId;
  final int annualLeaveQuota;
  final int earlyCheckoutToleranceMinutes;
  final int minLeaveAdvanceDays;
  final int payrollPeriodDays;
  final bool payrollEndMonth;
  final int operationalHours;
  final int extraHourAllowance;
  final PayrollType payrollType;

  // Tambahan properti baru untuk salary_screen
  final int baseSalary;
  final int dailyBonus;
  final int healthAllowance;
  final int transportAllowance;
  final int salaryDisbursementDay;

  const PositionModel({
    required this.id,
    required this.name,
    required this.divisionId,
    required this.annualLeaveQuota,
    required this.earlyCheckoutToleranceMinutes,
    required this.minLeaveAdvanceDays,
    required this.payrollPeriodDays,
    required this.operationalHours,
    required this.extraHourAllowance,
    required this.payrollType,
    this.payrollEndMonth = true,
    // Require properti baru
    required this.baseSalary,
    required this.dailyBonus,
    required this.healthAllowance,
    required this.transportAllowance,
    required this.salaryDisbursementDay,
  });
}

enum PayrollType { weekly, biweekly, monthly }

// ── Division ─────────────────────────────────────────────────
class DivisionModel {
  final String id;
  final String name;

  const DivisionModel({required this.id, required this.name});
}

// ── Shift ────────────────────────────────────────────────────
class ShiftModel {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int breakDurationMinutes;

  // Sprint 3: jam istirahat TETAP dari Shift (`Shift.jamIstirahatMulai`/
  // `jamIstirahatSelesai`, "HH:mm"), dipakai sebagai target countdown
  // istirahat yang selalu mengarah ke jam SELESAI tetap, bukan durasi
  // sejak staff menekan tombol. Null bila Shift tidak punya jam istirahat
  // terkonfigurasi (mengikuti nullability kolom di backend) — di kasus itu
  // UI fallback ke [breakDurationMinutes].
  final String? jamIstirahatMulai;
  final String? jamIstirahatSelesai;

  const ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakDurationMinutes = 60,
    this.jamIstirahatMulai,
    this.jamIstirahatSelesai,
  });

  String get startTimeStr =>
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  String get endTimeStr =>
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

  Duration get workDuration {
    final start = startTime.hour * 60 + startTime.minute;
    final end = endTime.hour * 60 + endTime.minute;
    return Duration(minutes: end - start - breakDurationMinutes);
  }
}

// ── User Profile ──────────────────────────────────────────────
class UserProfile {
  final String id;
  final String name;
  final String username;
  final String password;
  final String employeeId;
  final String nik; // ← Nomor Induk Karyawan, dipakai di slip PDF
  final String positionId;
  final String divisionId;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final ShiftModel currentShift;
  final PositionModel position;
  final int points;
  final double maxOvertimeHours;

  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.employeeId,
    this.nik = '-',
    required this.positionId,
    required this.divisionId,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.currentShift,
    required this.position,
    this.points = 0,
    this.maxOvertimeHours = 4.0,
  });

  UserProfile copyWith({int? points, String? email, String? phoneNumber}) =>
      UserProfile(
        id: id,
        name: name,
        username: username,
        password: password,
        employeeId: employeeId,
        nik: nik,
        positionId: positionId,
        divisionId: divisionId,
        email: email ?? this.email,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        role: role,
        currentShift: currentShift,
        position: position,
        points: points ?? this.points,
        maxOvertimeHours: maxOvertimeHours,
      );
}

enum UserRole { staff, supervisor, admin }

// ── Attendance ────────────────────────────────────────────────
class AttendanceRecord {
  final String id;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? breakStart;
  final DateTime? breakEnd;
  final AttendanceStatus status;
  final String? locationLabel;
  final bool useGps;
  final int? lateMinutes;
  final int? overtimeMinutes;
  final int pointsEarned;
  final String? overtimeReason;
  final bool overtimeApplied;
  final RequestStatus overtimeStatus;

  // ── Fase 8: kolom nyata dari tabel `attendance` ──────────────────
  /// Total menit istirahat hari itu (`Attendance.breakDurasi`), akumulatif.
  /// Ini satu-satunya data istirahat yang disimpan — TIDAK ada jam mulai/
  /// selesai istirahat sebagai data yang ditampilkan.
  final int breakMinutes;

  /// Sedang istirahat sekarang (`Attendance.breakMulaiAt` masih terisi).
  final bool isOnBreak;

  /// Kapan istirahat yang sedang berjalan dimulai — dipakai HANYA untuk
  /// menghitung timer berjalan di layar, tidak pernah ditampilkan sebagai jam.
  final DateTime? breakStartedAt;

  /// Uang makan yang didapat hari itu (`Attendance.uangMakan`), rupiah.
  final int uangMakan;

  /// Foto absensi (URL Drive / path server), kosong bila tidak ada.
  final String fotoMasuk;
  final String fotoKeluar;

  /// MOMEN NYATA baris absensi ini dibuat (`Attendance.createdAt`) —
  /// yaitu detik saat tombol check-in benar-benar ditekan, menurut jam SERVER.
  ///
  /// Berbeda dari [checkIn] yang merupakan JAM TERCATAT ("08:05") dan bisa
  /// saja bukan waktu sungguhan (mis. jam yang di-hardcode saat pengujian,
  /// atau entri manual admin). Timer "waktu kerja" di layar dihitung dari
  /// SINI supaya selalu mulai 00:00:00 tepat saat check-in, bukan melompat ke
  /// selisih terhadap jam masuk yang tercatat.
  final DateTime? recordedAt;

  /// Terakhir kali baris ini diubah (`Attendance.updatedAt`). Dipakai sebagai
  /// perkiraan momen check-out untuk membekukan timer setelah pulang.
  final DateTime? lastUpdatedAt;

  const AttendanceRecord({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.breakStart,
    this.breakEnd,
    required this.status,
    this.locationLabel,
    this.useGps = false,
    this.lateMinutes,
    this.overtimeMinutes,
    this.pointsEarned = 0,
    this.overtimeReason,
    this.overtimeApplied = false,
    this.overtimeStatus = RequestStatus.pending,
    this.breakMinutes = 0,
    this.isOnBreak = false,
    this.breakStartedAt,
    this.uangMakan = 0,
    this.fotoMasuk = '',
    this.fotoKeluar = '',
    this.recordedAt,
    this.lastUpdatedAt,
  });

  /// Bangun dari JSON backend (/api/mobile/staff/:id/attendance).
  /// Backend menyimpan `tanggal` (ISO date), `checkIn`/`checkOut` "HH:mm",
  /// `status` (hadir|terlambat|izin|cuti|alpha|pulang_awal), `keterlambatan`,
  /// `lembur`, `lokasi`.
  factory AttendanceRecord.fromApi(Map<String, dynamic> j) {
    // Backend mengirim `tanggal` sebagai local-midnight yang diserialisasi ke
    // UTC (mis. "…T17:00:00.000Z" untuk WIB). Konversi ke lokal dulu agar
    // komponen tanggalnya tidak mundur satu hari.
    final parsed = DateTime.tryParse((j['tanggal'] ?? '').toString())?.toLocal();
    final base = parsed != null
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : DateTime.now();

    DateTime? combine(dynamic hhmm) {
      final s = hhmm?.toString() ?? '';
      final parts = s.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    AttendanceStatus mapStatus(String s) {
      switch (s) {
        case 'terlambat':
          return AttendanceStatus.late;
        case 'izin':
        case 'cuti':
          return AttendanceStatus.leave;
        case 'alpha':
          return AttendanceStatus.absent;
        default:
          return AttendanceStatus.present;
      }
    }

    int? asIntN(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    final lokasi = (j['lokasi'] ?? '').toString();

    // Fase 8: `breakMulaiAt` non-null berarti staff SEDANG istirahat.
    final breakMulaiAt =
        DateTime.tryParse((j['breakMulaiAt'] ?? '').toString())?.toLocal();

    return AttendanceRecord(
      id: (j['id'] ?? '').toString(),
      date: base,
      checkIn: combine(j['checkIn']),
      checkOut: combine(j['checkOut']),
      status: mapStatus((j['status'] ?? '').toString()),
      locationLabel: lokasi.isEmpty ? null : lokasi,
      useGps: true,
      lateMinutes: asIntN(j['keterlambatan']),
      overtimeMinutes: asIntN(j['lembur']),
      breakMinutes: asIntN(j['breakDurasi']) ?? 0,
      isOnBreak: breakMulaiAt != null,
      breakStartedAt: breakMulaiAt,
      uangMakan: asIntN(j['uangMakan']) ?? 0,
      fotoMasuk: (j['fotoMasuk'] ?? '').toString(),
      fotoKeluar: (j['fotoKeluar'] ?? '').toString(),
      recordedAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
      lastUpdatedAt:
          DateTime.tryParse((j['updatedAt'] ?? '').toString())?.toLocal(),
    );
  }

  /// Durasi kerja bersih = (checkout - checkin) - durasi istirahat.
  ///
  /// Fase 8: durasi istirahat kini diambil dari [breakMinutes] (kolom
  /// `Attendance.breakDurasi` di DB) — sebelumnya dihitung dari
  /// breakStart/breakEnd yang tidak pernah terisi dari backend sama sekali,
  /// sehingga istirahat tidak pernah benar-benar dipotong dari jam kerja.
  Duration? get workDuration {
    if (checkIn == null || checkOut == null) return null;
    final raw = checkOut!.difference(checkIn!);
    final breakDur = breakMinutes > 0
        ? Duration(minutes: breakMinutes)
        : ((breakStart != null && breakEnd != null)
            ? breakEnd!.difference(breakStart!)
            : Duration.zero);
    final net = raw - breakDur;
    return net.isNegative ? Duration.zero : net;
  }

  AttendanceRecord copyWith({
    String? id,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
    DateTime? breakStart,
    DateTime? breakEnd,
    AttendanceStatus? status,
    String? locationLabel,
    bool? useGps,
    int? lateMinutes,
    int? overtimeMinutes,
    int? pointsEarned,
    String? overtimeReason,
    bool? overtimeApplied,
    RequestStatus? overtimeStatus,
    int? breakMinutes,
    bool? isOnBreak,
    DateTime? breakStartedAt,
    int? uangMakan,
    String? fotoMasuk,
    String? fotoKeluar,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      breakStart: breakStart ?? this.breakStart,
      breakEnd: breakEnd ?? this.breakEnd,
      status: status ?? this.status,
      locationLabel: locationLabel ?? this.locationLabel,
      useGps: useGps ?? this.useGps,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      overtimeReason: overtimeReason ?? this.overtimeReason,
      overtimeApplied: overtimeApplied ?? this.overtimeApplied,
      overtimeStatus: overtimeStatus ?? this.overtimeStatus,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      breakStartedAt: breakStartedAt ?? this.breakStartedAt,
      uangMakan: uangMakan ?? this.uangMakan,
      fotoMasuk: fotoMasuk ?? this.fotoMasuk,
      fotoKeluar: fotoKeluar ?? this.fotoKeluar,
    );
  }
}

enum AttendanceStatus { present, late, absent, leave, holiday }

// ── Leave Request ─────────────────────────────────────────────
class LeaveRequest {
  final String id;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final RequestStatus status;
  final String? reason;
  final String? adminNote;
  final String? employeeName;
  final List<String> attachmentPaths;
  final List<AllowanceType> allowances;
  final DateTime submittedAt;

  const LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    this.adminNote,
    this.attachmentPaths = const [],
    this.allowances = const [],
    this.employeeName,
    required this.submittedAt,
  });

  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// Bangun dari JSON backend (/api/mobile/staff/:id/leave).
  /// Backend: `tipe` (Cuti|Izin|Sakit|Dinas), `subTipe`, `alasan`,
  /// `tanggalMulai`/`tanggalSelesai` (ISO date), `status`, `alasanTolak`,
  /// `diajukanPada`.
  factory LeaveRequest.fromApi(Map<String, dynamic> j) {
    LeaveType mapType(String tipe, String subTipe) {
      switch (tipe) {
        case 'Cuti':
          return LeaveType.annual;
        case 'Sakit':
          return LeaveType.sick;
        case 'Dinas':
          return LeaveType.seminar;
        case 'Izin':
        case 'Ijin': // enum DB memakai ejaan "Ijin"
          return subTipe.toLowerCase().contains('seminar')
              ? LeaveType.seminar
              : LeaveType.school;
        default:
          return LeaveType.school;
      }
    }

    RequestStatus mapStatus(String s) {
      switch (s) {
        case 'approved':
          return RequestStatus.approved;
        case 'rejected':
          return RequestStatus.rejected;
        default:
          return RequestStatus.pending;
      }
    }

    DateTime parseDate(dynamic v) {
      final p = DateTime.tryParse(v?.toString() ?? '');
      return p == null ? DateTime.now() : DateTime(p.year, p.month, p.day);
    }

    DateTime parseTs(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();

    final tolak = (j['alasanTolak'] ?? '').toString();

    return LeaveRequest(
      id: (j['id'] ?? '').toString(),
      type: mapType((j['tipe'] ?? '').toString(), (j['subTipe'] ?? '').toString()),
      startDate: parseDate(j['tanggalMulai']),
      endDate: parseDate(j['tanggalSelesai']),
      status: mapStatus((j['status'] ?? '').toString()),
      reason: (j['alasan'] ?? '').toString(),
      adminNote: tolak.isEmpty ? null : tolak,
      submittedAt: parseTs(j['diajukanPada']),
      // Fase 8: terisi ketika backend menyertakan relasi `staff` — yaitu
      // pada endpoint pengajuan BAWAHAN, di mana kartu harus menampilkan
      // nama pengaju. Untuk pengajuan sendiri relasi ini tidak dikirim dan
      // nilainya tetap null (layar riwayat sendiri memang tidak memakainya).
      employeeName: j['staff'] is Map
          ? ((j['staff'] as Map)['nama'] ?? '').toString()
          : null,
    );
  }
}

enum LeaveType { annual, sick, seminar, school }

enum RequestStatus { pending, approved, rejected }

enum AllowanceType { health, accommodation, transport, spp }

// ── Salary Slip ───────────────────────────────────────────────
/// Kelompok komponen gaji — Fase 8.
///
/// Struktur slip mengikuti aturan yang diminta:
///   Gaji Bersih   = pendapatan pokok (gaji pokok, bonus, lembur, THR)
///                   dikurangi PPh 21
///   Take Home Pay = Gaji Bersih + Tunjangan − Potongan
///
/// Karena itu komponen tidak lagi cukup dibedakan "pendapatan vs potongan"
/// saja — tunjangan harus bisa dipisahkan dari pendapatan pokok, dan PPh
/// harus bisa dipisahkan dari potongan lain.
enum SalaryGroup {
  /// Gaji pokok, bonus tepat waktu/kehadiran, lembur, THR.
  pendapatanPokok,

  /// Tunjangan + fasilitas + uang makan — ditampilkan DI BAWAH gaji bersih.
  tunjangan,

  /// PPh 21 — dipotong untuk mendapat "gaji bersih".
  pajak,

  /// Denda keterlambatan, potongan alpha, BPJS — dipotong dari gaji bersih
  /// untuk mendapat take home pay.
  potongan,
}

class SalaryComponent {
  final String label;
  final String note;
  final int amount;
  final SalaryGroup group;

  /// Sprint 2 EPIC 9: komponen ini TAMPIL di rincian tapi TIDAK ikut menambah
  /// Take Home Pay (`gajiNetto` server). Yang masuk kategori ini:
  ///   - tunjangan dengan `bentuk: "barang"` (kena pajak, tapi bukan uang tunai)
  ///   - semua item Fasilitas (natura — hanya kelebihan di atas batas yang kena
  ///     pajak, nominalnya sendiri tidak pernah ditransfer)
  ///   - uang makan (dijumlah live dari Attendance, backend belum wire ke
  ///     `gajiNetto`)
  /// Dipakai UI untuk menandai baris dengan badge, supaya staff tidak bingung
  /// kenapa jumlah rincian tunjangan lebih besar dari yang menambah THP.
  final bool excludedFromThp;

  const SalaryComponent({
    required this.label,
    this.note = '',
    required this.amount,
    required this.group,
    this.excludedFromThp = false,
  });

  /// Kompatibilitas dengan layar lama yang hanya mengenal "potongan atau bukan".
  bool get isDeduction =>
      group == SalaryGroup.pajak || group == SalaryGroup.potongan;

  /// [note] + penjelasan eksplisit kalau komponen ini tidak menambah THP.
  /// Dipakai di media yang tidak bisa menampilkan badge (PDF cetak slip);
  /// di layar, badge "Di luar THP" yang membawa informasi ini.
  String get noteWithThpNotice {
    if (!excludedFromThp) return note;
    const notice = 'tidak termasuk Take Home Pay';
    return note.isEmpty ? notice : '$note — $notice';
  }
}

class LeaveRecord {
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String status; // 'Disetujui' | 'Ditolak' | 'Menunggu'

  const LeaveRecord({
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.status,
  });
}

class SalarySlip {
  final String period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String transferBy;
  final List<SalaryComponent> components;
  final int workingDays;
  final int presentDays;
  final int lateDays;
  final int overtimeHours;
  final int? leaveDays;
  final int? permissionDays;
  final List<LeaveRecord>? leaveHistory;
  final List<LeaveRecord>? permissionHistory;

  /// ANGKA TAKE HOME PAY RESMI dari server (`slip_gaji.gajiNetto`) — jumlah
  /// yang benar-benar ditransfer HRD. JANGAN dihitung ulang di client: server
  /// (`payroll-calc.ts`) sudah memakai formula resmi
  /// `gajiNetto = totalPendapatan + totalTunjanganUang`, di mana
  /// `totalPendapatan` sudah memperhitungkan PPh 21 dan potongan BPJS staff.
  final int gajiNetto;

  /// `slip_gaji.totalTunjanganUang` — HANYA tunjangan `bentuk: "uang"`, yaitu
  /// bagian tunjangan yang benar-benar menambah [gajiNetto]. Tunjangan
  /// `bentuk: "barang"`, Fasilitas, dan uang makan TIDAK termasuk di sini.
  final int totalTunjanganUang;

  const SalarySlip({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.transferBy,
    required this.components,
    required this.workingDays,
    required this.presentDays,
    required this.lateDays,
    required this.overtimeHours,
    required this.leaveDays,
    required this.permissionDays,
    required this.leaveHistory,
    required this.permissionHistory,
    required this.gajiNetto,
    required this.totalTunjanganUang,
  });

  /// Alias agar kompatibel dengan salary_screen yang pakai `slip.workDays`
  int get workDays => workingDays;

  /// Jumlah hari alpha (tidak hadir tanpa cuti/izin). Cuti & izin dikeluarkan
  /// agar tidak dihitung sebagai ketidakhadiran.
  int get absentDays {
    final absent =
        workingDays - presentDays - (leaveDays ?? 0) - (permissionDays ?? 0);
    return absent < 0 ? 0 : absent;
  }

  /// Bangun dari JSON backend (/api/mobile/staff/:id/gaji/slip).
  /// Backend `SlipGaji` tidak menyimpan rincian kehadiran, jadi statistik
  /// (hari kerja/hadir/cuti/izin + riwayat) dihitung server dari tabel
  /// Attendance & LeaveRequest lalu disertakan di respons.
  factory SalarySlip.fromApi(Map<String, dynamic> j) {
    int gi(String k) => (j[k] as num?)?.toInt() ?? 0;

    List<LeaveRecord> parseHistory(String key) {
      final raw = j[key];
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((m) {
        final map = m.map((k, v) => MapEntry(k.toString(), v));
        DateTime parseDate(String k) =>
            DateTime.tryParse((map[k] ?? '').toString()) ?? DateTime.now();
        return LeaveRecord(
          reason: (map['reason'] ?? '').toString(),
          startDate: parseDate('startDate'),
          endDate: parseDate('endDate'),
          totalDays: (map['totalDays'] as num?)?.toInt() ?? 1,
          status: (map['status'] ?? 'Disetujui').toString(),
        );
      }).toList();
    }

    final periodeRaw = (j['periode'] ?? '').toString(); // "2026-01"
    final parts = periodeRaw.split('-');
    final now = DateTime.now();
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) ?? now.year : now.year;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    const monthNames = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final periodLabel =
        (month >= 1 && month <= 12) ? '${monthNames[month]} $year' : periodeRaw;

    final components = <SalaryComponent>[];
    void add(SalaryGroup group, String label, String note, int amount,
        {bool excludedFromThp = false}) {
      if (amount != 0) {
        components.add(SalaryComponent(
          label: label,
          note: note,
          amount: amount,
          group: group,
          excludedFromThp: excludedFromThp,
        ));
      }
    }

    // ── Pendapatan pokok ──────────────────────────────────────
    add(SalaryGroup.pendapatanPokok, 'Gaji Pokok', '', gi('gajiPokok'));
    add(SalaryGroup.pendapatanPokok, 'Bonus Tepat Waktu',
        'Per hari check-in tepat waktu', gi('bonusTepat'));
    add(SalaryGroup.pendapatanPokok, 'Bonus Kehadiran',
        'Hadir penuh (hari izin tidak membatalkan)', gi('bonusKehadiran'));
    add(SalaryGroup.pendapatanPokok, 'Lembur', '${gi('lemburJam')} jam',
        gi('lemburTotal'));
    add(SalaryGroup.pendapatanPokok, 'THR', '', gi('thrAmount'));

    // ── Tunjangan (dinamis dari DB) ───────────────────────────
    //
    // Fase 8: dibaca dari `tunjanganBreakdown`/`fasilitasBreakdown` —
    // sebelumnya app membaca 4 kolom lama (tunjanganTransport/Makan/
    // Kesehatan/Tambahan) yang backend sudah tandai DEPRECATED dan selalu
    // isi 0, jadi bagian tunjangan di slip praktis selalu kosong meskipun
    // staff punya tunjangan.
    // Sprint 2 EPIC 9b: setiap item punya `bentuk` ("uang" | "barang") —
    // field ini sudah lama dikirim backend tapi tidak pernah dibaca app.
    // Tunjangan `barang` tetap kena pajak dan tetap ditampilkan, TAPI tidak
    // pernah ikut ke `gajiNetto`/THP karena tidak pernah dicairkan tunai.
    final tunjanganRaw = j['tunjanganBreakdown'];
    if (tunjanganRaw is List) {
      for (final item in tunjanganRaw.whereType<Map>()) {
        final nama = (item['nama'] ?? 'Tunjangan').toString();
        final jumlah = (item['jumlah'] as num?)?.toInt() ?? 0;
        final periode = (item['periode'] ?? '').toString();
        final bentuk = (item['bentuk'] ?? 'uang').toString();
        final isBarang = bentuk == 'barang';
        final note = [
          if (periode == 'harian') 'Dibayar per hari hadir',
          if (isBarang) 'Berbentuk barang',
        ].join(', ');
        add(SalaryGroup.tunjangan, nama, note, jumlah,
            excludedFromThp: isBarang);
      }
    }

    // Fasilitas (natura) — hanya kelebihan di atas batas per kategori yang
    // kena pajak (PP 55/2022 + PMK 66/2023), dan nominalnya TIDAK PERNAH
    // masuk ke `gajiNetto`/THP.
    final fasilitasRaw = j['fasilitasBreakdown'];
    if (fasilitasRaw is List) {
      for (final item in fasilitasRaw.whereType<Map>()) {
        final kategori = (item['kategori'] ?? 'Fasilitas').toString();
        final nominal = (item['nominal'] as num?)?.toInt() ?? 0;
        add(SalaryGroup.tunjangan, kategori, 'Fasilitas (natura)', nominal,
            excludedFromThp: true);
      }
    }

    // Uang makan — dijumlahkan server dari Attendance.uangMakan per hari.
    // Sejak 2026-08-03 backend sudah me-wire angka ini ke `gajiNetto`
    // (PMK 66/2023: tunjangan berbentuk uang adalah objek PPh21, kena pajak
    // dan ikut Take Home Pay, sama seperti Tunjangan tunai lainnya) — jadi
    // TIDAK ditandai excludedFromThp lagi.
    add(SalaryGroup.tunjangan, 'Uang Makan',
        '${gi('uangMakanDays')} hari memenuhi syarat', gi('uangMakan'));

    // ── Pajak & potongan ──────────────────────────────────────
    add(SalaryGroup.pajak, 'PPh 21', 'Pajak penghasilan', gi('pajakPPh21'));
    add(SalaryGroup.potongan, 'Denda Keterlambatan', '', gi('dendaTerlambat'));
    add(SalaryGroup.potongan, 'Potongan Alpha', '', gi('potonganAlpha'));
    // Sprint 2 EPIC 9c: `potonganBPJS` sekarang BISA nonzero (BPJS skema split
    // — sebagian ditanggung perusahaan, sebagian dipotong dari gaji staff).
    // Dulu selalu 0 sehingga baris ini praktis tidak pernah tampil.
    add(SalaryGroup.potongan, 'Potongan BPJS',
        'BPJS bagian staff (dipotong dari gaji)', gi('potonganBPJS'));

    final bank = AppSession.staff?.namaBank ?? '';

    return SalarySlip(
      period: periodLabel,
      periodStart: start,
      periodEnd: end,
      transferBy: bank.isNotEmpty ? '$bank Transfer' : 'Bank Transfer',
      components: components,
      workingDays: gi('workingDays'),
      presentDays: gi('presentDays'),
      lateDays: gi('lateDays'),
      overtimeHours: gi('overtimeHours') != 0 ? gi('overtimeHours') : gi('lemburJam'),
      leaveDays: gi('leaveDays'),
      permissionDays: gi('permissionDays'),
      leaveHistory: parseHistory('leaveHistory'),
      permissionHistory: parseHistory('permissionHistory'),
      gajiNetto: gi('gajiNetto'),
      totalTunjanganUang: gi('totalTunjanganUang'),
    );
  }

  int _sum(SalaryGroup group) => components
      .where((c) => c.group == group)
      .fold(0, (sum, c) => sum + c.amount);

  /// Pendapatan pokok: gaji pokok + bonus + lembur + THR.
  int get pendapatanPokok => _sum(SalaryGroup.pendapatanPokok);

  /// Total tunjangan YANG DITAMPILKAN di rincian (termasuk tunjangan barang,
  /// fasilitas & uang makan). Ini angka TAMPILAN — bukan angka yang menambah
  /// Take Home Pay. Yang menambah THP hanya [totalTunjanganUang].
  int get totalTunjangan => _sum(SalaryGroup.tunjangan);

  /// Bagian dari [totalTunjangan] yang TIDAK menambah Take Home Pay
  /// (tunjangan bentuk barang + fasilitas + uang makan).
  int get tunjanganDiluarThp {
    final selisih = totalTunjangan - totalTunjanganUang;
    return selisih < 0 ? 0 : selisih;
  }

  /// PPh 21.
  int get pajak => _sum(SalaryGroup.pajak);

  /// Potongan selain pajak: denda keterlambatan, alpha, BPJS.
  int get totalPotongan => _sum(SalaryGroup.potongan);

  /// GAJI BERSIH = gaji pokok (dan pendapatan pokok lainnya) − PPh 21.
  ///
  /// Fase 8, sesuai aturan yang diminta: "gaji bersih: gaji pokok - pph, dan
  /// lainnya". Tunjangan TIDAK masuk di sini — ia ditampilkan terpisah di
  /// bawah gaji bersih, lalu ikut ke take home pay.
  int get gajiBersih => pendapatanPokok - pajak;

  /// TAKE HOME PAY = `gajiNetto` dari server, BUKAN hitung ulang di client.
  ///
  /// Server sudah menghitung dengan formula resmi (termasuk aturan Fasilitas &
  /// tunjangan-barang yang tidak masuk THP, dan potongan BPJS staff kalau ada)
  /// — app hanya MENAMPILKAN, tidak boleh menduplikasi logika ini. Setiap kali
  /// backend mengubah formula, versi hitung-manual akan salah lagi tanpa ada
  /// yang sadar; membaca `gajiNetto` langsung membuat app otomatis ikut benar.
  ///
  /// Identitas yang berlaku (bisa dipakai sanity-check):
  ///   [pendapatanPokok] − [totalDeduction] + [totalTunjanganUang] == [gajiNetto]
  int get takeHomePay => gajiNetto;

  // ── Kompatibilitas layar lama ────────────────────────────────

  /// Total pendapatan yang benar-benar dibayarkan tunai: pendapatan pokok +
  /// tunjangan bentuk uang saja (tanpa barang/fasilitas/uang makan).
  int get totalIncome => pendapatanPokok + totalTunjanganUang;

  /// Seluruh potongan = PPh 21 + denda + alpha + potongan BPJS. Sama dengan
  /// `slip_gaji.totalPotongan` di server.
  int get totalDeduction => pajak + totalPotongan;

  int get netSalary => gajiNetto;
}

// ── Notification ──────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final bool isTeam;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.isTeam = false,
  });

  /// Bangun dari JSON backend (/api/mobile/staff/:id/notifications).
  /// Backend: `type` (leave_approved|leave_rejected|...), `title`, `body`,
  /// `readAt`, `createdAt`.
  factory AppNotification.fromApi(Map<String, dynamic> j) {
    final type = (j['type'] ?? '').toString();
    NotificationType mapType(String t) {
      if (t.contains('approved')) return NotificationType.approval;
      if (t.contains('rejected')) return NotificationType.rejection;
      if (t.contains('reminder')) return NotificationType.reminder;
      return NotificationType.info;
    }

    return AppNotification(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      message: (j['body'] ?? '').toString(),
      type: mapType(type),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      isRead: j['readAt'] != null,
      isTeam: false,
    );
  }
}

enum NotificationType { approval, rejection, reminder, info }

// ── App State ─────────────────────────────────────────────────
enum AttendanceState {
  notCheckedIn,
  checkedIn,
  onBreak,
  breakEnded,
  checkedOut,
}

// ============================================================
// SAMPLE DATA
// ============================================================

class SampleData {
  static const DivisionModel divMarketing = DivisionModel(
    id: 'D001',
    name: 'Marketing',
  );
  static const DivisionModel divIT = DivisionModel(
    id: 'D002',
    name: 'IT',
  );
  static const DivisionModel divHR = DivisionModel(
    id: 'D003',
    name: 'HR',
  );

  static const PositionModel posSalesExecutive = PositionModel(
    id: 'P001',
    name: 'Sales Executive',
    divisionId: 'D001',
    annualLeaveQuota: 12,
    earlyCheckoutToleranceMinutes: 30,
    minLeaveAdvanceDays: 3,
    payrollPeriodDays: 30,
    operationalHours: 8,
    extraHourAllowance: 3,
    payrollType: PayrollType.monthly,
    payrollEndMonth: true,
    // Value untuk properti baru
    baseSalary: 5000000,
    dailyBonus: 50000,
    healthAllowance: 200000,
    transportAllowance: 500000,
    salaryDisbursementDay: 25,
  );

  static const PositionModel posITSupervisor = PositionModel(
    id: 'P002',
    name: 'IT Supervisor',
    divisionId: 'D002',
    annualLeaveQuota: 15,
    earlyCheckoutToleranceMinutes: 60,
    minLeaveAdvanceDays: 3,
    payrollPeriodDays: 30,
    operationalHours: 8,
    extraHourAllowance: 3,
    payrollType: PayrollType.monthly,
    payrollEndMonth: true,
    // Value untuk properti baru
    baseSalary: 10000000,
    dailyBonus: 75000,
    healthAllowance: 200000,
    transportAllowance: 500000,
    salaryDisbursementDay: 25,
  );
  static const PositionModel posHR = PositionModel(
    id: 'P003',
    name: 'Admin HR',
    divisionId: 'D003',
    annualLeaveQuota: 15,
    earlyCheckoutToleranceMinutes: 60,
    minLeaveAdvanceDays: 3,
    payrollPeriodDays: 30,
    operationalHours: 8,
    extraHourAllowance: 3,
    payrollType: PayrollType.monthly,
    payrollEndMonth: true,
    // Value untuk properti baru
    baseSalary: 10000000,
    dailyBonus: 75000,
    healthAllowance: 200000,
    transportAllowance: 500000,
    salaryDisbursementDay: 25,
  );

  static const ShiftModel morningShift = ShiftModel(
    id: 'SH001',
    name: 'Shift Pagi',
    startTime: TimeOfDay(hour: 8, minute: 0),
    endTime: TimeOfDay(hour: 17, minute: 0),
    breakDurationMinutes: 60,
  );

//   static const UserProfile currentUser = UserProfile(
//     id: 'U001',
//     name: 'Ahmad Rizki',
//     employeeId: 'EMP-2024-001',
//     positionId: 'P001',
//     divisionId: 'D001',
//     email: 'ahmad.rizki@staffsync.id',
//     role: UserRole.staff,
//     currentShift: morningShift,
//     position: posSalesExecutive,
//     points: 420,
//   );

  // ── Demo login users ───────────────────────────────────────
  // User 1 — Supervisor      : phone 081234567890
  // User 2 — Karyawan biasa  : phone 089876543210
  // User 3 — Admin           : phone 08111222333
  static final List<UserProfile> _users = [
    const UserProfile(
      id: 'U001',
      name: 'Rina Kartika',
      username: 'rina',
      password: '123456',
      employeeId: 'EMP-2024-001',
      nik: '3578012505900002',
      positionId: 'P002',
      divisionId: 'D002',
      email: 'rina.kartika@hadirin.id',
      phoneNumber: '081234567890',
      role: UserRole.supervisor,
      currentShift: morningShift,
      position: posITSupervisor,
      points: 420,
      maxOvertimeHours: 4.0,
    ),
    const UserProfile(
      id: 'U002',
      name: 'Ahmad Rizki',
      username: 'ahmad',
      password: '123456',
      employeeId: 'EMP-2024-002',
      nik: '3174081207950003',
      positionId: 'P001',
      divisionId: 'D001',
      email: 'ahmad.rizki@staffsync.id',
      phoneNumber: '089876543210',
      role: UserRole.staff,
      currentShift: morningShift,
      position: posSalesExecutive,
      points: 420,
      maxOvertimeHours: 3.5,
    ),
    const UserProfile(
      id: 'U003',
      name: 'Admin Hadir-In',
      username: 'admin',
      password: '123456',
      employeeId: 'ADM-2024-001',
      nik: '3174081207950005',
      positionId: 'P003',
      divisionId: 'D003',
      email: 'admin@hadirin.id',
      phoneNumber: '08111222333',
      role: UserRole.admin,
      currentShift: morningShift,
      position: posHR,
      points: 1000,
      maxOvertimeHours: 6.0,
    ),
    const UserProfile(
      id: 'U004',
      name: 'Budi Santoso',
      username: 'budi',
      password: '123456',
      employeeId: 'EMP-2024-003',
      nik: '3578012505900010',
      positionId: 'P001',
      divisionId: 'D001',
      email: 'budi.santoso@hadirin.id',
      phoneNumber: '081300400500',
      role: UserRole.staff,
      currentShift: morningShift,
      position: posSalesExecutive,
      points: 280,
      maxOvertimeHours: 2.0,
    ),
    const UserProfile(
      id: 'U005',
      name: 'Dewi Lestari',
      username: 'dewi',
      password: '123456',
      employeeId: 'EMP-2024-004',
      nik: '3174081207950020',
      positionId: 'P001',
      divisionId: 'D001',
      email: 'dewi.lestari@hadirin.id',
      phoneNumber: '082211223344',
      role: UserRole.staff,
      currentShift: morningShift,
      position: posSalesExecutive,
      points: 350,
      maxOvertimeHours: 4.5,
    ),
    const UserProfile(
      id: 'U006',
      name: 'Fajar Nugroho',
      username: 'fajar',
      password: '123456',
      employeeId: 'EMP-2024-005',
      nik: '3578012505900030',
      positionId: 'P002',
      divisionId: 'D002',
      email: 'fajar.nugroho@hadirin.id',
      phoneNumber: '083344556677',
      role: UserRole.staff,
      currentShift: morningShift,
      position: posITSupervisor,
      points: 410,
      maxOvertimeHours: 5.0,
    ),
  ];

  static List<UserProfile> get allUsers => _users;

  /// Active user — set by AppSession
  static UserProfile get currentUser => AppSession.currentUser;

  static final List<AttendanceRecord> recentAttendance = [
    AttendanceRecord(
      id: 'A001',
      date: DateTime.now().subtract(const Duration(days: 1)),
      checkIn: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1, 8, 0),
      checkOut: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1, 19, 30),
      status: AttendanceStatus.present,
      locationLabel:
          'Jl. Sudirman No. 12, Kel. Karet Tengsin, Kec. Tanah Abang',
      useGps: true,
      pointsEarned: 10,
    ),
    AttendanceRecord(
      id: 'A002',
      date: DateTime.now().subtract(const Duration(days: 2)),
      checkIn: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 2, 8, 15),
      checkOut: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 2, 18, 15),
      status: AttendanceStatus.late,
      locationLabel: 'Jl. Gatot Subroto, Kel. Menteng Atas, Kec. Setiabudi',
      useGps: true,
      lateMinutes: 45,
      pointsEarned: 5,
    ),
    AttendanceRecord(
      id: 'A003',
      date: DateTime.now().subtract(const Duration(days: 3)),
      checkIn: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 3, 8, 0),
      checkOut: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 3, 17, 0),
      status: AttendanceStatus.present,
      locationLabel: 'Jl. HR Rasuna Said, Kel. Kuningan Timur, Kec. Setiabudi',
      useGps: false,
      pointsEarned: 15,
    ),
    AttendanceRecord(
      id: 'A004',
      date: DateTime.now().subtract(const Duration(days: 4)),
      status: AttendanceStatus.leave,
      pointsEarned: 0,
    ),
    AttendanceRecord(
      id: 'A005',
      date: DateTime.now().subtract(const Duration(days: 5)),
      checkIn: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 5, 8, 0),
      checkOut: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 5, 20, 0),
      status: AttendanceStatus.present,
      locationLabel: 'Jl. Kuningan, Kel. Guntur, Kec. Setiabudi',
      useGps: true,
      pointsEarned: 10,
    ),
  ];

  static final List<LeaveRequest> leaveRequests = [
    LeaveRequest(
      id: 'L001',
      type: LeaveType.annual,
      startDate: DateTime.now().add(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 9)),
      status: RequestStatus.approved,
      reason: 'Keperluan keluarga',
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      allowances: [],
    ),
    LeaveRequest(
      id: 'L002',
      type: LeaveType.sick,
      startDate: DateTime.now().subtract(const Duration(days: 4)),
      endDate: DateTime.now().subtract(const Duration(days: 4)),
      status: RequestStatus.approved,
      reason: 'Demam',
      submittedAt: DateTime.now().subtract(const Duration(days: 4)),
      allowances: [AllowanceType.health],
    ),
    LeaveRequest(
      id: 'L003',
      type: LeaveType.seminar,
      startDate: DateTime.now().add(const Duration(days: 14)),
      endDate: DateTime.now().add(const Duration(days: 14)),
      status: RequestStatus.pending,
      reason: 'Seminar Digital Marketing Indonesia 2024',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      allowances: [AllowanceType.accommodation, AllowanceType.transport],
    ),
  ];

  static final List<LeaveRequest> subordinateLeaveRequests = [
    LeaveRequest(
      id: 'L001',
      employeeName: 'Ahmad Rizki',
      type: LeaveType.annual,
      startDate: DateTime.now().add(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 9)),
      status: RequestStatus.pending,
      reason: 'Keperluan keluarga',
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      allowances: [],
    ),
    LeaveRequest(
      id: 'L002',
      employeeName: 'Budi Santoso',
      type: LeaveType.sick,
      startDate: DateTime.now().subtract(const Duration(days: 4)),
      endDate: DateTime.now().subtract(const Duration(days: 4)),
      status: RequestStatus.pending,
      reason: 'Demam',
      submittedAt: DateTime.now().subtract(const Duration(days: 4)),
      allowances: [AllowanceType.health],
    ),
    LeaveRequest(
      id: 'L003',
      employeeName: 'Dewi Lestari',
      type: LeaveType.seminar,
      startDate: DateTime.now().add(const Duration(days: 14)),
      endDate: DateTime.now().add(const Duration(days: 14)),
      status: RequestStatus.pending,
      reason: 'Seminar Digital Marketing Indonesia 2024',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      allowances: [AllowanceType.accommodation, AllowanceType.transport],
    ),
  ];

  /// Fase 8: daftar slip gaji contoh DIHAPUS. Slip gaji sekarang selalu
  /// datang dari backend (`GET /mobile/staff/:id/gaji/slip`, lihat
  /// `SalaryService`) — tidak ada satu pun layar yang membaca daftar ini,
  /// dan membiarkannya hanya mengundang layar baru memakai angka karangan.
  static final List<SalarySlip> salaryHistory = <SalarySlip>[];

  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'N001',
      title: 'Pengajuan Izin Disetujui',
      message: 'Pengajuan izin sakit Anda tanggal 12 Jan telah disetujui.',
      type: NotificationType.approval,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 'N002',
      title: 'Seminar Menunggu Verifikasi',
      message:
          'Pengajuan seminar tanggal 14 Feb masih menunggu persetujuan admin.',
      type: NotificationType.info,
      createdAt: DateTime.now().subtract(const Duration(hours: 10)),
    ),
    AppNotification(
      id: 'N003',
      title: 'Pengingat Check-out',
      message: 'Jangan lupa check-out sebelum meninggalkan kantor.',
      type: NotificationType.reminder,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  static final List<LeaveRequest> employeeApplications = [
    LeaveRequest(
      id: 'L004',
      type: LeaveType.annual,
      startDate: DateTime.now().add(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 12)),
      status: RequestStatus.pending,
      reason: 'Acara pernikahan keluarga',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      allowances: [],
    ),
    LeaveRequest(
      id: 'L005',
      type: LeaveType.sick,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().subtract(const Duration(days: 1)),
      status: RequestStatus.pending,
      reason: 'Sakit tifus',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      allowances: [AllowanceType.health],
    ),
  ];

  static const List<String> motivationalMessages = [
    "Selamat datang! Hari yang produktif menanti. 🌟",
    "Semangat! Kamu bisa melewati hari ini dengan luar biasa! 💪",
    "Setiap langkah kecil membawa perubahan besar. Ayo mulai! 🚀",
    "Kamu adalah bintang tim kami. Tetap bersinar! ⭐",
    "Hari baru, peluang baru. Let's make it count! 🎯",
  ];

  static const List<String> breakMessages = [
    "Let's get some rest now! Kamu sudah bekerja keras. 🌿",
    "Waktu istirahat adalah investasi produktivitas. Nikmati! ☕",
    "Recharge your energy — kamu butuh ini! 🔋",
  ];

  static const List<String> checkoutMessages = [
    "Thank you for today! Kamu luar biasa. 🙌",
    "Kerja keras hari ini sudah tercatat. Sampai besok! 🌙",
    "Great job! Istirahat yang baik ya malam ini. ⭐",
  ];
}

// ============================================================
// STAFF PROFILE (data asli dari backend /api/mobile/staff/:id/profile)
// ============================================================
/// Representasi profil staff dari backend. Menyimpan field mentah + relasi
/// (divisi, jabatan, shift, lokasi) dan dapat dipetakan ke [UserProfile]
/// lewat [toUserProfile] agar kompatibel dengan layar yang sudah ada.
class StaffProfile {
  final String id;
  final String nama;
  final String email;
  final String phone;
  final String level;
  final String statusKepegawaian;
  final String status;
  final int sisaCuti;
  final int totalCuti;
  final String photo;
  final String namaBank;
  final String nomorRekening;
  final String namaPemilikRekening;

  // Relasi (nama-nama siap tampil)
  final String divisiNama;
  final String divisiColor;
  final String jabatanNama;
  final bool jabatanIsSupervisor;
  final int gajiPokok;
  final int maxExtraHour;
  final String shiftNama;
  final String jamMasuk; // "08:00"
  final String jamPulang; // "17:00"
  final String lokasiNama;
  final String lokasiAlamat;
  // Fase 8: titik & radius geofence lokasi kerja, dipakai layar absensi untuk
  // memberi tahu staff apakah ia sudah berada di area kantor. Null = staff
  // belum ditempatkan pada Lokasi mana pun (server pun melewati pengecekan).
  final double? lokasiLatitude;
  final double? lokasiLongitude;
  final int lokasiRadius;

  // Sprint 2 OTP/auth overhaul: nomor kontak admin office (staff tidak lagi
  // bisa ganti nomor HP sendiri — arahkan ke admin lewat nomor ini). Kosong
  // bila HRD belum mengisinya di Portal Office.
  final String kontakAdminPhone;

  const StaffProfile({
    required this.id,
    required this.nama,
    required this.email,
    required this.phone,
    required this.level,
    required this.statusKepegawaian,
    required this.status,
    required this.sisaCuti,
    required this.totalCuti,
    required this.photo,
    required this.namaBank,
    required this.nomorRekening,
    required this.namaPemilikRekening,
    required this.divisiNama,
    required this.divisiColor,
    required this.jabatanNama,
    required this.jabatanIsSupervisor,
    required this.gajiPokok,
    required this.maxExtraHour,
    required this.shiftNama,
    required this.jamMasuk,
    required this.jamPulang,
    required this.lokasiNama,
    required this.lokasiAlamat,
    this.lokasiLatitude,
    this.lokasiLongitude,
    this.lokasiRadius = 100,
    this.kontakAdminPhone = '',
  });

  factory StaffProfile.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> rel(String key) =>
        j[key] is Map ? Map<String, dynamic>.from(j[key] as Map) : const {};
    final divisi = rel('divisi');
    final jabatan = rel('jabatan');
    final shift = rel('shift');
    final lokasi = rel('lokasi');
    final office = rel('office');
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return StaffProfile(
      id: (j['id'] ?? '').toString(),
      nama: (j['nama'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      level: (j['level'] ?? '').toString(),
      statusKepegawaian: (j['statusKepegawaian'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      sisaCuti: asInt(j['sisaCuti']),
      totalCuti: asInt(j['totalCuti']),
      photo: (j['photo'] ?? '').toString(),
      namaBank: (j['namaBank'] ?? '').toString(),
      nomorRekening: (j['nomorRekening'] ?? '').toString(),
      namaPemilikRekening: (j['namaPemilikRekening'] ?? '').toString(),
      divisiNama: (divisi['nama'] ?? '-').toString(),
      divisiColor: (divisi['color'] ?? '#3b82f6').toString(),
      jabatanNama: (jabatan['nama'] ?? '-').toString(),
      jabatanIsSupervisor: jabatan['isSupervisor'] == true,
      gajiPokok: asInt(jabatan['gajiPokok']),
      maxExtraHour: asInt(jabatan['maxExtraHour']),
      shiftNama: (shift['nama'] ?? '-').toString(),
      jamMasuk: (shift['jamMasuk'] ?? '08:00').toString(),
      jamPulang: (shift['jamPulang'] ?? '17:00').toString(),
      lokasiNama: (lokasi['nama'] ?? '-').toString(),
      lokasiAlamat: (lokasi['alamat'] ?? '-').toString(),
      lokasiLatitude: (lokasi['latitude'] as num?)?.toDouble(),
      lokasiLongitude: (lokasi['longitude'] as num?)?.toDouble(),
      lokasiRadius: asInt(lokasi['radius']) == 0 ? 100 : asInt(lokasi['radius']),
      kontakAdminPhone: (office['kontakAdminPhone'] ?? '').toString(),
    );
  }

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Petakan ke [UserProfile] lama agar layar existing tetap berfungsi.
  UserProfile toUserProfile() {
    final pos = PositionModel(
      id: '',
      name: jabatanNama,
      divisionId: divisiNama,
      annualLeaveQuota: totalCuti,
      earlyCheckoutToleranceMinutes: 30,
      minLeaveAdvanceDays: 3,
      payrollPeriodDays: 30,
      operationalHours: 8,
      extraHourAllowance: maxExtraHour,
      payrollType: PayrollType.monthly,
      payrollEndMonth: true,
      baseSalary: gajiPokok,
      dailyBonus: 0,
      healthAllowance: 0,
      transportAllowance: 0,
      salaryDisbursementDay: 25,
    );
    final shift = ShiftModel(
      id: '',
      name: shiftNama,
      startTime: _parseTime(jamMasuk),
      endTime: _parseTime(jamPulang),
    );
    return UserProfile(
      id: id,
      name: nama,
      username: email,
      password: '',
      employeeId: id,
      nik: '-',
      positionId: '',
      divisionId: divisiNama,
      email: email,
      phoneNumber: phone,
      role: jabatanIsSupervisor ? UserRole.supervisor : UserRole.staff,
      currentShift: shift,
      position: pos,
      points: 0,
      maxOvertimeHours: maxExtraHour.toDouble(),
    );
  }
}

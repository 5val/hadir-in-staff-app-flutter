// ============================================================
// STAFFSYNC MODELS
// ============================================================

import 'package:flutter/material.dart';

class AppSession {
  static UserProfile? _currentUser;

  static UserProfile get currentUser =>
      _currentUser ?? SampleData._users.first;

  static bool get isSupervisor =>
      currentUser.role == UserRole.supervisor;

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

  static void clearUser() => _currentUser = null;

  static void updateEmail(String newEmail) {
    final current = currentUser;
    final updated = current.copyWith(email: newEmail);
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
          final suffixInput = normalizedInput.substring(normalizedInput.length - 9);
          final suffixUser = normalizedUser.substring(normalizedUser.length - 9);
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

  const ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakDurationMinutes = 60,
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
  final String nik;          // ← Nomor Induk Karyawan, dipakai di slip PDF
  final String positionId;
  final String divisionId;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final ShiftModel currentShift;
  final PositionModel position;
  final int points;

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
  });

  UserProfile copyWith({int? points, String? email}) =>
      UserProfile(
        id: id, name: name, username: username, password: password,
        employeeId: employeeId, nik: nik,
        positionId: positionId, divisionId: divisionId,
        email: email ?? this.email, phoneNumber: phoneNumber, role: role, currentShift: currentShift,
        position: position, points: points ?? this.points,
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
  });

  Duration? get workDuration {
    if (checkIn == null || checkOut == null) return null;
    final raw = checkOut!.difference(checkIn!);
    final breakDur = (breakStart != null && breakEnd != null)
        ? breakEnd!.difference(breakStart!)
        : Duration.zero;
    return raw - breakDur;
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
}

enum LeaveType { annual, sick, seminar, school }
enum RequestStatus { pending, approved, rejected }
enum AllowanceType { health, accommodation, transport, spp }

// ── Salary Slip ───────────────────────────────────────────────
class SalaryComponent {
  final String label;
  final String note;
  final int amount;
  final bool isDeduction;

  const SalaryComponent({
    required this.label,
    this.note = '',
    required this.amount,
    this.isDeduction = false,
  });
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
  final List<SalaryComponent> components;
  final int workingDays;
  final int presentDays;
  final int lateDays;
  final int overtimeHours;
  final int? leaveDays;
  final int? permissionDays;
  final List<LeaveRecord>? leaveHistory;
  final List<LeaveRecord>? permissionHistory;

  const SalarySlip({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.components,
    required this.workingDays,
    required this.presentDays,
    required this.lateDays,
    required this.overtimeHours,
    required this.leaveDays,
    required this.permissionDays,
    required this.leaveHistory,
    required this.permissionHistory,
  });

  /// Alias agar kompatibel dengan salary_screen yang pakai `slip.workDays`
  int get workDays => workingDays;

  /// Jumlah hari tidak hadir (bukan cuti/sakit yang sudah dihitung)
  int get absentDays => workingDays - presentDays;

  int get totalIncome => components
      .where((c) => !c.isDeduction)
      .fold(0, (sum, c) => sum + c.amount);

  int get totalDeduction => components
      .where((c) => c.isDeduction)
      .fold(0, (sum, c) => sum + c.amount);

  int get netSalary => totalIncome - totalDeduction;
}

// ── Notification ──────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });
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
    id: 'D001', name: 'Marketing',
  );
  static const DivisionModel divIT = DivisionModel(
    id: 'D002', name: 'IT',
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

  // ── Two demo login users ───────────────────────────────────
  // User 1 — Karyawan biasa  : ID EMP001 / username rina   / pass pass123
  // User 2 — Supervisor      : ID SUP001 / username budi   / pass pass123
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
  )
  ];

  static List<UserProfile> get allUsers => _users;

  /// Active user — set by AppSession
  static UserProfile get currentUser => AppSession.currentUser;

  static final List<AttendanceRecord> recentAttendance = [
    AttendanceRecord(
      id: 'A001',
      date: DateTime.now().subtract(const Duration(days: 1)),
      checkIn: DateTime.now().subtract(const Duration(days: 1, hours: 9)),
      checkOut: DateTime.now().subtract(const Duration(days: 1, hours: 0, minutes: 30)),
      status: AttendanceStatus.present,
      locationLabel: 'Jl. Sudirman No. 12, Kel. Karet Tengsin, Kec. Tanah Abang',
      useGps: true,
      pointsEarned: 10,
    ),
    AttendanceRecord(
      id: 'A002',
      date: DateTime.now().subtract(const Duration(days: 2)),
      checkIn: DateTime.now().subtract(const Duration(days: 2, hours: 8, minutes: 15)),
      checkOut: DateTime.now().subtract(const Duration(days: 2, hours: 0)),
      status: AttendanceStatus.late,
      locationLabel: 'Jl. Gatot Subroto, Kel. Menteng Atas, Kec. Setiabudi',
      useGps: true,
      lateMinutes: 45,
      pointsEarned: 5,
    ),
    AttendanceRecord(
      id: 'A003',
      date: DateTime.now().subtract(const Duration(days: 3)),
      checkIn: DateTime.now().subtract(const Duration(days: 3, hours: 9)),
      checkOut: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
      status: AttendanceStatus.present,
      locationLabel: 'Jl. HR Rasuna Said, Kel. Kuningan Timur, Kec. Setiabudi',
      useGps: false,
      overtimeMinutes: 60,
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
      checkIn: DateTime.now().subtract(const Duration(days: 5, hours: 9)),
      checkOut: DateTime.now().subtract(const Duration(days: 5, hours: 0)),
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

  static final List<SalarySlip> salaryHistory = [
    // ── Mei 2024 ──────────────────────────────────────────────
    SalarySlip(
      period: 'Mei 2024',
      periodStart: DateTime(2024, 5, 1),
      periodEnd: DateTime(2024, 5, 31),
      workingDays: 23,
      presentDays: 23,
      lateDays: 0,
      overtimeHours: 2,
      leaveDays: 0,
      permissionDays: 0,
      leaveHistory: [
        LeaveRecord(
          reason: 'Acara Keluarga',
          startDate: DateTime(2024, 5, 10),
          endDate: DateTime(2024, 5, 10),
          totalDays: 1,
          status: 'Ditolak', // Contoh pengajuan cuti yang ditolak
        ),
      ],
      permissionHistory: const [],
      components: const [
        SalaryComponent(label: 'Gaji Pokok', note: 'Jabatan IT Supervisor', amount: 10000000),
        SalaryComponent(label: 'Tunjangan Transport', note: 'Dibayarkan per bulan', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', note: '23 hari × Rp 30.000', amount: 690000),
        SalaryComponent(label: 'Tunjangan Kesehatan', note: 'Dibayarkan per bulan', amount: 200000),
        SalaryComponent(label: 'Bonus Kehadiran Penuh', note: 'Hadir 23/23 hari kerja', amount: 1150000),
        SalaryComponent(label: 'Lembur (2 jam)', note: '2 jam × Rp 75.000', amount: 150000),
        SalaryComponent(label: 'BPJS Kesehatan', note: '1% dari gaji pokok', amount: 100000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', note: '2% dari gaji pokok', amount: 200000, isDeduction: true),
        SalaryComponent(label: 'PPh 21', note: 'Pajak penghasilan bulanan', amount: 350000, isDeduction: true),
      ],
    ),

    // ── April 2024 ────────────────────────────────────────────
    SalarySlip(
      period: 'April 2024',
      periodStart: DateTime(2024, 4, 1),
      periodEnd: DateTime(2024, 4, 30),
      workingDays: 22,
      presentDays: 20, // 2 hari tidak hadir (1 Cuti, 1 Izin)
      lateDays: 2,
      overtimeHours: 0,
      leaveDays: 1,
      permissionDays: 1,
      leaveHistory: [
        LeaveRecord(
          reason: 'Cuti Tahunan',
          startDate: DateTime(2024, 4, 15),
          endDate: DateTime(2024, 4, 15),
          totalDays: 1,
          status: 'Disetujui',
        ),
      ],
      permissionHistory: [
        LeaveRecord(
          reason: 'Sakit (Tanpa Surat Dokter)',
          startDate: DateTime(2024, 4, 22),
          endDate: DateTime(2024, 4, 22),
          totalDays: 1,
          status: 'Disetujui',
        ),
      ],
      components: const [
        SalaryComponent(label: 'Gaji Pokok', note: 'Jabatan IT Supervisor', amount: 10000000),
        SalaryComponent(label: 'Tunjangan Transport', note: 'Dibayarkan per bulan', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', note: '20 hari × Rp 30.000', amount: 600000),
        SalaryComponent(label: 'Tunjangan Kesehatan', note: 'Dibayarkan per bulan', amount: 200000),
        SalaryComponent(label: 'Bonus Kehadiran', note: 'Hadir 20/22 hari (parsial)', amount: 1000000),
        SalaryComponent(label: 'Potongan Keterlambatan', note: '2 hari terlambat × Rp 25.000', amount: 50000, isDeduction: true),
        SalaryComponent(label: 'BPJS Kesehatan', note: '1% dari gaji pokok', amount: 100000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', note: '2% dari gaji pokok', amount: 200000, isDeduction: true),
        SalaryComponent(label: 'PPh 21', note: 'Pajak penghasilan bulanan', amount: 350000, isDeduction: true),
      ],
    ),

    // ── Maret 2024 ────────────────────────────────────────────
    SalarySlip(
      period: 'Maret 2024',
      periodStart: DateTime(2024, 3, 1),
      periodEnd: DateTime(2024, 3, 31),
      workingDays: 21,
      presentDays: 21,
      lateDays: 0,
      overtimeHours: 5,
      leaveDays: 0,
      permissionDays: 0,
      leaveHistory: const [],
      permissionHistory: const [],
      components: const [
        SalaryComponent(label: 'Gaji Pokok', note: 'Jabatan IT Supervisor', amount: 10000000),
        SalaryComponent(label: 'Tunjangan Transport', note: 'Dibayarkan per bulan', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', note: '21 hari × Rp 30.000', amount: 630000),
        SalaryComponent(label: 'Tunjangan Kesehatan', note: 'Dibayarkan per bulan', amount: 200000),
        SalaryComponent(label: 'Bonus Kehadiran Penuh', note: 'Hadir 21/21 hari kerja', amount: 1050000),
        SalaryComponent(label: 'Lembur (5 jam)', note: '5 jam × Rp 75.000', amount: 375000),
        SalaryComponent(label: 'BPJS Kesehatan', note: '1% dari gaji pokok', amount: 100000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', note: '2% dari gaji pokok', amount: 200000, isDeduction: true),
        SalaryComponent(label: 'PPh 21', note: 'Pajak penghasilan bulanan', amount: 350000, isDeduction: true),
      ],
    ),

    // ── Februari 2024 ─────────────────────────────────────────
    SalarySlip(
      period: 'Februari 2024',
      periodStart: DateTime(2024, 2, 1),
      periodEnd: DateTime(2024, 2, 29),
      workingDays: 20,
      presentDays: 19, // 1 hari tidak hadir (Izin)
      lateDays: 1,
      overtimeHours: 3,
      leaveDays: 0,
      permissionDays: 1,
      leaveHistory: const [],
      permissionHistory: [
        LeaveRecord(
          reason: 'Keperluan Mendadak',
          startDate: DateTime(2024, 2, 12),
          endDate: DateTime(2024, 2, 12),
          totalDays: 1,
          status: 'Disetujui',
        ),
      ],
      components: const [
        SalaryComponent(label: 'Gaji Pokok', note: 'Jabatan IT Supervisor', amount: 10000000),
        SalaryComponent(label: 'Tunjangan Transport', note: 'Dibayarkan per bulan', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', note: '19 hari × Rp 30.000', amount: 570000),
        SalaryComponent(label: 'Tunjangan Kesehatan', note: 'Dibayarkan per bulan', amount: 200000),
        SalaryComponent(label: 'Bonus Kehadiran', note: 'Hadir 19/20 hari (parsial)', amount: 950000),
        SalaryComponent(label: 'Lembur (3 jam)', note: '3 jam × Rp 75.000', amount: 225000),
        SalaryComponent(label: 'Potongan Keterlambatan', note: '1 hari terlambat × Rp 25.000', amount: 25000, isDeduction: true),
        SalaryComponent(label: 'BPJS Kesehatan', note: '1% dari gaji pokok', amount: 100000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', note: '2% dari gaji pokok', amount: 200000, isDeduction: true),
        SalaryComponent(label: 'PPh 21', note: 'Pajak penghasilan bulanan', amount: 350000, isDeduction: true),
      ],
    ),

    // ── Januari 2024 ──────────────────────────────────────────
    SalarySlip(
      period: 'Januari 2024',
      periodStart: DateTime(2024, 1, 1),
      periodEnd: DateTime(2024, 1, 31),
      workingDays: 23,
      presentDays: 22, // 1 hari tidak hadir (Cuti)
      lateDays: 1,
      overtimeHours: 4,
      leaveDays: 1,
      permissionDays: 0,
      leaveHistory: [
        LeaveRecord(
          reason: 'Cuti Tahunan',
          startDate: DateTime(2024, 1, 5),
          endDate: DateTime(2024, 1, 5),
          totalDays: 1,
          status: 'Disetujui',
        ),
      ],
      permissionHistory: const [],
      components: const [
        SalaryComponent(label: 'Gaji Pokok', note: 'Jabatan IT Supervisor', amount: 10000000),
        SalaryComponent(label: 'Tunjangan Transport', note: 'Dibayarkan per bulan', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', note: '22 hari × Rp 30.000', amount: 660000),
        SalaryComponent(label: 'Tunjangan Kesehatan', note: 'Dibayarkan per bulan', amount: 200000),
        SalaryComponent(label: 'Bonus Kehadiran', note: 'Hadir 22/23 hari (parsial)', amount: 1100000),
        SalaryComponent(label: 'Lembur (4 jam)', note: '4 jam × Rp 75.000', amount: 300000),
        SalaryComponent(label: 'Potongan Keterlambatan', note: '1 hari terlambat × Rp 25.000', amount: 25000, isDeduction: true),
        SalaryComponent(label: 'BPJS Kesehatan', note: '1% dari gaji pokok', amount: 100000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', note: '2% dari gaji pokok', amount: 200000, isDeduction: true),
        SalaryComponent(label: 'PPh 21', note: 'Pajak penghasilan bulanan', amount: 350000, isDeduction: true),
      ],
    ),

    // ── Desember 2023 ─────────────────────────────────────────
    SalarySlip(
      period: 'Desember 2023',
      periodStart: DateTime(2023, 12, 1),
      periodEnd: DateTime(2023, 12, 31),
      workingDays: 21,
      presentDays: 21, 
      lateDays: 0,
      overtimeHours: 8,
      leaveDays: 2, // Cuti bersama biasanya dihitung hadir, jadi presentDays tetap 21
      permissionDays: 0,
      leaveHistory: [
        LeaveRecord(
          reason: 'Cuti Akhir Tahun',
          startDate: DateTime(2023, 12, 27),
          endDate: DateTime(2023, 12, 28),
          totalDays: 2,
          status: 'Disetujui',
        ),
      ],
      permissionHistory: const [],
      components: const [
        SalaryComponent(label: 'Gaji Pokok', note: 'Jabatan IT Supervisor', amount: 10000000),
        SalaryComponent(label: 'Tunjangan Transport', note: 'Dibayarkan per bulan', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', note: '21 hari × Rp 30.000', amount: 630000),
        SalaryComponent(label: 'Tunjangan Kesehatan', note: 'Dibayarkan per bulan', amount: 200000),
        SalaryComponent(label: 'Bonus Kehadiran Penuh', note: 'Hadir 21/21 hari kerja', amount: 1050000),
        SalaryComponent(label: 'Lembur (8 jam)', note: '8 jam × Rp 75.000', amount: 600000),
        SalaryComponent(label: 'Bonus Akhir Tahun', note: 'THR / Bonus tahunan', amount: 10000000),
        SalaryComponent(label: 'BPJS Kesehatan', note: '1% dari gaji pokok', amount: 100000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', note: '2% dari gaji pokok', amount: 200000, isDeduction: true),
        SalaryComponent(label: 'PPh 21', note: 'Pajak penghasilan bulanan', amount: 1200000, isDeduction: true),
      ],
    ),
  ];

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
      message: 'Pengajuan seminar tanggal 14 Feb masih menunggu persetujuan admin.',
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
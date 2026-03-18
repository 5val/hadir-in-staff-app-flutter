// ============================================================
// STAFFSYNC MODELS
// ============================================================

import 'package:flutter/material.dart';

// ── Position Master ──────────────────────────────────────────
class PositionModel {
  final String id;
  final String name;
  final String divisionId;
  final int annualLeaveQuota;
  final int earlyCheckoutToleranceMinutes; // menit toleransi pulang awal
  final int minLeaveAdvanceDays; // minimal H-berapa pengajuan cuti
  final int payrollPeriodDays; // 7=mingguan, 14=2 minggu, 30=bulanan
  final bool payrollEndMonth; // true=akhir bulan, false=awal bulan (jika bulanan)
  final int operationalHours; // jam operasional normal
  final int extraHourAllowance; // maks jam lembur per hari
  final PayrollType payrollType;

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
  final String employeeId;
  final String positionId;
  final String divisionId;
  final String email;
  final UserRole role;
  final ShiftModel currentShift;
  final PositionModel position;
  final int points;

  const UserProfile({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.positionId,
    required this.divisionId,
    required this.email,
    required this.role,
    required this.currentShift,
    required this.position,
    this.points = 0,
  });

  UserProfile copyWith({int? points}) =>
      UserProfile(
        id: id, name: name, employeeId: employeeId,
        positionId: positionId, divisionId: divisionId,
        email: email, role: role, currentShift: currentShift,
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
  final int amount;
  final bool isDeduction;

  const SalaryComponent({
    required this.label,
    required this.amount,
    this.isDeduction = false,
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

  const SalarySlip({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.components,
    required this.workingDays,
    required this.presentDays,
    required this.lateDays,
    required this.overtimeHours,
  });

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
  );

  static const ShiftModel morningShift = ShiftModel(
    id: 'SH001',
    name: 'Shift Pagi',
    startTime: TimeOfDay(hour: 8, minute: 0),
    endTime: TimeOfDay(hour: 17, minute: 0),
    breakDurationMinutes: 60,
  );

  static const UserProfile currentUser = UserProfile(
    id: 'U001',
    name: 'Ahmad Rizki',
    employeeId: 'EMP-2024-001',
    positionId: 'P001',
    divisionId: 'D001',
    email: 'ahmad.rizki@staffsync.id',
    role: UserRole.staff,
    currentShift: morningShift,
    position: posSalesExecutive,
    points: 420,
  );

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

  static final List<SalarySlip> salaryHistory = [
    SalarySlip(
      period: 'Januari 2024',
      periodStart: DateTime(2024, 1, 1),
      periodEnd: DateTime(2024, 1, 31),
      workingDays: 23,
      presentDays: 22,
      lateDays: 1,
      overtimeHours: 4,
      components: const [
        SalaryComponent(label: 'Gaji Pokok', amount: 5000000),
        SalaryComponent(label: 'Tunjangan Transport', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', amount: 300000),
        SalaryComponent(label: 'Tunjangan Kesehatan', amount: 200000),
        SalaryComponent(label: 'Lembur (4 jam)', amount: 350000),
        SalaryComponent(label: 'Potongan Keterlambatan', amount: 50000, isDeduction: true),
        SalaryComponent(label: 'BPJS Kesehatan', amount: 120000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', amount: 150000, isDeduction: true),
      ],
    ),
    SalarySlip(
      period: 'Desember 2023',
      periodStart: DateTime(2023, 12, 1),
      periodEnd: DateTime(2023, 12, 31),
      workingDays: 21,
      presentDays: 21,
      lateDays: 0,
      overtimeHours: 8,
      components: const [
        SalaryComponent(label: 'Gaji Pokok', amount: 5000000),
        SalaryComponent(label: 'Tunjangan Transport', amount: 500000),
        SalaryComponent(label: 'Tunjangan Makan', amount: 300000),
        SalaryComponent(label: 'Tunjangan Kesehatan', amount: 200000),
        SalaryComponent(label: 'Lembur (8 jam)', amount: 700000),
        SalaryComponent(label: 'Bonus Akhir Tahun', amount: 1000000),
        SalaryComponent(label: 'BPJS Kesehatan', amount: 120000, isDeduction: true),
        SalaryComponent(label: 'BPJS Ketenagakerjaan', amount: 150000, isDeduction: true),
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
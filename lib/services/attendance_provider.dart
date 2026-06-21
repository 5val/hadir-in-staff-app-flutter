import 'package:flutter/material.dart';

/// Status kehadiran karyawan hari ini
enum AttendanceProviderStatus {
  notCheckedIn, // Belum check-in sama sekali
  checkedIn, // Sudah check-in, sedang bekerja
  onBreak, // Sedang istirahat
  breakEnded, // Selesai istirahat, kembali bekerja
  checkedOut, // Sudah check-out, selesai hari ini
}

/// Aturan jam istirahat & checkout — satu sumber kebenaran untuk seluruh app
class AttendanceRules {
  // ── Jam istirahat ───────────────────────────────────────────────
  /// Jam mulai istirahat (12:00)
  static const int breakStartHour = 12;
  static const int breakStartMinute = 0;

  /// Jam selesai istirahat (13:00)
  static const int breakEndHour = 13;
  static const int breakEndMinute = 0;

  // ── Batas checkout ──────────────────────────────────────────────
  /// Check-out hanya tersedia setelah jam ini (12:00 siang)
  static const int checkoutCutoffHour = 24;
  static const int checkoutCutoffMinute = 0;

  // ── Jam pulang normal & toleransi pulang awal ────────────────────
  /// Jam pulang normal (17:00 / jam 5 sore)
  static const int normalCheckoutHour = 24;
  static const int normalCheckoutMinute = 0;

  /// Toleransi pulang awal dalam jam.
  /// Misal: 1 → karyawan boleh pulang mulai jam 16:00 tanpa peringatan.
  /// Set ke 0 untuk menonaktifkan toleransi.
  static const int earlyCheckoutToleranceHours = 1;

  // ── Helper (berbasis DateTime.now()) ────────────────────────────

  /// True jika sekarang tepat dalam rentang 12:00–13:00
  static bool get isBreakTime {
    final now = DateTime.now();
    final start = DateTime(
        now.year, now.month, now.day, breakStartHour, breakStartMinute);
    final end =
        DateTime(now.year, now.month, now.day, breakEndHour, breakEndMinute);
    return now.isAfter(start) && now.isBefore(end);
  }

  static bool get isBeforeBreakTime {
    final now = DateTime.now();
    final start = DateTime(
        now.year, now.month, now.day, breakStartHour, breakStartMinute);
    return now.isBefore(start);
  }

  static bool get isAfterBreakTime {
    final now = DateTime.now();
    final end =
        DateTime(now.year, now.month, now.day, breakEndHour, breakEndMinute);
    return now.isAfter(end);
  }

  /// Jam mulai toleransi pulang awal (normalCheckoutHour - earlyCheckoutToleranceHours)
  static int get earlyCheckoutStartHour =>
      normalCheckoutHour - earlyCheckoutToleranceHours;

  /// True jika sekarang sudah >= jam toleransi pulang awal
  /// (misal toleransi 1 jam → true mulai jam 16:00)
  static bool get isWithinEarlyCheckoutWindow {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, earlyCheckoutStartHour,
        normalCheckoutMinute);
    return now.isAfter(start) || now.isAtSameMomentAs(start);
  }

  /// True jika sekarang sudah >= jam pulang normal (17:00)
  static bool get isAfterNormalCheckout {
    final now = DateTime.now();
    final normal = DateTime(
        now.year, now.month, now.day, normalCheckoutHour, normalCheckoutMinute);
    return now.isAfter(normal) || now.isAtSameMomentAs(normal);
  }

  /// True jika check-out bisa dilakukan tanpa popup peringatan:
  /// sudah >= jam pulang normal ATAU masih dalam toleransi pulang awal.
  static bool get canCheckoutWithoutWarning =>
      isAfterNormalCheckout ||
      (earlyCheckoutToleranceHours > 0 && isWithinEarlyCheckoutWindow);

  /// Tombol istirahat aktif HANYA saat jam 12:00–13:00
  static bool get canStartBreak => isBreakTime;

  /// Check-out tersedia setelah jam 12:00 siang
  static bool get canCheckout {
    final now = DateTime.now();
    final cutoff = DateTime(
        now.year, now.month, now.day, checkoutCutoffHour, checkoutCutoffMinute);
    return now.isAfter(cutoff);
  }

  static String get breakWindowLabel =>
      '${breakStartHour.toString().padLeft(2, '0')}:${breakStartMinute.toString().padLeft(2, '0')}'
      ' – '
      '${breakEndHour.toString().padLeft(2, '0')}:${breakEndMinute.toString().padLeft(2, '0')}';
}

/// Shared state untuk status absensi — dipakai HomeTab dan FAB di MainScreen
class AttendanceProvider extends ChangeNotifier {
  AttendanceProviderStatus _status = AttendanceProviderStatus.notCheckedIn;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  DateTime? _breakStartTime;
  DateTime? _breakEndTime;

  AttendanceProviderStatus get status => _status;
  DateTime? get checkInTime => _checkInTime;
  DateTime? get checkOutTime => _checkOutTime;
  DateTime? get breakStartTime => _breakStartTime;
  DateTime? get breakEndTime => _breakEndTime;

  bool get isNotCheckedIn => _status == AttendanceProviderStatus.notCheckedIn;
  bool get isCheckedIn => _status == AttendanceProviderStatus.checkedIn;
  bool get isOnBreak => _status == AttendanceProviderStatus.onBreak;
  bool get isBreakEnded => _status == AttendanceProviderStatus.breakEnded;
  bool get isCheckedOut => _status == AttendanceProviderStatus.checkedOut;

  /// FAB → alert istirahat (bukan kamera)
  bool get needsBreakAction => _status == AttendanceProviderStatus.onBreak;

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

  void doCheckIn() {
    _status = AttendanceProviderStatus.checkedIn;
    _checkInTime = DateTime.now();
    notifyListeners();
  }

  void doCheckOut() {
    _status = AttendanceProviderStatus.checkedOut;
    _checkOutTime = DateTime.now();
    notifyListeners();
  }

  void startBreak() {
    _status = AttendanceProviderStatus.onBreak;
    _breakStartTime = DateTime.now();
    notifyListeners();
  }

  void endBreak() {
    _status = AttendanceProviderStatus.breakEnded;
    _breakEndTime = DateTime.now();
    notifyListeners();
  }

  void returnToWork() {
    _status = AttendanceProviderStatus.checkedIn;
    notifyListeners();
  }

  void reset() {
    _status = AttendanceProviderStatus.notCheckedIn;
    _checkInTime = null;
    _checkOutTime = null;
    _breakStartTime = null;
    _breakEndTime = null;
    notifyListeners();
  }
}

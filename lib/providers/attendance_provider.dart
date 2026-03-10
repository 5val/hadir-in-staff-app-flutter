import 'package:flutter/material.dart';

class AttendanceData {
  final String time;
  final String address;
  final String date;

  const AttendanceData({
    required this.time,
    required this.address,
    required this.date,
  });
}

class AttendanceProvider extends ChangeNotifier {
  AttendanceData? _attendanceData;

  AttendanceData? get attendanceData => _attendanceData;

  void setAttendance(AttendanceData data) {
    _attendanceData = data;
    notifyListeners();
  }

  void clearAttendance() {
    _attendanceData = null;
    notifyListeners();
  }
}

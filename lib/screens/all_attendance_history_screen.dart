import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class AllAttendanceHistoryScreen extends StatefulWidget {
  const AllAttendanceHistoryScreen({super.key});

  @override
  State<AllAttendanceHistoryScreen> createState() => _AllAttendanceHistoryScreenState();
}

class _AllAttendanceHistoryScreenState extends State<AllAttendanceHistoryScreen> {
  final user = SampleData.currentUser;
  late List<AttendanceRecord> _allAttendanceRecords;

  @override
  void initState() {
    super.initState();
    _generateFullAttendanceHistory();
  }

  void _generateFullAttendanceHistory() {
    final today = DateTime.now();
    final List<AttendanceRecord> generatedRecords = [];

    // Generate records for the last 60 days (or adjust as needed)
    for (int i = 0; i < 60; i++) {
      final date = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final dayOfWeek = date.weekday;

      // Check if it's Saturday or Sunday
      if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
        generatedRecords.add(
          AttendanceRecord(
            id: 'HOLIDAY-${date.toIso8601String()}',
            date: date,
            status: AttendanceStatus.holiday,
            pointsEarned: 0,
          ),
        );
      } else {
        // Try to find an actual record from SampleData
        final existingRecord = SampleData.recentAttendance.firstWhere(
          (record) => record.date.year == date.year &&
                      record.date.month == date.month &&
                      record.date.day == date.day,
          orElse: () => AttendanceRecord( // If not found, assume absent for now
            id: 'ABSENT-${date.toIso8601String()}',
            date: date,
            status: AttendanceStatus.absent,
            pointsEarned: 0,
          ),
        );
        generatedRecords.add(existingRecord);
      }
    }
    _allAttendanceRecords = generatedRecords;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.slate700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Riwayat Kehadiran', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allAttendanceRecords.length,
        itemBuilder: (context, index) {
          final rec = _allAttendanceRecords[index];
          final isHoliday = rec.status == AttendanceStatus.holiday;
          final isLate = !isHoliday && rec.checkIn != null &&
              rec.checkIn!.hour > user.currentShift.startTime.hour;
          final absent = !isHoliday && rec.checkIn == null;

          // Calculate total work duration
          String totalWork = '--:--';
          if (rec.checkIn != null && rec.checkOut != null) {
            final dur = rec.checkOut!.difference(rec.checkIn!);
            totalWork = '${dur.inHours.toString().padLeft(2,'0')}:${(dur.inMinutes % 60).toString().padLeft(2,'0')}';
          }

          Color statusColor;
          Color statusBg;
          String statusLabel;

          if (isHoliday) {
            statusColor = AppColors.brandNavy;
            statusBg = AppColors.brandNavy.withOpacity(0.08);
            statusLabel = 'LIBUR';
          } else if (absent) {
            statusColor = AppColors.danger;
            statusBg = AppColors.danger.withOpacity(0.08);
            statusLabel = 'ABSEN';
          } else if (isLate) {
            statusColor = AppColors.warning;
            statusBg = AppColors.warning.withOpacity(0.08);
            statusLabel = 'TERLAMBAT';
          } else {
            statusColor = AppColors.brandLimeDark;
            statusBg = AppColors.brandLime.withOpacity(0.15);
            statusLabel = 'TEPAT WAKTU';
          }

          // Date formatting
          final day = DateFormat('d', 'id_ID').format(rec.date);
          final dayName = DateFormat('EEE', 'id_ID').format(rec.date).toUpperCase();
          final monthYear = DateFormat('MMM', 'id_ID').format(rec.date);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate100),
              boxShadow: [
                BoxShadow(
                  color: AppColors.slate200.withOpacity(0.5),
                  blurRadius: 4, offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // ── Tanggal kotak ─────────────────────────
                  Container(
                    width: 48, height: 52,
                    decoration: BoxDecoration(
                      color: isHoliday
                          ? AppColors.brandNavy.withOpacity(0.08)
                          : (absent ? AppColors.danger.withOpacity(0.08) : AppColors.brandNavy),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayName,
                            style: GoogleFonts.inter(
                                fontSize: 8, fontWeight: FontWeight.w700,
                                color: isHoliday
                                    ? AppColors.brandNavy.withOpacity(0.6)
                                    : (absent ? AppColors.danger.withOpacity(0.6) : Colors.white.withOpacity(0.7)),
                                letterSpacing: 0.5)),
                        Text(day,
                            style: GoogleFonts.inter(
                                fontSize: 20, fontWeight: FontWeight.w800,
                                color: isHoliday ? AppColors.brandNavy : (absent ? AppColors.danger : Colors.white),
                                height: 1.0)),
                        Text(monthYear,
                            style: GoogleFonts.inter(
                                fontSize: 8,
                                color: isHoliday
                                    ? AppColors.brandNavy.withOpacity(0.5)
                                    : (absent ? AppColors.danger.withOpacity(0.5) : Colors.white.withOpacity(0.55)))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Info waktu ────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isHoliday && !absent) ...[
                          Row(
                            children: [
                              _HistoryTimeCol(
                                label: 'Check In',
                                value: rec.checkIn != null
                                    ? _fmtHM24(rec.checkIn!) : '--:--',
                              ),
                              const SizedBox(width: 14),
                              _HistoryTimeCol(
                                label: 'Check Out',
                                value: rec.checkOut != null
                                    ? _fmtHM24(rec.checkOut!) : '--:--',
                              ),
                              const SizedBox(width: 14),
                              _HistoryTimeCol(
                                label: 'Total Jam',
                                value: totalWork,
                                highlight: true,
                              ),
                            ],
                          ),
                        ] else if (isHoliday) ...[
                          Text('Hari Libur',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppColors.brandNavy)),
                        ] else if (absent) ...[
                          Text('Tidak Hadir',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppColors.danger)),
                        ],
                        const SizedBox(height: 6),
                        // Baris 2: Lokasi
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 11, color: AppColors.slate400),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                isHoliday ? 'Tidak ada aktivitas' : 'Office, West Jakarta, Indonesia',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: AppColors.slate400),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Status badge ──────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusLabel,
                        style: GoogleFonts.inter(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: statusColor, letterSpacing: 0.3)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── History Time Column ───────────────────────────────────────────
  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  Widget _HistoryTimeCol({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: AppColors.slate400, letterSpacing: 0.3)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: highlight ? AppColors.brandNavy : AppColors.slate800)),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class AllAttendanceHistoryScreen extends StatefulWidget {
  const AllAttendanceHistoryScreen({super.key});

  @override
  State<AllAttendanceHistoryScreen> createState() =>
      _AllAttendanceHistoryScreenState();
}

class _AllAttendanceHistoryScreenState
    extends State<AllAttendanceHistoryScreen> {
  final user = SampleData.currentUser;
  late List<AttendanceRecord> _allAttendanceRecords;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateFullAttendanceHistory();
  }

  void _generateFullAttendanceHistory() {
    final List<AttendanceRecord> generatedRecords = [];
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;

    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_selectedDate.year, _selectedDate.month, i);

      if (date.isAfter(DateTime.now())) continue;

      final dayOfWeek = date.weekday;

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
        final existingRecord = SampleData.recentAttendance.firstWhere(
          (record) =>
              record.date.year == date.year &&
              record.date.month == date.month &&
              record.date.day == date.day,
          orElse: () => AttendanceRecord(
            id: 'ABSENT-${date.toIso8601String()}',
            date: date,
            status: AttendanceStatus.absent,
            pointsEarned: 0,
          ),
        );
        generatedRecords.add(existingRecord);
      }
    }
    _allAttendanceRecords = generatedRecords.reversed.toList();
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate =
          DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
      _generateFullAttendanceHistory();
    });
  }

  // ── Fungsi Popup Pemilih Bulan & Tahun ────────────────────────────────
  Future<void> _showMonthYearPicker(BuildContext context) async {
    int tempMonth = _selectedDate.month;
    int tempYear = _selectedDate.year;

    final List<String> monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              surfaceTintColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Pilih Bulan & Tahun',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.slate900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Dropdown Bulan ──
                  DropdownButtonFormField<int>(
                    value: tempMonth,
                    decoration: InputDecoration(
                      labelText: 'Bulan',
                      labelStyle: GoogleFonts.inter(color: AppColors.slate700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.brandNavy),
                      ),
                    ),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          monthNames[index],
                          style: GoogleFonts.inter(color: AppColors.slate800),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => tempMonth = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Dropdown Tahun ──
                  DropdownButtonFormField<int>(
                    value: tempYear,
                    decoration: InputDecoration(
                      labelText: 'Tahun',
                      labelStyle: GoogleFonts.inter(color: AppColors.slate700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.brandNavy),
                      ),
                    ),
                    items: List.generate(5, (index) {
                      // Menampilkan dari tahun sekarang mundur ke 5 tahun ke belakang
                      int year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(
                          year.toString(),
                          style: GoogleFonts.inter(color: AppColors.slate800),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => tempYear = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(
                      color: AppColors.slate700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Tutup popup

                    // Update state utama dan generate ulang data absensi
                    setState(() {
                      _selectedDate = DateTime(tempYear, tempMonth, 1);
                      _generateFullAttendanceHistory();
                    });
                  },
                  child: Text(
                    'Terapkan',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
      body: Column(
        children: [
          // Filter Bulan
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //   color: Colors.white,
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [
          //       IconButton(
          //         icon: const Icon(Icons.chevron_left_rounded),
          //         onPressed: () => _changeMonth(-1),
          //       ),
          //       Text(
          //         DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate),
          //         style: GoogleFonts.inter(
          //           fontSize: 16,
          //           fontWeight: FontWeight.w700,
          //           color: AppColors.brandNavy,
          //         ),
          //       ),
          //       IconButton(
          //         icon: const Icon(Icons.chevron_right_rounded),
          //         onPressed: _selectedDate.month == DateTime.now().month &&
          //                 _selectedDate.year == DateTime.now().year
          //             ? null
          //             : () => _changeMonth(1),
          //       ),
          //     ],
          //   ),
          // ),
          _buildHeaderFilter(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allAttendanceRecords.length,
              itemBuilder: (context, index) {
                final rec = _allAttendanceRecords[index];
                final isHoliday = rec.status == AttendanceStatus.holiday;
                final isLate = !isHoliday &&
                    rec.checkIn != null &&
                    rec.checkIn!.hour > user.currentShift.startTime.hour;
                final absent = !isHoliday && rec.checkIn == null;

                // Calculate total work duration
                String totalWork = '--:--';
                if (rec.checkIn != null && rec.checkOut != null) {
                  final dur = rec.checkOut!.difference(rec.checkIn!);
                  totalWork =
                      '${dur.inHours.toString().padLeft(2, '0')}:${(dur.inMinutes % 60).toString().padLeft(2, '0')}';
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
                final dayName =
                    DateFormat('EEE', 'id_ID').format(rec.date).toUpperCase();
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
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // ── Tanggal kotak ─────────────────────────
                        Container(
                          width: 48,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isHoliday
                                ? AppColors.brandNavy.withOpacity(0.08)
                                : (absent
                                    ? AppColors.danger.withOpacity(0.08)
                                    : AppColors.brandNavy),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(dayName,
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: isHoliday
                                          ? AppColors.brandNavy.withOpacity(0.6)
                                          : (absent
                                              ? AppColors.danger
                                                  .withOpacity(0.6)
                                              : Colors.white.withOpacity(0.7)),
                                      letterSpacing: 0.5)),
                              Text(day,
                                  style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: isHoliday
                                          ? AppColors.brandNavy
                                          : (absent
                                              ? AppColors.danger
                                              : Colors.white),
                                      height: 1.0)),
                              Text(monthYear,
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      color: isHoliday
                                          ? AppColors.brandNavy.withOpacity(0.5)
                                          : (absent
                                              ? AppColors.danger
                                                  .withOpacity(0.5)
                                              : Colors.white
                                                  .withOpacity(0.55)))),
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
                                          ? _fmtHM24(rec.checkIn!)
                                          : '--:--',
                                    ),
                                    const SizedBox(width: 14),
                                    _HistoryTimeCol(
                                      label: 'Check Out',
                                      value: rec.checkOut != null
                                          ? _fmtHM24(rec.checkOut!)
                                          : '--:--',
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandNavy)),
                              ] else if (absent) ...[
                                Text('Tidak Hadir',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
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
                                      isHoliday
                                          ? 'Tidak ada aktivitas'
                                          : 'Office, West Jakarta, Indonesia',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.slate400),
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
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: 0.3)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ), // Expanded
        ], // children
      ),
    );
  }

  // ── History Time Column ───────────────────────────────────────────
  String _fmtHM24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
                letterSpacing: 0.3)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.brandNavy : AppColors.slate800)),
      ],
    );
  }

  // ── Widget Filter yang bisa di-tap ──────────────────────────────────
  Widget _buildHeaderFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showMonthYearPicker(context), // <--- Trigger Popup
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandNavy.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: AppColors.brandNavy, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periode Absensi',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMMM yyyy', 'id_ID')
                              .format(_selectedDate),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

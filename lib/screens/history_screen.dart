import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Filter state
  AttendanceStatus? _filterStatus; // null = semua
  DateTimeRange?    _dateRange;

  List<AttendanceRecord> get _filtered {
    var list = SampleData.recentAttendance;
    if (_filterStatus != null) {
      list = list.where((r) => r.status == _filterStatus).toList();
    }
    if (_dateRange != null) {
      list = list.where((r) =>
          !r.date.isBefore(_dateRange!.start) &&
          !r.date.isAfter(_dateRange!.end)).toList();
    }
    return list;
  }

  String _fmtDate(DateTime dt) {
    const days = ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei',
                    'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]}';
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  String _getStatusEmoji(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:  return '✅';
      case AttendanceStatus.late:     return '⏰';
      case AttendanceStatus.absent:   return '❌';
      case AttendanceStatus.leave:    return '🌴';
      case AttendanceStatus.holiday:  return '🏖️';
    }
  }

  bool get _hasActiveFilter =>
      _filterStatus != null || _dateRange != null;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.brandNavy, surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _resetFilters() {
    setState(() {
      _filterStatus = null;
      _dateRange    = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = _filtered;
    final fmt = DateFormat('dd MMM');

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ATTENDANCE',
                              style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.brandNavy, letterSpacing: 1.2,
                              )),
                          Text('History',
                              style: AppText.headline2
                                  .copyWith(color: AppColors.slate900)),
                        ],
                      ),
                      const Spacer(),
                      // Reset filter button (jika ada filter aktif)
                      if (_hasActiveFilter)
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.danger),
                          label: Text('Reset',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.danger)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Filter row ─────────────────────────
                  Row(
                    children: [
                      // Status filter dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _filterStatus != null
                                ? AppColors.brandNavy.withOpacity(0.07)
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _filterStatus != null
                                  ? AppColors.brandNavy.withOpacity(0.3)
                                  : AppColors.slate200,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AttendanceStatus?>(
                              value: _filterStatus,
                              isDense: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16, color: AppColors.slate600),
                              hint: Text('Semua Status',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.slate600)),
                              items: [
                                _sItem(null, 'Semua Status'),
                                _sItem(AttendanceStatus.present, '✅  Hadir'),
                                _sItem(AttendanceStatus.late, '⏰  Terlambat'),
                                _sItem(AttendanceStatus.absent, '❌  Absen'),
                                _sItem(AttendanceStatus.leave, '🌴  Cuti'),
                                _sItem(AttendanceStatus.holiday, '🏖️  Libur'),
                              ],
                              onChanged: (v) =>
                                  setState(() => _filterStatus = v),
                              selectedItemBuilder: (ctx) => [
                                _sel('Semua Status'),
                                _sel('Hadir'),
                                _sel('Terlambat'),
                                _sel('Absen'),
                                _sel('Cuti'),
                                _sel('Libur'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date range picker button
                      GestureDetector(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _dateRange != null
                                ? AppColors.brandNavy.withOpacity(0.07)
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _dateRange != null
                                  ? AppColors.brandNavy.withOpacity(0.3)
                                  : AppColors.slate200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                                color: _dateRange != null
                                    ? AppColors.brandNavy
                                    : AppColors.slate600,
                              ),
                              if (_dateRange != null) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '${fmt.format(_dateRange!.start)} – '
                                  '${fmt.format(_dateRange!.end)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: AppColors.brandNavy,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 5),
                                Text('Tanggal',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.slate600)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),

            // ── Result count ─────────────────────────────
            if (_hasActiveFilter)
              Container(
                color: AppColors.brandNavy.withOpacity(0.04),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 14, color: AppColors.brandNavy),
                    const SizedBox(width: 6),
                    Text('${records.length} data ditemukan',
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.brandNavy,
                        )),
                  ],
                ),
              ),

            // ── List ────────────────────────────────────
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: AppColors.slate300),
                          const SizedBox(height: 12),
                          Text('Tidak ada data',
                              style: AppText.body2),
                          if (_hasActiveFilter) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _resetFilters,
                              child: const Text('Reset Filter'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = records[i];
                        Color c;
                        String label;
                        switch (r.status) {
                          case AttendanceStatus.present:
                            c = AppColors.brandLimeDark; label = 'Hadir'; break;
                          case AttendanceStatus.late:
                            c = AppColors.warning; label = 'Terlambat'; break;
                          case AttendanceStatus.absent:
                            c = AppColors.danger; label = 'Absen'; break;
                          case AttendanceStatus.leave:
                            c = AppColors.brandNavy; label = 'Cuti'; break;
                          case AttendanceStatus.holiday:
                            c = AppColors.brandCyanDark; label = 'Libur'; break;
                        }
                        return SectionCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: c.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    _getStatusEmoji(r.status),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_fmtDate(r.date),
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.slate900)),
                                    if (r.checkIn != null)
                                      Text(
                                        '${_fmtTime(r.checkIn)} — ${_fmtTime(r.checkOut)}',
                                        style: AppText.body2,
                                      ),
                                    if ((r.lateMinutes ?? 0) > 0)
                                      Text(
                                        'Terlambat ${r.lateMinutes} menit',
                                        style: AppText.caption.copyWith(
                                            color: AppColors.warning),
                                      ),
                                    if ((r.overtimeMinutes ?? 0) > 0)
                                      Text(
                                        'Lembur ${r.overtimeMinutes} menit',
                                        style: AppText.caption.copyWith(
                                            color: AppColors.brandNavy),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusBadge(label: label, color: c),
                                  if (r.pointsEarned > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('+${r.pointsEarned} pts',
                                        style: AppText.caption.copyWith(
                                            color: AppColors.brandNavy)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<AttendanceStatus?> _sItem(
      AttendanceStatus? val, String label) {
    return DropdownMenuItem(
      value: val,
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.slate900)),
    );
  }

  Widget _sel(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t,
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: _filterStatus != null ? AppColors.brandNavy : AppColors.slate700,
        )),
  );
}
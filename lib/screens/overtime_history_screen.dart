import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class OvertimeHistoryScreen extends StatefulWidget {
  const OvertimeHistoryScreen({super.key});

  @override
  State<OvertimeHistoryScreen> createState() => _OvertimeHistoryScreenState();
}

class _OvertimeHistoryScreenState extends State<OvertimeHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  RequestStatus? _status;

  List<AttendanceRecord> get _filtered {
    var list =
        SampleData.recentAttendance.where((r) => r.overtimeApplied).toList();

    // Filter by start date
    if (_startDate != null) {
      list = list.where((r) {
        final recordDateOnly = DateTime(r.date.year, r.date.month, r.date.day);
        final startDateOnly =
            DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        return recordDateOnly.isAfter(startDateOnly) ||
            recordDateOnly.isAtSameMomentAs(startDateOnly);
      }).toList();
    }

    // Filter by end date
    if (_endDate != null) {
      list = list.where((r) {
        final recordDateOnly = DateTime(r.date.year, r.date.month, r.date.day);
        final endDateOnly =
            DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        return recordDateOnly.isBefore(endDateOnly) ||
            recordDateOnly.isAtSameMomentAs(endDateOnly);
      }).toList();
    }

    // Filter by status
    if (_status != null) {
      list = list.where((r) => r.overtimeStatus == _status).toList();
    }

    // Sort by date descending
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.slate900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.slate900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Widget _buildDateInput({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate300),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.slate600),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.slate700,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value == null
                          ? '-'
                          : DateFormat('dd/MM/yyyy').format(value),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value == null
                            ? AppColors.slate400
                            : AppColors.slate800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final tf = DateFormat('HH:mm');
    final filteredRecords = _filtered;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Riwayat Pengajuan Lembur',
          style: AppText.headline3.copyWith(color: AppColors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: Column(
        children: [
          // ── Filter Section ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date range picker row
                Row(
                  children: [
                    _buildDateInput(
                      label: 'Mulai',
                      value: _startDate,
                      onTap: _pickStartDate,
                    ),
                    const SizedBox(width: 8),
                    Text('-',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.slate700)),
                    const SizedBox(width: 8),
                    _buildDateInput(
                      label: 'Selesai',
                      value: _endDate,
                      onTap: _pickEndDate,
                    ),
                    if (_startDate != null || _endDate != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.slate700),
                        onPressed: () => setState(() {
                          _startDate = null;
                          _endDate = null;
                        }),
                        tooltip: 'Reset Tanggal',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Status chips
                Text(
                  'Status Pengajuan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _status == null,
                        onTap: () => setState(() => _status = null),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Menunggu',
                        color: AppColors.brandOrange,
                        selected: _status == RequestStatus.pending,
                        onTap: () =>
                            setState(() => _status = RequestStatus.pending),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Disetujui',
                        color: AppColors.brandLimeDark,
                        selected: _status == RequestStatus.approved,
                        onTap: () =>
                            setState(() => _status = RequestStatus.approved),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Ditolak',
                        color: AppColors.danger,
                        selected: _status == RequestStatus.rejected,
                        onTap: () =>
                            setState(() => _status = RequestStatus.rejected),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.slate200),

          // ── History List ────────────────────────────────────
          Expanded(
            child: filteredRecords.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada riwayat pengajuan',
                            style: AppText.headline3
                                .copyWith(color: AppColors.slate900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coba ubah filter pencarian Anda.',
                            style: AppText.body2
                                .copyWith(color: AppColors.slate600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, i) {
                      final record = filteredRecords[i];
                      final userShift = SampleData.currentUser.currentShift;

                      Color statusColor;
                      String statusLabel;
                      switch (record.overtimeStatus) {
                        case RequestStatus.approved:
                          statusColor = AppColors.brandLimeDark;
                          statusLabel = 'Disetujui';
                          break;
                        case RequestStatus.rejected:
                          statusColor = AppColors.danger;
                          statusLabel = 'Ditolak';
                          break;
                        case RequestStatus.pending:
                        default:
                          statusColor = AppColors.brandOrange;
                          statusLabel = 'Menunggu';
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      df.format(record.date),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.slate800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: statusColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const AppDivider(),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.login_rounded,
                                      size: 16, color: AppColors.slate700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Check-in: ${record.checkIn != null ? tf.format(record.checkIn!) : '-'}',
                                    style: AppText.body2,
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.logout_rounded,
                                      size: 16, color: AppColors.slate700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Check-out: ${tf.format(record.checkOut!)}',
                                    style: AppText.body2,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 16, color: AppColors.slate700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pulang Normal: ${userShift.endTimeStr}',
                                    style: AppText.body2,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.slate50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Detail Pengajuan Lembur:',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.slate700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.slate900,
                                            height: 1.4),
                                        children: [
                                          const TextSpan(
                                              text: 'Durasi: ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          TextSpan(
                                              text:
                                                  '${record.overtimeMinutes != null ? (record.overtimeMinutes! / 60).toStringAsFixed(1) : "0"} jam\n'),
                                          const TextSpan(
                                              text: 'Alasan: ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          TextSpan(
                                              text: '${record.overtimeReason}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Private Filter Chip ───────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    this.color = AppColors.brandNavy,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : AppColors.slate300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13, color: selected ? color : AppColors.slate600),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppColors.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

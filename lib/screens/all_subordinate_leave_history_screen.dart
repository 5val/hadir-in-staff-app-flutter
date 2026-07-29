import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/subordinate_service.dart';

/// Read-only history of all subordinate leave requests — visible to supervisors.
class AllSubordinateLeaveHistoryScreen extends StatefulWidget {
  const AllSubordinateLeaveHistoryScreen({super.key});

  @override
  State<AllSubordinateLeaveHistoryScreen> createState() =>
      _AllSubordinateLeaveHistoryScreenState();
}

class _AllSubordinateLeaveHistoryScreenState
    extends State<AllSubordinateLeaveHistoryScreen> {
  LeaveType?     _filterType;
  RequestStatus? _filterStatus;

  /// Fase 8: riwayat lengkap pengajuan bawahan dari database
  /// (`GET .../subordinates/requests?status=all`) — sebelumnya layar ini
  /// membaca `SampleData.subordinateLeaveRequests` yang isinya dummy.
  List<LeaveRequest> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SubordinateService.load(status: 'all');
      if (!mounted) return;
      setState(() {
        _all = data.leave;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<LeaveRequest> get _filtered {
    var list = List<LeaveRequest>.from(_all);
    if (_filterType   != null) list = list.where((r) => r.type   == _filterType).toList();
    if (_filterStatus != null) list = list.where((r) => r.status == _filterStatus).toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Riwayat Pengajuan Karyawan',
            style: AppText.headline3.copyWith(color: AppColors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: Column(
        children: [
          // ── Filter chips: Jenis ───────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jenis',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _filterType == null,
                        onTap: () => setState(() => _filterType = null),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Cuti',
                        icon: Icons.beach_access_rounded,
                        selected: _filterType == LeaveType.annual,
                        onTap: () => setState(() =>
                            _filterType = _filterType == LeaveType.annual
                                ? null
                                : LeaveType.annual),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Sakit',
                        icon: Icons.local_hospital_rounded,
                        selected: _filterType == LeaveType.sick,
                        onTap: () => setState(() =>
                            _filterType = _filterType == LeaveType.sick
                                ? null
                                : LeaveType.sick),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Seminar',
                        icon: Icons.school_rounded,
                        selected: _filterType == LeaveType.seminar,
                        onTap: () => setState(() =>
                            _filterType = _filterType == LeaveType.seminar
                                ? null
                                : LeaveType.seminar),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Lainnya',
                        icon: Icons.event_note_rounded,
                        selected: _filterType == LeaveType.school,
                        onTap: () => setState(() =>
                            _filterType = _filterType == LeaveType.school
                                ? null
                                : LeaveType.school),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Filter chips: Status ──────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _filterStatus == null,
                        onTap: () =>
                            setState(() => _filterStatus = null),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Menunggu',
                        color: AppColors.brandOrange,
                        selected: _filterStatus == RequestStatus.pending,
                        onTap: () => setState(() =>
                            _filterStatus =
                                _filterStatus == RequestStatus.pending
                                    ? null
                                    : RequestStatus.pending),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Disetujui',
                        color: AppColors.brandLimeDark,
                        selected: _filterStatus == RequestStatus.approved,
                        onTap: () => setState(() =>
                            _filterStatus =
                                _filterStatus == RequestStatus.approved
                                    ? null
                                    : RequestStatus.approved),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Ditolak',
                        color: AppColors.danger,
                        selected: _filterStatus == RequestStatus.rejected,
                        onTap: () => setState(() =>
                            _filterStatus =
                                _filterStatus == RequestStatus.rejected
                                    ? null
                                    : RequestStatus.rejected),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: AppColors.slate200),

          // ── Summary chips ─────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _SummaryChip(
                    label: 'Total',
                    count: _filtered.length,
                    color: AppColors.brandNavy),
                const SizedBox(width: 8),
                _SummaryChip(
                    label: 'Disetujui',
                    count: _filtered
                        .where((r) => r.status == RequestStatus.approved)
                        .length,
                    color: AppColors.brandLimeDark),
                const SizedBox(width: 8),
                _SummaryChip(
                    label: 'Menunggu',
                    count: _filtered
                        .where((r) => r.status == RequestStatus.pending)
                        .length,
                    color: AppColors.brandOrange),
                const SizedBox(width: 8),
                _SummaryChip(
                    label: 'Ditolak',
                    count: _filtered
                        .where((r) => r.status == RequestStatus.rejected)
                        .length,
                    color: AppColors.danger),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 44, color: AppColors.slate400),
                          const SizedBox(height: 10),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: AppText.body2),
                          const SizedBox(height: 14),
                          ElevatedButton(
                              onPressed: _load,
                              child: const Text('Coba Lagi')),
                        ],
                      ),
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📭', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Tidak ada pengajuan',
                            style: AppText.headline3
                                .copyWith(color: AppColors.slate900)),
                        const SizedBox(height: 4),
                        Text('Coba ubah filter pencarian',
                            style: AppText.body2),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _SubordinateRequestCard(request: _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String    label;
  final IconData? icon;
  final Color     color;
  final bool      selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppColors.brandNavy,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.slate100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? color : AppColors.slate600),
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

// ── Summary Chip ──────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

// ── Subordinate Request Card ──────────────────────────────────
class _SubordinateRequestCard extends StatelessWidget {
  final LeaveRequest request;
  const _SubordinateRequestCard({required this.request});

  Color get _statusColor {
    switch (request.status) {
      case RequestStatus.approved: return AppColors.brandLimeDark;
      case RequestStatus.rejected: return AppColors.danger;
      case RequestStatus.pending:  return AppColors.brandOrange;
    }
  }

  String get _statusLabel {
    switch (request.status) {
      case RequestStatus.approved: return 'DISETUJUI';
      case RequestStatus.rejected: return 'DITOLAK';
      case RequestStatus.pending:  return 'MENUNGGU';
    }
  }

  String get _typeLabel {
    switch (request.type) {
      case LeaveType.annual:  return 'Cuti Tahunan';
      case LeaveType.sick:    return 'Izin Sakit';
      case LeaveType.seminar: return 'Izin Seminar';
      case LeaveType.school:  return 'Izin Lainnya';
      default:                return 'Izin Lainnya';
    }
  }

  IconData get _typeIcon {
    switch (request.type) {
      case LeaveType.annual:  return Icons.beach_access_rounded;
      case LeaveType.sick:    return Icons.local_hospital_rounded;
      case LeaveType.seminar: return Icons.school_rounded;
      default:                return Icons.event_note_rounded;
    }
  }

  String get _initials {
    final name = request.employeeName ?? '?';
    return name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();
  }

  @override
  Widget build(BuildContext context) {
    final fDate  = DateFormat('dd MMM yyyy', 'id_ID');
    final fShort = DateFormat('dd MMM',      'id_ID');

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon, color: _statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_typeLabel,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900)),
                      const Spacer(),
                      StatusBadge(label: _statusLabel, color: _statusColor),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (request.employeeName != null)
                    Row(
                      children: [
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.brandNavy.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _initials,
                              style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandNavy),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          request.employeeName!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandNavy),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${fShort.format(request.startDate)} – ${fDate.format(request.endDate)}  ·  ${request.dayCount} hari',
                    style: AppText.body2.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.reason ?? '',
                    style: AppText.body2.copyWith(fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diajukan: ${DateFormat('dd MMM yyyy, HH:mm').format(request.submittedAt)}',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.slate400, size: 16),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final f = DateFormat('dd MMMM yyyy', 'id_ID');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Detail Pengajuan',
                    style: AppText.headline3
                        .copyWith(color: AppColors.slate900)),
                const Spacer(),
                StatusBadge(label: _statusLabel, color: _statusColor),
              ],
            ),
            const SizedBox(height: 16),
            if (request.employeeName != null) ...[
              _Row('Karyawan', request.employeeName!),
              const AppDivider(),
            ],
            _Row('Jenis Pengajuan', _typeLabel),
            const AppDivider(),
            _Row('Tanggal Mulai',   f.format(request.startDate)),
            const AppDivider(),
            _Row('Tanggal Selesai', f.format(request.endDate)),
            const AppDivider(),
            _Row('Durasi', '${request.dayCount} hari'),
            const AppDivider(),
            _Row('Alasan', request.reason ?? '-'),
            const AppDivider(),
            _Row('Diajukan',
                DateFormat('dd MMM yyyy, HH:mm').format(request.submittedAt)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(label, style: AppText.body2)),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900))),
        ],
      ),
    );
  }
}
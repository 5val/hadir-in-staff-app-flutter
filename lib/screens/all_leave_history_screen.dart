import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class AllLeaveHistoryScreen extends StatefulWidget {
  const AllLeaveHistoryScreen({super.key});

  @override
  State<AllLeaveHistoryScreen> createState() => _AllLeaveHistoryScreenState();
}

class _AllLeaveHistoryScreenState extends State<AllLeaveHistoryScreen> {
  LeaveType? _filterType;
  RequestStatus? _filterStatus;

  List<LeaveRequest> get _filtered {
    var list = List<LeaveRequest>.from(SampleData.leaveRequests);
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
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Riwayat Pengajuan', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Type filter
                Expanded(
                  child: DropdownButtonFormField<LeaveType?>(
                    value: _filterType,
                    decoration: const InputDecoration(
                      labelText: 'Jenis',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua Jenis')),
                      DropdownMenuItem(value: LeaveType.annual, child: Text('Cuti')),
                      DropdownMenuItem(value: LeaveType.sick,   child: Text('Sakit')),
                      DropdownMenuItem(value: LeaveType.seminar,child: Text('Seminar')),
                      DropdownMenuItem(value: LeaveType.school, child: Text('Sekolah')),
                    ],
                    onChanged: (v) => setState(() => _filterType = v),
                  ),
                ),
                const SizedBox(width: 10),
                // Status filter
                Expanded(
                  child: DropdownButtonFormField<RequestStatus?>(
                    value: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null,                    child: Text('Semua Status')),
                      DropdownMenuItem(value: RequestStatus.pending,   child: Text('Menunggu')),
                      DropdownMenuItem(value: RequestStatus.approved,  child: Text('Disetujui')),
                      DropdownMenuItem(value: RequestStatus.rejected,  child: Text('Ditolak')),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v),
                  ),
                ),
                if (_filterType != null || _filterStatus != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppColors.danger, size: 20),
                    onPressed: () => setState(() { _filterType = null; _filterStatus = null; }),
                    tooltip: 'Reset filter',
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: AppColors.slate200),

          // Summary chips
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _SummaryChip(label: 'Total', count: _filtered.length, color: AppColors.brandNavy),
                const SizedBox(width: 8),
                _SummaryChip(label: 'Disetujui', count: _filtered.where((r) => r.status == RequestStatus.approved).length, color: AppColors.brandLimeDark),
                const SizedBox(width: 8),
                _SummaryChip(label: 'Menunggu', count: _filtered.where((r) => r.status == RequestStatus.pending).length, color: AppColors.warning),
                const SizedBox(width: 8),
                _SummaryChip(label: 'Ditolak', count: _filtered.where((r) => r.status == RequestStatus.rejected).length, color: AppColors.danger),
              ],
            ),
          ),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📭', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Tidak ada pengajuan', style: AppText.headline3.copyWith(color: AppColors.slate900)),
                        const SizedBox(height: 4),
                        Text('Coba ubah filter pencarian', style: AppText.body2),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _RequestCard(request: _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Chip ──────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label; final int count; final Color color;
  const _SummaryChip({required this.label, required this.count, required this.color});

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
          Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final LeaveRequest request;
  const _RequestCard({required this.request});

  Color get _statusColor {
    switch (request.status) {
      case RequestStatus.approved: return AppColors.brandLimeDark;
      case RequestStatus.rejected: return AppColors.danger;
      case RequestStatus.pending:  return AppColors.warning;
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
      case LeaveType.school:  return 'Izin Sekolah';
      default:                return 'Izin Lainnya';
    }
  }

  IconData get _typeIcon {
    switch (request.type) {
      case LeaveType.annual:  return Icons.beach_access_rounded;
      case LeaveType.sick:    return Icons.local_hospital_rounded;
      case LeaveType.seminar: return Icons.school_rounded;
      case LeaveType.school:  return Icons.menu_book_rounded;
      default:                return Icons.event_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fDate  = DateFormat('dd MMM yyyy', 'id_ID');
    final fShort = DateFormat('dd MMM',      'id_ID');

    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback(() {
          _showDetail(context);
        } as FrameCallback),
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
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.slate900,
                          )),
                      const Spacer(),
                      StatusBadge(label: _statusLabel, color: _statusColor),
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate400, size: 16),
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
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Detail Pengajuan', style: AppText.headline3.copyWith(color: AppColors.slate900)),
                const Spacer(),
                StatusBadge(label: _statusLabel, color: _statusColor),
              ],
            ),
            const SizedBox(height: 16),
            _Row('Jenis Pengajuan', _typeLabel),
            const AppDivider(),
            _Row('Tanggal Mulai', f.format(request.startDate)),
            const AppDivider(),
            _Row('Tanggal Selesai', f.format(request.endDate)),
            const AppDivider(),
            _Row('Durasi', '${request.dayCount} hari'),
            const AppDivider(),
            _Row('Alasan', request.reason ?? "-"),
            const AppDivider(),
            _Row('Diajukan', DateFormat('dd MMM yyyy, HH:mm').format(request.submittedAt)),
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
          SizedBox(width: 120, child: Text(label, style: AppText.body2)),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate900))),
        ],
      ),
    );
  }
}
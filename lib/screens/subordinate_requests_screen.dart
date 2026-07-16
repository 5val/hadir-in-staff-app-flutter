import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'all_subordinate_leave_history_screen.dart';

class SubordinateRequestsScreen extends StatefulWidget {
  const SubordinateRequestsScreen({super.key});

  @override
  State<SubordinateRequestsScreen> createState() =>
      _SubordinateRequestsScreenState();
}

class _SubordinateRequestsScreenState extends State<SubordinateRequestsScreen> {
  void _updateRequestStatus(LeaveRequest app, RequestStatus status) {
    setState(() {
      final idx =
          SampleData.subordinateLeaveRequests.indexWhere((r) => r.id == app.id);
      if (idx != -1) {
        final updated = LeaveRequest(
          id: app.id,
          employeeName: app.employeeName,
          type: app.type,
          startDate: app.startDate,
          endDate: app.endDate,
          status: status,
          reason: app.reason,
          submittedAt: app.submittedAt,
          allowances: app.allowances,
          adminNote: app.adminNote,
          attachmentPaths: app.attachmentPaths,
        );
        SampleData.subordinateLeaveRequests[idx] = updated;
      }
    });
  }

  void _showActionDialog(bool approve, LeaveRequest app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(
          approve ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: approve ? AppColors.brandLimeDark : AppColors.danger,
          size: 40,
        ),
        title: Text(approve ? 'Setujui Pengajuan?' : 'Tolak Pengajuan?'),
        content: Text(
          '${approve ? "Setujui" : "Tolak"} pengajuan dari ${app.employeeName}?',
          style: AppText.body2,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  approve ? AppColors.brandLimeDark : AppColors.danger,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateRequestStatus(
                  app, approve ? RequestStatus.approved : RequestStatus.rejected);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approve
                        ? 'Pengajuan berhasil disetujui'
                        : 'Pengajuan berhasil ditolak',
                  ),
                  backgroundColor: AppColors.brandNavy,
                ),
              );
            },
            child: Text(approve ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
  }

  String _allowanceLabel(AllowanceType a) {
    switch (a) {
      case AllowanceType.health:        return 'Surat Dokter';
      case AllowanceType.accommodation: return 'Resep';
      case AllowanceType.transport:     return 'Nota Transportasi';
      case AllowanceType.spp:           return 'Konsumsi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = SampleData.subordinateLeaveRequests
        .where((r) => r.status == RequestStatus.pending)
        .toList();

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
          'Pengajuan Karyawan',
          style: AppText.headline3.copyWith(color: AppColors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.white),
            tooltip: 'Riwayat Pengajuan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AllSubordinateLeaveHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: apps.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada pengajuan masuk',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Semua pengajuan tim telah diproses.',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: apps.length,
              itemBuilder: (ctx, i) {
                final app = apps[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionCard(
                    padding: EdgeInsets.zero,
                    child: _EmployeeAppTile(
                      app: app,
                      onApprove: () => _showActionDialog(true, app),
                      onReject: () => _showActionDialog(false, app),
                      allowanceLabel: _allowanceLabel,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmployeeAppTile extends StatelessWidget {
  final LeaveRequest app;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String Function(AllowanceType) allowanceLabel;

  const _EmployeeAppTile({
    required this.app,
    required this.onApprove,
    required this.onReject,
    required this.allowanceLabel,
  });

  String get _initials =>
      app.employeeName!.split(' ').map((w) => w[0]).take(2).join();

  String get _typeLabel {
    switch (app.type) {
      case LeaveType.annual:  return 'Cuti Tahunan';
      case LeaveType.sick:    return 'Izin Sakit';
      case LeaveType.seminar: return 'Izin Seminar';
      case LeaveType.school:  return 'Izin Lainnya';
      default:                return 'Izin Lainnya';
    }
  }

  IconData get _typeIcon {
    switch (app.type) {
      case LeaveType.annual:  return Icons.beach_access_rounded;
      case LeaveType.sick:    return Icons.local_hospital_rounded;
      case LeaveType.seminar: return Icons.school_rounded;
      default:                return Icons.event_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM yyyy', 'id_ID');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                app.employeeName ?? '',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(_typeIcon,
                      size: 11, color: AppColors.brandNavyLight),
                  const SizedBox(width: 4),
                  Text(
                    _typeLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandNavyLight),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    size: 14, color: AppColors.slate700),
                const SizedBox(width: 6),
                Text(
                  '${f.format(app.startDate)} – ${f.format(app.endDate)}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${app.dayCount} hari',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandNavy),
                  ),
                ),
              ],
            ),
          ),

          if (app.reason != null && app.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 13, color: AppColors.slate400),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    app.reason!,
                    style: AppText.body2.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (app.allowances.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: app.allowances.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandCyanDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.brandCyanDark.withOpacity(0.2)),
                  ),
                  child: Text(
                    allowanceLabel(a),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandCyanDark),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showDetail(context),
                icon: const Icon(Icons.info_outline_rounded, size: 14),
                label: const Text('Detail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandNavy,
                  side: const BorderSide(color: AppColors.brandNavy, width: 1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              _ActionBtn(
                label: 'Tolak',
                color: AppColors.danger,
                onTap: onReject,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                label: 'Setujui',
                color: AppColors.brandLimeDark,
                onTap: onApprove,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final f = DateFormat('dd MMMM yyyy', 'id_ID');
    final ft = DateFormat('dd MMM yyyy, HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.brandNavy, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Detail Pengajuan',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _DetailRow(label: 'Karyawan', value: app.employeeName ?? ''),
            const AppDivider(),
            _DetailRow(label: 'Jenis Izin/Cuti', value: _typeLabel),
            const AppDivider(),
            _DetailRow(
              label: 'Durasi',
              value: '${f.format(app.startDate)} s/d ${f.format(app.endDate)} (${app.dayCount} hari)',
            ),
            const AppDivider(),
            _DetailRow(
              label: 'Alasan',
              value: app.reason ?? '-',
              isMultiLine: true,
            ),
            const AppDivider(),
            _DetailRow(
              label: 'Diajukan Pada',
              value: ft.format(app.submittedAt),
            ),

            if (app.allowances.isNotEmpty) ...[
              const AppDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dokumen yang Dilampirkan',
                        style: AppText.caption),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: app.allowances.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brandCyanDark.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.brandCyanDark.withOpacity(0.2)),
                          ),
                          child: Text(
                            allowanceLabel(a),
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandCyanDark),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool isMultiLine;
  const _DetailRow(
      {required this.label, required this.value, this.isMultiLine = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
            // isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // Spacer(),
          SizedBox(
            width: 100,
            child: Text(label, style: AppText.caption),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

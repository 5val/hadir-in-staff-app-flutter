import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'login_screen.dart';
import 'all_leave_history_screen.dart';

/// Leave & Time Off tab — tampil langsung di MainScreen.
/// Re-verifikasi sekali per sesi. Setelah verified:
///   - Supervisor: dropdown "Employee Applications" di atas
///   - Dropdown Cuti & dropdown Izin (accordion/expandable)
///   - History pengajuan 7 hari terakhir
class LeaveTab extends StatefulWidget {
  const LeaveTab({super.key});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
  bool _isVerified  = false;
  bool _isVerifying = false;

  // Accordion states
  bool _cutiExpanded = false;
  bool _izinExpanded = false;
  bool _empExpanded  = false; // supervisor only

  final bool _isSupervisor =
      SampleData.currentUser.role == UserRole.supervisor;

  // ── Re-verification ─────────────────────────────────────
  Future<void> _doVerify() async {
    setState(() => _isVerifying = true);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(destination: LoginDestination.leaveRequest),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      if (result == true) _isVerified = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isVerified ? _buildContent() : _buildVerifyGate(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEAVE & TIME OFF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                    letterSpacing: 1.2,
                  )),
              Text('Cuti & Izin',
                  style: AppText.headline2
                      .copyWith(color: AppColors.slate900)),
            ],
          ),
          const Spacer(),
          if (_isVerified)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.brandLime.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 12, color: AppColors.brandLimeDark),
                  const SizedBox(width: 4),
                  Text('Terverifikasi',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandLimeDark,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Verify Gate ──────────────────────────────────────────
  Widget _buildVerifyGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandNavy.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.brandNavy, size: 38),
            ),
            const SizedBox(height: 20),
            Text('Verifikasi Diperlukan',
                style:
                    AppText.headline2.copyWith(color: AppColors.slate900),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Untuk keamanan, masukkan kembali kredensial kamu sebelum mengakses Cuti & Izin.',
              style: AppText.body2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Verifikasi Sekarang',
              color: AppColors.brandNavy,
              icon: Icons.verified_user_rounded,
              isLoading: _isVerifying,
              height: 52,
              onTap: _isVerifying ? null : _doVerify,
            ),
          ],
        ),
      ),
    );
  }

  // ── Content (after verified) ─────────────────────────────
  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Supervisor: Employee Applications accordion
        if (_isSupervisor) ...[
          _buildSupervisorAccordion(),
          const SizedBox(height: 12),
        ],

        // Cuti accordion
        _buildAccordion(
          expanded: _cutiExpanded,
          onToggle: () => setState(() {
            _cutiExpanded = !_cutiExpanded;
            if (_cutiExpanded) _izinExpanded = false;
          }),
          icon: Icons.beach_access_rounded,
          iconColor: AppColors.brandNavy,
          title: 'Cuti Tahunan',
          subtitle: 'Ajukan cuti dari jatah tahunan kamu',
          pills: const ['Maks 12 hari/tahun', 'Min H-3'],
          content: const _CutiForm(),
        ),

        const SizedBox(height: 12),

        // Izin accordion
        _buildAccordion(
          expanded: _izinExpanded,
          onToggle: () => setState(() {
            _izinExpanded = !_izinExpanded;
            if (_izinExpanded) _cutiExpanded = false;
          }),
          icon: Icons.medical_services_rounded,
          iconColor: AppColors.brandCyanDark,
          title: 'Pengajuan Izin',
          subtitle: 'Izin sakit, seminar, atau keperluan sekolah',
          pills: const ['Sakit', 'Seminar', 'Sekolah'],
          content: const _IzinForm(),
        ),

        const SizedBox(height: 24),

        // History
        _buildHistory(),
      ],
    );
  }

  // ── Supervisor Accordion ─────────────────────────────────
  Widget _buildSupervisorAccordion() {
    final pendingCount = SampleData.subordinateLeaveRequests
        .where((r) => r.status == RequestStatus.pending)
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _empExpanded
              ? AppColors.warning.withOpacity(0.5)
              : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _empExpanded = !_empExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                        Icons.supervisor_account_rounded,
                        color: AppColors.warning,
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pengajuan Karyawan',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            )),
                        Text('Lihat & kelola pengajuan tim kamu',
                            style: AppText.body2),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$pendingCount menunggu',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _empExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.slate400,
                        size: 22),
                  ),
                ],
              ),
            ),
          ),
          if (_empExpanded) ...[
            const AppDivider(),
            _buildEmployeeApplicationList(),
          ],
        ],
      ),
    );
  }

  // ── Employee Application List ────────────────────────────
  Widget _buildEmployeeApplicationList() {
    final apps = SampleData.subordinateLeaveRequests;
    return Column(
      children: apps.asMap().entries.map((e) {
        final app  = e.value;
        final isLast = e.key == apps.length - 1;
        return Column(
          children: [
            _EmployeeAppTile(
              app: app,
              onApprove: () => _showActionDialog(true, app.employeeName!),
              onReject:  () => _showActionDialog(false, app.employeeName!),
            ),
            if (!isLast) const AppDivider(),
          ],
        );
      }).toList(),
    );
  }

  void _showActionDialog(bool approve, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(
          approve
              ? Icons.check_circle_rounded
              : Icons.cancel_rounded,
          color: approve ? AppColors.brandLimeDark : AppColors.danger,
          size: 40,
        ),
        title: Text(approve ? 'Setujui Pengajuan?' : 'Tolak Pengajuan?'),
        content: Text(
          '${approve ? "Setujui" : "Tolak"} pengajuan dari $name?',
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
              backgroundColor: approve
                  ? AppColors.brandLimeDark
                  : AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(approve ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
  }

  // ── Generic Accordion ────────────────────────────────────
  Widget _buildAccordion({
    required bool expanded,
    required VoidCallback onToggle,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> pills,
    required Widget content,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded
              ? iconColor.withOpacity(0.4)
              : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            )),
                        Text(subtitle, style: AppText.body2),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          children: pills
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate100,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(p,
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.slate600)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.slate400, size: 22),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const AppDivider(),
            content,
          ],
        ],
      ),
    );
  }

  // ── History ──────────────────────────────────────────────
  Widget _buildHistory() {
    final requests = SampleData.leaveRequests
        .where((r) => r.submittedAt.isAfter(
            DateTime.now().subtract(const Duration(days: 7))))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Riwayat Pengajuan',
                style: AppText.headline3
                    .copyWith(color: AppColors.slate900)),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AllLeaveHistoryScreen())),
              child: Text('Lihat Semua',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          SectionCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Belum ada pengajuan 7 hari terakhir',
                    style: AppText.body2),
              ),
            ),
          )
        else
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: requests.asMap().entries.map((e) {
                final req  = e.value;
                final isLast = e.key == requests.length - 1;
                return Column(
                  children: [
                    _RequestHistoryTile(request: req),
                    if (!isLast) const AppDivider(),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EMPLOYEE APPLICATION TILE  (supervisor view)
// ═══════════════════════════════════════════════════════════
class _EmployeeAppTile extends StatelessWidget {
  final LeaveRequest app;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _EmployeeAppTile({
    required this.app,
    required this.onApprove,
    required this.onReject,
  });

  // helpers ─────────────────────────────────────────────────
  String get _initials =>
      app.employeeName!.split(' ').map((w) => w[0]).take(2).join();

  String get _typeLabel {
    switch (app.type) {
      case LeaveType.annual:  return 'Cuti Tahunan';
      case LeaveType.sick:    return 'Izin Sakit';
      case LeaveType.seminar: return 'Izin Seminar';
      case LeaveType.school:  return 'Izin Sekolah';
    }
  }

  IconData get _typeIcon {
    switch (app.type) {
      case LeaveType.annual:  return Icons.beach_access_rounded;
      case LeaveType.sick:    return Icons.local_hospital_rounded;
      case LeaveType.seminar: return Icons.school_rounded;
      case LeaveType.school:  return Icons.menu_book_rounded;
    }
  }

  Color get _statusColor {
    switch (app.status) {
      case RequestStatus.approved: return AppColors.brandLimeDark;
      case RequestStatus.rejected: return AppColors.danger;
      case RequestStatus.pending:  return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (app.status) {
      case RequestStatus.approved: return 'DISETUJUI';
      case RequestStatus.rejected: return 'DITOLAK';
      case RequestStatus.pending:  return 'MENUNGGU';
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM yyyy', 'id_ID');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: Avatar + name + status badge ────────
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandNavy,
                      AppColors.brandNavy.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.employeeName!,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate900),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_typeIcon,
                            size: 12, color: AppColors.brandCyanDark),
                        const SizedBox(width: 4),
                        Text(
                          _typeLabel,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandCyanDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _statusColor.withOpacity(0.25)),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Date range + duration ────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

          // ── Reason preview ───────────────────────────────
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

          // ── Allowance chips ──────────────────────────────
          if (app.allowances.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: app.allowances.map((a) {
                final label = _allowanceLabel(a);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandCyanDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color:
                            AppColors.brandCyanDark.withOpacity(0.2)),
                  ),
                  child: Text(
                    label,
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

          // ── Action buttons ───────────────────────────────
          Row(
            children: [
              // Detail button
              OutlinedButton.icon(
                onPressed: () => WidgetsBinding.instance.addPostFrameCallback(() {
                    _showDetail(context);
                  } as FrameCallback),
                icon: const Icon(Icons.info_outline_rounded, size: 14),
                label: const Text('Detail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandNavy,
                  side: const BorderSide(
                      color: AppColors.brandNavy, width: 1),
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

              // Reject button
              if (app.status == RequestStatus.pending) ...[
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
            ],
          ),
        ],
      ),
    );
  }

  String _allowanceLabel(AllowanceType a) {
    switch (a) {
      case AllowanceType.health:        return '+ Tunjangan Kesehatan';
      case AllowanceType.accommodation: return '+ Tunjangan Akomodasi';
      case AllowanceType.transport:     return '+ Tunjangan Transport';
      case AllowanceType.spp:           return '+ Tunjangan SPP';
    }
  }

  void _showDetail(BuildContext context) {
    final f  = DateFormat('dd MMMM yyyy', 'id_ID');
    final ft = DateFormat('dd MMM yyyy, HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
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

            // Header row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandNavy,
                        AppColors.brandNavy.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.employeeName!,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate900),
                      ),
                      Text(_typeLabel,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandCyanDark)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _statusColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const AppDivider(),
            const SizedBox(height: 16),

            Text('Detail Pengajuan',
                style: AppText.label.copyWith(color: AppColors.slate700)),
            const SizedBox(height: 12),
            _DetailRow('Jenis', _typeLabel),
            _DetailRow('Tanggal Mulai', f.format(app.startDate)),
            _DetailRow('Tanggal Selesai', f.format(app.endDate)),
            _DetailRow('Durasi', '${app.dayCount} hari'),
            if (app.reason != null)
              _DetailRow('Alasan', app.reason!),
            _DetailRow('Diajukan', ft.format(app.submittedAt)),

            if (app.allowances.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Tunjangan Diminta',
                  style: AppText.label
                      .copyWith(color: AppColors.slate700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: app.allowances
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.brandCyanDark
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.brandCyanDark
                                    .withOpacity(0.2)),
                          ),
                          child: Text(
                            _allowanceLabel(a),
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandCyanDark),
                          ),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CUTI FORM
// ═══════════════════════════════════════════════════════════
class _CutiForm extends StatefulWidget {
  const _CutiForm();
  @override
  State<_CutiForm> createState() => _CutiFormState();
}

class _CutiFormState extends State<_CutiForm> {
  final user        = SampleData.currentUser;
  DateTime? _start, _end;
  final _reasonCtrl = TextEditingController();
  bool _submitting  = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _usedLeave => SampleData.leaveRequests
      .where((r) =>
          r.type == LeaveType.annual &&
          r.status != RequestStatus.rejected)
      .fold(0, (s, r) => s + r.dayCount);

  int get _remaining => user.position.annualLeaveQuota - _usedLeave;
  int get _days => (_start == null || _end == null)
      ? 0
      : _end!.difference(_start!).inDays + 1;

  bool get _canSubmit {
    if (_start == null || _end == null) return false;
    if (_reasonCtrl.text.trim().isEmpty) return false;
    if (_days > _remaining) return false;
    final minDate = DateTime.now()
        .add(Duration(days: user.position.minLeaveAdvanceDays));
    return !_start!.isBefore(minDate);
  }

  Future<void> _pickDate(bool isStart) async {
    final minDate = DateTime.now()
        .add(Duration(days: user.position.minLeaveAdvanceDays));
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? (_start ?? minDate) : (_end ?? _start ?? minDate),
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _start = null;
      _end   = null;
      _reasonCtrl.clear();
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
              color: AppColors.brandLimeDark, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 24),
        ),
        title: const Text('Pengajuan Berhasil!',
            textAlign: TextAlign.center),
        content: Text('Pengajuan cuti telah dikirim ke admin.',
            style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM yyyy', 'id_ID');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quota
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sisa Cuti Kamu', style: AppText.body2),
                Text(
                  '$_remaining dari ${user.position.annualLeaveQuota} hari',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandNavy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Date pickers
          Row(
            children: [
              Expanded(
                  child: _DatePickerField(
                label: 'Tanggal Mulai',
                value: _start != null ? f.format(_start!) : null,
                onTap: () => _pickDate(true),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _DatePickerField(
                label: 'Tanggal Selesai',
                value: _end != null ? f.format(_end!) : null,
                onTap: () => _pickDate(false),
              )),
            ],
          ),
          if (_days > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Total: $_days hari kerja',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _days > _remaining
                      ? AppColors.danger
                      : AppColors.brandLimeDark),
            ),
          ],
          const SizedBox(height: 14),

          Text('Alasan Cuti', style: AppText.label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Tuliskan alasan cuti kamu...',
            ),
          ),
          const SizedBox(height: 16),

          GradientButton(
            label: 'Kirim Pengajuan Cuti',
            color: _canSubmit ? AppColors.brandNavy : AppColors.slate300,
            textColor:
                _canSubmit ? Colors.white : AppColors.slate700,
            isLoading: _submitting,
            height: 48,
            onTap: _canSubmit && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// IZIN FORM  (with end-date + conditional photo upload)
// ═══════════════════════════════════════════════════════════
class _IzinForm extends StatefulWidget {
  const _IzinForm();
  @override
  State<_IzinForm> createState() => _IzinFormState();
}

class _IzinFormState extends State<_IzinForm> {
  String?   _type;
  DateTime? _startDate;
  DateTime? _endDate;
  final _noteCtrl   = TextEditingController();
  bool _submitting  = false;

  /// Daftar slot foto; key = label tunjangan, value = mock path (null = belum upload)
  List<_PhotoSlot> _photoSlots = [];

  // ── Lookup tables ────────────────────────────────────────
  static const _types = [
    ('Sakit',              Icons.local_hospital_rounded),
    ('Seminar',            Icons.school_rounded),
    ('Sekolah',  Icons.menu_book_rounded),
  ];

  /// Photo slot definitions per jenis izin
  static const Map<String, List<(String, IconData)>> _slotDefs = {
    'Sakit': [
      ('Surat Dokter / Resep', Icons.medical_information_rounded),
    ],
    'Seminar': [
      ('Bukti Transportasi',        Icons.directions_car_rounded),
      ('Bukti Konsumsi/Akomodasi',  Icons.restaurant_rounded),
    ],
    'Keperluan Sekolah': [
      ('Bukti Pembayaran SPP', Icons.receipt_long_rounded),
    ],
    'Lainnya': [],
  };

  // ── Helpers ──────────────────────────────────────────────
  List<AllowanceType> get _allowances {
    switch (_type) {
      case 'Sakit':             return [AllowanceType.health];
      case 'Seminar':           return [AllowanceType.transport, AllowanceType.accommodation];
      case 'Keperluan Sekolah': return [AllowanceType.spp];
      default:                  return [];
    }
  }

  void _onTypeChanged(String type) {
    final defs = _slotDefs[type] ?? [];
    setState(() {
      _type       = type;
      _photoSlots = defs
          .map((d) => _PhotoSlot(label: d.$1, icon: d.$2))
          .toList();
    });
  }

  bool get _photosComplete =>
      _photoSlots.every((s) => s.uploaded);

  bool get _canSubmit {
    if (_type == null) return false;
    if (_startDate == null || _endDate == null) return false;
    if (_noteCtrl.text.trim().isEmpty) return false;
    if (_photoSlots.isNotEmpty && !_photosComplete) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _type       = null;
      _startDate  = null;
      _endDate    = null;
      _photoSlots = [];
      _noteCtrl.clear();
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: AppColors.brandCyanDark, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 24),
        ),
        title: const Text('Pengajuan Terkirim!',
            textAlign: TextAlign.center),
        content: Text('Pengajuan izin kamu sedang diproses.',
            style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM yyyy', 'id_ID');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type chips ─────────────────────────────────
          Text('Jenis Izin', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final selected = _type == t.$1;
              return GestureDetector(
                onTap: () => _onTypeChanged(t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandCyanDark.withOpacity(0.1)
                        : AppColors.slate100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.brandCyanDark
                          : AppColors.slate200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$2,
                          size: 14,
                          color: selected
                              ? AppColors.brandCyanDark
                              : AppColors.slate700),
                      const SizedBox(width: 5),
                      Text(t.$1,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.brandCyanDark
                                : AppColors.slate700,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ── Date range ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  label: 'Tanggal Mulai',
                  value: _startDate != null ? f.format(_startDate!) : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 7)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        // reset end date if it's before new start
                        if (_endDate != null &&
                            _endDate!.isBefore(picked)) {
                          _endDate = picked;
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DatePickerField(
                  label: 'Tanggal Selesai',
                  value: _endDate != null ? f.format(_endDate!) : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _endDate ?? _startDate ?? DateTime.now(),
                      firstDate:
                          _startDate ?? DateTime.now()
                              .subtract(const Duration(days: 7)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                ),
              ),
            ],
          ),

          // Duration indicator
          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Total: ${_endDate!.difference(_startDate!).inDays + 1} hari',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandCyanDark),
            ),
          ],

          const SizedBox(height: 14),

          // ── Notes ─────────────────────────────────────
          Text('Keterangan', style: AppText.label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Tuliskan keterangan izin kamu...',
            ),
          ),

          // ── Photo upload (conditional) ─────────────────
          if (_photoSlots.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPhotoUploadSection(),
          ],

          const SizedBox(height: 16),

          GradientButton(
            label: 'Kirim Pengajuan Izin',
            color: _canSubmit
                ? AppColors.brandCyanDark
                : AppColors.slate300,
            textColor:
                _canSubmit ? Colors.white : AppColors.slate700,
            isLoading: _submitting,
            height: 48,
            onTap: _canSubmit && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }

  // ── Photo Upload Section ─────────────────────────────────
  Widget _buildPhotoUploadSection() {
    final uploadedCount = _photoSlots.where((s) => s.uploaded).length;
    final totalCount    = _photoSlots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Lampiran Dokumen', style: AppText.label),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _photosComplete
                    ? AppColors.brandLimeDark.withOpacity(0.12)
                    : AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$uploadedCount/$totalCount',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _photosComplete
                        ? AppColors.brandLimeDark
                        : AppColors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Upload foto pendukung untuk kelengkapan tunjangan.',
          style: AppText.body2.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 10),

        // Slots
        ..._photoSlots.asMap().entries.map((e) {
          final idx  = e.key;
          final slot = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PhotoUploadSlot(
              slot: slot,
              index: idx + 1,
              onUpload: () {
                // Simulate picking a file
                setState(() {
                  _photoSlots[idx] =
                      _PhotoSlot.uploaded(slot.label, slot.icon);
                });
              },
              onRemove: () {
                setState(() {
                  _photoSlots[idx] =
                      _PhotoSlot(label: slot.label, icon: slot.icon);
                });
              },
            ),
          );
        }),

        // Allowance note
        if (_allowances.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandCyanDark.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.brandCyanDark.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.brandCyanDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dokumen ini dibutuhkan untuk klaim: ${_allowances.map(_allowanceName).join(', ')}.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brandCyanDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _allowanceName(AllowanceType a) {
    switch (a) {
      case AllowanceType.health:        return 'Tunjangan Kesehatan';
      case AllowanceType.accommodation: return 'Tunjangan Akomodasi';
      case AllowanceType.transport:     return 'Tunjangan Transport';
      case AllowanceType.spp:           return 'Tunjangan SPP';
    }
  }
}

// ── Photo Slot Model ─────────────────────────────────────────
class _PhotoSlot {
  final String  label;
  final IconData icon;
  final String? filePath; // null = not uploaded

  const _PhotoSlot({required this.label, required this.icon})
      : filePath = null;

  const _PhotoSlot.uploaded(this.label, this.icon)
      : filePath = 'mock_photo_path';

  bool get uploaded => filePath != null;
}

// ── Photo Upload Slot Widget ──────────────────────────────────
class _PhotoUploadSlot extends StatelessWidget {
  final _PhotoSlot  slot;
  final int         index;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  const _PhotoUploadSlot({
    required this.slot,
    required this.index,
    required this.onUpload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: slot.uploaded ? null : onUpload,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: slot.uploaded
              ? AppColors.brandLimeDark.withOpacity(0.06)
              : AppColors.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: slot.uploaded
                ? AppColors.brandLimeDark.withOpacity(0.4)
                : AppColors.slate200,
            style: slot.uploaded
                ? BorderStyle.solid
                : BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: slot.uploaded
                    ? AppColors.brandLimeDark.withOpacity(0.12)
                    : AppColors.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                slot.uploaded
                    ? Icons.check_circle_rounded
                    : slot.icon,
                size: 18,
                color: slot.uploaded
                    ? AppColors.brandLimeDark
                    : AppColors.slate700,
              ),
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto ${index}: ${slot.label}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: slot.uploaded
                          ? AppColors.slate800
                          : AppColors.slate700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slot.uploaded
                        ? 'Foto berhasil diunggah'
                        : 'Ketuk untuk unggah foto',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: slot.uploaded
                          ? AppColors.brandLimeDark
                          : AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),

            // Action button
            if (slot.uploaded)
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.danger),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandCyanDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.upload_rounded,
                        size: 12, color: AppColors.brandCyanDark),
                    const SizedBox(width: 4),
                    Text('Upload',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandCyanDark)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DATE PICKER FIELD
// ═══════════════════════════════════════════════════════════
class _DatePickerField extends StatelessWidget {
  final String  label;
  final String? value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.slate700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? 'Pilih tanggal',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: value != null
                          ? AppColors.slate900
                          : AppColors.slate400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REQUEST HISTORY TILE
// ═══════════════════════════════════════════════════════════
class _RequestHistoryTile extends StatelessWidget {
  final LeaveRequest request;
  const _RequestHistoryTile({required this.request});

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

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM', 'id_ID');
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback(() {
          _showDetail(context);
        } as FrameCallback),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                request.type == LeaveType.annual
                    ? Icons.beach_access_rounded
                    : Icons.medical_services_rounded,
                color: _statusColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.type == LeaveType.annual
                        ? 'Cuti Tahunan'
                        : 'Izin',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900),
                  ),
                  Text(
                    '${f.format(request.startDate)} – ${f.format(request.endDate)}',
                    style: AppText.body2.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _statusColor),
              ),
            ),
            const SizedBox(width: 4),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
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
            Text('Detail Pengajuan',
                style:
                    AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 16),
            _DetailRow('Jenis',
                request.type == LeaveType.annual ? 'Cuti Tahunan' : 'Izin'),
            _DetailRow('Tanggal Mulai', f.format(request.startDate)),
            _DetailRow('Tanggal Selesai', f.format(request.endDate)),
            _DetailRow('Durasi', '${request.dayCount} hari'),
            _DetailRow('Status', _statusLabel),
            _DetailRow(
                'Diajukan',
                DateFormat('dd MMM yyyy, HH:mm')
                    .format(request.submittedAt)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════
class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppText.body2),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String     label;
  final Color      color;
  final VoidCallback onTap;
  final bool       filled;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? color : color.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
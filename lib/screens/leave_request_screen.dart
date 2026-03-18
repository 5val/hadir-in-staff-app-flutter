import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class LeaveRequestScreen extends StatefulWidget {
  final UserProfile user;
  const LeaveRequestScreen({super.key, required this.user});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────
  int get _usedLeave => SampleData.leaveRequests
      .where((r) => r.type == LeaveType.annual && r.status != RequestStatus.rejected)
      .fold(0, (s, r) => s + r.dayCount);

  int get _remainingLeave => widget.user.position.annualLeaveQuota - _usedLeave;

  int get _requestedDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  bool get _canSubmit {
    if (_startDate == null || _endDate == null) return false;
    if (_reasonCtrl.text.trim().isEmpty) return false;
    if (_requestedDays > _remainingLeave) return false;
    final minDate = DateTime.now()
        .add(Duration(days: widget.user.position.minLeaveAdvanceDays));
    if (_startDate!.isBefore(minDate)) return false;
    return true;
  }

  String _fmtDate(DateTime dt) => DateFormat('dd MMM yyyy', 'id_ID').format(dt);

  String _leaveTypeLabel(LeaveType t) {
    switch (t) {
      case LeaveType.annual:  return 'Cuti Tahunan';
      case LeaveType.sick:    return 'Sakit';
      case LeaveType.seminar: return 'Seminar';
      case LeaveType.school:  return 'Sekolah';
    }
  }

  // ── Date pickers ──────────────────────────────────────────
  Future<void> _pickStartDate() async {
    final minDate = DateTime.now()
        .add(Duration(days: widget.user.position.minLeaveAdvanceDays));
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? minDate,
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.success, shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
        title: const Text('Pengajuan Berhasil!', textAlign: TextAlign.center),
        content: Text(
          'Pengajuan cuti $_requestedDays hari telah dikirim ke admin untuk diverifikasi.',
          style: AppText.body2, textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _startDate = null; _endDate = null; _reasonCtrl.clear();
              });
              _tabCtrl.animateTo(1);
            },
            child: const Text('Lihat Riwayat'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Pengajuan Cuti', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // ── Balance card ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: SectionCard(
              borderColor: AppColors.primary.withOpacity(0.3),
              color: AppColors.primary.withOpacity(0.08),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sisa Cuti Tahunan', style: AppText.label),
                      const SizedBox(height: 4),
                      Text(
                        '$_remainingLeave Hari',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text('dari ${widget.user.position.annualLeaveQuota} hari/tahun',
                          style: AppText.caption),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatPill(label: 'Digunakan', value: '$_usedLeave hr'),
                      const SizedBox(height: 6),
                      _StatPill(
                        label: 'Min. H-${widget.user.position.minLeaveAdvanceDays}',
                        value: 'Pengajuan',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Tabs ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Ajukan Cuti'),
                  Tab(text: 'Riwayat'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildForm(), _buildHistory()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Form ─────────────────────────────────────────────────
  Widget _buildForm() {
    final minDays = widget.user.position.minLeaveAdvanceDays;
    final minDate = DateTime.now().add(Duration(days: minDays));
    final isTooEarly = _startDate != null && _startDate!.isBefore(minDate);
    final isExceeded = _requestedDays > _remainingLeave;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info notice
          SectionCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pengajuan cuti minimal H-$minDays (${_fmtDate(minDate)})',
                    style: AppText.body2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text('Tanggal Cuti', style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateCard(
                  label: 'Mulai',
                  date: _startDate,
                  onTap: _pickStartDate,
                  hasError: isTooEarly,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateCard(
                  label: 'Selesai',
                  date: _endDate,
                  onTap: _startDate == null ? null : _pickEndDate,
                ),
              ),
            ],
          ),

          if (isTooEarly) ...[
            const SizedBox(height: 6),
            Text(
              '⚠ Pengajuan harus minimal H-$minDays (${_fmtDate(minDate)})',
              style: AppText.caption.copyWith(color: AppColors.warning),
            ),
          ],

          if (_requestedDays > 0) ...[
            const SizedBox(height: 10),
            SectionCard(
              borderColor: (isExceeded ? AppColors.danger : AppColors.success)
                  .withOpacity(0.35),
              color: (isExceeded ? AppColors.danger : AppColors.success)
                  .withOpacity(0.07),
              child: Row(
                children: [
                  Icon(
                    isExceeded
                        ? Icons.warning_rounded
                        : Icons.event_available_rounded,
                    color: isExceeded ? AppColors.danger : AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExceeded
                        ? 'Melebihi sisa cuti! Sisa: $_remainingLeave hari'
                        : 'Total: $_requestedDays hari (Sisa: ${_remainingLeave - _requestedDays} hari)',
                    style: AppText.body2.copyWith(
                        color: isExceeded ? AppColors.danger : AppColors.success),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Text('Alasan Cuti', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Tuliskan alasan pengajuan cuti...',
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 24),

          GradientButton(
            label: _isSubmitting ? 'Mengajukan...' : 'Kirim Pengajuan Cuti',
            color: _canSubmit ? AppColors.primary : AppColors.surfaceVariant,
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            onTap: _canSubmit ? _submit : null,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── History ───────────────────────────────────────────────
  Widget _buildHistory() {
    final requests = SampleData.leaveRequests;
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note_rounded,
                color: AppColors.textMuted, size: 52),
            const SizedBox(height: 12),
            Text('Belum ada riwayat cuti', style: AppText.body2),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) => _HistoryCard(
          request: requests[i], leaveTypeLabel: _leaveTypeLabel),
    );
  }
}

// ── Date Card ─────────────────────────────────────────────────
class _DateCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback? onTap;
  final bool hasError;

  const _DateCard({
    required this.label,
    required this.date,
    this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: disabled ? AppColors.surface.withOpacity(0.5) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasError
                ? AppColors.warning
                : date != null
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12,
                    color: date != null ? AppColors.primary : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy').format(date!)
                      : 'Pilih tanggal',
                  style: AppText.body2.copyWith(
                    color: date != null ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Card ──────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final LeaveRequest request;
  final String Function(LeaveType) leaveTypeLabel;

  const _HistoryCard({required this.request, required this.leaveTypeLabel});

  @override
  Widget build(BuildContext context) {
    Color sc;
    String sl;
    switch (request.status) {
      case RequestStatus.pending:
        sc = AppColors.warning; sl = 'Menunggu'; break;
      case RequestStatus.approved:
        sc = AppColors.success; sl = 'Disetujui'; break;
      case RequestStatus.rejected:
        sc = AppColors.danger;  sl = 'Ditolak'; break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(
                    label: leaveTypeLabel(request.type), color: AppColors.primary),
                const Spacer(),
                StatusBadge(label: sl, color: sc),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd MMM').format(request.startDate)} – '
                  '${DateFormat('dd MMM yyyy').format(request.endDate)}',
                  style: AppText.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text('(${request.dayCount} hr)', style: AppText.body2),
              ],
            ),
            if (request.reason != null) ...[
              const SizedBox(height: 6),
              Text(request.reason!, style: AppText.body2),
            ],
            if (request.adminNote != null) ...[
              const SizedBox(height: 8),
              const AppDivider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: AppColors.primary, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Admin: ${request.adminNote}',
                      style: AppText.caption.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.primary.withOpacity(0.7), fontSize: 10)),
        ],
      ),
    );
  }
}
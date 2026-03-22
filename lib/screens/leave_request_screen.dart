import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class LeaveRequestScreen extends StatefulWidget {
  final UserProfile user;
  final int initialTab;

  const LeaveRequestScreen({
    super.key,
    required this.user,
    this.initialTab = 0,
  });

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── Leave (Cuti) state ────────────────────────────────────
  DateTime? _leaveStart;
  DateTime? _leaveEnd;
  final _leaveReasonCtrl = TextEditingController();
  bool _leaveSubmitting = false;

  // ── Permission (Izin) state ───────────────────────────────
  LeaveType _permType       = LeaveType.sick;
  DateTime? _permStart;
  DateTime? _permEnd;
  final _permReasonCtrl     = TextEditingController();
  final List<String?> _attachments = [null, null];
  bool _permSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _leaveReasonCtrl.dispose();
    _permReasonCtrl.dispose();
    super.dispose();
  }

  // ── Leave helpers ─────────────────────────────────────────
  int get _usedLeave => SampleData.leaveRequests
      .where((r) => r.type == LeaveType.annual && r.status != RequestStatus.rejected)
      .fold(0, (s, r) => s + r.dayCount);

  int get _remainingLeave => widget.user.position.annualLeaveQuota - _usedLeave;

  int get _requestedDays {
    if (_leaveStart == null || _leaveEnd == null) return 0;
    return _leaveEnd!.difference(_leaveStart!).inDays + 1;
  }

  bool get _leaveCanSubmit {
    if (_leaveStart == null || _leaveEnd == null) return false;
    if (_leaveReasonCtrl.text.trim().isEmpty) return false;
    if (_requestedDays > _remainingLeave) return false;
    final minDate = DateTime.now()
        .add(Duration(days: widget.user.position.minLeaveAdvanceDays));
    if (_leaveStart!.isBefore(minDate)) return false;
    return true;
  }

  // ── Permission helpers ────────────────────────────────────
  bool get _isSick    => _permType == LeaveType.sick;
  bool get _isSeminar => _permType == LeaveType.seminar;

  int get _maxPhotos => _isSeminar ? 2 : 1;

  List<AllowanceType> get _allowances {
    switch (_permType) {
      case LeaveType.sick:    return [AllowanceType.health];
      case LeaveType.seminar: return [AllowanceType.accommodation, AllowanceType.transport];
      case LeaveType.school:  return [AllowanceType.spp];
      default:                return [];
    }
  }

  bool get _hasEnoughAttachments =>
      _attachments.take(_maxPhotos).any((a) => a != null);

  bool _isPastDate(DateTime dt) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return dt.isBefore(today);
  }

  bool get _permCanSubmit =>
      _permStart != null &&
      _permEnd != null &&
      _permReasonCtrl.text.trim().isNotEmpty &&
      _hasEnoughAttachments &&
      _permDateValid();

  bool _permDateValid() {
    if (_permStart == null) return true;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _isSick ? !_permStart!.isAfter(today) : !_permStart!.isBefore(today);
  }

  // ── Label helpers ─────────────────────────────────────────
  String _fmtDate(DateTime dt) => DateFormat('dd MMM yyyy', 'id_ID').format(dt);

  String _leaveTypeLabel(LeaveType t) {
    switch (t) {
      case LeaveType.annual:  return 'Cuti Tahunan';
      case LeaveType.sick:    return 'Izin Sakit';
      case LeaveType.seminar: return 'Izin Seminar';
      case LeaveType.school:  return 'Izin Sekolah';
    }
  }

  String _permTypeShortLabel(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return 'Sakit';
      case LeaveType.seminar: return 'Seminar';
      case LeaveType.school:  return 'Sekolah';
      default:                return '';
    }
  }

  String _allowanceLabel(AllowanceType a) {
    switch (a) {
      case AllowanceType.health:        return 'Tunjangan Kesehatan';
      case AllowanceType.accommodation: return 'Tunjangan Akomodasi';
      case AllowanceType.transport:     return 'Tunjangan Transportasi';
      case AllowanceType.spp:           return 'Tunjangan SPP (One-time)';
    }
  }

  Color _permTypeColor(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return AppColors.danger;
      case LeaveType.seminar: return AppColors.brandCyanDark;
      case LeaveType.school:  return AppColors.brandNavy;
      default:                return AppColors.brandNavy;
    }
  }

  IconData _permTypeIcon(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return Icons.local_hospital_rounded;
      case LeaveType.seminar: return Icons.school_rounded;
      case LeaveType.school:  return Icons.menu_book_rounded;
      default:                return Icons.event_note_rounded;
    }
  }

  // ── Date pickers — Leave ──────────────────────────────────
  Future<void> _pickLeaveStart() async {
    final minDate = DateTime.now()
        .add(Duration(days: widget.user.position.minLeaveAdvanceDays));
    final picked = await _datePicker(
      initial: _leaveStart ?? minDate,
      first:   minDate,
      last:    DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _leaveStart = picked;
        if (_leaveEnd != null && _leaveEnd!.isBefore(picked)) _leaveEnd = picked;
      });
    }
  }

  Future<void> _pickLeaveEnd() async {
    if (_leaveStart == null) return;
    final picked = await _datePicker(
      initial: _leaveEnd ?? _leaveStart!,
      first:   _leaveStart!,
      last:    DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _leaveEnd = picked);
  }

  // ── Date pickers — Permission ─────────────────────────────
  Future<void> _pickPermStart() async {
    final today = DateTime.now();
    final firstDate = _isSick
        ? today.subtract(const Duration(days: 30))
        : DateTime(today.year, today.month, today.day);
    final lastDate = _isSick
        ? DateTime(today.year, today.month, today.day)
        : today.add(const Duration(days: 180));
    final picked = await _datePicker(
      initial: _permStart ?? firstDate,
      first:   firstDate,
      last:    lastDate,
    );
    if (picked != null) {
      setState(() {
        _permStart = picked;
        if (_permEnd != null && _permEnd!.isBefore(picked)) _permEnd = picked;
      });
    }
  }

  Future<void> _pickPermEnd() async {
    if (_permStart == null) return;
    final today  = DateTime.now();
    final lastDate = _isSick
        ? DateTime(today.year, today.month, today.day)
        : today.add(const Duration(days: 180));
    final picked = await _datePicker(
      initial: _permEnd ?? _permStart!,
      first:   _permStart!,
      last:    lastDate,
    );
    if (picked != null) setState(() => _permEnd = picked);
  }

  Future<DateTime?> _datePicker({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.brandNavy,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
  }

  // ── Photo helpers ─────────────────────────────────────────
  void _pickPhoto(int i) {
    setState(() => _attachments[i] = 'photo_${i + 1}.jpg');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Foto ${i + 1} berhasil ditambahkan'),
      backgroundColor: AppColors.brandLimeDark,
    ));
  }

  void _removePhoto(int i) => setState(() => _attachments[i] = null);

  // ── Submit leave ──────────────────────────────────────────
  Future<void> _submitLeave() async {
    if (!_leaveCanSubmit) return;
    setState(() => _leaveSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _leaveSubmitting = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: AppColors.brandLimeDark, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
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
                _leaveStart = null; _leaveEnd = null; _leaveReasonCtrl.clear();
              });
              _tabCtrl.animateTo(2);
            },
            child: const Text('Lihat Riwayat'),
          ),
        ],
      ),
    );
  }

  // ── Submit permission ─────────────────────────────────────
  Future<void> _submitPerm() async {
    if (!_permCanSubmit) return;
    setState(() => _permSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _permSubmitting = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Text('✅', style: TextStyle(fontSize: 38)),
        title: const Text('Pengajuan Terkirim!', textAlign: TextAlign.center),
        content: Text(
          'Pengajuan Izin ${_permTypeShortLabel(_permType)} telah dikirim ke admin untuk verifikasi.',
          style: AppText.body2, textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _permStart = null; _permEnd = null;
                _permReasonCtrl.clear();
                _attachments.fillRange(0, 2, null);
              });
              _tabCtrl.animateTo(2);
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
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.slate700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(AppAssets.logoIcon, height: 26),
            const SizedBox(width: 8),
            Text('Cuti & Izin', style: AppText.headline3),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: Column(
        children: [
          // ── Leave balance summary (selalu tampil di atas tabs) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SectionCard(
              color: AppColors.brandNavy.withOpacity(0.05),
              borderColor: AppColors.brandNavy.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sisa Cuti Tahunan', style: AppText.label),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_remainingLeave',
                            style: GoogleFonts.inter(
                              fontSize: 28, fontWeight: FontWeight.w800,
                              color: AppColors.brandNavy,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('hari', style: AppText.body2),
                        ],
                      ),
                      Text('dari ${widget.user.position.annualLeaveQuota} hr/tahun',
                          style: AppText.caption),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 6,
                    children: [
                      _StatPill(label: 'Digunakan', value: '$_usedLeave hr'),
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

          const SizedBox(height: 12),

          // ── Tabs ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.white,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.white),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Ajukan Cuti'),
                  Tab(text: 'Ajukan Izin'),
                  Tab(text: 'Riwayat'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 2),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildLeaveForm(),
                _buildPermForm(),
                _buildHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 0 — AJUKAN CUTI
  // ─────────────────────────────────────────────────────────
  Widget _buildLeaveForm() {
    final minDays    = widget.user.position.minLeaveAdvanceDays;
    final minDate    = DateTime.now().add(Duration(days: minDays));
    final isTooEarly = _leaveStart != null && _leaveStart!.isBefore(minDate);
    final isExceeded = _requestedDays > _remainingLeave;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          SectionCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.brandNavy, size: 16),
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
              Expanded(child: _DatePicker(
                label: 'Mulai', date: _leaveStart,
                onTap: _pickLeaveStart, hasError: isTooEarly,
              )),
              const SizedBox(width: 10),
              Expanded(child: _DatePicker(
                label: 'Selesai', date: _leaveEnd,
                onTap: _leaveStart == null ? null : _pickLeaveEnd,
              )),
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
              color: (isExceeded ? AppColors.danger : AppColors.brandLimeDark)
                  .withOpacity(0.06),
              borderColor: (isExceeded ? AppColors.danger : AppColors.brandLimeDark)
                  .withOpacity(0.3),
              child: Row(
                children: [
                  Icon(
                    isExceeded ? Icons.warning_rounded : Icons.event_available_rounded,
                    color: isExceeded ? AppColors.danger : AppColors.brandLimeDark,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExceeded
                        ? 'Melebihi sisa cuti! Sisa: $_remainingLeave hari'
                        : 'Total: $_requestedDays hari (Sisa: ${_remainingLeave - _requestedDays} hari)',
                    style: AppText.body2.copyWith(
                        color: isExceeded ? AppColors.danger : AppColors.brandLimeDark),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Text('Alasan Cuti', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _leaveReasonCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.slate900),
            decoration: const InputDecoration(
              hintText: 'Tuliskan alasan pengajuan cuti...',
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 24),

          GradientButton(
            label: _leaveSubmitting ? 'Mengajukan...' : 'Kirim Pengajuan Cuti',
            color: _leaveCanSubmit ? AppColors.brandNavy : AppColors.slate200,
            icon: Icons.send_rounded,
            isLoading: _leaveSubmitting,
            onTap: _leaveCanSubmit ? _submitLeave : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 1 — AJUKAN IZIN
  // ─────────────────────────────────────────────────────────
  Widget _buildPermForm() {
    final typeColor = _permTypeColor(_permType);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jenis izin selector
          Text('Jenis Izin', style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              LeaveType.sick,
              LeaveType.seminar,
              LeaveType.school,
            ].map((t) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _TypeBtn(
                  selected: _permType == t,
                  label: _permTypeShortLabel(t),
                  icon: _permTypeIcon(t),
                  color: _permTypeColor(t),
                  onTap: () => setState(() {
                    _permType = t;
                    _attachments.fillRange(0, 2, null);
                    _permStart = null; _permEnd = null;
                  }),
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 14),

          // Allowance info
          SectionCard(
            color: typeColor.withOpacity(0.05),
            borderColor: typeColor.withOpacity(0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_permTypeIcon(_permType), color: typeColor, size: 15),
                    const SizedBox(width: 6),
                    Text('Tunjangan yang Diperoleh',
                        style: AppText.label.copyWith(color: typeColor)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._allowances.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.brandLimeDark, size: 13),
                      const SizedBox(width: 6),
                      Text(_allowanceLabel(a), style: AppText.body2),
                    ],
                  ),
                )),
                if (_isSick) ...[
                  const SizedBox(height: 6),
                  const AppDivider(),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.brandNavy, size: 12),
                      const SizedBox(width: 4),
                      Text('Izin sakit bisa diajukan untuk hari sebelumnya',
                          style: AppText.caption
                              .copyWith(color: AppColors.brandNavy)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(_isSick ? 'Tanggal Sakit' : 'Tanggal Izin', style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _DatePicker(
                  label: 'Mulai', date: _permStart, onTap: _pickPermStart)),
              const SizedBox(width: 10),
              Expanded(child: _DatePicker(
                  label: 'Selesai', date: _permEnd,
                  onTap: _permStart == null ? null : _pickPermEnd)),
            ],
          ),

          // Date warning for seminar/school
          if (!_isSick && _permStart != null && _isPastDate(_permStart!)) ...[
            const SizedBox(height: 6),
            SectionCard(
              color: AppColors.danger.withOpacity(0.05),
              borderColor: AppColors.danger.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger, size: 14),
                  const SizedBox(width: 6),
                  Text('Tanggal izin tidak boleh sebelum hari ini',
                      style: AppText.caption.copyWith(color: AppColors.danger)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          Text('Keterangan / Alasan', style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: _permReasonCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.slate900),
            decoration: InputDecoration(
              hintText: _isSick
                  ? 'Deskripsikan keluhan sakit kamu...'
                  : _isSeminar
                      ? 'Nama seminar, penyelenggara, lokasi...'
                      : 'Nama institusi, mata pelajaran/kuliah...',
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Text('Upload Bukti', style: AppText.label),
              const SizedBox(width: 6),
              StatusBadge(label: '$_maxPhotos foto maks', color: typeColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isSick
                ? 'Wajib upload surat dokter (1 foto)'
                : _isSeminar
                    ? 'Upload bukti pendaftaran & akomodasi (maks 2 foto)'
                    : 'Upload bukti tagihan SPP (1 foto)',
            style: AppText.body2,
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              _maxPhotos,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _maxPhotos - 1 ? 8 : 0),
                  child: _AttachCard(
                    index: i,
                    filename: _attachments[i],
                    onAdd: () => _pickPhoto(i),
                    onRemove: () => _removePhoto(i),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          GradientButton(
            label: _permSubmitting ? 'Mengajukan...' : 'Kirim Pengajuan Izin',
            color: _permCanSubmit ? AppColors.brandNavy : AppColors.slate200,
            icon: Icons.send_rounded,
            isLoading: _permSubmitting,
            onTap: _permCanSubmit ? _submitPerm : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 2 — RIWAYAT (semua cuti + izin, diurutkan terbaru)
  // ─────────────────────────────────────────────────────────
  Widget _buildHistory() {
    final all = [...SampleData.leaveRequests]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note_rounded,
                color: AppColors.slate300, size: 56),
            const SizedBox(height: 12),
            Text('Belum ada riwayat cuti & izin', style: AppText.body2),
          ],
        ),
      );
    }

    // Group by annual vs permission
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: all.map((r) => _HistoryCard(
            request: r,
            typeLabel: _leaveTypeLabel(r.type),
            allowanceLabel: _allowanceLabel,
          )).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED HELPER WIDGETS
// ─────────────────────────────────────────────────────────────

// ── Date Picker Card ──────────────────────────────────────────
class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback? onTap;
  final bool hasError;

  const _DatePicker({
    required this.label, required this.date, this.onTap, this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: disabled ? AppColors.slate50 : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasError
                ? AppColors.warning
                : date != null
                    ? AppColors.brandNavy.withOpacity(0.5)
                    : AppColors.slate200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12,
                    color: date != null ? AppColors.brandNavy : AppColors.slate400),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    date != null
                        ? DateFormat('dd MMM yyyy').format(date!)
                        : 'Pilih tanggal',
                    style: AppText.body2.copyWith(
                      color: date != null ? AppColors.slate900 : AppColors.slate400,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
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

// ── Type Button ───────────────────────────────────────────────
class _TypeBtn extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.selected, required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.slate400, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.slate400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attachment Card ───────────────────────────────────────────
class _AttachCard extends StatelessWidget {
  final int index;
  final String? filename;
  final VoidCallback onAdd, onRemove;

  const _AttachCard({
    required this.index, this.filename,
    required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final has = filename != null;
    return GestureDetector(
      onTap: has ? null : onAdd,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: has ? AppColors.brandLime.withOpacity(0.08) : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: has ? AppColors.brandLimeDark.withOpacity(0.4) : AppColors.slate200,
          ),
        ),
        child: has
            ? Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_rounded,
                            color: AppColors.brandLimeDark, size: 24),
                        const SizedBox(height: 4),
                        Text(filename!,
                            style: AppText.caption
                                .copyWith(color: AppColors.brandLimeDark),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 11),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.slate400, size: 24),
                  const SizedBox(height: 4),
                  Text('Foto ${index + 1}', style: AppText.caption),
                ],
              ),
      ),
    );
  }
}

// ── History Card ──────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final LeaveRequest request;
  final String typeLabel;
  final String Function(AllowanceType) allowanceLabel;

  const _HistoryCard({
    required this.request,
    required this.typeLabel,
    required this.allowanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color sc; String sl;
    switch (request.status) {
      case RequestStatus.pending:  sc = AppColors.warning; sl = 'Menunggu';  break;
      case RequestStatus.approved: sc = AppColors.brandLimeDark; sl = 'Disetujui'; break;
      case RequestStatus.rejected: sc = AppColors.danger;  sl = 'Ditolak';   break;
    }

    // Color-code by type
    final typeColor = request.type == LeaveType.annual
        ? AppColors.brandNavy
        : request.type == LeaveType.sick
            ? AppColors.danger
            : request.type == LeaveType.seminar
                ? AppColors.brandCyanDark
                : AppColors.brandNavy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(label: typeLabel, color: typeColor),
                const Spacer(),
                StatusBadge(label: sl, color: sc),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    color: AppColors.brandNavy, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${DateFormat('dd MMM').format(request.startDate)} – '
                    '${DateFormat('dd MMM yyyy').format(request.endDate)}',
                    style: AppText.body1.copyWith(
                        fontWeight: FontWeight.w600, color: AppColors.slate900),
                  ),
                ),
                Text('(${request.dayCount} hr)', style: AppText.body2),
              ],
            ),
            if (request.reason != null) ...[
              const SizedBox(height: 5),
              Text(request.reason!, style: AppText.body2),
            ],
            if (request.allowances.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: request.allowances
                    .map((a) => StatusBadge(
                          label: allowanceLabel(a),
                          color: request.status == RequestStatus.rejected
                              ? AppColors.slate400
                              : AppColors.brandCyanDark,
                        ))
                    .toList(),
              ),
            ],
            if (request.adminNote != null) ...[
              const SizedBox(height: 8),
              const AppDivider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    request.status == RequestStatus.rejected
                        ? Icons.block_rounded
                        : Icons.admin_panel_settings_rounded,
                    color: request.status == RequestStatus.rejected
                        ? AppColors.danger
                        : AppColors.brandNavy,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Admin: ${request.adminNote}',
                      style: AppText.caption.copyWith(
                        color: request.status == RequestStatus.rejected
                            ? AppColors.danger
                            : AppColors.brandNavy,
                      ),
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
  final String label, value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brandNavy.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.brandNavy.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.brandNavy,
                  fontWeight: FontWeight.w700, fontSize: 12)),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.brandNavy.withOpacity(0.65), fontSize: 10)),
        ],
      ),
    );
  }
}
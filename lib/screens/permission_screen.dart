import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  LeaveType _selectedType  = LeaveType.sick;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl        = TextEditingController();
  final List<String?> _attachments = [null, null];
  bool _isSubmitting       = false;

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
  bool get _isSick    => _selectedType == LeaveType.sick;
  bool get _isSeminar => _selectedType == LeaveType.seminar;

  int get _maxPhotos => _isSeminar ? 2 : 1;

  List<AllowanceType> get _allowances {
    switch (_selectedType) {
      case LeaveType.sick:    return [AllowanceType.health];
      case LeaveType.seminar: return [AllowanceType.accommodation, AllowanceType.transport];
      case LeaveType.school:  return [AllowanceType.spp];
      default:                return [];
    }
  }

  String _typeLabel(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return 'Izin Sakit';
      case LeaveType.seminar: return 'Izin Seminar';
      case LeaveType.school:  return 'Izin Sekolah';
      default:                return 'Izin';
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

  Color _typeColor(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return AppColors.danger;
      case LeaveType.seminar: return AppColors.teal;
      case LeaveType.school:  return AppColors.primary;
      default:                return AppColors.primary;
    }
  }

  IconData _typeIcon(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return Icons.local_hospital_rounded;
      case LeaveType.seminar: return Icons.school_rounded;
      case LeaveType.school:  return Icons.menu_book_rounded;
      default:                return Icons.event_note_rounded;
    }
  }

  bool get _hasEnoughAttachments =>
      _attachments.take(_maxPhotos).any((a) => a != null);

  // ── Validation ────────────────────────────────────────────
  /// Izin seminar/sekolah: tanggal harus SEBELUM hari ini (hari ini ke depan = ok)
  /// Izin sakit: tanggal boleh retroaktif (max 30 hari lalu) sampai hari ini
  bool _isDateValid() {
    if (_startDate == null) return true; // belum pilih, skip
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (_isSick) {
      // Sakit: start <= today
      return !_startDate!.isAfter(today);
    } else {
      // Seminar/Sekolah: tanggal harus sebelum hari ini (tidak boleh hari lampau)
      return !_startDate!.isBefore(today);
    }
  }

  bool _isPastDate(DateTime dt) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return dt.isBefore(today);
  }

  bool get _canSubmit =>
      _startDate != null &&
      _endDate != null &&
      _reasonCtrl.text.trim().isNotEmpty &&
      _hasEnoughAttachments &&
      _isDateValid();

  // ── Date Pickers ──────────────────────────────────────────
  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    // Sakit boleh retroaktif (max 30 hari lalu) s/d hari ini
    // Seminar/Sekolah: hari ini ke depan
    final firstDate = _isSick
        ? today.subtract(const Duration(days: 30))
        : DateTime(today.year, today.month, today.day);
    final lastDate  = _isSick
        ? DateTime(today.year, today.month, today.day) // max today
        : today.add(const Duration(days: 180));

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary, surface: AppColors.surface,
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
    final today  = DateTime.now();
    final lastDate = _isSick
        ? DateTime(today.year, today.month, today.day)
        : today.add(const Duration(days: 180));

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary, surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _pickPhoto(int index) {
    setState(() => _attachments[index] = 'photo_${index + 1}.jpg');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Foto ${index + 1} berhasil ditambahkan'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _removePhoto(int index) => setState(() => _attachments[index] = null);

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Text('✅', style: TextStyle(fontSize: 40)),
        title: const Text('Pengajuan Terkirim!', textAlign: TextAlign.center),
        content: Text(
          'Pengajuan ${_typeLabel(_selectedType)} telah dikirim ke admin untuk verifikasi.',
          style: AppText.body2, textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _tabCtrl.animateTo(1);
              setState(() {
                _startDate = null; _endDate = null;
                _reasonCtrl.clear();
                _attachments.fillRange(0, 2, null);
              });
            },
            child: const Text('OK'),
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
        title: Text('Pengajuan Izin', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // ── Tabs ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
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
                  Tab(text: 'Ajukan Izin'),
                  Tab(text: 'Riwayat'),
                ],
              ),
            ),
          ),

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
    final typeColor = _typeColor(_selectedType);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type selector
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
                  type: t,
                  selected: _selectedType == t,
                  label: _typeLabel(t).replaceFirst('Izin ', ''),
                  icon: _typeIcon(t),
                  color: _typeColor(t),
                  onTap: () => setState(() {
                    _selectedType = t;
                    _attachments.fillRange(0, 2, null);
                    _startDate = null;
                    _endDate   = null;
                  }),
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 14),

          // Allowance info
          SectionCard(
            borderColor: typeColor.withOpacity(0.3),
            color: typeColor.withOpacity(0.07),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(_selectedType), color: typeColor, size: 16),
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
                          color: AppColors.success, size: 14),
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
                          color: AppColors.primary, size: 12),
                      const SizedBox(width: 4),
                      Text('Izin sakit bisa diajukan untuk hari sebelumnya',
                          style: AppText.caption.copyWith(color: AppColors.primary)),
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
              Expanded(
                child: _DateTile(
                  label: 'Mulai', date: _startDate, onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTile(
                  label: 'Selesai', date: _endDate,
                  onTap: _startDate == null ? null : _pickEndDate,
                ),
              ),
            ],
          ),

          // Date validation warning for seminar/school
          if (!_isSick && _startDate != null && _isPastDate(_startDate!))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SectionCard(
                borderColor: AppColors.danger.withOpacity(0.4),
                color: AppColors.danger.withOpacity(0.07),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.danger, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tanggal izin tidak boleh sebelum hari ini',
                        style: AppText.caption.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),

          Text('Keterangan / Alasan', style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            style: TextStyle(color: AppColors.textPrimary),
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
            label: 'Kirim Pengajuan',
            color: _canSubmit ? AppColors.primary : AppColors.surfaceVariant,
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            onTap: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }

  // ── History ───────────────────────────────────────────────
  Widget _buildHistory() {
    final requests = SampleData.leaveRequests
        .where((r) => r.type != LeaveType.annual)
        .toList();

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note_rounded,
                color: AppColors.textMuted, size: 52),
            const SizedBox(height: 12),
            Text('Belum ada riwayat izin', style: AppText.body2),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) => _HistoryCard(request: requests[i]),
    );
  }
}

// ── Type Button ───────────────────────────────────────────────
class _TypeBtn extends StatelessWidget {
  final LeaveType type;
  final bool selected;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.type, required this.selected, required this.label,
    required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.textMuted, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Tile ─────────────────────────────────────────────────
class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback? onTap;

  const _DateTile({required this.label, this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.surface.withOpacity(0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: date != null
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
                Icon(Icons.calendar_today_rounded,
                    size: 12,
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

// ── Attachment Card ───────────────────────────────────────────
class _AttachCard extends StatelessWidget {
  final int index;
  final String? filename;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _AttachCard({
    required this.index, this.filename, required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final has = filename != null;
    return GestureDetector(
      onTap: has ? null : onAdd,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: has ? AppColors.success.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: has ? AppColors.success.withOpacity(0.4) : AppColors.border,
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
                            color: AppColors.success, size: 24),
                        const SizedBox(height: 4),
                        Text(filename!,
                            style: AppText.caption
                                .copyWith(color: AppColors.success),
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
                          color: AppColors.danger, shape: BoxShape.circle,
                        ),
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
                      color: AppColors.textMuted, size: 24),
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
  const _HistoryCard({required this.request});

  String _typeLabel(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return 'Izin Sakit';
      case LeaveType.seminar: return 'Izin Seminar';
      case LeaveType.school:  return 'Izin Sekolah';
      default:                return 'Izin';
    }
  }

  String _allowanceLabel(AllowanceType a) {
    switch (a) {
      case AllowanceType.health:        return 'Tunjangan Kesehatan';
      case AllowanceType.accommodation: return 'Tunjangan Akomodasi';
      case AllowanceType.transport:     return 'Tunjangan Transportasi';
      case AllowanceType.spp:           return 'Tunjangan SPP';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color sc; String sl;
    switch (request.status) {
      case RequestStatus.pending:  sc = AppColors.warning; sl = 'Menunggu';  break;
      case RequestStatus.approved: sc = AppColors.success; sl = 'Disetujui'; break;
      case RequestStatus.rejected: sc = AppColors.danger;  sl = 'Ditolak';   break;
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
                StatusBadge(label: _typeLabel(request.type), color: AppColors.primary),
                const Spacer(),
                StatusBadge(label: sl, color: sc),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd MMM').format(request.startDate)} – '
                  '${DateFormat('dd MMM yyyy').format(request.endDate)}',
                  style: AppText.body1.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (request.reason != null) ...[
              const SizedBox(height: 4),
              Text(request.reason!, style: AppText.body2),
            ],
            if (request.allowances.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: request.allowances
                    .map((a) => StatusBadge(
                          label: _allowanceLabel(a),
                          color: request.status == RequestStatus.rejected
                              ? AppColors.textMuted
                              : AppColors.teal,
                        ))
                    .toList(),
              ),
            ],
            if (request.status == RequestStatus.rejected &&
                request.adminNote != null) ...[
              const SizedBox(height: 8),
              const AppDivider(),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.block_rounded, color: AppColors.danger, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Ditolak: ${request.adminNote}',
                        style: AppText.caption.copyWith(color: AppColors.danger)),
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
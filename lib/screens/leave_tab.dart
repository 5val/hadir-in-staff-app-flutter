import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'leave_choice_screen.dart';

/// Leave tab — menampilkan HANYA satu form (Cuti atau Izin),
/// ditentukan dari LeaveChoiceScreen (0 = Cuti, 1 = Izin).
/// Dilengkapi tombol kembali ke LeaveChoiceScreen.
class LeaveTab extends StatefulWidget {
  final int initialSubTab; // 0 = Cuti, 1 = Izin
  const LeaveTab({super.key, this.initialSubTab = 0});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
  late int _subTab;

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialSubTab.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final isCuti = _subTab == 0;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back → LeaveChoiceScreen
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: AppColors.slate700),
                    tooltip: 'Pilih jenis pengajuan',
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LeaveChoiceScreen()),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text('APPLICATION PORTAL',
                        //     style: GoogleFonts.inter(
                        //       fontSize: 10, fontWeight: FontWeight.w700,
                        //       color: AppColors.brandNavy, letterSpacing: 1.2,
                        //     )),
                        const SizedBox(height: 2),
                        Text(
                          isCuti ? 'Pengajuan Cuti' : 'Pengajuan Izin',
                          style: AppText.headline2
                              .copyWith(color: AppColors.slate900),
                        ),
                        Text(
                          isCuti
                              ? 'Ajukan cuti tahunan kamu di sini.'
                              : 'Submit dokumen izin sakit, seminar, atau sekolah.',
                          style: AppText.body2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),

            // ── Content ───────────────────────────────────
            Expanded(
              child: isCuti ? const _CutiForm() : const _IzinForm(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CUTI FORM
// ─────────────────────────────────────────────────────────────
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
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  int get _usedLeave => SampleData.leaveRequests
      .where((r) =>
          r.type == LeaveType.annual &&
          r.status != RequestStatus.rejected)
      .fold(0, (s, r) => s + r.dayCount);

  int get _remaining => user.position.annualLeaveQuota - _usedLeave;

  int get _days =>
      (_start == null || _end == null)
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
      initialDate: isStart ? (_start ?? minDate) : (_end ?? _start ?? minDate),
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => _datePicker(ctx, child),
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
      _submitting = false; _start = null; _end = null; _reasonCtrl.clear();
    });
    _showSuccessDialog('Pengajuan Berhasil!',
        'Pengajuan cuti $_days hari telah dikirim ke admin.');
  }

  void _showSuccessDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          width: 48, height: 48,
          decoration: const BoxDecoration(
              color: AppColors.brandLimeDark, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(msg, style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minDate = DateTime.now()
        .add(Duration(days: user.position.minLeaveAdvanceDays));
    final isTooEarly =
        _start != null && _start!.isBefore(minDate);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Saldo cuti
        _BalanceCard(remaining: _remaining, used: _usedLeave,
            quota: user.position.annualLeaveQuota,
            minAdvanceDays: user.position.minLeaveAdvanceDays),
        const SizedBox(height: 16),

        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateField(
                label: 'TANGGAL MULAI',
                value: _start,
                onTap: () => _pickDate(true),
                hasError: isTooEarly,
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'TANGGAL SELESAI',
                value: _end,
                onTap: _start == null ? null : () => _pickDate(false),
              ),

              if (isTooEarly) ...[
                const SizedBox(height: 8),
                _InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  text: 'Pengajuan min. H-${user.position.minLeaveAdvanceDays}'
                      ' (${DateFormat("dd MMM yyyy", "id_ID").format(minDate)})',
                ),
              ],

              if (_days > 0) ...[
                const SizedBox(height: 8),
                _InfoBanner(
                  icon: _days > _remaining
                      ? Icons.warning_rounded
                      : Icons.event_available_rounded,
                  color: _days > _remaining
                      ? AppColors.danger
                      : AppColors.brandLimeDark,
                  text: _days > _remaining
                      ? 'Melebihi sisa cuti ($_remaining hari tersisa)'
                      : '$_days hari · Sisa: ${_remaining - _days} hari',
                ),
              ],

              const SizedBox(height: 16),
              _FieldLabel(label: 'ALASAN CUTI'),
              const SizedBox(height: 6),
              _TextArea(
                controller: _reasonCtrl,
                hint: 'Tuliskan alasan pengajuan cuti...',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        GradientButton(
          label: _submitting ? 'Mengirim...' : 'Submit Pengajuan Cuti',
          color: _canSubmit ? AppColors.brandNavy : AppColors.slate200,
          isLoading: _submitting,
          height: 52,
          borderRadius: 12,
          onTap: _canSubmit ? _submit : null,
        ),

        const SizedBox(height: 24),
        _RecentRequests(
          requests: SampleData.leaveRequests
              .where((r) => r.type == LeaveType.annual)
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  IZIN FORM
// ─────────────────────────────────────────────────────────────
class _IzinForm extends StatefulWidget {
  const _IzinForm();

  @override
  State<_IzinForm> createState() => _IzinFormState();
}

class _IzinFormState extends State<_IzinForm> {
  LeaveType _type  = LeaveType.sick;
  DateTime? _start, _end;
  final _reasonCtrl = TextEditingController();
  String?   _fileName;
  bool      _submitting = false;

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  bool get _isSick    => _type == LeaveType.sick;
  bool get _isSeminar => _type == LeaveType.seminar;

  // bool _isDateValid() {
  //   if (_start == null) return true;
  //   final today = _today();
  //   return _isSick ? !_start!.isAfter(today) : !_start!.isBefore(today);
  // }

  bool _isDateValid() {
    if (_start == null) return true;
    final today = _today();

    // Semua jenis izin harus <= hari ini
    return !_start!.isAfter(today);
  }

  DateTime _today() => DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool get _canSubmit =>
      _start != null && _end != null &&
      _reasonCtrl.text.trim().isNotEmpty &&
      _fileName != null && _isDateValid();

  // Future<void> _pickDate(bool isStart) async {
  //   final today     = DateTime.now();
  //   final firstDate = _isSick
  //       ? today.subtract(const Duration(days: 30))
  //       : _today();
  //   final lastDate  = _isSick
  //       ? _today()
  //       : today.add(const Duration(days: 180));

  //   final initDate = isStart
  //       ? (_start ?? firstDate)
  //       : (_end ?? _start ?? firstDate);

  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate:
  //         initDate.isBefore(firstDate) ? firstDate :
  //         initDate.isAfter(lastDate)   ? lastDate  : initDate,
  //     firstDate: firstDate, lastDate: lastDate,
  //     builder: (ctx, child) => _datePicker(ctx, child),
  //   );
  //   if (picked == null) return;
  //   setState(() {
  //     if (isStart) {
  //       _start = picked;
  //       if (_end != null && _end!.isBefore(picked)) _end = picked;
  //     } else {
  //       _end = picked;
  //     }
  //   });
  // }

  Future<void> _pickDate(bool isStart) async {
  final today = _today();

  // Semua jenis izin hanya boleh sebelum / sampai hari ini
  final firstDate = today.subtract(const Duration(days: 30)); // optional range
  final lastDate  = today;

  final initDate = isStart
      ? (_start ?? lastDate)
      : (_end ?? _start ?? lastDate);

  final picked = await showDatePicker(
    context: context,
    initialDate: initDate.isBefore(firstDate)
        ? firstDate
        : initDate.isAfter(lastDate)
            ? lastDate
            : initDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (ctx, child) => _datePicker(ctx, child),
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

  String _typeLabel(LeaveType t) {
    switch (t) {
      case LeaveType.sick:    return 'Sakit';
      case LeaveType.seminar: return 'Seminar';
      case LeaveType.school:  return 'Sekolah';
      default:                return 'Izin';
    }
  }

  List<AllowanceType> get _allowances {
    switch (_type) {
      case LeaveType.sick:    return [AllowanceType.health];
      case LeaveType.seminar: return [AllowanceType.accommodation, AllowanceType.transport];
      case LeaveType.school:  return [AllowanceType.spp];
      default:                return [];
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

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _submitting = false; _start = null; _end = null;
      _reasonCtrl.clear(); _fileName = null;
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Text('✅', style: TextStyle(fontSize: 36), textAlign: TextAlign.center),
        title: const Text('Pengajuan Terkirim!', textAlign: TextAlign.center),
        content: Text('Pengajuan Izin ${_typeLabel(_type)} dikirim ke admin.',
            style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _type == LeaveType.sick
        ? AppColors.danger
        : _type == LeaveType.seminar
            ? AppColors.brandCyanDark
            : AppColors.brandNavy;
    final isDateInvalid = !_isSick &&
        _start != null && _start!.isBefore(_today());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Jenis selector ────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.slate200),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              LeaveType.sick, LeaveType.seminar, LeaveType.school,
            ].map((t) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _type = t; _start = null; _end = null; _fileName = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _type == t ? AppColors.brandNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(
                    _typeLabel(t),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _type == t ? Colors.white : AppColors.slate600,
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // Allowance info
        SectionCard(
          color: typeColor.withOpacity(0.05),
          borderColor: typeColor.withOpacity(0.2),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tunjangan yang diperoleh:',
                  style: AppText.label.copyWith(color: typeColor)),
              const SizedBox(height: 6),
              ..._allowances.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.brandLimeDark, size: 14),
                    const SizedBox(width: 6),
                    Text(_allowanceLabel(a), style: AppText.body2),
                  ],
                ),
              )),
              if (_isSick) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.brandCyanDark, size: 12),
                    const SizedBox(width: 4),
                    Text('Bisa retroaktif (maks 30 hari lalu)',
                        style: AppText.caption
                            .copyWith(color: AppColors.brandCyanDark)),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateField(
                label: _isSick ? 'TANGGAL SAKIT MULAI' : 'TANGGAL IZIN MULAI',
                value: _start,
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 14),
              _DateField(
                label: _isSick ? 'TANGGAL SAKIT SELESAI' : 'TANGGAL IZIN SELESAI',
                value: _end,
                onTap: _start == null ? null : () => _pickDate(false),
              ),

              if (isDateInvalid) ...[
                const SizedBox(height: 8),
                _InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  text: 'Tanggal tidak boleh sebelum hari ini',
                ),
              ],

              const SizedBox(height: 16),
              _FieldLabel(label: 'KETERANGAN / ALASAN'),
              const SizedBox(height: 6),
              _TextArea(
                controller: _reasonCtrl,
                hint: _isSick
                    ? 'Deskripsikan keluhan sakit kamu...'
                    : _isSeminar
                        ? 'Nama seminar, penyelenggara, lokasi...'
                        : 'Nama institusi, mata pelajaran/kuliah...',
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  _FieldLabel(
                      label: _isSeminar ? 'UPLOAD BUKTI (maks 2)' : 'UPLOAD BUKTI (maks 1)'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isSick
                    ? 'Wajib upload surat dokter'
                    : _isSeminar
                        ? 'Bukti pendaftaran & akomodasi'
                        : 'Bukti tagihan SPP',
                style: AppText.caption,
              ),
              const SizedBox(height: 8),
              _UploadArea(
                filename: _fileName,
                onTap: () => setState(() =>
                    _fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}.jpg'),
                onRemove: () => setState(() => _fileName = null),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        GradientButton(
          label: _submitting ? 'Mengirim...' : 'Submit Pengajuan Izin',
          color: _canSubmit ? AppColors.brandNavy : AppColors.slate200,
          isLoading: _submitting,
          height: 52,
          borderRadius: 12,
          onTap: _canSubmit ? _submit : null,
        ),

        const SizedBox(height: 24),
        _RecentRequests(
          requests: SampleData.leaveRequests
              .where((r) => r.type != LeaveType.annual)
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────

Widget _datePicker(BuildContext ctx, Widget? child) => Theme(
  data: Theme.of(ctx).copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.brandNavy, surface: AppColors.white,
    ),
  ),
  child: child!,
);

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B), letterSpacing: 0.8,
        ));
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppText.caption.copyWith(
                    color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback? onTap;
  final bool hasError;

  const _DateField({
    required this.label, this.value, this.onTap, this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: onTap == null ? AppColors.slate100 : AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError
                    ? AppColors.danger
                    : value != null
                        ? AppColors.brandNavy.withOpacity(0.45)
                        : AppColors.slate200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? fmt.format(value!) : 'MM/DD/YYYY',
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: value != null
                          ? AppColors.slate900
                          : AppColors.slate400,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: value != null ? AppColors.brandNavy : AppColors.slate400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TextArea extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _TextArea({
    required this.controller, required this.hint, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(color: AppColors.slate900, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.slate50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.slate200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.slate200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.brandNavy, width: 2)),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}

class _UploadArea extends StatelessWidget {
  final String? filename;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _UploadArea({this.filename, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final has = filename != null;
    return GestureDetector(
      onTap: has ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: has ? AppColors.brandLime.withOpacity(0.07) : AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has
                ? AppColors.brandLimeDark.withOpacity(0.4)
                : AppColors.slate200,
          ),
        ),
        child: has
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.brandLimeDark, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(filename!,
                        style: AppText.body2.copyWith(
                            color: AppColors.brandLimeDark),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.danger, size: 16),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.slate400, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text('Tap to capture or upload',
                      style: AppText.body1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700)),
                  const SizedBox(height: 2),
                  Text('JPG, PNG up to 5MB', style: AppText.caption),
                ],
              ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int remaining, used, quota, minAdvanceDays;
  const _BalanceCard({
    required this.remaining, required this.used,
    required this.quota, required this.minAdvanceDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandNavy.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access_rounded,
              color: AppColors.brandNavy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sisa Cuti Tahunan', style: AppText.label),
                Row(
                  children: [
                    Text('$remaining',
                        style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: AppColors.brandNavy,
                        )),
                    const SizedBox(width: 4),
                    Text('dari $quota hari/tahun', style: AppText.body2),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Digunakan: $used hr', style: AppText.caption),
              Text('Min. H-$minAdvanceDays', style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RECENT REQUESTS — with working filter
// ─────────────────────────────────────────────────────────────
class _RecentRequests extends StatefulWidget {
  final List<LeaveRequest> requests;
  const _RecentRequests({required this.requests});

  @override
  State<_RecentRequests> createState() => _RecentRequestsState();
}

class _RecentRequestsState extends State<_RecentRequests> {
  RequestStatus? _filterStatus; // null = semua

  String _typeLabel(LeaveType t) {
    switch (t) {
      case LeaveType.annual:  return 'Cuti Tahunan';
      case LeaveType.sick:    return 'Sakit (Sick Leave)';
      case LeaveType.seminar: return 'Seminar';
      case LeaveType.school:  return 'Sekolah (Study)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterStatus == null
        ? widget.requests
        : widget.requests.where((r) => r.status == _filterStatus).toList();

    if (widget.requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + filter ──────────────────────────
        Row(
          children: [
            Text('Recent Requests',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const Spacer(),
            // Filter dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.slate200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RequestStatus?>(
                  value: _filterStatus,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.slate600),
                  hint: Text('Semua Status',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.slate600)),
                  items: [
                    _dropdownItem(null, 'Semua'),
                    _dropdownItem(RequestStatus.pending, 'Menunggu'),
                    _dropdownItem(RequestStatus.approved, 'Disetujui'),
                    _dropdownItem(RequestStatus.rejected, 'Ditolak'),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v),
                  selectedItemBuilder: (ctx) => [
                    _selectedText('Semua'),
                    _selectedText('Menunggu'),
                    _selectedText('Disetujui'),
                    _selectedText('Ditolak'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Empty state ──────────────────────────────
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Tidak ada pengajuan dengan status ini.',
                  style: AppText.body2),
            ),
          )
        else
          ...filtered.map((r) {
            Color sc; String sl;
            switch (r.status) {
              case RequestStatus.pending:
                sc = AppColors.warning; sl = 'PENDING'; break;
              case RequestStatus.approved:
                sc = AppColors.brandLimeDark; sl = 'APPROVED'; break;
              case RequestStatus.rejected:
                sc = AppColors.danger; sl = 'REJECTED'; break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: sc.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(
                        r.status == RequestStatus.approved
                            ? Icons.check_rounded
                            : r.status == RequestStatus.rejected
                                ? Icons.close_rounded
                                : Icons.hourglass_top_rounded,
                        color: sc, size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(_typeLabel(r.type),
                                    style: AppText.body1.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.slate900)),
                              ),
                              _StatusBadge(label: sl, color: sc),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('dd MMM').format(r.startDate)} – '
                            '${DateFormat('dd MMM yyyy').format(r.endDate)}',
                            style: AppText.body2,
                          ),
                          if (r.adminNote != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: RichText(
                                text: TextSpan(
                                  style: AppText.body2,
                                  children: [
                                    TextSpan(
                                        text: 'Alasan: ',
                                        style: AppText.body2.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.danger)),
                                    TextSpan(text: r.adminNote),
                                  ],
                                ),
                              ),
                            )
                          else
                            Text(
                              r.status == RequestStatus.pending
                                  ? 'Waiting for supervisor review'
                                  : r.status == RequestStatus.approved
                                      ? 'Verified by HR Dept.'
                                      : '',
                              style: AppText.body2,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  DropdownMenuItem<RequestStatus?> _dropdownItem(
      RequestStatus? val, String label) {
    return DropdownMenuItem(
      value: val,
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate900)),
    );
  }

  Widget _selectedText(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.brandNavy));
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w800, color: color,
          )),
    );
  }
}
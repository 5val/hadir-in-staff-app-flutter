import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/work_date_picker.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/leave_service.dart';
import '../services/api_client.dart';
import '../services/overtime_service.dart';
import '../services/subordinate_service.dart';
import '../services/calendar_service.dart';
import 'all_leave_history_screen.dart';
import 'all_subordinate_leave_history_screen.dart';
import 'subordinate_requests_screen.dart';

/// Leave & Time Off tab — tampil langsung di MainScreen.
/// Tanpa re-verifikasi. Tab selector untuk: Pengajuan Karyawan (supervisor),
/// Ajukan Cuti, Ajukan Izin, dan Riwayat Pengajuan.
class LeaveTab extends StatefulWidget {
  const LeaveTab({super.key});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
  // Tab index:
  //   supervisor: 0=Karyawan, 1=Ajukan Cuti, 2=Ajukan Izin, 3=Riwayat
  //   non-supervisor: 0=Ajukan Cuti, 1=Ajukan Izin, 2=Riwayat
  int _selectedTab = 0;

  /// Fase 8: status "atasan" ditentukan SERVER lewat AuthorityGrant
  /// (`isApprover` pada respons subordinates), bukan lagi role dummy di app.
  bool get _isSupervisor => _subordinates.isApprover;

  bool _showAllHistory = false;
  LeaveType? _filterType;
  RequestStatus? _filterStatus;
  DateTime? _overtimeStartDate;
  DateTime? _overtimeEndDate;

  // Riwayat pengajuan cuti/izin milik staff (dari backend).
  List<LeaveRequest> _myLeaves = [];
  bool _loadingLeaves = true;
  String? _leaveError;

  // ── Lembur (Fase 8) ─────────────────────────────────────────
  /// Hari kerja yang memenuhi syarat lembur (H-3, checkout lewat jam pulang,
  /// hari libur dilewati) — SELURUHNYA dihitung backend.
  List<OvertimeEligibleDay> _overtimeDays = [];
  bool _loadingOvertime = true;
  String? _overtimeError;

  /// Riwayat pengajuan lembur — ditampilkan di tab "Riwayat" gabungan,
  /// menggantikan layar riwayat lembur terpisah yang dihapus.
  List<OvertimeRequestRecord> _myOvertime = [];

  // ── Pengajuan bawahan (Manager/SPV) — Fase 8 ────────────────
  /// Data asli dari `GET .../subordinates/requests`. Menggantikan
  /// `SampleData.subordinateLeaveRequests` yang tombol Setujui/Tolak-nya
  /// dulu hanya menutup dialog tanpa mengubah apa pun di database.
  SubordinateRequests _subordinates = SubordinateRequests.empty;
  bool _loadingSubordinates = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
    _loadOvertimeDays();
    _loadSubordinates();
  }

  Future<void> _loadSubordinates() async {
    setState(() => _loadingSubordinates = true);
    try {
      final data = await SubordinateService.load();
      if (!mounted) return;
      setState(() {
        _subordinates = data;
        _loadingSubordinates = false;
      });
    } on ApiException {
      if (!mounted) return;
      // Gagal memuat pengajuan bawahan tidak boleh mengunci tab lain.
      setState(() {
        _subordinates = SubordinateRequests.empty;
        _loadingSubordinates = false;
      });
    }
  }

  Future<void> _loadOvertimeDays() async {
    setState(() {
      _loadingOvertime = true;
      _overtimeError = null;
    });
    try {
      final days = await OvertimeService.eligibleDays();
      final history = await OvertimeService.history();
      if (!mounted) return;
      setState(() {
        _overtimeDays = days;
        _myOvertime = history;
        _loadingOvertime = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _overtimeError = e.message;
        _loadingOvertime = false;
      });
    }
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _loadingLeaves = true;
      _leaveError = null;
    });
    try {
      final list = await LeaveService.myLeaves();
      if (!mounted) return;
      setState(() {
        _myLeaves = list;
        _loadingLeaves = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _leaveError = e.message;
        _loadingLeaves = false;
      });
    }
  }

  List<LeaveRequest> get _filtered {
    var list = List<LeaveRequest>.from(_myLeaves);
    if (_filterType != null)
      list = list.where((r) => r.type == _filterType).toList();
    if (_filterStatus != null)
      list = list.where((r) => r.status == _filterStatus).toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  List<_TabDef> get _tabs => const [
        _TabDef(Icons.beach_access_rounded, 'Cuti'),
        _TabDef(Icons.medical_services_rounded, 'Izin'),
        _TabDef(Icons.more_time_rounded, 'Lembur'),
        _TabDef(Icons.history_rounded, 'Riwayat'),
      ];

  /// Setujui/tolak pengajuan bawahan — Fase 8: benar-benar mengubah status
  /// di database (dan memicu potong sisa cuti + notifikasi ke staff, lewat
  /// fungsi approval yang sama dengan portal web).
  Future<void> _respondToLeave(LeaveRequest app, bool approve) async {
    final name = app.employeeName ?? 'karyawan ini';
    final ok = await _confirmAction(approve, name);
    if (ok != true) return;

    try {
      await SubordinateService.respondLeave(
        leaveId: app.id,
        approve: approve,
      );
      if (!mounted) return;
      await _loadSubordinates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve
              ? 'Pengajuan $name disetujui.'
              : 'Pengajuan $name ditolak.'),
          backgroundColor:
              approve ? AppColors.brandLimeDark : AppColors.slate700,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<bool?> _confirmAction(bool approve, String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(
          approve ? Icons.check_circle_rounded : Icons.cancel_rounded,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  approve ? AppColors.brandLimeDark : AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.brandNavy,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEAVE & TIME OFF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: 1.2,
                  )),
              Text('Cuti & Izin',
                  style: AppText.headline2.copyWith(color: AppColors.white)),
            ],
          ),
          if (_isSupervisor) _buildSeeMyTeamButton(),
        ],
      ),
    );
  }

  Widget _buildSeeMyTeamButton() {
    final pendingCount = _subordinates.leave
        .where((r) => r.status == RequestStatus.pending)
        .length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SubordinateRequestsScreen(),
            ),
          );
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_alt_rounded,
                color: AppColors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'See My Team',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.brandOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$pendingCount',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: AppColors.brandNavy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: _tabs.asMap().entries.map((e) {
          final idx = e.key;
          final tab = e.value;
          final selected = idx == _selectedTab;

          // Show pending badge on "Cuti" tab for supervisor (since Cuti is now idx == 0)
          final pendingCount = (_isSupervisor && idx == 0)
              ? _subordinates.leave
                  .where((r) => r.status == RequestStatus.pending)
                  .length
              : 0;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = idx;
                _showAllHistory = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: idx < _tabs.length - 1 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.white.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.white.withOpacity(0.4)
                        : AppColors.white.withOpacity(0.12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(tab.icon,
                            size: 18,
                            color: selected
                                ? AppColors.white
                                : AppColors.white.withOpacity(0.55)),
                        if (pendingCount > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: AppColors.brandOrange,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$pendingCount',
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.white
                            : AppColors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab Content ──────────────────────────────────────────
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildCutiTab();
      case 1:
        return _buildIzinTab();
      case 2:
        return _buildLemburTab();
      case 3:
        return _buildRiwayatTab();
    }
    return const SizedBox();
  }

  // ── Employee Tab (supervisor) ────────────────────────────
  Widget _buildEmployeeTab() {
    if (_loadingSubordinates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final apps = _subordinates.leave;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Header row with "Lihat Riwayat" button
        Row(
          children: [
            Text('Pengajuan Karyawan',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AllSubordinateLeaveHistoryScreen()),
              ),
              icon: const Icon(Icons.history_rounded,
                  size: 14, color: AppColors.brandNavy),
              label: Text('Semua Riwayat',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandNavy)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (apps.isEmpty)
          SectionCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('Tidak ada pengajuan masuk', style: AppText.body2),
                  ],
                ),
              ),
            ),
          )
        else
          ...apps.asMap().entries.map((e) {
            final app = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                padding: EdgeInsets.zero,
                child: _EmployeeAppTile(
                  app: app,
                  onApprove: () => _respondToLeave(app, true),
                  onReject: () => _respondToLeave(app, false),
                ),
              ),
            );
          }),
      ],
    );
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

  // ── Lembur Tab ───────────────────────────────────────────
  // ── Lembur Tab ───────────────────────────────────────────
  //
  // Fase 8 — ditulis ulang total. Sebelumnya tab ini memfilter
  // `SampleData.recentAttendance` (data dummy di memori) dan "mengajukan"
  // lembur hanya dengan menandai objek dummy itu `overtimeApplied = true`,
  // yang hilang begitu app ditutup. Tidak ada satu pun panggilan API.
  //
  // Sekarang seluruh isinya datang dari backend
  // (`GET .../lembur/eligible-days`), yang menerapkan tiga aturan produk:
  //   1. hanya 3 HARI KERJA terakhir (H-3) — akhir pekan & hari libur
  //      dilewati, jadi kalau hari ini Senin yang muncul Jumat/Kamis/Rabu;
  //   2. hanya hari yang checkout-nya memang melewati jam pulang shift —
  //      kalau tidak ada, daftarnya kosong (bukan "3 lembur terakhir");
  //   3. tidak bisa diajukan bila gaji periode tersebut sudah ditutup.
  //
  // Sub-tab "Riwayat Pengajuan Lembur" juga dihapus dari sini — riwayatnya
  // digabung ke tab "Riwayat" bersama cuti & izin.
  Widget _buildLemburTab() {
    final df = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

    if (_loadingOvertime) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_overtimeError != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 40, color: AppColors.slate400),
                  const SizedBox(height: 10),
                  Text(_overtimeError!,
                      textAlign: TextAlign.center, style: AppText.body2),
                  const SizedBox(height: 14),
                  ElevatedButton(
                      onPressed: _loadOvertimeDays,
                      child: const Text('Coba Lagi')),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOvertimeDays,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Info batas lembur — angkanya dari Jabatan.maxExtraHour di DB.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brandNavy,
                  AppColors.brandNavy.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_time_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Batas Maksimal Lembur Anda',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 2),
                      Text(
                        '${AppSession.staff?.maxExtraHour ?? 4} Jam / Pengajuan',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text('Hari yang Bisa Diajukan',
                  style:
                      AppText.headline3.copyWith(color: AppColors.slate900)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_overtimeDays.length}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandOrange)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Menampilkan maksimal 3 hari kerja terakhir yang jam pulangnya '
            'melebihi jam pulang shift. Hari libur tidak dihitung.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),

          if (_overtimeDays.isEmpty)
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('OK', style: TextStyle(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada hari yang bisa diajukan lembur.\n'
                      'Lembur baru muncul di sini bila check-out Anda '
                      'melewati jam pulang shift.',
                      textAlign: TextAlign.center,
                      style: AppText.body2.copyWith(color: AppColors.slate600),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._overtimeDays.map((day) => _buildOvertimeDayCard(day, df)),
        ],
      ),
    );
  }

  Widget _buildOvertimeDayCard(OvertimeEligibleDay day, DateFormat df) {
    final jam = day.menitLewatJamPulang ~/ 60;
    final menit = day.menitLewatJamPulang % 60;
    final lebihStr = jam > 0 ? '$jam jam $menit menit' : '$menit menit';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(df.format(day.tanggal),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800)),
            const SizedBox(height: 10),
            const AppDivider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.login_rounded,
                    size: 16, color: AppColors.slate700),
                const SizedBox(width: 6),
                Text('Check-in: ${day.checkIn ?? '-'}', style: AppText.body2),
                const SizedBox(width: 16),
                const Icon(Icons.logout_rounded,
                    size: 16, color: AppColors.slate700),
                const SizedBox(width: 6),
                Text('Check-out: ${day.checkOut ?? '-'}',
                    style: AppText.body2),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 16, color: AppColors.slate700),
                const SizedBox(width: 6),
                Text('Pulang shift: ${day.jamPulangShift}',
                    style: AppText.body2),
                const Spacer(),
                Text('Kelebihan: $lebihStr',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandOrange)),
              ],
            ),
            const SizedBox(height: 14),
            if (day.bisaDiajukan)
              GradientButton(
                label: 'Ajukan Lembur',
                height: 40,
                color: AppColors.brandNavy,
                onTap: () => _showOvertimeDialog(day, df.format(day.tanggal)),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                        day.sudahDiajukan
                            ? Icons.hourglass_top_rounded
                            : Icons.lock_rounded,
                        size: 16,
                        color: AppColors.slate600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        day.alasanTidakBisa ?? 'Tidak bisa diajukan.',
                        style: AppText.caption,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Dialog pengajuan lembur -> kirim ke backend (bukan lagi menandai objek
  /// dummy di memori). Jam mulai default = jam pulang shift.
  void _showOvertimeDialog(OvertimeEligibleDay day, String dateStr) async {
    final maxHours = (AppSession.staff?.maxExtraHour ?? 4).toDouble();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _OvertimeRequestDialog(maxOvertimeHours: maxHours, dateStr: dateStr),
    );
    if (result == null) return;

    final hours = result['hours'] as double;
    final reason = result['reason'] as String;

    // jamMulai = jam pulang shift; jamSelesai = jamMulai + durasi diajukan.
    final parts = day.jamPulangShift.split(':');
    final startMin = (int.tryParse(parts.first) ?? 17) * 60 +
        (int.tryParse(parts.last) ?? 0);
    final endMin = startMin + (hours * 60).round();
    String fmt(int m) =>
        '${((m ~/ 60) % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    try {
      await OvertimeService.submit(
        tanggal: day.tanggal,
        jamMulai: fmt(startMin),
        jamSelesai: fmt(endMin),
        alasan: reason,
      );
      if (!mounted) return;
      await _loadOvertimeDays();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.brandLimeDark, shape: BoxShape.circle),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
          title:
              const Text('Pengajuan Berhasil!', textAlign: TextAlign.center),
          content: Text('Pengajuan lembur telah dikirim ke atasan Anda.',
              style: AppText.body2, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'))
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    }
  }

  // ── Cuti Tab ─────────────────────────────────────────────
  Widget _buildCutiTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.slate100)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.beach_access_rounded,
                          color: AppColors.brandNavy, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ajukan Cuti Tahunan',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate900)),
                        Text('Dari jatah cuti tahunan kamu',
                            style: AppText.body2),
                      ],
                    ),
                  ],
                ),
              ),
              _CutiForm(onSubmitted: _loadLeaves),
            ],
          ),
        ),
      ],
    );
  }

  // ── Izin Tab ─────────────────────────────────────────────
  Widget _buildIzinTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.slate100)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.brandCyanDark.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.medical_services_rounded,
                          color: AppColors.brandCyanDark, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ajukan Izin',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate900)),
                        Text('Sakit, seminar, atau keperluan lainnya',
                            style: AppText.body2),
                      ],
                    ),
                  ],
                ),
              ),
              _IzinForm(onSubmitted: _loadLeaves),
            ],
          ),
        ),
      ],
    );
  }

  // ── Riwayat Tab ──────────────────────────────────────────
  Widget _buildRiwayatTab() {
    if (_loadingLeaves) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.brandNavy));
    }
    if (_leaveError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.slate400),
              const SizedBox(height: 12),
              Text(_leaveError!,
                  textAlign: TextAlign.center, style: AppText.body2),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadLeaves,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_showAllHistory) {
      return Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() => _showAllHistory = false),
              ),
              Text('Semua Riwayat',
                  style: AppText.headline3.copyWith(color: AppColors.slate900)),
            ],
          ),
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
                        onTap: () => setState(() => _filterType =
                            _filterType == LeaveType.annual
                                ? null
                                : LeaveType.annual),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Sakit',
                        icon: Icons.local_hospital_rounded,
                        selected: _filterType == LeaveType.sick,
                        onTap: () => setState(() => _filterType =
                            _filterType == LeaveType.sick
                                ? null
                                : LeaveType.sick),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Seminar',
                        icon: Icons.school_rounded,
                        selected: _filterType == LeaveType.seminar,
                        onTap: () => setState(() => _filterType =
                            _filterType == LeaveType.seminar
                                ? null
                                : LeaveType.seminar),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Lainnya',
                        icon: Icons.event_note_rounded,
                        selected: _filterType == LeaveType.school,
                        onTap: () => setState(() => _filterType =
                            _filterType == LeaveType.school
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
                        onTap: () => setState(() => _filterStatus = null),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Menunggu',
                        color: AppColors.brandOrange,
                        selected: _filterStatus == RequestStatus.pending,
                        onTap: () => setState(() => _filterStatus =
                            _filterStatus == RequestStatus.pending
                                ? null
                                : RequestStatus.pending),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Disetujui',
                        color: AppColors.brandLimeDark,
                        selected: _filterStatus == RequestStatus.approved,
                        onTap: () => setState(() => _filterStatus =
                            _filterStatus == RequestStatus.approved
                                ? null
                                : RequestStatus.approved),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Ditolak',
                        color: AppColors.danger,
                        selected: _filterStatus == RequestStatus.rejected,
                        onTap: () => setState(() => _filterStatus =
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
          ),
          Expanded(
            child: _filtered.isEmpty
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
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final req = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SectionCard(
                          padding: EdgeInsets.zero,
                          child: _RequestHistoryTile(request: req),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    final requests = _myLeaves
        .where((r) => r.submittedAt
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Riwayat Pengajuanmu',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            TextButton(
              onPressed: () => setState(() {
                _filterType = null;
                _filterStatus = null;
                _showAllHistory = true;
              }),
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
                final req = e.value;
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

        // ── Riwayat Lembur ──────────────────────────────────
        //
        // Fase 8: digabung ke sini sesuai permintaan ("riwayat pengajuan
        // lembur dijadikan satu di tab Riwayat"). Tab Lembur kini murni
        // berisi daftar hari yang bisa diajukan, dan layar
        // `overtime_history_screen.dart` yang berbasis data dummy dihapus.
        const SizedBox(height: 20),
        Text('Riwayat Pengajuan Lembur',
            style: AppText.headline3.copyWith(color: AppColors.slate900)),
        const SizedBox(height: 8),
        if (_myOvertime.isEmpty)
          SectionCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Text('Belum ada pengajuan lembur', style: AppText.body2),
              ),
            ),
          )
        else
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _myOvertime.asMap().entries.map((e) {
                final isLast = e.key == _myOvertime.length - 1;
                return Column(
                  children: [
                    _OvertimeHistoryTile(record: e.value),
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

/// Satu baris riwayat lembur — data asli dari tabel `overtime_request`.
class _OvertimeHistoryTile extends StatelessWidget {
  final OvertimeRequestRecord record;

  const _OvertimeHistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, d MMM yyyy', 'id_ID');

    late final Color color;
    late final String label;
    switch (record.status) {
      case 'approved':
        color = AppColors.brandLimeDark;
        label = 'Disetujui';
        break;
      case 'rejected':
        color = AppColors.danger;
        label = 'Ditolak';
        break;
      default:
        color = AppColors.brandOrange;
        label = 'Menunggu';
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.more_time_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(df.format(record.tanggal),
                    style: AppText.body1
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${record.jamMulai} – ${record.jamSelesai} '
                  '(${record.durasiJam.toStringAsFixed(record.durasiJam % 1 == 0 ? 0 : 1)} jam)',
                  style: AppText.caption,
                ),
                if (record.alasan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(record.alasan, style: AppText.caption),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Tab Definition ────────────────────────────────────────────
class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef(this.icon, this.label);
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

  String get _initials =>
      app.employeeName!.split(' ').map((w) => w[0]).take(2).join();

  String get _typeLabel {
    switch (app.type) {
      case LeaveType.annual:
        return 'Cuti Tahunan';
      case LeaveType.sick:
        return 'Izin Sakit';
      case LeaveType.seminar:
        return 'Izin Seminar';
      case LeaveType.school:
        return 'Izin Lainnya';
      default:
        return 'Izin Lainnya';
    }
  }

  IconData get _typeIcon {
    switch (app.type) {
      case LeaveType.annual:
        return Icons.beach_access_rounded;
      case LeaveType.sick:
        return Icons.local_hospital_rounded;
      case LeaveType.seminar:
        return Icons.school_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  Color get _statusColor {
    switch (app.status) {
      case RequestStatus.approved:
        return AppColors.brandLimeDark;
      case RequestStatus.rejected:
        return AppColors.danger;
      case RequestStatus.pending:
        return AppColors.brandOrange;
    }
  }

  String get _statusLabel {
    switch (app.status) {
      case RequestStatus.approved:
        return 'DISETUJUI';
      case RequestStatus.rejected:
        return 'DITOLAK';
      case RequestStatus.pending:
        return 'MENUNGGU';
    }
  }

  String _allowanceLabel(AllowanceType a) {
    switch (a) {
      case AllowanceType.health:
        return 'Surat Dokter';
      case AllowanceType.accommodation:
        return 'Resep';
      case AllowanceType.transport:
        return 'Nota Transportasi';
      case AllowanceType.spp:
        return 'Konsumsi';
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withOpacity(0.25)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandCyanDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.brandCyanDark.withOpacity(0.2)),
                  ),
                  child: Text(
                    _allowanceLabel(a),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
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
                      app.employeeName!
                          .split(' ')
                          .map((w) => w[0])
                          .take(2)
                          .join(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
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
            if (app.reason != null) _DetailRow('Alasan', app.reason!),
            _DetailRow('Diajukan', ft.format(app.submittedAt)),
            if (app.allowances.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Tunjangan Diminta',
                  style: AppText.label.copyWith(color: AppColors.slate700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: app.allowances
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.brandCyanDark.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.brandCyanDark.withOpacity(0.2)),
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
  final VoidCallback? onSubmitted;
  const _CutiForm({this.onSubmitted});
  @override
  State<_CutiForm> createState() => _CutiFormState();
}

class _CutiFormState extends State<_CutiForm> {
  final user = SampleData.currentUser;
  DateTime? _start, _end;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // Sisa & jatah cuti dari profil backend (fallback ke quota jabatan dummy).
  int get _quota =>
      AppSession.staff?.totalCuti ?? user.position.annualLeaveQuota;
  int get _remaining => AppSession.staff?.sisaCuti ?? _quota;
  int get _days => (_start == null || _end == null)
      ? 0
      : _end!.difference(_start!).inDays + 1;

  bool get _canSubmit {
    if (_start == null || _end == null) return false;
    if (_reasonCtrl.text.trim().isEmpty) return false;
    if (_days > _remaining) return false;
    final minDate =
        DateTime.now().add(Duration(days: user.position.minLeaveAdvanceDays));
    return !_start!.isBefore(minDate);
  }

  Future<void> _pickDate(bool isStart) async {
    final minDate =
        DateTime.now().add(Duration(days: user.position.minLeaveAdvanceDays));
    // Fase 8: hari libur & hari non-kerja shift di-disable di picker.
    final picked = await showWorkDatePicker(
      context: context,
      initialDate: isStart ? (_start ?? minDate) : (_end ?? _start ?? minDate),
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
    try {
      await LeaveService.create(
        tipe: 'Cuti',
        subTipe: 'Cuti Tahunan',
        alasan: _reasonCtrl.text.trim(),
        tanggalMulai: _start!,
        tanggalSelesai: _end!,
        jumlahHari: _days,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _start = null;
      _end = null;
      _reasonCtrl.clear();
    });
    widget.onSubmitted?.call();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
              color: AppColors.brandLimeDark, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
        ),
        title: const Text('Pengajuan Berhasil!', textAlign: TextAlign.center),
        content: Text('Pengajuan cuti telah dikirim ke admin.',
            style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
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
                  '$_remaining dari $_quota hari',
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
            textColor: _canSubmit ? Colors.white : AppColors.slate700,
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
// Sekolah → Others (maks 1 foto)
// ═══════════════════════════════════════════════════════════
class _IzinForm extends StatefulWidget {
  final VoidCallback? onSubmitted;
  const _IzinForm({this.onSubmitted});
  @override
  State<_IzinForm> createState() => _IzinFormState();
}

class _IzinFormState extends State<_IzinForm> {
  String? _type;
  DateTime? _startDate;
  DateTime? _endDate;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  // Photo slot: max 1 for Others, specific for Sakit/Seminar
  _PhotoSlot? _photoSlot;

  static const _types = [
    ('Sakit', Icons.local_hospital_rounded),
    ('Seminar', Icons.school_rounded),
    ('Lainnya', Icons.event_note_rounded),
  ];

  // Returns null if no photo required for this type
  (String, IconData)? _slotDefFor(String type) {
    switch (type) {
      case 'Sakit':
        return ('Surat Dokter / Resep', Icons.medical_information_rounded);
      case 'Seminar':
        return ('Bukti Transportasi/Konsumsi', Icons.receipt_long_rounded);
      case 'Lainnya':
        return ('Foto Pendukung', Icons.image_rounded);
      default:
        return null;
    }
  }

  List<AllowanceType> get _allowances {
    switch (_type) {
      case 'Sakit':
        return [AllowanceType.health];
      case 'Seminar':
        return [AllowanceType.transport, AllowanceType.accommodation];
      default:
        return [];
    }
  }

  void _onTypeChanged(String type) {
    final def = _slotDefFor(type);
    setState(() {
      _type = type;
      _photoSlot = def != null ? _PhotoSlot(label: def.$1, icon: def.$2) : null;
    });
  }

  bool get _canSubmit {
    if (_type == null) return false;
    if (_startDate == null || _endDate == null) return false;
    if (_noteCtrl.text.trim().isEmpty) return false;
    // For Sakit and Seminar, photo is required
    if ((_type == 'Sakit' || _type == 'Seminar') &&
        (_photoSlot == null || !_photoSlot!.uploaded)) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    // Petakan jenis izin UI → tipe/subTipe backend.
    final String tipe = _type == 'Sakit' ? 'Sakit' : 'Izin';
    final String subTipe = _type == 'Sakit' ? '' : (_type ?? '');
    final int jumlahHari = _endDate!.difference(_startDate!).inDays + 1;

    setState(() => _submitting = true);
    try {
      await LeaveService.create(
        tipe: tipe,
        subTipe: subTipe,
        alasan: _noteCtrl.text.trim(),
        tanggalMulai: _startDate!,
        tanggalSelesai: _endDate!,
        jumlahHari: jumlahHari,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _type = null;
      _startDate = null;
      _endDate = null;
      _photoSlot = null;
      _noteCtrl.clear();
    });
    widget.onSubmitted?.call();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
              color: AppColors.brandCyanDark, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
        ),
        title: const Text('Pengajuan Terkirim!', textAlign: TextAlign.center),
        content: Text('Pengajuan izin kamu sedang diproses.',
            style: AppText.body2, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    final picked = await showWorkDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        if (_endDate != null && _endDate!.isBefore(picked)) {
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
                    final picked = await showWorkDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate ?? DateTime.now(),
                      firstDate: _startDate ??
                          DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                ),
              ),
            ],
          ),

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

          // ── Photo upload (max 1) ───────────────────────
          if (_photoSlot != null) ...[
            const SizedBox(height: 16),
            _buildPhotoSection(),
          ],

          const SizedBox(height: 16),

          GradientButton(
            label: 'Kirim Pengajuan Izin',
            color: _canSubmit ? AppColors.brandCyanDark : AppColors.slate300,
            textColor: _canSubmit ? Colors.white : AppColors.slate700,
            isLoading: _submitting,
            height: 48,
            onTap: _canSubmit && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    final slot = _photoSlot!;
    final required = _type == 'Sakit' || _type == 'Seminar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Lampiran Foto', style: AppText.label),
            const SizedBox(width: 6),
            if (required)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Wajib',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Opsional',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate600)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Maks. 1 foto pendukung.',
          style: AppText.body2.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 10),
        _PhotoUploadSlot(
          slot: slot,
          index: 1,
          onUpload: () {
            setState(() {
              _photoSlot = _PhotoSlot.uploaded(slot.label, slot.icon);
            });
          },
          onRemove: () {
            setState(() {
              _photoSlot = _PhotoSlot(label: slot.label, icon: slot.icon);
            });
          },
        ),
        if (_allowances.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandCyanDark.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.brandCyanDark.withOpacity(0.15)),
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
      case AllowanceType.health:
        return 'Surat Dokter';
      case AllowanceType.accommodation:
        return 'Resep';
      case AllowanceType.transport:
        return 'Nota Transportasi';
      case AllowanceType.spp:
        return 'Konsumsi';
    }
  }
}

// ── Photo Slot Model ─────────────────────────────────────────
class _PhotoSlot {
  final String label;
  final IconData icon;
  final String? filePath;

  const _PhotoSlot({required this.label, required this.icon}) : filePath = null;

  const _PhotoSlot.uploaded(this.label, this.icon)
      : filePath = 'mock_photo_path';

  bool get uploaded => filePath != null;
}

// ── Photo Upload Slot Widget ──────────────────────────────────
class _PhotoUploadSlot extends StatelessWidget {
  final _PhotoSlot slot;
  final int index;
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
          ),
        ),
        child: Row(
          children: [
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
                slot.uploaded ? Icons.check_circle_rounded : slot.icon,
                size: 18,
                color: slot.uploaded
                    ? AppColors.brandLimeDark
                    : AppColors.slate700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.label,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
  final String label;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      case RequestStatus.approved:
        return AppColors.brandLimeDark;
      case RequestStatus.rejected:
        return AppColors.danger;
      case RequestStatus.pending:
        return AppColors.brandOrange;
    }
  }

  String get _statusLabel {
    switch (request.status) {
      case RequestStatus.approved:
        return 'DISETUJUI';
      case RequestStatus.rejected:
        return 'DITOLAK';
      case RequestStatus.pending:
        return 'MENUNGGU';
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM', 'id_ID');
    return GestureDetector(
      onTap: () => _showDetail(context),
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
                    request.type == LeaveType.annual ? 'Cuti Tahunan' : 'Izin',
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 16),
            _DetailRow('Jenis',
                request.type == LeaveType.annual ? 'Cuti Tahunan' : 'Izin'),
            _DetailRow('Tanggal Mulai', f.format(request.startDate)),
            _DetailRow('Tanggal Selesai', f.format(request.endDate)),
            _DetailRow('Durasi', '${request.dayCount} hari'),
            _DetailRow('Status', _statusLabel),
            _DetailRow('Diajukan',
                DateFormat('dd MMM yyyy, HH:mm').format(request.submittedAt)),
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
            child: Text(
              label,
              style: AppText.body2,
              textAlign: TextAlign.start,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.start,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

// ── Filter Chip ───────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
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

// ── Summary Chip ──────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
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
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// OVERTIME REQUEST DIALOG
// ═══════════════════════════════════════════════════════════
class _OvertimeRequestDialog extends StatefulWidget {
  final double maxOvertimeHours;
  final String dateStr;

  const _OvertimeRequestDialog({
    required this.maxOvertimeHours,
    required this.dateStr,
  });

  @override
  State<_OvertimeRequestDialog> createState() => _OvertimeRequestDialogState();
}

class _OvertimeRequestDialogState extends State<_OvertimeRequestDialog> {
  final _hoursCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      title: Column(
        children: [
          const Icon(Icons.more_time_rounded,
              color: AppColors.brandNavy, size: 36),
          const SizedBox(height: 10),
          Text(
            'Ajukan Lembur',
            style: AppText.headline3.copyWith(color: AppColors.slate900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            widget.dateStr,
            style: AppText.body2.copyWith(color: AppColors.slate700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.brandOrange.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.brandOrange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Batas lembur Anda: ${widget.maxOvertimeHours} jam',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Durasi Lembur (Jam)', style: AppText.label),
              const SizedBox(height: 6),
              TextFormField(
                controller: _hoursCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Contoh: 1.5 atau 2',
                  suffixText: 'jam',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Masukkan durasi lembur';
                  }
                  final hours = double.tryParse(val);
                  if (hours == null) {
                    return 'Masukkan angka desimal yang valid';
                  }
                  if (hours <= 0) {
                    return 'Durasi harus lebih dari 0';
                  }
                  if (hours > widget.maxOvertimeHours) {
                    return 'Tidak boleh melebihi ${widget.maxOvertimeHours} jam';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Text('Alasan Lembur', style: AppText.label),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Menyelesaikan laporan bulanan IT...',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Masukkan alasan lembur';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandNavy,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'hours': double.parse(_hoursCtrl.text),
                'reason': _reasonCtrl.text.trim(),
              });
            }
          },
          child: Text(
            'Kirim',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

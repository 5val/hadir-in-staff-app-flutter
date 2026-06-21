import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'account_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model untuk absensi staff (tampilan admin)
// ─────────────────────────────────────────────────────────────────────────────
class StaffAttendanceEntry {
  final UserProfile staff;
  final AttendanceStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? locationLabel;
  final int? lateMinutes;

  const StaffAttendanceEntry({
    required this.staff,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.locationLabel,
    this.lateMinutes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard Tab (2 tab internal: Dashboard & List Absensi)
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  int _tab = 0;

  void _onTabTap(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: Column(
        children: [
          if (_tab != 2) _buildHeader(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _DashboardView(),
                _AttendanceListView(),
                AccountTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppColors.white,
      elevation: 8,
      shadowColor: AppColors.brandNavy.withOpacity(0.1),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: _tab == 0,
              onTap: () => _onTabTap(0),
            ),
            _NavItem(
              icon: Icons.fact_check_rounded,
              label: 'List Absensi',
              selected: _tab == 1,
              onTap: () => _onTabTap(1),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Akun',
              selected: _tab == 2,
              onTap: () => _onTabTap(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.brandNavy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                child: Image.asset(
                  AppAssets.logoIcon,
                  height: 28,
                  // color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PANEL ADMIN',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      )),
                  Text('Hadir-In',
                      style:
                          AppText.headline2.copyWith(color: AppColors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandNavy : AppColors.slate400;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Dashboard — Statistik & Produktivitas
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardView extends StatelessWidget {
  const _DashboardView();

  // Mock statistik
  static final List<StaffAttendanceEntry> _todayData = _generateTodayData();

  static List<StaffAttendanceEntry> _generateTodayData() {
    final staffList =
        SampleData.allUsers.where((u) => u.role != UserRole.admin).toList();

    final now = DateTime.now();
    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.late,
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.leave,
    ];

    return List.generate(staffList.length, (i) {
      final status = statuses[i % statuses.length];
      return StaffAttendanceEntry(
        staff: staffList[i],
        status: status,
        checkIn: (status == AttendanceStatus.present ||
                status == AttendanceStatus.late)
            ? now.subtract(Duration(hours: 8 - i, minutes: i * 5))
            : null,
        checkOut: (status == AttendanceStatus.present)
            ? now.subtract(Duration(minutes: 30 + i * 10))
            : null,
        locationLabel: 'Kantor Pusat',
        lateMinutes: status == AttendanceStatus.late ? (15 + i * 5) : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _todayData;
    final totalStaff = data.length;
    final hadir =
        data.where((e) => e.status == AttendanceStatus.present).length;
    final terlambat =
        data.where((e) => e.status == AttendanceStatus.late).length;
    final absen = data.where((e) => e.status == AttendanceStatus.absent).length;
    final cuti = data.where((e) => e.status == AttendanceStatus.leave).length;
    final hadirTotal = hadir + terlambat;
    final pct = totalStaff > 0 ? hadirTotal / totalStaff : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tanggal hari ini
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.brandNavy),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                      .format(DateTime.now()),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandNavy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statistik kehadiran hari ini
          Text('Kehadiran Hari Ini',
              style: AppText.headline3.copyWith(color: AppColors.slate800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Staff',
                  value: '$totalStaff',
                  icon: Icons.groups_rounded,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Hadir',
                  value: '$hadir',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.brandLimeDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Terlambat',
                  value: '$terlambat',
                  icon: Icons.schedule_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Absen',
                  value: '$absen',
                  icon: Icons.cancel_rounded,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatCard(
            label: 'Cuti / Izin',
            value: '$cuti',
            icon: Icons.event_busy_rounded,
            color: AppColors.brandNavyLight,
            fullWidth: true,
          ),

          const SizedBox(height: 20),

          // Progress kehadiran
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandNavy.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tingkat Kehadiran',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                        )),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: pct >= 0.8
                            ? AppColors.brandLimeDark
                            : pct >= 0.6
                                ? AppColors.warning
                                : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 12,
                    backgroundColor: AppColors.slate100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 0.8
                          ? AppColors.brandLimeDark
                          : pct >= 0.6
                              ? AppColors.warning
                              : AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$hadirTotal dari $totalStaff staff hadir',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.slate700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Produktivitas
          Text('Produktivitas',
              style: AppText.headline3.copyWith(color: AppColors.slate800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandNavy.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _ProductivityRow(
                  label: 'Rata-rata Jam Kerja',
                  value: '7 jam 45 menit',
                  icon: Icons.timer_rounded,
                  color: AppColors.brandNavy,
                ),
                const Divider(height: 20),
                _ProductivityRow(
                  label: 'Tepat Waktu',
                  value:
                      '${totalStaff > 0 ? ((hadir / (hadir + terlambat).clamp(1, 9999)) * 100).toStringAsFixed(0) : 0}%',
                  icon: Icons.verified_rounded,
                  color: AppColors.brandLimeDark,
                ),
                const Divider(height: 20),
                _ProductivityRow(
                  label: 'Tingkat Absensi',
                  value:
                      '${totalStaff > 0 ? ((absen / totalStaff) * 100).toStringAsFixed(0) : 0}%',
                  icon: Icons.trending_down_rounded,
                  color: AppColors.danger,
                ),
                const Divider(height: 20),
                _ProductivityRow(
                  label: 'Staff Aktif Bulan Ini',
                  value: '${totalStaff - absen}',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.brandCyanDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Ringkasan staff per status (hari ini)
          Text('Status Staff Hari Ini',
              style: AppText.headline3.copyWith(color: AppColors.slate800)),
          const SizedBox(height: 12),
          ...data.map((e) => _StaffStatusRow(entry: e)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: List Absensi — Dengan filter tanggal & nama staff
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceListView extends StatefulWidget {
  const _AttendanceListView();

  @override
  State<_AttendanceListView> createState() => _AttendanceListViewState();
}

class _AttendanceListViewState extends State<_AttendanceListView> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedStaffId; // null = semua staff

  final List<UserProfile> _allStaff =
      SampleData.allUsers.where((u) => u.role != UserRole.admin).toList();

  // Generate data absensi mock berdasarkan tanggal
  List<StaffAttendanceEntry> _generateData(DateTime date) {
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.late,
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.leave,
    ];

    return List.generate(_allStaff.length, (i) {
      final status = isPast || isToday
          ? statuses[i % statuses.length]
          : AttendanceStatus.absent; // hari depan belum ada data

      return StaffAttendanceEntry(
        staff: _allStaff[i],
        status: status,
        checkIn: (status == AttendanceStatus.present ||
                status == AttendanceStatus.late)
            ? DateTime(date.year, date.month, date.day, 8 + (i % 2), i * 3 % 30)
            : null,
        checkOut: (status == AttendanceStatus.present && (isPast || isToday))
            ? DateTime(date.year, date.month, date.day, 17, (i * 7) % 30)
            : null,
        locationLabel: i % 2 == 0 ? 'Kantor Pusat' : 'Remote',
        lateMinutes: status == AttendanceStatus.late ? (10 + i * 5) : null,
      );
    });
  }

  List<StaffAttendanceEntry> get _filteredData {
    final all = _generateData(_selectedDate);
    if (_selectedStaffId == null) return all;
    return all.where((e) => e.staff.id == _selectedStaffId).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.brandNavy,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredData;

    return Column(
      children: [
        // ── Filter Bar ─────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate400,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Filter tanggal
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.slate200),
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.slate50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 16, color: AppColors.brandNavy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('d MMM yyyy').format(_selectedDate),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded,
                                color: AppColors.slate400, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Filter nama staff
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.slate200),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.slate50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedStaffId,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: AppColors.slate400, size: 18),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate800,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  const Icon(Icons.groups_rounded,
                                      size: 16, color: AppColors.slate400),
                                  const SizedBox(width: 6),
                                  Text('Semua Staff',
                                      style: GoogleFonts.inter(fontSize: 13)),
                                ],
                              ),
                            ),
                            ..._allStaff.map((s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text(s.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 13)),
                                )),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedStaffId = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Ringkasan kecil ────────────────────────────────────
        Container(
          color: AppColors.slate50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${data.length} entri',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700),
              ),
              const Spacer(),
              _MiniChip(
                label:
                    '${data.where((e) => e.status == AttendanceStatus.present).length} Hadir',
                color: AppColors.brandLimeDark,
              ),
              const SizedBox(width: 6),
              _MiniChip(
                label:
                    '${data.where((e) => e.status == AttendanceStatus.late).length} Terlambat',
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              _MiniChip(
                label:
                    '${data.where((e) => e.status == AttendanceStatus.absent).length} Absen',
                color: AppColors.danger,
              ),
            ],
          ),
        ),

        // ── List ───────────────────────────────────────────────
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 48, color: AppColors.slate300),
                      const SizedBox(height: 12),
                      Text('Tidak ada data',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.slate400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: data.length,
                  itemBuilder: (ctx, i) => _AttendanceCard(entry: data[i]),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.slate700)),
              Text(value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductivityRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _ProductivityRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.slate600)),
        ),
        Text(value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            )),
      ],
    );
  }
}

class _StaffStatusRow extends StatelessWidget {
  final StaffAttendanceEntry entry;

  const _StaffStatusRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _Avatar(name: entry.staff.name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.staff.name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800)),
                Text(entry.staff.position.name,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
          _StatusBadge(status: entry.status),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final StaffAttendanceEntry entry;

  const _AttendanceCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row atas: avatar + nama + status
          Row(
            children: [
              _Avatar(name: entry.staff.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.staff.name,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800)),
                    Text(entry.staff.position.name,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
              ),
              _StatusBadge(status: entry.status),
            ],
          ),

          if (entry.checkIn != null ||
              entry.checkOut != null ||
              entry.locationLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Check-in / Check-out
                  Row(
                    children: [
                      Expanded(
                        child: _TimeInfo(
                          icon: Icons.login_rounded,
                          label: 'Check-In',
                          time: entry.checkIn != null
                              ? DateFormat('HH:mm').format(entry.checkIn!)
                              : '--:--',
                          color: AppColors.brandLimeDark,
                        ),
                      ),
                      Container(
                          width: 1, height: 30, color: AppColors.slate200),
                      Expanded(
                        child: _TimeInfo(
                          icon: Icons.logout_rounded,
                          label: 'Check-Out',
                          time: entry.checkOut != null
                              ? DateFormat('HH:mm').format(entry.checkOut!)
                              : '--:--',
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),

                  // Lokasi
                  if (entry.locationLabel != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 13, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.locationLabel!,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.slate700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.lateMinutes != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${entry.lateMinutes} mnt',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final IconData icon;
  final String label, time;
  final Color color;

  const _TimeInfo({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.slate400)),
            ],
          ),
          const SizedBox(height: 2),
          Text(time,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color:
                    time == '--:--' ? AppColors.slate300 : AppColors.slate800,
              )),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.brandNavy,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.split(' ').map((e) => e[0]).take(2).join(),
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case AttendanceStatus.present:
        color = AppColors.brandLimeDark;
        label = 'HADIR';
        break;
      case AttendanceStatus.late:
        color = AppColors.warning;
        label = 'TERLAMBAT';
        break;
      case AttendanceStatus.absent:
        color = AppColors.danger;
        label = 'ABSEN';
        break;
      case AttendanceStatus.leave:
        color = AppColors.brandNavy;
        label = 'CUTI/IZIN';
        break;
      case AttendanceStatus.holiday:
        color = AppColors.brandNavyLight;
        label = 'LIBUR';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

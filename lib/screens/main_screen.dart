import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/attendance_provider.dart'; // ← shared state
import '../services/attendance_service.dart';
import '../services/profile_service.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import '../screens/camera_checkin_screen.dart'; // ← halaman kamera
import '../models/models.dart';
import 'login_screen.dart';
import 'home_tab.dart';
import 'leave_tab.dart';
import 'salary_screen.dart';
import 'account_tab.dart';
import 'manager_dashboard_tab.dart';

/// Bottom-nav wrapper — Home | Leave & Time Off | [FAB] | Salary | Account
///
/// Admin hanya punya 2 tab: Dashboard & List Absensi (no FAB)
///
/// FAB behaviour berdasarkan [AttendanceProvider._status] (untuk non-admin):
///  • notCheckedIn  → buka kamera (check-in)
///  • checkedIn     → buka kamera (check-out) — tombol istirahat ada di HomeTab
///  • onBreak       → alert "Selesai Istirahat?" (tanpa kamera)
///  • breakEnded    → buka kamera (check-out)
///  • checkedOut    → FAB disabled / info sudah selesai
class MainScreen extends StatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _tab;

  /// AttendanceProvider diinisialisasi di sini agar bisa dibagikan ke
  /// seluruh widget tree melalui [InheritedAttendance].
  final AttendanceProvider _attendance = AttendanceProvider();

  // Status hidrasi profil staff dari backend.
  bool _loadingProfile = true;
  String? _profileError;

  bool get _isAdmin => AppSession.isAdmin;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    // Rebuild FAB ketika status berubah
    _attendance.addListener(() => setState(() {}));
    _hydrateProfile();
  }

  /// Ambil profil staff asli dari backend & sinkronkan ke AppSession sebelum
  /// menampilkan konten, agar seluruh tab menampilkan data nyata.
  Future<void> _hydrateProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      await ProfileService.loadAndCache();
      // Sinkronkan status absensi hari ini (best-effort, tidak memblokir).
      try {
        final today = await AttendanceService.today();
        _attendance.hydrateFromToday(today);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = e.message;
      });
    }
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(destination: LoginDestination.landing)),
      (r) => false,
    );
  }

  @override
  void dispose() {
    _attendance.dispose();
    super.dispose();
  }

  void _onTabTap(int i) => setState(() => _tab = i);

  // ── FAB tap handler ──────────────────────────────────────────
  Future<void> _onFabTap() async {
    final status = _attendance.status;

    // Sudah check-out → tidak ada aksi
    if (status == AttendanceProviderStatus.checkedOut) {
      _showInfoSnackbar('Kamu sudah check-out hari ini. Sampai besok! 🌙');
      return;
    }

    // Sedang istirahat → alert selesai istirahat (tanpa kamera)
    if (status == AttendanceProviderStatus.onBreak) {
      await _showEndBreakDialog();
      return;
    }

    // Tentukan tipe kamera
    final actionType = (status == AttendanceProviderStatus.notCheckedIn)
        ? CameraActionType.checkIn
        : CameraActionType.checkOut;

    // Buka halaman kamera
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraCheckinScreen(actionType: actionType),
      ),
    );

    if (!mounted || result == null || !result.confirmed) return;

    // Simpan ke backend sesuai aksi.
    try {
      if (result.actionType == CameraActionType.checkIn) {
        await _attendance.checkInRemote(
            lokasi: result.address, fotoPath: result.imagePath);
        if (!mounted) return;
        _showSuccessSnackbar('Check-in berhasil! Selamat bekerja 💪');
      } else {
        await _attendance.checkOutRemote(fotoPath: result.imagePath);
        if (!mounted) return;
        _showSuccessSnackbar('Check-out berhasil! Istirahat yang baik 🌙');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showInfoSnackbar(e.message);
    }
  }

  // ── Dialog selesai istirahat ─────────────────────────────────
  Future<void> _showEndBreakDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        title: Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('Selesai Istirahat?',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Apakah kamu sudah siap untuk kembali bekerja?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Belum',
                style: GoogleFonts.inter(color: AppColors.slate700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Ya, Kembali Bekerja',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    _attendance.endBreak();
    _showSuccessSnackbar('Selamat bekerja kembali! 💪');
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: AppColors.brandNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showInfoSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      backgroundColor: AppColors.slate600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Memuat profil staff dari backend.
    if (_loadingProfile) {
      return const Scaffold(
        backgroundColor: AppColors.slate50,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandNavy),
        ),
      );
    }

    // Gagal memuat profil (mis. jaringan / sesi habis).
    if (_profileError != null) {
      return _ProfileErrorView(
        message: _profileError!,
        onRetry: _hydrateProfile,
        onLogout: _logout,
      );
    }

    // Admin: tampilan khusus (hanya dashboard, tidak ada FAB)
    if (_isAdmin) {
      return _buildAdminLayout();
    }

    // Staff / Supervisor: tampilan normal
    return _buildStaffLayout();
  }

  // ── Admin Layout (hanya 2 tab, no FAB) ───────────────────────
  Widget _buildAdminLayout() {
    return InheritedAttendance(
      provider: _attendance,
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        body: const AdminDashboardTab(),
      ),
    );
  }

  // ── Staff/Supervisor Layout ───────────────────────────────────
  Widget _buildStaffLayout() {
    final isManager = AppSession.currentUser.role == UserRole.admin;
    return InheritedAttendance(
      provider: _attendance,
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        body: IndexedStack(
          index: _tab,
          children: [
            HomeTab(
              onNavigateToAccount: () => _onTabTap(4),
              attendance: _attendance,
            ),
            isManager ? const AdminDashboardTab() : const LeaveTab(),
            // slot 2 kosong — FAB menangani kamera secara push, bukan IndexedStack
            const SizedBox.shrink(),
            const SalaryScreen(isFromAccount: false),
            const AccountTab(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(isManager),
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildBottomNav(bool isManager) {
    return BottomAppBar(
      color: AppColors.white,
      elevation: 8,
      shadowColor: AppColors.brandNavy.withOpacity(0.1),
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _tab == 0,
              onTap: () => _onTabTap(0),
            ),
            if (isManager)
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Tim',
                selected: _tab == 1,
                onTap: () => _onTabTap(1),
              )
            else
              _NavItem(
                icon: Icons.event_note_rounded,
                label: 'Cuti & Izin',
                selected: _tab == 1,
                onTap: () => _onTabTap(1),
              ),
            const SizedBox(width: 56), // spacer FAB
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Gaji',
              selected: _tab == 3,
              onTap: () => _onTabTap(3),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Akun',
              selected: _tab == 4,
              onTap: () => _onTabTap(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    final status = _attendance.status;
    final isDone = status == AttendanceProviderStatus.checkedOut;
    final isBreak = status == AttendanceProviderStatus.onBreak;

    // Warna FAB
    Color fabColor;
    IconData fabIcon;
    if (isDone) {
      fabColor = AppColors.slate400;
      fabIcon = Icons.check_circle_rounded;
    } else if (isBreak) {
      fabColor = const Color(0xFFE67E22); // orange
      fabIcon = Icons.free_breakfast_rounded;
    } else {
      fabColor = AppColors.brandNavy;
      fabIcon = Icons.camera_alt_outlined;
    }

    return GestureDetector(
      onTap: _onFabTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: fabColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: fabColor.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(fabIcon, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Tampilan error saat gagal memuat profil ──────────────────────
class _ProfileErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ProfileErrorView({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 56, color: AppColors.slate400),
                const SizedBox(height: 16),
                Text('Gagal memuat data',
                    style: AppText.headline3
                        .copyWith(color: AppColors.slate900)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center, style: AppText.body2),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onLogout,
                  child: Text('Keluar',
                      style: GoogleFonts.inter(color: AppColors.slate600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── InheritedWidget untuk share AttendanceProvider ───────────────
class InheritedAttendance extends InheritedWidget {
  final AttendanceProvider provider;

  const InheritedAttendance({
    super.key,
    required this.provider,
    required super.child,
  });

  static AttendanceProvider of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedAttendance>()!
        .provider;
  }

  @override
  bool updateShouldNotify(InheritedAttendance old) => provider != old.provider;
}

// ── Nav Item ─────────────────────────────────────────────────────
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
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
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

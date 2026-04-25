import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/binding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'salary_screen.dart';

/// Account / Profile Tab — full sections per design spec
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final user = SampleData.currentUser;
  bool _notifEnabled = true;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: Text('Kamu perlu login ulang lain kali.', style: AppText.body2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SessionService.clearSession();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(destination: LoginDestination.landing)),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HADIR-IN',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy, letterSpacing: 1.2,
                          )),
                      Text('Profile',
                          style: AppText.headline2
                              .copyWith(color: AppColors.slate900)),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  // ── Profile Section ───────────────────
                  _buildProfileSection(),
                  const SizedBox(height: 20),

                  // ── Account Section ───────────────────
                  _buildSection(
                    title: 'Akun',
                    icon: Icons.manage_accounts_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        label: 'Informasi Akun',
                        subtitle: 'ID, email, divisi, shift',
                        onTap: () => WidgetsBinding.instance.addPostFrameCallback(() {
                            _showAccountInfo();
                          } as FrameCallback),
                      ),
                      _MenuItem(
                        icon: Icons.history_rounded,
                        label: 'Riwayat Kehadiran',
                        subtitle: 'Lihat rekap kehadiran lengkap',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen())),
                      ),
                      _MenuItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Riwayat Gaji',
                        subtitle: 'Slip gaji bulan-bulan lalu',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const SalaryScreen(isFromAccount: true))),
                      ),
                      _MenuItem(
                        icon: Icons.verified_user_rounded,
                        label: 'Verifikasi Akun',
                        subtitle: 'Status verifikasi identitas',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brandLime.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('VERIFIED',
                              style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: AppColors.brandLimeDark,
                              )),
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Content & Design ──────────────────
                  _buildSection(
                    title: 'Konten & Tampilan',
                    icon: Icons.palette_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifikasi',
                        subtitle: _notifEnabled ? 'Aktif' : 'Nonaktif',
                        trailing: Switch(
                          value: _notifEnabled,
                          onChanged: (v) => setState(() => _notifEnabled = v),
                          activeColor: AppColors.brandNavy,
                        ),
                        onTap: () =>
                            setState(() => _notifEnabled = !_notifEnabled),
                      ),
                      _MenuItem(
                        icon: Icons.color_lens_outlined,
                        label: 'Tema',
                        subtitle: 'Light (default)',
                        onTap: () => _showComingSoon('Pengaturan Tema'),
                      ),
                      _MenuItem(
                        icon: Icons.language_rounded,
                        label: 'Bahasa',
                        subtitle: 'Indonesia',
                        onTap: () => _showComingSoon('Pengaturan Bahasa'),
                      ),
                      _MenuItem(
                        icon: Icons.text_fields_rounded,
                        label: 'Ukuran Teks',
                        subtitle: 'Normal (default)',
                        showDivider: false,
                        onTap: () => _showComingSoon('Ukuran Teks'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Support ───────────────────────────
                  _buildSection(
                    title: 'Dukungan',
                    icon: Icons.support_agent_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Pusat Bantuan',
                        subtitle: 'FAQ dan panduan penggunaan',
                        onTap: () => _showComingSoon('Pusat Bantuan'),
                      ),
                      _MenuItem(
                        icon: Icons.support_rounded,
                        label: 'Bantuan HR',
                        subtitle: 'Hubungi tim HR langsung',
                        showDivider: false,
                        onTap: () => _showComingSoon('Bantuan HR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Security ──────────────────────────
                  _buildSection(
                    title: 'Keamanan',
                    icon: Icons.security_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        label: 'Ubah Password',
                        subtitle: 'Ganti password akun kamu',
                        onTap: () => _showChangePassword(),
                      ),
                      _MenuItem(
                        icon: Icons.pin_outlined,
                        label: 'Ubah PIN',
                        subtitle: 'PIN untuk verifikasi cepat',
                        showDivider: false,
                        onTap: () => _showComingSoon('Ubah PIN'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── About ─────────────────────────────
                  _buildSection(
                    title: 'Tentang Aplikasi',
                    icon: Icons.info_outline_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.star_outline_rounded,
                        label: 'Keunggulan Hadir-In',
                        subtitle: 'Kenapa pakai Hadir-In?',
                        onTap: () => _showAboutFeature(),
                      ),
                      _MenuItem(
                        icon: Icons.menu_book_rounded,
                        label: 'Panduan Hadir-In',
                        subtitle: 'Cara menggunakan aplikasi',
                        onTap: () => _showComingSoon('Panduan Hadir-In'),
                      ),
                      _MenuItem(
                        icon: Icons.gavel_rounded,
                        label: 'Syarat & Ketentuan',
                        subtitle: 'Baca syarat penggunaan',
                        onTap: () => _showComingSoon('Syarat & Ketentuan'),
                      ),
                      _MenuItem(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Kebijakan Privasi',
                        subtitle: 'Cara kami melindungi datamu',
                        showDivider: false,
                        onTap: () => _showComingSoon('Kebijakan Privasi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // App version
                  Center(
                    child: Text('Hadir-In v2.0.0 · Build 2026',
                        style: AppText.caption),
                  ),
                  const SizedBox(height: 12),

                  // Logout
                  GradientButton(
                    label: 'Keluar dari Akun',
                    color: AppColors.danger,
                    icon: Icons.logout_rounded,
                    outlined: true,
                    textColor: AppColors.danger,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile Section ───────────────────────────────────────
  Widget _buildProfileSection() {
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with change photo
              Stack(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.brandNavy,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.name.split(' ').map((w) => w[0]).take(2).join(),
                        style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ganti foto profil!'),
                            duration: const Duration(seconds: 2),
                          ),
                        ),
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.brandLimeDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: AppText.headline3
                            .copyWith(color: AppColors.slate900)),
                    const SizedBox(height: 2),
                    Text(user.position.name, style: AppText.body2),
                    const SizedBox(height: 4),
                    StatusBadge(
                      label: user.role.name.toUpperCase(),
                      color: AppColors.brandNavy,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.slate400),
                onPressed: () => WidgetsBinding.instance.addPostFrameCallback(() {
                    _showAccountInfo();
                  } as FrameCallback),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const AppDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                label: 'ID Karyawan',
                value: user.employeeId,
                icon: Icons.badge_outlined,
              ),
              Container(width: 1, height: 36, color: AppColors.slate200),
              _StatChip(
                label: 'Sisa Cuti',
                value: '9 hari',
                icon: Icons.beach_access_rounded,
              ),
              Container(width: 1, height: 36, color: AppColors.slate200),
              _StatChip(
                label: 'Shift',
                value: user.currentShift.name,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Builder ───────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.brandNavy, size: 16),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.brandNavy, letterSpacing: 0.5,
                )),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.map((item) {
              return Column(
                children: [
                  GestureDetector(
                    onTap: item.onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon,
                                color: AppColors.slate600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 14, fontWeight: FontWeight.w600,
                                      color: AppColors.slate900,
                                    )),
                                if (item.subtitle != null)
                                  Text(item.subtitle!,
                                      style: AppText.body2.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          if (item.trailing != null) item.trailing!
                          else const Icon(Icons.chevron_right_rounded,
                              color: AppColors.slate400, size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (item.showDivider) const AppDivider(),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature akan segera tersedia!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAccountInfo() {
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
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Informasi Akun',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 16),
            _InfoRow(Icons.person_outline_rounded, 'Nama Lengkap', user.name),
            const AppDivider(),
            _InfoRow(Icons.badge_outlined, 'ID Karyawan', user.employeeId),
            const AppDivider(),
            _InfoRow(Icons.email_outlined, 'Email', user.email),
            const AppDivider(),
            _InfoRow(Icons.business_outlined, 'Divisi', 'Marketing'),
            const AppDivider(),
            _InfoRow(Icons.schedule_outlined, 'Shift',
                '${user.currentShift.name} (${user.currentShift.startTimeStr}–${user.currentShift.endTimeStr})'),
            const AppDivider(),
            _InfoRow(Icons.work_outline_rounded, 'Jabatan', user.position.name),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, bottom: MediaQuery.of(_).viewInsets.bottom + 32,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ubah Password',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 16),
            _PasswordField(label: 'Password Lama', controller: oldCtrl),
            const SizedBox(height: 12),
            _PasswordField(label: 'Password Baru', controller: newCtrl),
            const SizedBox(height: 12),
            _PasswordField(label: 'Konfirmasi Password Baru', controller: confCtrl),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Simpan Password Baru',
              color: AppColors.brandNavy,
              height: 50,
              onTap: () {
                Navigator.pop(_);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password berhasil diubah!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutFeature() {
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
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Keunggulan Hadir-In',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 16),
            ...const [
              ('📍', 'Deteksi Lokasi Akurat',
                  'Verifikasi lokasi GPS dan anti-fake location untuk kehadiran yang jujur'),
              ('⏱️', 'Pencatatan Real-Time',
                  'Check-in, check-out, dan break tercatat secara langsung'),
              ('📊', 'Transparansi Gaji',
                  'Lihat slip gaji dan komponen penggajian secara detail'),
              ('🔐', 'Keamanan Berlapis',
                  'Verifikasi ulang untuk akses fitur sensitif'),
              ('📱', 'Akses Kapan Saja',
                  'Login sekali, gunakan terus sampai kamu logout sendiri'),
            ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(f.$1, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: AppColors.slate900,
                                )),
                            Text(f.$3, style: AppText.body2.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.showDivider = true,
  });
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatChip({
    required this.label, required this.value, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.brandNavy, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            )),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9, color: AppColors.slate700)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandNavy, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.slate900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  const _PasswordField({required this.label, required this.controller});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obs = true;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obs,
          decoration: InputDecoration(
            hintText: widget.label,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obs ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.slate400, size: 18,
              ),
              onPressed: () => setState(() => _obs = !_obs),
            ),
          ),
        ),
      ],
    );
  }
}
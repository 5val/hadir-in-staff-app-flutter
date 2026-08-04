import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/src/scheduler/binding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import 'account_info_screen.dart';
import 'history_screen.dart';
import 'salary_screen.dart';
import 'auth_wrapper.dart';
import 'all_attendance_history_screen.dart';
import 'onboarding_documents_screen.dart';

/// Account / Profile Tab — full sections per design spec
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final user = SampleData.currentUser;
  bool _notifEnabled = true;
  String _soundNotifMode = 'Sound';

  /// Status dokumen onboarding (pas foto, KTP, BPJS, NPWP) milik staff ini.
  /// Dipakai untuk memberi tahu bila ada dokumen yang DITOLAK admin/manajer
  /// dan perlu diunggah ulang. Best-effort: gagal memuat tidak menampilkan
  /// apa-apa, tidak menampilkan peringatan palsu.
  OnboardingStatus? _docStatus;

  /// Dokumen yang ditolak HRD dan menunggu revisi.
  List<OnboardingDocument> get _rejectedDocs =>
      _docStatus?.documents.where((d) => d.isRejected).toList() ?? const [];

  /// Dokumen wajib yang belum pernah diunggah sama sekali.
  List<OnboardingDocument> get _missingRequiredDocs =>
      _docStatus?.requiredDocuments.where((d) => !d.submitted).toList() ??
      const [];

  @override
  void initState() {
    super.initState();
    _loadSoundNotif();
    _loadDocStatus();
  }

  Future<void> _loadSoundNotif() async {
    final mode = await SessionService.getSoundNotifMode();
    setState(() {
      _soundNotifMode = mode;
    });
  }

  Future<void> _loadDocStatus() async {
    try {
      final status = await DocumentService.onboardingStatus();
      if (!mounted) return;
      setState(() => _docStatus = status);
    } on ApiException {
      // Diamkan — menu tetap bisa dibuka, hanya badge-nya yang tidak muncul.
    }
  }

  /// Ringkasan status dokumen untuk baris menu.
  String get _documentsSubtitle {
    if (_docStatus == null) return 'Pas foto, KTP, BPJS, NPWP';
    if (_rejectedDocs.isNotEmpty) {
      final nama = _rejectedDocs.map((d) => d.label).join(', ');
      return '$nama ditolak — perlu diunggah ulang';
    }
    if (_missingRequiredDocs.isNotEmpty) {
      return '${_missingRequiredDocs.length} dokumen wajib belum diunggah';
    }
    return 'Pas foto, KTP, BPJS, NPWP';
  }

  /// Buka layar dokumen, lalu segarkan badge setelah kembali (staff mungkin
  /// baru saja mengunggah ulang dokumen yang ditolak).
  Future<void> _openDocuments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingDocumentsScreen(manageMode: true),
      ),
    );
    if (!mounted) return;
    _loadDocStatus();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content:
            Text('Kamu perlu login ulang lain kali.', style: AppText.body2),
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
              color: AppColors.brandNavy,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HADIR-IN',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 1.2,
                          )),
                      Text('Profile',
                          style: AppText.headline2
                              .copyWith(color: AppColors.white)),
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

                  // ── Notifikasi dokumen ditolak ────────
                  // Muncul hanya bila admin/manajer menolak salah satu
                  // dokumen. Backend sudah membuat notifikasi
                  // `document_rejected` di inbox; kartu ini mengangkatnya ke
                  // halaman Profile supaya tidak terlewat, lengkap dengan
                  // alasan penolakannya dan jalan pintas untuk revisi.
                  if (_rejectedDocs.isNotEmpty) ...[
                    _buildRejectedDocsAlert(),
                    const SizedBox(height: 20),
                  ],

                  // ── Hubungi Admin ──────────────────────
                  // Sprint 2 OTP/auth overhaul (Piece 4): staff tidak lagi
                  // bisa ganti nomor HP terdaftar sendiri di app — kalau
                  // butuh, harus lewat admin office. `kontakAdminPhone`
                  // (office-level, diisi HRD di Portal Office) ditampilkan
                  // di sini. Disembunyikan total bila HRD belum mengisinya
                  // (bukan status error/kosong yang terlihat rusak).
                  if ((AppSession.staff?.kontakAdminPhone ?? '').isNotEmpty) ...[
                    _buildContactAdminCard(AppSession.staff!.kontakAdminPhone),
                    const SizedBox(height: 20),
                  ],

                  // ── Account Section ───────────────────
                  _buildSection(
                    title: 'Akun',
                    icon: Icons.manage_accounts_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        label: 'Informasi Akun',
                        subtitle: user.role == UserRole.admin
                            ? 'ID, email, divisi'
                            : 'ID, email, divisi, shift',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountInfoScreen()),
                          );
                          setState(() {});
                        },
                      ),
                      // Dokumen onboarding (pas foto, KTP, BPJS, NPWP) —
                      // jalan masuk untuk melengkapi/mengganti dokumen setelah
                      // staff berada di dalam app. Tanpa ini, dokumen yang
                      // tidak diwajibkan server (BPJS/NPWP staff non-BPJS)
                      // tidak pernah punya tempat untuk diunggah.
                      if (user.role != UserRole.admin)
                        _MenuItem(
                          icon: Icons.folder_shared_outlined,
                          label: 'Dokumen Saya',
                          subtitle: _documentsSubtitle,
                          // Badge merah = ada dokumen yang ditolak HRD dan
                          // harus diunggah ulang.
                          trailing: _rejectedDocs.isEmpty
                              ? null
                              : _CountBadge(
                                  count: _rejectedDocs.length,
                                  label: 'DITOLAK',
                                ),
                          onTap: _openDocuments,
                        ),
                      if (user.role != UserRole.admin)
                        _MenuItem(
                          icon: Icons.history_rounded,
                          label: 'Riwayat Kehadiran',
                          subtitle: 'Lihat rekap kehadiran lengkap',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AllAttendanceHistoryScreen())),
                        ),
                      if (user.role != UserRole.admin)
                        _MenuItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'Riwayat Gaji',
                          subtitle: 'Slip gaji bulan-bulan lalu',
                          showDivider: false,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const SalaryScreen(isFromAccount: true))),
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
                        icon: Icons.volume_up_outlined,
                        label: 'Notifikasi Suara',
                        subtitle: _soundNotifMode == 'Sound'
                            ? 'Sound (Bersuara)'
                            : _soundNotifMode == 'Vibration'
                                ? 'Vibration (Getar)'
                                : 'Silent (Hening)',
                        onTap: _showSoundNotificationSettings,
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
                  // _buildSection(
                  //   title: 'Dukungan',
                  //   icon: Icons.support_agent_rounded,
                  //   items: [
                  //     _MenuItem(
                  //       icon: Icons.phone_enabled_rounded,
                  //       label: 'Kontak Atasan',
                  //       subtitle: 'Hubungi Atasan Anda',
                  //       onTap: () => _showComingSoon('Kontak Atasan'),
                  //     ),
                  //     _MenuItem(
                  //       icon: Icons.support_rounded,
                  //       label: 'Bantuan HR',
                  //       subtitle: 'Hubungi tim HR langsung',
                  //       showDivider: false,
                  //       onTap: () => _showComingSoon('Bantuan HR'),
                  //     ),
                  //   ],
                  // ),
                  // const SizedBox(height: 16),

                  // ── Security ──────────────────────────
                  _buildSection(
                    title: 'Keamanan',
                    icon: Icons.security_rounded,
                    items: [
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        label: 'Ubah Passcode',
                        subtitle: 'Ganti passcode pengaman sesi Anda',
                        showDivider: false,
                        onTap: () => _showChangePasscode(),
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
                  // Center(
                  //   child: Text('Hadir-In v2.0.0 · Build 2026',
                  //       style: AppText.caption),
                  // ),
                  // const SizedBox(height: 12),

                  // Logout
                  GradientButton(
                    label: 'Logout',
                    color: AppColors.danger,
                    // icon: Icons.logout_rounded,
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
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.brandNavy,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.name.split(' ').map((w) => w[0]).take(2).join(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ganti foto profil!'),
                          duration: const Duration(seconds: 2),
                        ),
                      ),
                      child: Container(
                        width: 26,
                        height: 26,
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
                    // const SizedBox(height: 4),
                    // StatusBadge(
                    //   label: user.role.name.toUpperCase(),
                    //   color: AppColors.brandNavy,
                    // ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.slate400),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AccountInfoScreen()),
                  );
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Akun Anda telah terverifikasi dengan NIK dan Wajah.')),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brandLime.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.brandLimeDark.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.brandLimeDark, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Verifikasi Akun',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandLime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'VERIFIED',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const AppDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => _showQrCodeDialog(context, user.employeeId),
                child: const _StatChip(
                  label: 'Scan ID',
                  value: 'ID Staff',
                  icon: Icons.qr_code_2_rounded,
                ),
              ),
              if (user.role != UserRole.admin) ...[
                Container(width: 1, height: 36, color: AppColors.slate200),
                _StatChip(
                  label: 'Sisa Cuti',
                  value: '${AppSession.staff?.sisaCuti ?? 0} hari',
                  icon: Icons.beach_access_rounded,
                ),
                Container(width: 1, height: 36, color: AppColors.slate200),
                _StatChip(
                  label: 'Shift',
                  value: user.currentShift.name,
                  icon: Icons.schedule_rounded,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Builder ───────────────────────────────────────
  // ── Kartu peringatan dokumen ditolak ──────────────────────
  Widget _buildRejectedDocsAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem_rounded,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _rejectedDocs.length == 1
                      ? 'Dokumen ditolak, perlu diunggah ulang'
                      : '${_rejectedDocs.length} dokumen ditolak, perlu diunggah ulang',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Alasan penolakan per dokumen, apa adanya dari catatan HRD.
          ..._rejectedDocs.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      (d.catatanAdmin ?? '').isEmpty
                          ? d.label
                          : '${d.label} — ${d.catatanAdmin}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.slate700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openDocuments,
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: Text('Unggah Ulang Sekarang',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Kartu "Hubungi Admin" ──────────────────────────────────
  //
  // Sprint 2 OTP/auth overhaul: tidak ada endpoint self-service untuk staff
  // mengganti nomor HP-nya sendiri (hanya verifikasi pertama kali oleh
  // admin) — kartu ini menjelaskan kenapa & memberi jalan pintas kontak.
  //
  // Buka WhatsApp/dialer beneran lewat `url_launcher`. Kalau gagal (mis. WA
  // tidak terinstal), fallback ke salin nomor ke clipboard supaya staff
  // tetap punya cara pakai nomornya.
  String _normalizeToWaNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) return digits;
    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    return '62$digits';
  }

  Future<void> _copyPhoneFallback(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tidak bisa membuka aplikasi — nomor ($phone) disalin'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/${_normalizeToWaNumber(phone)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) await _copyPhoneFallback(phone);
  }

  Future<void> _launchDial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri);
    if (!ok) await _copyPhoneFallback(phone);
  }

  Widget _buildContactAdminCard(String phone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandCyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandCyanDark.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandCyanDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: AppColors.brandCyanDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ganti nomor HP terdaftar? Hubungi admin',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nomor HP yang sudah terverifikasi hanya bisa diganti oleh admin kantor Anda.',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.slate700, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandCyanDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchWhatsApp(phone),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandCyanDark,
                          side:
                              BorderSide(color: AppColors.brandCyanDark.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 15),
                        label: Text('WhatsApp',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchDial(phone),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandCyanDark,
                          side:
                              BorderSide(color: AppColors.brandCyanDark.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.call_rounded, size: 15),
                        label: Text('Telepon',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandNavy,
                  letterSpacing: 0.5,
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
                            width: 36,
                            height: 36,
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate900,
                                    )),
                                if (item.subtitle != null)
                                  Text(item.subtitle!,
                                      style:
                                          AppText.body2.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          if (item.trailing != null)
                            item.trailing!
                          else
                            const Icon(Icons.chevron_right_rounded,
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

  void _showSoundNotificationSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Notifikasi Suara',
                style: AppText.headline3.copyWith(color: AppColors.slate900),
              ),
              const SizedBox(height: 16),
              RadioListTile<String>(
                activeColor: AppColors.brandNavy,
                title: Text('Sound (Bersuara)', style: AppText.body1),
                value: 'Sound',
                groupValue: _soundNotifMode,
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => _soundNotifMode = val);
                    setState(() => _soundNotifMode = val);
                    SessionService.saveSoundNotifMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                activeColor: AppColors.brandNavy,
                title: Text('Vibration (Getar)', style: AppText.body1),
                value: 'Vibration',
                groupValue: _soundNotifMode,
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => _soundNotifMode = val);
                    setState(() => _soundNotifMode = val);
                    SessionService.saveSoundNotifMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                activeColor: AppColors.brandNavy,
                title: Text('Silent (Hening)', style: AppText.body1),
                value: 'Silent',
                groupValue: _soundNotifMode,
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => _soundNotifMode = val);
                    setState(() => _soundNotifMode = val);
                    SessionService.saveSoundNotifMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
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
                width: 36,
                height: 4,
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
            _EmployeeQrCard(employeeId: user.employeeId),
            const AppDivider(),
            _InfoRow(Icons.email_outlined, 'Email', user.email),
            const AppDivider(),
            _InfoRow(Icons.business_outlined, 'Divisi', AppSession.staff?.divisiNama ?? '-'),
            if (user.role != UserRole.admin) ...[
              const AppDivider(),
              _InfoRow(Icons.schedule_outlined, 'Shift',
                  '${user.currentShift.name} (${user.currentShift.startTimeStr}–${user.currentShift.endTimeStr})'),
            ],
            const AppDivider(),
            _InfoRow(Icons.work_outline_rounded, 'Jabatan', user.position.name),
          ],
        ),
      ),
    );
  }

  void _showChangePasscode() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(_).viewInsets.bottom + 32,
          top: 16,
        ),
        child: Form(
          key: formKey,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ubah Passcode',
                  style: AppText.headline3.copyWith(color: AppColors.slate900)),
              const SizedBox(height: 16),
              _PasscodeField(label: 'Passcode Lama', controller: oldCtrl),
              const SizedBox(height: 12),
              _PasscodeField(label: 'Passcode Baru', controller: newCtrl),
              const SizedBox(height: 12),
              _PasscodeField(
                  label: 'Konfirmasi Passcode Baru', controller: confCtrl),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Simpan Passcode Baru',
                color: AppColors.brandNavy,
                height: 50,
                onTap: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (newCtrl.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Passcode baru harus 6 digit angka!'),
                          backgroundColor: AppColors.danger),
                    );
                    return;
                  }
                  if (newCtrl.text != confCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Konfirmasi passcode baru tidak cocok!'),
                          backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  // Fase 8: passcode lama diverifikasi SERVER (bcrypt), bukan
                  // dibandingkan dengan string di SharedPreferences, dan
                  // passcode baru disimpan terhash di `Staff.passcodeHash`
                  // sehingga tetap berlaku setelah logout / ganti HP.
                  try {
                    await AuthService.setPasscode(
                      passcode: newCtrl.text.trim(),
                      passcodeLama: oldCtrl.text.trim(),
                    );
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(e.message),
                          backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  if (!mounted) return;
                  Navigator.pop(_);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passcode berhasil diubah!')),
                  );
                },
              ),
            ],
          ),
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
                width: 36,
                height: 4,
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
              (
                '📍',
                'Deteksi Lokasi Akurat',
                'Verifikasi lokasi GPS dan anti-fake location untuk kehadiran yang jujur'
              ),
              (
                '⏱️',
                'Pencatatan Real-Time',
                'Check-in, check-out, dan break tercatat secara langsung'
              ),
              (
                '📊',
                'Transparansi Gaji',
                'Lihat slip gaji dan komponen penggajian secara detail'
              ),
              (
                '🔐',
                'Keamanan Berlapis',
                'Verifikasi ulang untuk akses fitur sensitif'
              ),
              (
                '📱',
                'Akses Kapan Saja',
                'Login sekali, gunakan terus sampai kamu logout sendiri'
              ),
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate900,
                                )),
                            Text(f.$3,
                                style: AppText.body2.copyWith(fontSize: 11)),
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

  void _showQrCodeDialog(BuildContext context, String employeeId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppColors.brandNavy),
            const SizedBox(width: 8),
            Text(
              'QR Code Karyawan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _EmployeeQrPainter(employeeId),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              employeeId,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.brandNavy,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
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

/// Lencana kecil merah untuk baris menu (mis. "2 DITOLAK").
class _CountBadge extends StatelessWidget {
  final int count;
  final String label;

  const _CountBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count $label',
          style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.brandNavy, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            )),
        Text(label,
            style: GoogleFonts.inter(fontSize: 9, color: AppColors.slate700)),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
                _obs
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.slate400,
                size: 18,
              ),
              onPressed: () => setState(() => _obs = !_obs),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasscodeField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  const _PasscodeField({required this.label, required this.controller});

  @override
  State<_PasscodeField> createState() => _PasscodeFieldState();
}

class _PasscodeFieldState extends State<_PasscodeField> {
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
          maxLength: 6,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.slate900),
          decoration: InputDecoration(
            hintText: widget.label,
            counterText: "",
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obs
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.slate400,
                size: 18,
              ),
              onPressed: () => setState(() => _obs = !_obs),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeQrCard extends StatelessWidget {
  final String employeeId;
  const _EmployeeQrCard({required this.employeeId});

  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppColors.brandNavy),
            const SizedBox(width: 8),
            Text(
              'QR Code Karyawan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _EmployeeQrPainter(employeeId),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              employeeId,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.brandNavy,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQrCodeDialog(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2_rounded, color: AppColors.brandNavy, size: 20),
                const SizedBox(width: 8),
                Text(
                  'QR Code Karyawan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandNavy.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                size: const Size(140, 140),
                painter: _EmployeeQrPainter(employeeId),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  employeeId,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.brandNavy),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeQrPainter extends CustomPainter {
  final String data;
  _EmployeeQrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final cellSize = size.width / 21;

    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + cellSize * 2, y + cellSize * 2, cellSize * 3, cellSize * 3),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(cellSize * 14, 0);
    drawFinder(0, cellSize * 14);

    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        bool isTopLeft = r < 8 && c < 8;
        bool isTopRight = r < 8 && c >= 13;
        bool isBottomLeft = r >= 13 && c < 8;
        if (isTopLeft || isTopRight || isBottomLeft) continue;

        bool isAlignment = r >= 14 && r <= 18 && c >= 14 && c <= 18;
        if (isAlignment) {
          int relR = r - 14;
          int relC = c - 14;
          bool fill = (relR == 0 || relR == 4 || relC == 0 || relC == 4 || (relR == 2 && relC == 2));
          if (fill) {
            canvas.drawRect(Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize), paint);
          }
          continue;
        }

        final hash = (data.hashCode ^ (r * 73) ^ (c * 19)) & 0xFFFF;
        if (hash % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

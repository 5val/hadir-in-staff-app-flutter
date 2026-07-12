import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SampleData.currentUser;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.slate700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile', style: AppText.headline3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Avatar ────────────────────────────────────
            Container(
              width: 84, height: 84,
              decoration: const BoxDecoration(
                color: AppColors.brandNavy, shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.name.split(' ').map((w) => w[0]).take(2).join(),
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(user.name,
                style: AppText.headline2.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 2),
            Text(user.position.name, style: AppText.body2),
            const SizedBox(height: 4),
            StatusBadge(label: user.role.name.toUpperCase(), color: AppColors.brandNavy),
            const SizedBox(height: 28),

            // ── QR Code Karyawan ──────────────────────────
            _EmployeeQrCard(employeeId: user.employeeId),
            const SizedBox(height: 16),

            // ── Info card ─────────────────────────────────
            SectionCard(
              child: Column(
                children: [
                  _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
                  const AppDivider(),
                  _InfoRow(icon: Icons.business_outlined, label: 'Divisi', value: 'Marketing'),
                  const AppDivider(),
                  _InfoRow(icon: Icons.schedule_outlined, label: 'Shift',
                      value: '${user.currentShift.name} (${user.currentShift.startTimeStr}–${user.currentShift.endTimeStr})'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Leave balance ─────────────────────────────
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sisa Cuti Tahunan', style: AppText.label),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('9',
                          style: GoogleFonts.inter(
                            fontSize: 36, fontWeight: FontWeight.w800,
                            color: AppColors.brandNavy,
                          )),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('hari tersisa', style: AppText.body2),
                          Text('dari 12 hari/tahun', style: AppText.caption),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 9 / 12,
                      backgroundColor: AppColors.slate100,
                      valueColor: const AlwaysStoppedAnimation(AppColors.brandNavy),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Settings ──────────────────────────────────
            SectionCard(
              child: Column(
                children: [
                  _MenuRow(icon: Icons.notifications_outlined,
                      label: 'Notifikasi', onTap: () {}),
                  const AppDivider(),
                  _MenuRow(icon: Icons.lock_outline_rounded,
                      label: 'Ubah Password', onTap: () {}),
                  const AppDivider(),
                  _MenuRow(icon: Icons.help_outline_rounded,
                      label: 'Bantuan & FAQ', onTap: () {}),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Logout ────────────────────────────────────
            GradientButton(
              label: 'Keluar dari Akun',
              color: AppColors.danger,
              icon: Icons.logout_rounded,
              outlined: true,
              textColor: AppColors.danger,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Keluar?'),
                    content: Text('Kamu perlu login ulang lain kali.',
                        style: AppText.body2),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await SessionService.clearSession();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen(
                        destination: LoginDestination.landing)),
                    (r) => false,
                  );
                }
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
                    style: AppText.body1.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.slate600, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppText.body1)),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.slate400, size: 20),
          ],
        ),
      ),
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
      child: SectionCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
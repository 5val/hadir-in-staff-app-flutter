import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'leave_tab.dart';

class LeaveChoiceScreen extends StatelessWidget {
  const LeaveChoiceScreen({super.key});

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
        title: Image.asset(AppAssets.logoFull, height: 28),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('APPLICATION PORTAL',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.brandNavy, letterSpacing: 1.2,
                )),
            const SizedBox(height: 6),
            Text('Pilih Jenis Pengajuan',
                style: AppText.headline2.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 4),
            Text('Pilih antara Cuti Tahunan atau Izin.',
                style: AppText.body2),
            const SizedBox(height: 28),

            // ── Cuti ──────────────────────────────────
            _ChoiceCard(
              icon: Icons.beach_access_rounded,
              iconBgColor: AppColors.brandNavy.withOpacity(0.08),
              iconColor: AppColors.brandNavy,
              title: 'Cuti Tahunan',
              subtitle: 'Ajukan cuti dari jatah tahunan kamu',
              pills: const ['Maks 12 hari/tahun', 'H-3 sebelum cuti'],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaveTab(initialSubTab: 0),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Izin ──────────────────────────────────
            _ChoiceCard(
              icon: Icons.medical_services_rounded,
              iconBgColor: AppColors.brandCyan.withOpacity(0.1),
              iconColor: AppColors.brandCyanDark,
              title: 'Izin',
              subtitle: 'Sakit, seminar, atau keperluan sekolah',
              pills: const ['Sakit', 'Seminar', 'Sekolah'],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaveTab(initialSubTab: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  final IconData icon;
  final Color iconBgColor, iconColor;
  final String title, subtitle;
  final List<String> pills;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon, required this.iconBgColor, required this.iconColor,
    required this.title, required this.subtitle,
    required this.pills, required this.onTap,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1, end: 0.97).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withOpacity(0.06),
                blurRadius: 12, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                    color: widget.iconBgColor,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(widget.icon, color: widget.iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.slate900,
                        )),
                    const SizedBox(height: 3),
                    Text(widget.subtitle, style: AppText.body2),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: widget.pills.map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p,
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w500,
                                color: AppColors.slate600)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.slate400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'checkin_screen.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _card1Slide;
  late Animation<Offset> _card2Slide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);

    _card1Slide = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));

    _card2Slide = Tween<Offset>(
      begin: const Offset(0.4, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));

    _cardFade = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeIn);

    _logoCtrl.forward().then((_) =>
        Future.delayed(const Duration(milliseconds: 150), () =>
            _cardsCtrl.forward()));
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo ──────────────────────────────────────
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'HadirIn',
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sistem Kehadiran & HR Karyawan',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Action Cards ──────────────────────────────
              FadeTransition(
                opacity: _cardFade,
                child: Column(
                  children: [
                    SlideTransition(
                      position: _card1Slide,
                      child: _LandingActionCard(
                        icon: Icons.fingerprint_rounded,
                        title: 'Check-in / Check-out',
                        subtitle: 'Catat kehadiran harian kamu',
                        accentColor: AppColors.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckinScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SlideTransition(
                      position: _card2Slide,
                      child: _LandingActionCard(
                        icon: Icons.event_note_rounded,
                        title: 'Cuti & Izin',
                        subtitle: 'Ajukan cuti, sakit, atau izin',
                        accentColor: AppColors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // ── Footer ────────────────────────────────────
              FadeTransition(
                opacity: _cardFade,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'v1.0.0 • Hadir-In',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Landing Action Card ───────────────────────────────────────
class _LandingActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _LandingActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_LandingActionCard> createState() => _LandingActionCardState();
}

class _LandingActionCardState extends State<_LandingActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
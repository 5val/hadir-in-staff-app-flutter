import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/session_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _cardsCtrl, _mascotCtrl;
  late Animation<double>   _logoFade, _logoScale, _cardFade, _mascotBounce;
  late Animation<Offset>   _card1Slide, _card2Slide;

  @override
  void initState() {
    super.initState();
    _logoCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _cardsCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _mascotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _logoFade  = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));

    _card1Slide = Tween<Offset>(begin: const Offset(-0.35, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));
    _card2Slide = Tween<Offset>(begin: const Offset(0.35, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));
    _cardFade = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeIn);

    _mascotBounce = Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: _mascotCtrl, curve: Curves.easeInOut));

    _logoCtrl.forward().then((_) =>
        Future.delayed(const Duration(milliseconds: 150), _cardsCtrl.forward));
  }

  @override
  void dispose() {
    _logoCtrl.dispose(); _cardsCtrl.dispose(); _mascotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 36),

              // ── Logo ──────────────────────────────────
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    children: [
                      Image.asset(AppAssets.logoFull, height: 52, fit: BoxFit.contain),
                      const SizedBox(height: 8),
                      Text(
                        'Sistem Kehadiran & HR Karyawan',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.slate600),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Mascot ────────────────────────────────
              AnimatedBuilder(
                animation: _mascotBounce,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _mascotBounce.value), child: child,
                ),
                child: Image.asset(AppAssets.mascotWave, height: 165),
              ),

              const SizedBox(height: 12),

              FadeTransition(
                opacity: _cardFade,
                child: Column(
                  children: [
                    Text('Pilih Aktivitas 👇',
                        style: AppText.headline2.copyWith(color: AppColors.brandNavy)),
                    const SizedBox(height: 5),
                    Text(
                      'Apa yang ingin kamu lakukan hari ini?',
                      style: AppText.body2, textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Cards ─────────────────────────────────
              FadeTransition(
                opacity: _cardFade,
                child: Column(
                  children: [
                    SlideTransition(
                      position: _card1Slide,
                      child: _ActionCard(
                        icon: Icons.fingerprint_rounded,
                        title: 'Check-in / Check-out',
                        subtitle: 'Catat kehadiran harian kamu',
                        badge: null,
                        accentColor: AppColors.brandNavy,
                        bgColor: AppColors.brandNavy.withOpacity(0.07),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MainScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SlideTransition(
                      position: _card2Slide,
                      child: _ActionCard(
                        icon: Icons.event_note_rounded,
                        title: 'Cuti & Izin',
                        subtitle: 'Ajukan cuti atau izin',
                        accentColor: AppColors.brandCyanDark,
                        bgColor: AppColors.brandCyan.withOpacity(0.08),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(
                              destination: LoginDestination.leaveRequest,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              FadeTransition(
                opacity: _cardFade,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Keluar dari Akun?'),
                        content: Text('Kamu perlu login ulang lain kali.',
                            style: AppText.body2),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true),
                              child: const Text('Keluar')),
                        ],
                      ),
                    );
                    if (ok == true) _clearAndNavigate();
                  },
                  icon: const Icon(Icons.logout_rounded,
                      size: 15, color: AppColors.slate400),
                  label: Text('Keluar dari Akun',
                      style: GoogleFonts.inter(
                          color: AppColors.slate400, fontSize: 13)),
                ),
              ),

              const SizedBox(height: 6),
              FadeTransition(
                opacity: _cardFade,
                child: Text('v1.0.0 • PT. Maju Bersama Indonesia',
                    style: AppText.caption, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearAndNavigate() async {
    await SessionService.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(
            destination: LoginDestination.landing)),
        (r) => false,
      );
    }
  }
}

// ── Action Card ───────────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final Color accentColor, bgColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    this.badge, required this.accentColor, required this.bgColor,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.07),
                blurRadius: 12, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.slate900,
                        )),
                    const SizedBox(height: 3),
                    Text(widget.subtitle, style: AppText.body2),
                    if (widget.badge != null) ...[
                      const SizedBox(height: 5),
                      Text(widget.badge!,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: AppColors.brandCyanDark,
                          )),
                    ],
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
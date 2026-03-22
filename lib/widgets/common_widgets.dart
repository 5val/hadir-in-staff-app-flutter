import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── App Button ────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  final double height;
  final double? width;
  final double borderRadius;
  final bool isLoading;
  final bool outlined;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.brandNavy,
    this.textColor,
    this.icon,
    this.height = 52,
    this.width,
    this.borderRadius = 10,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final enabled  = widget.onTap != null && !widget.isLoading;
    final fg       = widget.textColor ?? (widget.outlined ? widget.color : Colors.white);
    final disabledBg = AppColors.slate200;

    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled ? (_) { _ctrl.reverse(); widget.onTap?.call(); } : null,
      onTapCancel: enabled ? () => _ctrl.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: widget.outlined
                ? Colors.transparent
                : (enabled ? widget.color : disabledBg),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.outlined
                ? Border.all(
                    color: enabled ? widget.color : AppColors.slate300, width: 1.5)
                : null,
            boxShadow: (!widget.outlined && enabled)
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.outlined ? widget.color : Colors.white,
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      color: enabled ? fg : AppColors.slate400, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: enabled ? fg : AppColors.slate400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double borderRadius;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderRadius = 12,
    this.borderColor,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.slate200, width: 1,
        ),
        boxShadow: shadows ?? [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: color,
        ),
      ),
    );
  }
}

// ── Pulse Button ──────────────────────────────────────────────
class PulseButton extends StatefulWidget {
  final Widget child;
  final Color pulseColor;
  final double size;
  final VoidCallback? onTap;

  const PulseButton({
    super.key,
    required this.child,
    required this.pulseColor,
    required this.size,
    this.onTap,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _pulse = Tween<double>(begin: 1.0, end: 1.35)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.5, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: widget.size, height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.pulseColor.withOpacity(_opacity.value),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// ── Info Tile ─────────────────────────────────────────────────
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const InfoTile({
    super.key, required this.icon, required this.label,
    required this.value, this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? AppColors.brandNavy;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ic.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: ic, size: 18),
        ),
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
    );
  }
}

// ── Custom App Bar ────────────────────────────────────────────
class StaffAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Color? backgroundColor;

  const StaffAppBar({
    super.key, required this.title, this.actions,
    this.showBack = true, this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.white,
      title: Text(title),
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      automaticallyImplyLeading: false,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.slate200),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

// ── Shimmer Box ───────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width, height;
  final double borderRadius;

  const ShimmerBox({
    super.key, required this.width, required this.height, this.borderRadius = 6,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.slate200.withOpacity(_anim.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────
class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.slate200, thickness: 1, height: 1);
  }
}

// ── Mascot Overlay (replaces SmileyOverlay) ───────────────────
/// Shows the Hadir-In owl mascot with a message overlay.
/// [wave] = true → waving mascot, false → regular sitting mascot.
class MascotOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final String message;
  final bool wave;

  const MascotOverlay({
    super.key,
    required this.onDismiss,
    required this.message,
    this.wave = false,
  });

  @override
  State<MascotOverlay> createState() => _MascotOverlayState();
}

class _MascotOverlayState extends State<MascotOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _bounceCtrl;
  late Animation<double> _fade, _scale, _bounce;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade   = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scale  = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.elasticOut));
    _bounce = Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
    _fadeCtrl.forward();
    _bounceCtrl.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _fadeCtrl.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() { _fadeCtrl.dispose(); _bounceCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: SectionCard(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _bounce,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _bounce.value), child: child,
                    ),
                    child: Image.asset(
                      widget.wave ? AppAssets.mascotWave : AppAssets.mascot,
                      height: 110,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: AppText.headline3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Keep old name as alias
typedef SmileyOverlay = MascotOverlay;
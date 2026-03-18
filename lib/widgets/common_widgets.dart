import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── App Button (solid colour, no gradient) ────────────────────
// Named GradientButton for backward compatibility with existing screens.
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final double height;
  final double? width;
  final double borderRadius;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.primary,
    this.icon,
    this.height = 52,
    this.width,
    this.borderRadius = 10,
    this.isLoading = false,
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: enabled ? () => _ctrl.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: enabled ? widget.color : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: enabled
                  ? widget.color.withOpacity(0.3)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      color: enabled ? Colors.white : AppColors.textMuted,
                      size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.white : AppColors.textMuted,
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

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderRadius = 10,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
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
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
  late Animation<double> _pulse;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulse = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                width: widget.size,
                height: widget.size,
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
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? AppColors.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ic.withOpacity(0.12),
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
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.background,
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
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

// ── Shimmer Placeholder ───────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 6,
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
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withOpacity(_anim.value),
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
    return Divider(color: AppColors.border, thickness: 1, height: 1);
  }
}

// ── Smiley Overlay ────────────────────────────────────────────
class SmileyOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final String message;

  const SmileyOverlay({
    super.key,
    required this.onDismiss,
    required this.message,
  });

  @override
  State<SmileyOverlay> createState() => _SmileyOverlayState();
}

class _SmileyOverlayState extends State<SmileyOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _bounceCtrl;
  late Animation<double> _fade;
  late Animation<double> _bounce;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _bounceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.elasticOut),
    );
    _bounce = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    _fadeCtrl.forward();
    _bounceCtrl.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _fadeCtrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: SectionCard(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _bounce,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _bounce.value),
                      child: child,
                    ),
                    child: const Text('😊', style: TextStyle(fontSize: 80)),
                  ),
                  const SizedBox(height: 20),
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
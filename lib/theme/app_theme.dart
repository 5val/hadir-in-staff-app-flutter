import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Color Palette (CSS vars mapped to Flutter) ────────────────
class AppColors {
  // Primary (blue-500)
  static const Color primary     = Color(0xFF3B82F6);
  static const Color coral       = Color(0xFF3B82F6); // alias kept for compat
  static const Color coralLight  = Color(0xFF60A5FA);
  static const Color coralDark   = Color(0xFF2563EB);

  // Secondary accent (sky-400 — distinct from primary)
  static const Color teal      = Color(0xFF38BDF8);
  static const Color tealLight = Color(0xFF7DD3FC);

  // Legacy names kept for backward compat
  static const Color navy      = Color(0xFF171717);
  static const Color navyLight = Color(0xFF262626);
  static const Color navyCard  = Color(0xFF262626);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger  = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // Text
  static const Color textPrimary   = Color(0xFFE5E5E5);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textMuted     = Color(0xFF6B7280);

  // Backgrounds / surfaces
  static const Color background      = Color(0xFF171717);
  static const Color surface         = Color(0xFF262626);
  static const Color surfaceElevated = Color(0xFF2D2D2D);
  static const Color surfaceVariant  = Color(0xFF363636);
  static const Color border          = Color(0xFF404040);
  static const Color accent          = Color(0xFF1E3A8A);
  static const Color accentFg        = Color(0xFFBFDBFE);
}

// ── Theme ─────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.surfaceVariant,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Typography ─────────────────────────────────────────────────
class AppText {
  static TextStyle headline1 = GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
  );
  static TextStyle headline2 = GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle headline3 = GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle body1 = GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static TextStyle body2 = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted,
  );
  static TextStyle label = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
  );
  static TextStyle button = GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
  );
  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );

  // Aliases for backward-compat (used in notification_screen)
  static TextStyle get title => headline3;
  static TextStyle get body  => body1;
}
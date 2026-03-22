import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
//  HADIR-IN BRAND COLORS  (from COLOR-PALETTE.md)
// ─────────────────────────────────────────────────────────────
class AppColors {
  // ── Brand primaries ──────────────────────────────────────
  static const Color brandNavy      = Color(0xFF2D377F);
  static const Color brandNavyDark  = Color(0xFF1E285A);
  static const Color brandNavyLight = Color(0xFF4A5599);

  static const Color brandCyan      = Color(0xFF4DD0E1);
  static const Color brandCyanLight = Color(0xFF64E6F5);
  static const Color brandCyanDark  = Color(0xFF00ACC1);

  static const Color brandLime      = Color(0xFF9CCC65);
  static const Color brandLimeLight = Color(0xFFC5E1A5);
  static const Color brandLimeDark  = Color(0xFF7CB342);

  // ── Semantic convenience aliases ─────────────────────────
  static const Color primary   = brandNavy;
  static const Color secondary = brandCyan;
  static const Color success   = brandLime;
  static const Color successDark = brandLimeDark;

  static const Color warning   = Color(0xFFFFC107);
  static const Color danger    = Color(0xFFF44336);
  static const Color info      = brandCyan;

  // ── Neutral / supporting ─────────────────────────────────
  static const Color white    = Color(0xFFFFFFFF);
  static const Color slate50  = Color(0xFFF8FAFC);   // main screen bg
  static const Color slate100 = Color(0xFFF1F5F9);   // hover / field bg
  static const Color slate200 = Color(0xFFE2E8F0);   // borders, dividers
  static const Color slate300 = Color(0xFFCBD5E1);   // disabled
  static const Color slate400 = Color(0xFF94A3B8);   // placeholder
  static const Color slate600 = Color(0xFF475569);   // muted text
  static const Color slate700 = Color(0xFF334155);   // body text
  static const Color slate800 = Color(0xFF1E293B);   // secondary text
  static const Color slate900 = Color(0xFF0F172A);   // heading text

  // ── Compat aliases (old dark-theme names → light equivalents) ──
  static const Color background      = slate50;
  static const Color surface         = white;
  static const Color surfaceElevated = slate100;
  static const Color surfaceVariant  = slate200;
  static const Color border          = slate200;
  static const Color textPrimary     = slate900;
  static const Color textSecondary   = slate600;
  static const Color textMuted       = slate400;

  // Old coral / teal → map to brand
  static const Color coral     = brandNavy;
  static const Color teal      = brandCyan;
  static const Color tealLight = brandCyanLight;
  static const Color navy      = brandNavyDark;
  static const Color navyLight = brandNavy;
  static const Color navyCard  = white;
}

// ─────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark => light; // keep compat
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: false);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.slate50,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.brandNavy,
        secondary: AppColors.brandCyan,
        surface:   AppColors.white,
        error:     AppColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor:    AppColors.slate700,
        displayColor: AppColors.slate900,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.slate900,
        ),
        iconTheme: const IconThemeData(color: AppColors.slate700),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.slate200, width: 1),
        ),
        shadowColor: AppColors.brandNavy.withOpacity(0.06),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brandNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(color: AppColors.slate600),
        hintStyle: const TextStyle(color: AppColors.slate400),
        prefixIconColor: AppColors.slate400,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandNavy,
          side: const BorderSide(color: AppColors.brandNavy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor:   AppColors.brandNavy,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor:         AppColors.brandNavy,
        unselectedLabelColor: AppColors.slate400,
        indicatorColor:     AppColors.brandNavy,
        dividerColor:       AppColors.slate200,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.slate200,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandNavy
              : AppColors.slate300,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandNavy.withOpacity(0.35)
              : AppColors.slate200,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.slate200),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.slate900,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brandNavyDark,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TYPOGRAPHY
// ─────────────────────────────────────────────────────────────
class AppText {
  static TextStyle headline1 = GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.slate900,
  );
  static TextStyle headline2 = GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.slate900,
  );
  static TextStyle headline3 = GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slate900,
  );
  static TextStyle body1 = GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.slate700,
  );
  static TextStyle body2 = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.slate600,
  );
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate400,
  );
  static TextStyle label = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700,
  );
  static TextStyle button = GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
  );
  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.slate900,
  );

  // Aliases
  static TextStyle get title => headline3;
  static TextStyle get body  => body1;
}

// ─────────────────────────────────────────────────────────────
//  ASSET PATHS
// ─────────────────────────────────────────────────────────────
class AppAssets {
  static const String logoFull   = 'assets/images/logo_hadir_in_dengan_tulisan.png';
  static const String logoIcon   = 'assets/images/logo_hadir_in.png';
  static const String mascot     = 'assets/images/maskot_hadir_in.png';
  static const String mascotWave = 'assets/images/maskot_hadir_in_melambai.png';
}
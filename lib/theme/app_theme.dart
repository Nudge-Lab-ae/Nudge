// lib/theme/app_theme.dart
// Design System: "The Illuminated Scholar"
// Primary font: Plus Jakarta Sans (headlines) / Be Vietnam Pro (body)
// Color palette: warm charcoal-tobacco dark / warm off-white light

import 'package:flutter/material.dart';
// import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ─── Light Mode ───────────────────────────────────────────
  static const Color lightBackground = Color(0xFFFAF9F6);
  static const Color lightSurface = Color(0xFFFAF9F6);
  static Color lightSurfaceBright = Color(0xFFFAF9F6);
  static Color lightSurfaceContainerLowest = Color(0xFFFAF9F6);
  static const Color lightSurfaceContainerLow = Color(0xFFF5F0EB);
  static const Color lightSurfaceContainer = Color(0xFFECE7E2);
  static const Color lightSurfaceContainerHigh = Color(0xFFE7E2DC);
  static const Color lightSurfaceContainerHighest = Color(0xFFE1DCD6);
  static const Color lightSurfaceDim = Color(0xFFD8D4CD);

  static const Color lightOnBackground = Color(0xFF302E2B);
  static const Color lightOnSurface = Color(0xFF302E2B);
  static const Color lightOnSurfaceVariant = Color(0xFF5D5B58);
  static const Color lightOutline = Color(0xFF797672);
  static const Color lightOutlineVariant = Color(0xFFB0ACA8);

  static const Color lightPrimary = Color(0xFF751FE7);
  static const Color lightOnPrimary = Color(0xFFF9EFFF);
  static const Color lightPrimaryContainer = Color(0xFFB58BFF);
  static const Color lightOnPrimaryContainer = Color(0xFF30006A);
  static const Color lightPrimaryFixed = Color(0xFFB58BFF);
  static const Color lightPrimaryFixedDim = Color(0xFFA978FF);

  static const Color lightSecondary = Color(0xFF006288);
  static const Color lightOnSecondary = Color(0xFFE8F4FF);
  static const Color lightSecondaryContainer = Color(0xFF9ED9FF);
  static const Color lightOnSecondaryContainer = Color(0xFF004D6B);

  static const Color lightTertiary = Color(0xFF9E3654);
  static const Color lightOnTertiary = Color(0xFFFFEFF0);
  static const Color lightTertiaryContainer = Color(0xFFFF8FA9);
  static const Color lightOnTertiaryContainer = Color(0xFF65042A);

  static const Color lightError = Color(0xFFB41340);
  static const Color lightOnError = Color(0xFFFFEFEF);
  static const Color lightErrorContainer = Color(0xFFF74B6D);
  static const Color lightOnErrorContainer = Color(0xFF510017);

  // Material 3 inverse / tint tokens (canonical mockup parity)
  static const Color lightSurfaceTint = Color(0xFF751FE7);
  static const Color lightInversePrimary = Color(0xFFA775FF);
  static const Color lightInverseSurface = Color(0xFF0F0E0C);
  static const Color lightOnInverseSurface = Color(0xFFA09C98);

  // ─── Dark Mode ─────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF151311);
  static const Color darkSurface = Color(0xFF151311);
  static const Color darkSurfaceBright = Color(0xFF3B3936);
  static const Color darkSurfaceContainerLowest = Color(0xFF100E0C);
  static const Color darkSurfaceContainerLow = Color(0xFF1D1B19);
  static const Color darkSurfaceContainer = Color(0xFF211F1D);
  static const Color darkSurfaceContainerHigh = Color(0xFF2C2927);
  static const Color darkSurfaceContainerHighest = Color(0xFF373432);
  static const Color darkSurfaceDim = Color(0xFF151311);

  static const Color darkOnBackground = Color(0xFFE7E1DE);
  static const Color darkOnSurface = Color(0xFFE7E1DE);
  static const Color darkOnSurfaceVariant = Color(0xFFCDC2D8);
  static const Color darkOutline = Color(0xFF968DA1);
  static const Color darkOutlineVariant = Color(0xFF4B4455);

  static const Color darkPrimary = Color(0xFFD4BBFF);
  static const Color darkOnPrimary = Color(0xFF41008B);
  static const Color darkPrimaryContainer = Color(0xFF751FE7);
  static const Color darkOnPrimaryContainer = Color(0xFFDFCBFF);
  static const Color darkPrimaryFixed = Color(0xFFEBDCFF);
  static const Color darkPrimaryFixedDim = Color(0xFFD4BBFF);

  static const Color darkSecondary = Color(0xFF89CFFA);
  static const Color darkOnSecondary = Color(0xFF00344B);
  static const Color darkSecondaryContainer = Color(0xFF026389);
  static const Color darkOnSecondaryContainer = Color(0xFFA6DCFF);

  static const Color darkTertiary = Color(0xFFFFB68C);
  static const Color darkOnTertiary = Color(0xFF532200);
  static const Color darkTertiaryContainer = Color(0xFF954400);
  static const Color darkOnTertiaryContainer = Color(0xFFFFC8AA);

  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  // Material 3 inverse / tint tokens (canonical mockup parity)
  static const Color darkSurfaceTint = Color(0xFFD4BBFF);
  static const Color darkInversePrimary = Color(0xFF7825EA);
  static const Color darkInverseSurface = Color(0xFFE7E1DE);
  static const Color darkOnInverseSurface = Color(0xFF32302E);

  // ─── Shared ───────────────────────────────────────────────
  static const List<Color> primaryGradientLight = [Color(0xFF751FE7), Color(0xFF006288)];
  static const List<Color> primaryGradientDark  = [Color(0xFFD4BBFF), Color(0xFF89CFFA)];

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);
  static const Color vipGold = Color(0xFFFFB300);
}

class AppTheme {
  // ── Backward-compat aliases ──
  static Color primaryColor   = AppColors.lightPrimary;
  static Color secondaryColor = AppColors.lightSecondary;
  static Color accentColor    = AppColors.darkSecondary;
  static Color successColor   = AppColors.success;
  static Color warningColor   = AppColors.warning;
  static Color errorColor     = AppColors.lightError;

  static Color lightBackground        = AppColors.lightBackground;
  static Color lightSurface           = AppColors.lightSurface;
  static Color lightTextPrimary       = AppColors.lightOnSurface;
  static Color lightTextSecondary     = AppColors.lightOnSurfaceVariant;
  static Color lightTextHint          = AppColors.lightOutline;
  static Color lightDivider           = AppColors.lightOutlineVariant;
  static Color lightCardBorder        = AppColors.lightSurfaceContainerHigh;
  static Color lightIconColor         = AppColors.lightPrimary;

  static Color darkBackground         = AppColors.darkBackground;
  static Color darkSurface            = AppColors.darkSurface;
  static Color darkTextPrimary        = AppColors.darkOnSurface;
  static Color darkTextSecondary      = AppColors.darkOnSurfaceVariant;
  static Color darkTextHint           = AppColors.darkOutline;
  static Color darkDivider            = AppColors.darkOutlineVariant;
  static Color darkCardBorder         = AppColors.darkSurfaceContainerHighest;
  static Color darkIconColor          = AppColors.darkPrimary;

  // ── Universe colours (kept for social_universe.dart) ─────
  static Color lightUniverseBackground       = AppColors.lightSurfaceContainerLowest;
  static Color lightUniverseSurface          = AppColors.lightSurfaceContainerLowest;
  static const Color lightUniversePrimary    = Color(0xFF751FE7);
  static const Color lightUniverseSecondary  = Color(0xFF006288);
  static const Color lightUniverseAccent     = Color(0xFF30006A);

  static Color darkUniverseBackground        = AppColors.darkBackground;
  static Color darkUniverseSurface           = AppColors.darkSurfaceContainerLowest;
  static Color darkUniversePrimary           = AppColors.darkPrimary;
  static Color darkUniverseSecondary         = AppColors.darkSecondary;
  static Color darkUniverseAccent            = AppColors.lightPrimary;

  // ─── Internal helpers ────────────────────────────────────
  static TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge:  GoogleFonts.plusJakartaSans(fontSize: 57, fontWeight: FontWeight.w800, color: onSurface, letterSpacing: -1.0, height: 1.12),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.5, height: 1.16),
      displaySmall:  GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.25, height: 1.22),

      headlineLarge:  GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: onSurface, height: 1.25),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: onSurface, height: 1.28),
      headlineSmall:  GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: onSurface, height: 1.33),

      titleLarge:  GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w600, color: onSurface,         height: 1.27),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface,         height: 1.5,  letterSpacing: 0.15),
      titleSmall:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface,         height: 1.43, letterSpacing: 0.1),

      bodyLarge:  GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface,        height: 1.6,  letterSpacing: 0.5),
      bodyMedium: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w400, color: onSurface,        height: 1.5,  letterSpacing: 0.25),
      bodySmall:  GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceVariant, height: 1.33, letterSpacing: 0.4),

      labelLarge:  GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface,        height: 1.43, letterSpacing: 0.1),
      labelMedium: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: onSurfaceVariant, height: 1.33, letterSpacing: 0.5),
      labelSmall:  GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceVariant, height: 1.45, letterSpacing: 0.5),
    );
  }

  // ─── Light Theme ────────────────────────────────────────────
  static ThemeData lightTheme() {
    final tt = _buildTextTheme(AppColors.lightOnSurface, AppColors.lightOnSurfaceVariant);
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme:  ColorScheme.light(
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightOnPrimary,
        primaryContainer: AppColors.lightPrimaryContainer,
        onPrimaryContainer: AppColors.lightOnPrimaryContainer,
        secondary: AppColors.lightSecondary,
        onSecondary: AppColors.lightOnSecondary,
        secondaryContainer: AppColors.lightSecondaryContainer,
        onSecondaryContainer: AppColors.lightOnSecondaryContainer,
        tertiary: AppColors.lightTertiary,
        onTertiary: AppColors.lightOnTertiary,
        tertiaryContainer: AppColors.lightTertiaryContainer,
        onTertiaryContainer: AppColors.lightOnTertiaryContainer,
        error: AppColors.lightError,
        onError: AppColors.lightOnError,
        errorContainer: AppColors.lightErrorContainer,
        onErrorContainer: AppColors.lightOnErrorContainer,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightOnSurface,
        onSurfaceVariant: AppColors.lightOnSurfaceVariant,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.lightOutlineVariant,
        surfaceContainerLowest: AppColors.lightSurfaceContainerLowest,
        surfaceContainerLow: AppColors.lightSurfaceContainerLow,
        surfaceContainer: AppColors.lightSurfaceContainer,
        surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
        surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
        surfaceTint: AppColors.lightSurfaceTint,
        inversePrimary: AppColors.lightInversePrimary,
        inverseSurface: AppColors.lightInverseSurface,
        onInverseSurface: AppColors.lightOnInverseSurface,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: tt,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightOnSurface,
        elevation: 0, scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.lightOnSurface),
        iconTheme: IconThemeData(color: AppColors.lightOnSurface),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurfaceContainerLowest, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.lightSurfaceContainerLowest,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.lightPrimary, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle:  GoogleFonts.beVietnamPro(color: AppColors.lightOutline,            fontSize: 14),
        labelStyle: GoogleFonts.beVietnamPro(color: AppColors.lightOnSurfaceVariant,   fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.lightOnPrimary,
          elevation: 0, shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          side: BorderSide(color: AppColors.lightPrimary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          textStyle: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceContainerLow,
        selectedColor: AppColors.lightPrimaryContainer,
        labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: Colors.transparent, thickness: 0),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurfaceContainerLowest,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: AppColors.lightOnSurfaceVariant,
        showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, elevation: 0,
        selectedLabelStyle:   GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: AppColors.lightOnPrimary,
        elevation: 4, shape: StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.lightOnPrimary  : AppColors.lightOutline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.lightPrimary    : AppColors.lightSurfaceContainerHigh),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor:  WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.lightPrimary : Colors.transparent),
        checkColor: WidgetStateProperty.all(AppColors.lightOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: AppColors.lightOutlineVariant, width: 1.5),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurfaceContainerHighest,
        contentTextStyle: GoogleFonts.beVietnamPro(color: AppColors.lightOnSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.lightSurfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.lightOnSurface),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        elevation: 0, showDragHandle: true, dragHandleColor: AppColors.lightOutlineVariant,
      ),
      tabBarTheme: TabBarTheme(
        labelStyle:           GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w400),
        labelColor: AppColors.lightPrimary,
        unselectedLabelColor: AppColors.lightOnSurfaceVariant,
        indicatorColor: AppColors.lightPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
    );
  }

  // ─── Dark Theme ─────────────────────────────────────────────
  static ThemeData darkTheme() {
    final tt = _buildTextTheme(AppColors.darkOnSurface, AppColors.darkOnSurfaceVariant);
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        secondary: AppColors.darkSecondary,
        onSecondary: AppColors.darkOnSecondary,
        secondaryContainer: AppColors.darkSecondaryContainer,
        onSecondaryContainer: AppColors.darkOnSecondaryContainer,
        tertiary: AppColors.darkTertiary,
        onTertiary: AppColors.darkOnTertiary,
        tertiaryContainer: AppColors.darkTertiaryContainer,
        onTertiaryContainer: AppColors.darkOnTertiaryContainer,
        error: AppColors.darkError,
        onError: AppColors.darkOnError,
        errorContainer: AppColors.darkErrorContainer,
        onErrorContainer: AppColors.darkOnErrorContainer,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
        surfaceContainerLowest: AppColors.darkSurfaceContainerLowest,
        surfaceContainerLow: AppColors.darkSurfaceContainerLow,
        surfaceContainer: AppColors.darkSurfaceContainer,
        surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
        surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
        surfaceTint: AppColors.darkSurfaceTint,
        inversePrimary: AppColors.darkInversePrimary,
        inverseSurface: AppColors.darkInverseSurface,
        onInverseSurface: AppColors.darkOnInverseSurface,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: tt,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkOnSurface,
        elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface),
        iconTheme: IconThemeData(color: AppColors.darkOnSurface),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkSurfaceContainerLow, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.darkSurfaceContainerLowest,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.darkPrimary, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle:  GoogleFonts.beVietnamPro(color: AppColors.darkOutline,           fontSize: 14),
        labelStyle: GoogleFonts.beVietnamPro(color: AppColors.darkOnSurfaceVariant,  fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimaryContainer,
          foregroundColor: AppColors.darkOnPrimaryContainer,
          elevation: 0, shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          side: BorderSide(color: AppColors.darkPrimary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          textStyle: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceContainerHigh,
        selectedColor: AppColors.darkPrimaryContainer,
        labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: Colors.transparent, thickness: 0),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainerLow,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkOnSurfaceVariant,
        showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, elevation: 0,
        selectedLabelStyle:   GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkOnPrimary,
        elevation: 4, shape: StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.darkOnPrimary         : AppColors.darkOutline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.darkPrimaryContainer  : AppColors.darkSurfaceContainerHigh),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor:  WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.darkPrimaryContainer : Colors.transparent),
        checkColor: WidgetStateProperty.all(AppColors.darkOnPrimaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: AppColors.darkOutlineVariant, width: 1.5),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainerHighest,
        contentTextStyle: GoogleFonts.beVietnamPro(color: AppColors.darkOnSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.darkSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        elevation: 0, showDragHandle: true, dragHandleColor: AppColors.darkOutlineVariant,
      ),
      tabBarTheme: TabBarTheme(
        labelStyle:           GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w400),
        labelColor: AppColors.darkPrimary,
        unselectedLabelColor: AppColors.darkOnSurfaceVariant,
        indicatorColor: AppColors.darkPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
    );
  }
}

/// Canonical radius scale (matches Stitch mockup Tailwind config:
/// DEFAULT 1rem, lg 2rem, xl 3rem, full 9999px).
class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;   // 1rem — DEFAULT
  static const double lg = 32;   // 2rem
  static const double xl = 48;   // 3rem
  static const double pill = 9999;
}

// ─── Reusable decoration helpers ────────────────────────────────

BoxDecoration primaryGradientDecoration({bool isDark = false}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: isDark ? AppColors.primaryGradientDark : AppColors.primaryGradientLight,
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(9999),
    boxShadow: [
      BoxShadow(
        color: (isDark ? AppColors.darkPrimaryContainer : AppColors.lightPrimary).withOpacity(0.25),
        blurRadius: 20, offset: const Offset(0, 6),
      ),
    ],
  );
}

BoxDecoration glassDecoration({double opacity = 0.7, BorderRadius? borderRadius}) {
  return BoxDecoration(
    color: AppColors.darkSurfaceContainerHigh.withOpacity(opacity),
    borderRadius: borderRadius ?? BorderRadius.circular(24),
  );
}

BoxDecoration surfaceCardDecoration(BuildContext context, {double radius = 20, bool elevated = false}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: elevated
        ? (isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightSurfaceContainerLowest)
        : (isDark ? AppColors.darkSurfaceContainerLow    : AppColors.lightSurfaceContainerLowest),
    borderRadius: BorderRadius.circular(radius),
  );
}

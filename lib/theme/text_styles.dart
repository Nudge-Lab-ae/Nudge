// lib/theme/text_styles.dart
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'app_theme.dart';

class AppTextStyles {
  // ── Headlines (Plus Jakarta Sans) ──────────────────────────
  static TextStyle displayLarge(BuildContext context) =>
      Theme.of(context).textTheme.displayLarge!;
  static TextStyle displayMedium(BuildContext context) =>
      Theme.of(context).textTheme.displayMedium!;

  static TextStyle headline(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;
  static TextStyle headlineSmall(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!;

  static TextStyle titleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!;
  static TextStyle titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;
  static TextStyle titleSmall(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;

  // ── Body (Be Vietnam Pro) ───────────────────────────────────
  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;
  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;
  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  // ── Labels ─────────────────────────────────────────────────
  static TextStyle labelLarge(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;
  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!;
  static TextStyle labelSmall(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!;

  // ── Static convenience styles (use sparingly) ──────────────
  static final TextStyle nudgeTitle = GoogleFonts.plusJakartaSans(
    fontSize: 20, fontWeight: FontWeight.w700, height: 1.3,
  );
  static final TextStyle sectionHeader = GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.1,
  );
  static final TextStyle cardTitle = GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w600, height: 1.4,
  );
  static final TextStyle bodyText = GoogleFonts.beVietnamPro(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.55,
  );
  static final TextStyle caption = GoogleFonts.beVietnamPro(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
    color: AppColors.lightOnSurfaceVariant,
  );
  static final TextStyle pill = GoogleFonts.beVietnamPro(
    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2,
  );
  static final TextStyle buttonLabel = GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1,
  );
}

// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xff3CB3E9);
  static const Color secondaryColor = Color(0xFF5CDEE5);
  static const Color accentColor = Color(0xFF2D85F6);
  static const Color successColor = Color(0xff00dd00);
  static const Color warningColor = Color(0xFFFFA500);
  static const Color errorColor = Color(0xFFFF5252);
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFF9FAFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xff555555);
  static const Color lightTextSecondary = Color(0xff6e6e6e);
  static const Color lightTextHint = Color(0xFF8A8A8A);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightCardBorder = Color(0xFFFEFEFE);
  static const Color lightIconColor = Color(0xff3CB3E9);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2D2D2D);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextHint = Color(0xFF8A8A8A);
  static const Color darkDivider = Color(0xFF333333);
  static const Color darkCardBorder = Color(0xFF444444);
  static const Color darkIconColor = Color(0xFF5CDEE5);
  
  // Social Universe colors (light mode)
  static const Color lightUniverseBackground = Color(0xFFE6F7FF);
  static const Color lightUniverseSurface = Color(0xFFFFFFFF);
  static const Color lightUniversePrimary = Color(0xFF0066CC);
  static const Color lightUniverseSecondary = Color(0xFF66B2FF);
  static const Color lightUniverseAccent = Color(0xFF003366);
  
  // Social Universe colors (dark mode - keeping your existing dark scheme)
  static const Color darkUniverseBackground = Color(0xFF0A0E21);
  static const Color darkUniverseSurface = Color(0xFF1A1F38);
  static const Color darkUniversePrimary = Color(0xFF8A9DFF);
  static const Color darkUniverseSecondary = Color(0xFF5CDEE5);
  static const Color darkUniverseAccent = Color(0xFF2D85F6);
  
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      fontFamily: 'OpenSans',
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightSurface,
        background: lightBackground,
        onSurface: lightTextPrimary,
      ),
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightSurface,
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: lightCardBorder, width: 0.6),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
          color: lightTextPrimary,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: lightTextPrimary),
        displayMedium: TextStyle(fontSize: 24, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: lightTextPrimary),
        displaySmall: TextStyle(fontSize: 20, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: lightTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontFamily: 'OpenSans', color: lightTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontFamily: 'OpenSans', color: lightTextSecondary),
        bodySmall: TextStyle(fontSize: 12, fontFamily: 'OpenSans', color: lightTextHint),
        labelLarge: TextStyle(fontSize: 16, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: lightSurface),
      ),
      iconTheme: const IconThemeData(color: lightIconColor),
      dividerColor: lightDivider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextHint),
        labelStyle: const TextStyle(color: lightTextPrimary),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
    );
  }
  
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkIconColor,
      fontFamily: 'OpenSans',
      colorScheme: const ColorScheme.dark(
        primary: darkIconColor,
        secondary: secondaryColor,
        surface: darkSurface,
        background: darkBackground,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkSurface,
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: darkCardBorder, width: 0.6),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: darkTextPrimary),
        displayMedium: TextStyle(fontSize: 24, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: darkTextPrimary),
        displaySmall: TextStyle(fontSize: 20, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontFamily: 'OpenSans', color: darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontFamily: 'OpenSans', color: darkTextSecondary),
        bodySmall: TextStyle(fontSize: 12, fontFamily: 'OpenSans', color: darkTextHint),
        labelLarge: TextStyle(fontSize: 16, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: darkSurface),
      ),
      iconTheme: const IconThemeData(color: darkIconColor),
      dividerColor: darkDivider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkIconColor, width: 2),
        ),
        hintStyle: const TextStyle(color: darkTextHint),
        labelStyle: const TextStyle(color: darkTextPrimary),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: darkIconColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkIconColor,
          foregroundColor: darkBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: darkIconColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkIconColor,
        foregroundColor: darkBackground,
      ),
      useMaterial3: true,
    );
  }
}
// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() { _loadTheme(); }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  ThemeData getCurrentTheme(BuildContext context) =>
      _isDarkMode ? AppTheme.darkTheme() : AppTheme.lightTheme();

  // Kept for backward compatibility - prefer Theme.of(context) directly
  Color getBackgroundColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;

  Color getSurfaceColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkSurfaceContainerLow : AppColors.lightSurfaceContainerLow;

  Color getCardColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkSurfaceContainerLow : AppColors.lightSurfaceContainerLowest;

  Color getButtonColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkSurfaceContainerHigh : AppColors.lightSurfaceContainerHigh;

  Color getButtonSecondaryColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

  Color getTextPrimaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color getTextSecondaryColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

  Color getTextHintColor(BuildContext context) =>
      _isDarkMode ? AppColors.darkOutline : AppColors.lightOutline;
}

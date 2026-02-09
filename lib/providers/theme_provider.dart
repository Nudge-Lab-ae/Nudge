// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

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

  ThemeData getCurrentTheme(BuildContext context) {
    return _isDarkMode ? AppTheme.darkTheme() : AppTheme.lightTheme();
  }

  Color getBackgroundColor(BuildContext context) {
    return _isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground;
  }

  Color getSurfaceColor(BuildContext context) {
    return _isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface;
  }

  Color getCardColor(BuildContext context) {
    return _isDarkMode ? const Color.fromARGB(255, 57, 57, 57) : Colors.white;
  }

  Color getButtonColor(BuildContext context) {
    return _isDarkMode ? const Color.fromARGB(255, 146, 145, 145) : const Color.fromARGB(255, 196, 195, 195);
  }

  Color getButtonSecondaryColor(BuildContext context) {
    return _isDarkMode ? const Color.fromARGB(255, 167, 166, 166) : const Color.fromARGB(255, 90, 89, 89);
  }

  Color getTextPrimaryColor(BuildContext context) {
    return _isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
  }

  Color getTextSecondaryColor(BuildContext context) {
    return _isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
  }
}
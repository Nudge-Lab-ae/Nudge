// lib/helpers/deletion_retry_helper.dart
import 'package:shared_preferences/shared_preferences.dart';

class DeletionRetryHelper {
  static const String _deletionRetryKey = 'pending_deletion_retry';
  static const String _showPromptKey = 'show_retry_prompt';

  static Future<void> storeDeletionRetryIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deletionRetryKey, true);
  }

  static Future<bool> hasPendingDeletionRetry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deletionRetryKey) ?? false;
  }

  static Future<void> clearDeletionRetryIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deletionRetryKey);
  }

  static Future<void> setShowRetryPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPromptKey, value);
  }

  static Future<bool> shouldShowRetryPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showPromptKey) ?? false;
  }

  static Future<void> clearRetryPromptFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_showPromptKey);
  }
}
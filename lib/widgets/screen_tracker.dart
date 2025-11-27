// Create a new file: lib/utils/screen_tracker.dart
import 'package:flutter/material.dart';

class ScreenTracker {
  static String getCurrentScreen(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) return 'unknown';
    
    final routeName = route.settings.name;
    
    // Map route names to user-friendly screen names
    final screenMap = {
      '/dashboard': 'Dashboard',
      '/contacts': 'Contacts',
      '/groups': 'Groups', 
      '/nudges': 'Nudges',
      '/add-contact': 'Add Contact',
      '/contact-detail': 'Contact Detail',
      '/edit-contact': 'Edit Contact',
      '/import-contacts': 'Import Contacts',
      '/feedback-forum': 'Feedback Forum',
    };
    
    return screenMap[routeName] ?? routeName ?? 'unknown';
  }
  
  // For dashboard tabs
  static String getDashboardSection(int currentIndex) {
    final sections = ['Dashboard', 'Contacts', 'Groups', 'Nudges'];
    return sections[currentIndex];
  }
}
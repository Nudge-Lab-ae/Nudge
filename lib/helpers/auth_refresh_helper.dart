// lib/helpers/auth_refresh_helper.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthRefreshHelper {
  static Future<void> refreshAuthState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Force token refresh
        await user.getIdToken(true);
        
        // Reload user data
        await user.reload();
        
        // Get fresh user instance
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser != null) {
          //print('Auth state refreshed successfully for user: ${freshUser.uid}');
        }
      }
    } catch (e) {
      //print('Error refreshing auth state: $e');
    }
  }
}
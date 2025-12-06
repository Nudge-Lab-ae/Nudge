// lib/helpers/app_restart_helper.dart
import 'package:flutter/material.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';

class AppRestartHelper {
  static bool _shouldSkipSplash = false;
  
  static bool get shouldSkipSplash => _shouldSkipSplash;
  
  static void setSkipSplashFlag() {
    _shouldSkipSplash = true;
  }
  
  static void clearSkipSplashFlag() {
    _shouldSkipSplash = false;
  }
  
  // This method forces a complete app restart by pushing a new route
  // and clearing all existing state
  static void forceAppRestart(BuildContext context) {
    // Clear navigation stack and push to dashboard
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const RestartWrapper(child: DashboardScreen()),
      ),
      (route) => false,
    );
  }
}

// A wrapper widget that forces rebuild of child
class RestartWrapper extends StatefulWidget {
  final Widget child;
  
  const RestartWrapper({Key? key, required this.child}) : super(key: key);
  
  @override
  State<RestartWrapper> createState() => _RestartWrapperState();
}

class _RestartWrapperState extends State<RestartWrapper> {
  Key _key = UniqueKey();
  
  @override
  void initState() {
    super.initState();
    // Force a rebuild after a short delay to ensure fresh state
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _key = UniqueKey();
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
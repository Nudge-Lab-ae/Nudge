import 'package:flutter/material.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';

class AppWrapper extends StatefulWidget {
  final Widget child;

  const AppWrapper({super.key, required this.child});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _showFeedbackButton = true;

  // List of routes where we don't want to show the feedback button
  final _excludedRoutes = {
    '/welcome',
    '/login', 
    '/register',
    '/complete_profile',
    '/splash',
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content
        widget.child,
        
        // Global feedback button (conditionally shown)
        if (_showFeedbackButton) 
          Positioned(
            right: 16,
            bottom: 16,
            child: FeedbackFloatingButton(),
          ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateButtonVisibility();
  }

  void _updateButtonVisibility() {
    final route = ModalRoute.of(context);
    if (route != null) {
      final routeName = route.settings.name;
      final shouldShow = routeName != null && !_excludedRoutes.contains(routeName);
      
      if (shouldShow != _showFeedbackButton) {
        setState(() {
          _showFeedbackButton = shouldShow;
        });
      }
    }
  }
}
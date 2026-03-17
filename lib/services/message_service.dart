// top_message_service.dart
import 'package:flutter/material.dart';
import 'package:nudge/widgets/message_widget.dart';

class TopMessageService {
  static final TopMessageService _instance = TopMessageService._internal();
  factory TopMessageService() => _instance;
  TopMessageService._internal();

  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  // Original method for default style
  void showMessage({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = Colors.blue,
    Color textColor = Colors.white,
    IconData? icon,
  }) {
    if (_isShowing) {
      _removeOverlay();
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => TopMessageWidget.defaultStyle(
        message: message,
        duration: duration,
        backgroundColor: backgroundColor,
        textColor: textColor,
        icon: icon,
        onDismissed: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  // New method for custom content
  void showCustomContent({
    required BuildContext context,
    required Widget customContent,
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = Colors.blue,
    double height = 120,
  }) {
    if (_isShowing) {
      _removeOverlay();
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => TopMessageWidget.custom(
        height: height,
        customContent: customContent,
        duration: duration,
        backgroundColor: backgroundColor,
        onDismissed: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  // Method to manually dismiss
  void dismiss() {
    _removeOverlay();
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}
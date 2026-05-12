// top_message_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TopMessageWidget extends StatefulWidget {
  final Duration duration;
  final Color backgroundColor;
  final VoidCallback onDismissed;
  final Widget? customContent; // New: custom content widget
  final bool useDefaultContent; // Flag to toggle between default and custom
  final String? message; // Made optional for custom content
  final IconData? icon; // Made optional for custom content
  final Color? textColor; // Made optional for custom content
  final double? height; // Made optional for custom content

  const TopMessageWidget({
    Key? key,
    required this.duration,
    required this.backgroundColor,
    required this.onDismissed,
    this.customContent,
    this.useDefaultContent = false,
    this.message,
    this.icon,
    this.textColor,
    this.height,
  }) : super(key: key);

  // Factory constructor for default style
  factory TopMessageWidget.defaultStyle({
    required String message,
    required Duration duration,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onDismissed,
    IconData? icon,
  }) {
    return TopMessageWidget(
      duration: duration,
      backgroundColor: backgroundColor,
      onDismissed: onDismissed,
      useDefaultContent: true,
      message: message,
      icon: icon,
      textColor: textColor,
    );
  }

  // Factory constructor for custom content
  factory TopMessageWidget.custom({
    required Widget customContent,
    required Duration duration,
    required Color backgroundColor,
    required double height,
    required VoidCallback onDismissed,
  }) {
    return TopMessageWidget(
      duration: duration,
      backgroundColor: backgroundColor,
      onDismissed: onDismissed,
      useDefaultContent: false,
      height: height,
      customContent: customContent,
    );
  }

  @override
  _TopMessageWidgetState createState() => _TopMessageWidgetState();
}

class _TopMessageWidgetState extends State<TopMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset(0.0, -1.0),
      end: Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;

    _controller.reverse().then((_) {
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDefaultContent() {
    return Row(
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            color: widget.textColor,
            size: 18,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            widget.message!,
            style: TextStyle(
              color: widget.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: GoogleFonts.beVietnamPro().fontFamily
            ), textAlign: TextAlign.center,
            // maxLines: 1,
            // overflow: TextOverflow.ellipsis,
          ),
        ),
        // GestureDetector(
        //   onTap: _dismiss,
        //   child: Icon(
        //     Icons.close,
        //     color: widget.textColor?.withOpacity(0.7),
        //     size: 16,
        //   ),
        // ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Default style banners now grow to fit the message instead of
    // clipping at 80 / 120 px. Custom-content callers still honour the
    // explicit `height` they pass in.
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: widget.height ?? (statusBarHeight + 64),
            ),
            padding: EdgeInsets.only(top: statusBarHeight),
            color: widget.backgroundColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: widget.useDefaultContent
                  ? _buildDefaultContent()
                  : widget.customContent!,
            ),
          ),
        ),
      ),
    );
  }
}
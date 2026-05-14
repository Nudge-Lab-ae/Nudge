import 'dart:ui';
import 'package:nudge/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/screens/feedback/feedback_bottom_sheet.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
import 'package:provider/provider.dart';

class FeedbackAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  FeedbackAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

class FeedbackFloatingButton extends StatefulWidget {
  final String? currentSection;
  final List<FeedbackAction>? extraActions;
  final bool isDeleteMode;
  final VoidCallback? onDeletePressed;
  final String? deleteButtonLabel;
  final VoidCallback? onMenuStateChanged;
  final bool fromDashboard;
  final bool onDarkBackground;
  final FeedbackFloatingButtonController? controller;

  const FeedbackFloatingButton({
    super.key,
    this.currentSection,
    this.extraActions,
    this.isDeleteMode = false,
    this.onDeletePressed,
    this.deleteButtonLabel = 'Delete',
    this.onMenuStateChanged,
    this.fromDashboard = false,
    this.onDarkBackground = false,
    this.controller,
  });

  @override
  State<FeedbackFloatingButton> createState() => _FeedbackFloatingButtonState();
}

class _FeedbackFloatingButtonState extends State<FeedbackFloatingButton>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _menuController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;
  // Heartbeat plays a fixed number of cycles on first render, then stays
  // still — perpetual pulse was distracting on every screen.
  static const int _heartbeatMaxCycles = 2;
  int _heartbeatCycles = 0;

  @override
  void initState() {
    super.initState();

    _menuController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );

    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _heartbeatAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.15, end: 1.0), weight: 1),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.08), weight: 1),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.08, end: 1.0), weight: 2),
    ]).animate(
        CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut));

    _heartbeatController.addStatusListener(_onHeartbeatStatus);
    _heartbeatController.forward();

    widget.controller?.registerCloseCallback(closeMenuExternally);
  }

  void _onHeartbeatStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _heartbeatCycles++;
    if (_heartbeatCycles < _heartbeatMaxCycles) {
      _heartbeatController.forward(from: 0.0);
    }
  }

  // ── Menu state ────────────────────────────────────────────────────────────

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _menuController.forward();
      } else {
        _menuController.reverse();
      }
      context.read<FeedbackProvider>().setFabMenuState(_isExpanded);
      widget.onMenuStateChanged?.call();
    });
  }

  void _closeMenu() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _menuController.reverse();
      });
      context.read<FeedbackProvider>().setFabMenuState(false);
      widget.onMenuStateChanged?.call();
    }
  }

  void closeMenuExternally() => _closeMenu();

  // ── Navigation ────────────────────────────────────────────────────────────

  void _showFeedbackDialog(BuildContext context, String section) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedbackBottomSheet(
        currentSection: widget.currentSection ?? section,
      ),
    ).whenComplete(_closeMenu);
  }

  void _openFeedbackForum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackForumScreen()),
    ).whenComplete(_closeMenu);
  }

  @override
  void dispose() {
    _menuController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Build items: extra actions first (top of column), then fixed actions
    final allMenuItems = <Map<String, dynamic>>[];

    // Extra actions (Settings, Add Group, Log Interaction, etc.) — appear at top
    if (widget.extraActions != null) {
      for (final action in widget.extraActions!) {
        allMenuItems.add({
          'icon': action.icon,
          'text': action.label,
          'onTap': action.onPressed,
        });
      }
    }

    // Delete action
    if (widget.isDeleteMode && widget.onDeletePressed != null) {
      allMenuItems.add({
        'icon': Icons.delete_outline_rounded,
        'text': widget.deleteButtonLabel ?? 'Delete',
        'onTap': widget.onDeletePressed!,
      });
    }

    // Fixed: View Forum (non-dashboard only)
    if (!widget.fromDashboard) {
      allMenuItems.add({
        'icon': Icons.forum_outlined,
        'text': 'View Forum',
        'onTap': () => _openFeedbackForum(context),
      });
    }

    // Fixed: Give Feedback — always last (closest to close button)
    allMenuItems.add({
      'icon': Icons.chat_bubble_outline_rounded,
      'text': 'Give Feedback',
      'onTap': () {
        final route = ModalRoute.of(context)?.settings.name ?? 'unknown';
        _showFeedbackDialog(context, route);
      },
    });

    // ── Collapsed: just the FAB ──────────────────────────────────────────
    if (!_isExpanded) {
      return _buildMainButton();
    }

    // ── Expanded: full-screen overlay + vertical menu ─────────────────────
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useWhiteLabels = isDark || widget.onDarkBackground;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Backdrop blur (no tint — pure blur only) ───────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── Vertical menu column (above close button) ──────────────────
          Positioned(
            right: 0,
            bottom: 76, // above the 60px close button + 16px gap
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < allMenuItems.length; i++) ...[
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          alignment: Alignment.centerRight,
                          child: _buildVerticalMenuItem(
                            icon: allMenuItems[i]['icon'] as IconData,
                            text: allMenuItems[i]['text'] as String,
                            onTap: allMenuItems[i]['onTap'] as VoidCallback,
                            useWhiteLabel: useWhiteLabels,
                          ),
                        ),
                      ),
                      if (i < allMenuItems.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ),

          // ── Close button (purple X circle) ────────────────────────────
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildCloseButton(),
          ),
        ],
      ),
    );
  }

  // ── Collapsed FAB (Nudge logo with heartbeat) ──────────────────────────
  // Two variants per Stitch v4:
  //   light → dashboard_consistent_titles: 56px white circle, subtle shadow,
  //           32px Nudge logo foreground.
  //   dark  → social_universe_brighter_glow_2: 56px dark glass circle, 2px
  //           primary/40 ring, primary glow shadow, 40px logo.
  // Variant is selected by widget.onDarkBackground.

  Widget _buildMainButton() {
    // Dark variant fires either when the screen explicitly has a dark
    // background (e.g. Social Universe in light mode) OR whenever the
    // whole app is in dark mode. This keeps the FAB legible against the
    // dark scaffold on every tab when the user has dark mode enabled.
    final isDarkVariant = widget.onDarkBackground ||
        Theme.of(context).brightness == Brightness.dark;
    final logoSize = isDarkVariant ? 40.0 : 32.0;
    return AnimatedBuilder(
      animation: _heartbeatAnimation,
      builder: (context, _) => Transform.scale(
        scale: _heartbeatAnimation.value,
        child: GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkVariant
                  ? const Color(0xCC2D2926)
                  : Colors.white,
              border: Border.all(
                color: isDarkVariant
                    ? AppColors.lightPrimary.withOpacity(0.40)
                    : Colors.black.withOpacity(0.05),
                width: isDarkVariant ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkVariant
                      ? AppColors.lightPrimary.withOpacity(0.30)
                      : Colors.black.withOpacity(0.18),
                  blurRadius: isDarkVariant ? 20 : 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/Nudge-logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // ── Close button ──────────────────────────────────────────────────────────

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x55751FE7),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  // ── Individual menu item ──────────────────────────────────────────────────

  Widget _buildVerticalMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool useWhiteLabel = false,
  }) {
    final isHighlighted = _isPrimaryAction(text);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same canonical solid purple in light and dark mode (no separate
    // dark-mode tint). The dark surface fill behind the icon provides
    // the contrast.
    final iconColor =
        isHighlighted ? Colors.white : AppColors.solidPurple;
    final btnDecoration = isHighlighted
        ? const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x55751FE7),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: isDark ? const Color(0xFF2D2926) : Colors.white,
            shape: BoxShape.circle,
            border: isDark
                ? Border.all(
                    color: AppColors.lightPrimary.withOpacity(0.30),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          );

    return GestureDetector(
      onTap: () {
        onTap();
        _closeMenu();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              // Subtle shadow under the text for readability over blurred bg
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: useWhiteLabel ? Colors.white : Colors.black87,
                shadows: useWhiteLabel
                    ? null
                    : const [Shadow(color: Colors.white, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Circle button
          Container(
            width: 54,
            height: 54,
            decoration: btnDecoration,
            child: Center(
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  // Determines if an action should get the purple gradient highlight
  bool _isPrimaryAction(String text) {
    return text == 'Log Interaction' || text == 'Add Interaction';
  }
}

class FeedbackFloatingButtonController {
  void Function()? _closeMenuCallback;

  void closeMenu() => _closeMenuCallback?.call();

  void registerCloseCallback(void Function() callback) {
    _closeMenuCallback = callback;
  }
}
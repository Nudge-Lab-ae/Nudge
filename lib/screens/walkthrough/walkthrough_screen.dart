// lib/screens/walkthrough/walkthrough_screen.dart
// Post-signup onboarding walkthrough — 5 pages introducing the Social Universe.
// Mirrors Stitch mockups: walkthrough_welcome_final_v2, _three_circles_final,
// _star_sizes_final_v2, _movement_final_v2, _how_to_use_final.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/welcome_page.dart';
import 'pages/three_circles_page.dart';
import 'pages/star_sizes_page.dart';
import 'pages/movement_page.dart';
import 'pages/how_to_use_page.dart';

const String walkthroughCompletedKey = 'walkthrough_completed_v1';

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _pageCount = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_index >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onBack() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(walkthroughCompletedKey, true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/dashboard',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Walkthrough is always rendered in the light "Illuminated Scholar"
    // palette regardless of system theme — the Stitch mockups for these
    // screens are all `html class="light"`, and user feedback was that
    // the dark version felt too murky.
    return Theme(
      data: AppTheme.lightTheme(),
      child: Builder(
        builder: (themedContext) {
          final scheme = Theme.of(themedContext).colorScheme;
          return Scaffold(
            backgroundColor: const Color(0xFFFAF9F6),
            body: SafeArea(
              child: Column(
                children: [
                  _WalkthroughHeader(onClose: _finish, isDark: false),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _index = i),
                      children: const [
                        WelcomePage(),
                        ThreeCirclesPage(),
                        StarSizesPage(),
                        MovementPage(),
                        HowToUsePage(),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest.withOpacity(0.92),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: _WalkthroughFooter(
                      index: _index,
                      total: _pageCount,
                      onBack: _onBack,
                      onNext: _onNext,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WalkthroughHeader extends StatelessWidget {
  final VoidCallback onClose;
  final bool isDark;
  const _WalkthroughHeader({required this.onClose, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Skip walkthrough',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            iconSize: 22,
          ),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isDark
                  ? const [Color(0xFFE7E1DE), Color(0xFF968DA1)]
                  : const [Color(0xFF1A1A1A), Color(0xFF666666)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(bounds),
            child: Text(
              'SOCIAL UNIVERSE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 44), // visual balance for IconButton
        ],
      ),
    );
  }
}

class _WalkthroughFooter extends StatelessWidget {
  final int index;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _WalkthroughFooter({
    required this.index,
    required this.total,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFirst = index == 0;
    final isLast = index == total - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: isFirst ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: isFirst ? null : onBack,
              foreground: scheme.onSurfaceVariant,
              background: scheme.surfaceContainerLow,
            ),
          ),
          Expanded(
            child: Center(
              child: WalkthroughDots(
                index: index,
                total: total,
                activeColor: scheme.primary,
                inactiveColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          _CircleIconButton(
            icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
            onTap: onNext,
            foreground: scheme.onPrimary,
            background: scheme.primary,
            elevated: true,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color foreground;
  final Color background;
  final bool elevated;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.foreground,
    required this.background,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: elevated ? 8 : 0,
      shadowColor: elevated
          ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
          : Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: foreground),
        ),
      ),
    );
  }
}

class WalkthroughDots extends StatelessWidget {
  final int index;
  final int total;
  final Color activeColor;
  final Color inactiveColor;

  const WalkthroughDots({
    super.key,
    required this.index,
    required this.total,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        );
      }),
    );
  }
}

/// Shared body container for walkthrough pages: max-width, padding, scroll.
class WalkthroughBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const WalkthroughBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

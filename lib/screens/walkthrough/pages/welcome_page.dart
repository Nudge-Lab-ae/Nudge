// lib/screens/walkthrough/pages/welcome_page.dart
// Page 1 — Welcome. Mirrors walkthrough_welcome_final_v2.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/screens/walkthrough/walkthrough_screen.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(child: _BackgroundOrb(color: scheme.primaryContainer)),
        WalkthroughBody(
          children: [
            const SizedBox(height: 24),
            _NudgeWordmarkPill(scheme: scheme),
            const SizedBox(height: 36),
            _CentralIllustration(scheme: scheme, isDark: isDark),
            const SizedBox(height: 36),
            Text(
              'Welcome to Your Social Universe',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.5,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Visualize all your relationships at a glance. Each star represents a person in your life.',
              textAlign: TextAlign.center,
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ],
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final Color color;
  const _BackgroundOrb({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.7),
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.18), color.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _NudgeWordmarkPill extends StatelessWidget {
  final ColorScheme scheme;
  const _NudgeWordmarkPill({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.2)),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          // Near-black logo gradient per Stitch mockups
          // (`linear-gradient(to top, #1a1a1a, #666666)`).
          colors: [Color(0xFF1A1A1A), Color(0xFF666666)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(bounds),
        child: Text(
          'NUDGE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _CentralIllustration extends StatelessWidget {
  final ColorScheme scheme;
  final bool isDark;
  const _CentralIllustration({required this.scheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.30 : 0.06),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Central rocket plate
            Transform.rotate(
              angle: 0.18,
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(56),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            // Star satellite (top right)
            Align(
              alignment: const Alignment(0.85, -0.85),
              child: Transform.rotate(
                angle: -0.2,
                child: _SatelliteIcon(
                  icon: Icons.star_rounded,
                  background: scheme.tertiaryContainer,
                  size: 56,
                  iconSize: 30,
                ),
              ),
            ),
            // Group satellite (bottom left)
            Align(
              alignment: const Alignment(-0.85, 0.6),
              child: Transform.rotate(
                angle: 0.2,
                child: _SatelliteIcon(
                  icon: Icons.groups_rounded,
                  background: scheme.secondary,
                  size: 48,
                  iconSize: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SatelliteIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final double size;
  final double iconSize;
  const _SatelliteIcon({
    required this.icon,
    required this.background,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

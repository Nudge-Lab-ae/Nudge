// lib/screens/walkthrough/pages/three_circles_page.dart
// Page 2 — Three Circles. Mirrors walkthrough_three_circles_final.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/screens/walkthrough/walkthrough_screen.dart';

class ThreeCirclesPage extends StatelessWidget {
  const ThreeCirclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WalkthroughBody(
      children: [
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: _ThreeRingsVisual(scheme: scheme),
        ),
        const SizedBox(height: 32),
        Text(
          'The Three Circles',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.beVietnamPro(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
            children: [
              const TextSpan(
                text:
                    'Your connections are organized into three rings based on how active your relationship is: ',
              ),
              TextSpan(
                text: 'Inner',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: ', '),
              TextSpan(
                text: 'Middle',
                style: TextStyle(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: ', and '),
              TextSpan(
                text: 'Outer',
                style: TextStyle(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _RingLegend(scheme: scheme),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ThreeRingsVisual extends StatelessWidget {
  final ColorScheme scheme;
  const _ThreeRingsVisual({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.tertiary.withOpacity(0.22),
              width: 1.5,
            ),
          ),
        ),
        // Middle ring
        Container(
          width: 188,
          height: 188,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.secondary.withOpacity(0.22),
              width: 1.5,
            ),
          ),
        ),
        // Outer satellite (top of outer ring)
        const Align(
          alignment: Alignment(-0.5, -0.95),
          child: _RingSatellite(
            icon: Icons.groups_rounded,
            ringRole: _RingRole.outer,
          ),
        ),
        // Middle satellite (bottom-right of middle ring)
        const Align(
          alignment: Alignment(0.55, 0.55),
          child: _RingSatellite(
            icon: Icons.person_add_rounded,
            ringRole: _RingRole.middle,
          ),
        ),
        // Inner orb (the "heart")
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [scheme.primary, scheme.primaryContainer],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.38),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: scheme.onPrimary,
            size: 36,
          ),
        ),
      ],
    );
  }
}

enum _RingRole { outer, middle }

class _RingSatellite extends StatelessWidget {
  final IconData icon;
  final _RingRole ringRole;
  const _RingSatellite({required this.icon, required this.ringRole});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ringRole == _RingRole.outer ? scheme.tertiary : scheme.secondary;
    final size = ringRole == _RingRole.outer ? 48.0 : 40.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );
  }
}

class _RingLegend extends StatelessWidget {
  final ColorScheme scheme;
  const _RingLegend({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LegendCard(
            label: 'Inner',
            sub: 'Daily Vibes',
            color: scheme.primary,
            scheme: scheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LegendCard(
            label: 'Middle',
            sub: 'Casual Chat',
            color: scheme.secondary,
            scheme: scheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LegendCard(
            label: 'Outer',
            sub: 'Networking',
            color: scheme.tertiary,
            scheme: scheme,
          ),
        ),
      ],
    );
  }
}

class _LegendCard extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final ColorScheme scheme;
  const _LegendCard({
    required this.label,
    required this.sub,
    required this.color,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: GoogleFonts.beVietnamPro(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

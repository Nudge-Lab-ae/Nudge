// lib/screens/walkthrough/pages/star_sizes_page.dart
// Page 3 — Star Sizes Matter. Mirrors walkthrough_star_sizes_final_v2.
// Three floating stars with phased vertical drift (`floating-star` keyframe in mockup).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/screens/walkthrough/walkthrough_screen.dart';

class StarSizesPage extends StatefulWidget {
  const StarSizesPage({super.key});

  @override
  State<StarSizesPage> createState() => _StarSizesPageState();
}

class _StarSizesPageState extends State<StarSizesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(child: _BackgroundBlobs(scheme: scheme)),
        WalkthroughBody(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _FloatingStar(
                      label: 'Large',
                      tileSize: 130,
                      iconSize: 76,
                      phase: 0.0,
                      controller: _controller,
                      showBadge: true,
                      scheme: scheme,
                    ),
                    _FloatingStar(
                      label: 'Medium',
                      tileSize: 100,
                      iconSize: 56,
                      phase: 0.33,
                      controller: _controller,
                      scheme: scheme,
                    ),
                    _FloatingStar(
                      label: 'Small',
                      tileSize: 72,
                      iconSize: 36,
                      phase: 0.66,
                      controller: _controller,
                      scheme: scheme,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Star Sizes Matter',
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
                        'Larger stars are more important to you (based on your categories). Reorder categories in ',
                  ),
                  TextSpan(
                    text: 'Settings',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' to adjust sizes.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }
}

class _FloatingStar extends StatelessWidget {
  final String label;
  final double tileSize;
  final double iconSize;
  final double phase;
  final AnimationController controller;
  final bool showBadge;
  final ColorScheme scheme;

  const _FloatingStar({
    required this.label,
    required this.tileSize,
    required this.iconSize,
    required this.phase,
    required this.controller,
    required this.scheme,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = (controller.value + phase) % 1.0;
    final dy = math.sin(t * 2 * math.pi) * 8.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, dy),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: tileSize,
                height: tileSize,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 36,
                      offset: const Offset(0, 28),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: iconSize,
                  color: scheme.primary,
                ),
              ),
              if (showBadge)
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.tertiary,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'PRIORITY 1',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: scheme.onTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _BackgroundBlobs extends StatelessWidget {
  final ColorScheme scheme;
  const _BackgroundBlobs({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: _Blob(color: scheme.primaryContainer.withOpacity(0.18)),
          ),
          Positioned(
            bottom: -40,
            left: -60,
            child: _Blob(color: scheme.secondaryContainer.withOpacity(0.18)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  const _Blob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

// lib/screens/walkthrough/pages/movement_page.dart
// Page 4 — Movement & Engagement. Mirrors walkthrough_movement_final_v2.
// Progress track with a star sliding/pulsing along it.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/screens/walkthrough/walkthrough_screen.dart';

class MovementPage extends StatefulWidget {
  const MovementPage({super.key});

  @override
  State<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends State<MovementPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WalkthroughBody(
      children: [
        const SizedBox(height: 24),
        _NudgeWordmarkGradient(scheme: scheme),
        const SizedBox(height: 28),
        _ProgressVisual(
          scheme: scheme,
          pulseController: _pulseController,
        ),
        const SizedBox(height: 32),
        Text(
          'Movement & Engagement',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Stars move closer when you interact more, and drift outward when less active. Log interactions to strengthen connections!',
          textAlign: TextAlign.center,
          style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NudgeWordmarkGradient extends StatelessWidget {
  final ColorScheme scheme;
  const _NudgeWordmarkGradient({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          scheme.primary,
          scheme.primaryContainer,
          scheme.secondary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        'NUDGE',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -2.5,
        ),
      ),
    );
  }
}

class _ProgressVisual extends StatelessWidget {
  final ColorScheme scheme;
  final AnimationController pulseController;
  const _ProgressVisual({
    required this.scheme,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const fillRatio = 0.75;
                return Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Track
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                    // Fill
                    Positioned(
                      left: 0,
                      child: Container(
                        width: width * fillRatio,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [scheme.secondary, scheme.primary],
                          ),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                    // Origin dot
                    Positioned(
                      left: -6,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.surfaceContainerLowest,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                    // Star at fillRatio with pulsing ring
                    Positioned(
                      left: width * fillRatio - 30,
                      child: AnimatedBuilder(
                        animation: pulseController,
                        builder: (context, _) {
                          final t = pulseController.value;
                          final pulseOpacity = (1.0 - t).clamp(0.0, 1.0);
                          final pulseScale = 1.0 + t * 0.6;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: scheme.primary.withOpacity(
                                          0.45 * pulseOpacity),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.primaryContainer
                                        .withOpacity(0.25),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary.withOpacity(0.30),
                                      blurRadius: 28,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.stars_rounded,
                                  color: scheme.primary,
                                  size: 36,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BASELINE',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.outlineVariant,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                'PEAK ENGAGEMENT',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.secondary,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

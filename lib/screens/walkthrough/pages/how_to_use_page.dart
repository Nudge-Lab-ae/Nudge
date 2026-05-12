// lib/screens/walkthrough/pages/how_to_use_page.dart
// Page 5 — How to Use. Mirrors walkthrough_how_to_use_final.
// Final page: 3 instruction rows. Completion is via the round
// check button in the shared footer (no redundant in-page CTA).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/screens/walkthrough/walkthrough_screen.dart';

class HowToUsePage extends StatefulWidget {
  const HowToUsePage({super.key});

  @override
  State<HowToUsePage> createState() => _HowToUsePageState();
}

class _HowToUsePageState extends State<HowToUsePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WalkthroughBody(
      children: [
        const SizedBox(height: 12),
        Container(
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
                height: 160,
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withOpacity(0.05),
                        ),
                      ),
                      Icon(
                        Icons.star_rounded,
                        size: 110,
                        color: scheme.secondaryContainer,
                      ),
                      Positioned(
                        right: 18,
                        bottom: 14,
                        child: Transform.translate(
                          offset: Offset(0, -10 * _bounceController.value),
                          child: Icon(
                            Icons.touch_app_rounded,
                            size: 56,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How to Use',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              _InstructionRow(
                icon: Icons.ads_click_rounded,
                accent: scheme.primary,
                text: 'Tap any star to see contact details',
                scheme: scheme,
              ),
              const SizedBox(height: 12),
              _InstructionRow(
                icon: Icons.edit_note_rounded,
                accent: scheme.secondary,
                text: 'Log interactions from the contact panel',
                scheme: scheme,
              ),
              const SizedBox(height: 12),
              _InstructionRow(
                icon: Icons.sync_rounded,
                accent: scheme.tertiary,
                text: 'The system updates automatically',
                scheme: scheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String text;
  final ColorScheme scheme;
  const _InstructionRow({
    required this.icon,
    required this.accent,
    required this.text,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.beVietnamPro(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

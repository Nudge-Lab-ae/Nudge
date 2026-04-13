// lib/screens/welcome_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final size   = MediaQuery.of(context).size;

    // Colour tokens
    final bg      = isDark ? AppColors.darkBackground         : const Color(0xFFF5F2EE);
    final textP   = isDark ? AppColors.darkOnSurface          : AppColors.lightOnSurface;
    final textS   = isDark ? AppColors.darkOnSurfaceVariant   : AppColors.lightOnSurfaceVariant;
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [

          // ── Atmospheric blobs ──────────────────────────────────────────
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 380, height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.lightPrimary.withOpacity(isDark ? 0.22 : 0.12),
                  AppColors.lightPrimary.withOpacity(0),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 80, left: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.lightSecondary.withOpacity(isDark ? 0.18 : 0.10),
                  AppColors.lightSecondary.withOpacity(0),
                ]),
              ),
            ),
          ),

          // Subtle dot field
          Positioned.fill(
            child: CustomPaint(painter: _DotFieldPainter(isDark: isDark)),
          ),

          // ── Main content ───────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [

                // ── Logo hero (upper ~55 % of screen) ─────────────────
                Expanded(
                  flex: 55,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const Spacer(),

                        // Logo — no background, just the image with a glow
                        Center(
                          child: Container(
                            width: size.width * 0.62,
                            height: size.width * 0.62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.lightPrimary.withOpacity(
                                      isDark ? 0.28 : 0.16),
                                  blurRadius: 56,
                                  spreadRadius: 6,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(36),
                              child: Image.asset(
                                'assets/Nudge-logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // "NUDGE" wordmark — below the logo
                        Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? AppColors.primaryGradientDark
                                  : AppColors.primaryGradientLight,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text('NUDGE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 35, fontWeight: FontWeight.w900,
                                color: Colors.white,
                              )),
                          ),
                        ),

                        const Spacer(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Copy + CTA (lower ~45 %) ───────────────────────────
                Expanded(
                  flex: 45,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Headline
                        Text('Your relationships,',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34, fontWeight: FontWeight.w800,
                            color: textP, height: 1.1, letterSpacing: -0.5)),
                        // Second line with accent
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? AppColors.primaryGradientDark
                                : AppColors.primaryGradientLight,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(bounds),
                          child: Text('nourished.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 34, fontWeight: FontWeight.w800,
                              color: Colors.white, height: 1.1,
                              letterSpacing: -0.5)),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Stay meaningfully connected with the people who matter most.',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 15, fontWeight: FontWeight.w400,
                            color: textS, height: 1.6),
                        ),

                        const Spacer(),

                        // Get Started button
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: Container(
                            width: double.infinity, height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(9999),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.lightPrimary.withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Get Started',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16, fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sign in link
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/login'),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 14, color: textS),
                                children: [
                                  const TextSpan(text: 'Already have an account?  '),
                                  TextSpan(
                                    text: 'Sign in',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.lightPrimary,
                                    ).copyWith(inherit: false)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subtle dot field painter ───────────────────────────────────────────────
class _DotFieldPainter extends CustomPainter {
  final bool isDark;
  _DotFieldPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = Random(42);
    final paint = Paint()
      ..color = (isDark ? Colors.white : AppColors.lightPrimary)
          .withOpacity(isDark ? 0.05 : 0.04);
    for (int i = 0; i < 55; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.4 + 0.4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotFieldPainter old) => old.isDark != isDark;
}
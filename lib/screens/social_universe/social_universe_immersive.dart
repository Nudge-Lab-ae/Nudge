// lib/screens/social_universe/social_universe_immersive.dart
//
// Full immersive Social Universe view rebuilt from scratch to match
// the canonical Stitch mockup `social_universe_brighter_glow_2`:
//
//   • Dark starfield background (#1A1816) with subtle white dots
//   • Three concentric orbit rings (purple-tinted) at fixed sizes
//   • Central "YOU" avatar with primary→primary-container gradient ring
//   • Contacts plotted as stars on their `computedRing` at their
//     `angleDeg`, color-coded (primary / secondary / tertiary) and
//     pulse-animated. Names sit below each star.
//   • Top app bar: NUDGE wordmark (light gradient) + glowing info icon
//     that opens the walkthrough.
//   • FAB bottom-right with the N logo and a purple glow ring,
//     positioned per mockup. Tapping it dismisses the immersive view.
//
// Tapping a star surfaces the existing ContactDetailsModal so we don't
// lose any of the wired-up interaction logic. The widget used on the
// dashboard (lib/widgets/social_universe.dart) is intentionally left
// alone — this is a wholly new screen-level implementation.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/contact_detail_modal.dart';
import 'package:provider/provider.dart';

class SocialUniverseImmersiveScreen extends StatefulWidget {
  const SocialUniverseImmersiveScreen({super.key});

  @override
  State<SocialUniverseImmersiveScreen> createState() =>
      _SocialUniverseImmersiveScreenState();
}

class _SocialUniverseImmersiveScreenState
    extends State<SocialUniverseImmersiveScreen>
    with TickerProviderStateMixin {
  // Canonical palette + sizes pulled directly from the brighter-glow mockup.
  static const Color _spaceBackground = Color(0xFF1A1816);
  static const Color _ringColor = Color(0x1AA775FF); // rgba(167,117,255,0.10)
  static const Color _primary = Color(0xFF751FE7);
  static const Color _primaryContainer = Color(0xFFB58BFF);
  static const Color _secondary = Color(0xFF006288);
  static const Color _tertiary = Color(0xFF9E3654);
  static const Color _secondaryFixedDim = Color(0xFF78CDFF);
  static const Color _onPrimary = Color(0xFFF9EFFF);

  // Three functional orbit rings (mockup uses 280/480/680) where contacts
  // get plotted, plus two decorative outer rings that the user can reveal
  // by zooming out. The decorative rings give the universe a sense of
  // 'there's more out here' instead of cutting to dead black space at
  // the edge of the screen.
  static const double _innerRingDiameter = 280;
  static const double _middleRingDiameter = 480;
  static const double _outerRingDiameter = 680;
  static const double _decorativeRing1Diameter = 920;
  static const double _decorativeRing2Diameter = 1180;
  // Canvas is a square big enough to contain the outermost decorative
  // ring + room for the star labels (~80px on each side). No clipping.
  static const double _universeCanvasSize = _decorativeRing2Diameter + 220;

  // Pulse glow on stars + slow orbital rotation are driven by separate
  // controllers so their cadence is independent.
  late final AnimationController _pulseController;
  late final AnimationController _orbitController;

  // InteractiveViewer scale/pan state. Default = identity (1.0): the
  // universe fills the viewport and the outer ring spills past the
  // edges, dropping the user inside the experience. Pinching out
  // shrinks the canvas to reveal the decorative rings beyond.
  final TransformationController _viewport = TransformationController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90), // one full revolution / 1.5 min
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    _viewport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return Scaffold(
      backgroundColor: _spaceBackground,
      body: StreamProvider<List<Contact>>.value(
        value: apiService.getContactsStream(),
        initialData: const [],
        child: Consumer<List<Contact>>(
          builder: (context, contacts, _) {
            // Filter to contacts with valid ring placement so we don't
            // pile unplaced stars at the dead-centre point.
            final placedContacts = contacts
                .where((c) => c.computedRing.isNotEmpty)
                .toList(growable: false);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Pinch-zoomable universe — starfield, soft glow, rings,
                // stars, and YOU avatar are ALL inside the InteractiveViewer
                // so they scale together. The canvas is a fixed square
                // bigger than the outer ring so every ring renders as a
                // complete closed circle at every zoom level. Initial
                // transform (didChangeDependencies) fits the canvas to
                // the viewport so the outer ring is visible on first paint.
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _viewport,
                    // 0.3 lets the user zoom WAY out and see the full
                    // canvas — both decorative outer rings included.
                    // Default 1.0 is immersive: outer ring spills past
                    // the screen edges so the user feels inside the
                    // universe, not staring at a tiny island in a void.
                    minScale: 0.3,
                    maxScale: 3.0,
                    boundaryMargin: const EdgeInsets.all(600),
                    child: Center(
                      child: SizedBox(
                        width: _universeCanvasSize,
                        height: _universeCanvasSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Starfield — sized to the canvas so it scales
                            // with everything else during pinch-zoom.
                            const Positioned.fill(
                              child: CustomPaint(painter: _StarfieldPainter()),
                            ),
                            // Soft radial purple glow over the starfield.
                            const Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    radius: 0.7,
                                    colors: [
                                      Color(0x14751FE7), // 8% primary
                                      Color(0x00751FE7),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _orbitController,
                              builder: (context, child) {
                                final angle =
                                    _orbitController.value * 2 * math.pi;
                                return Transform.rotate(
                                  angle: angle,
                                  child: child,
                                );
                              },
                              child: _UniverseCanvas(
                                contacts: placedContacts,
                                pulseController: _pulseController,
                                orbitController: _orbitController,
                                innerDiameter: _innerRingDiameter,
                                middleDiameter: _middleRingDiameter,
                                outerDiameter: _outerRingDiameter,
                                decorativeRing1Diameter:
                                    _decorativeRing1Diameter,
                                decorativeRing2Diameter:
                                    _decorativeRing2Diameter,
                                ringColor: _ringColor,
                                primary: _primary,
                                primaryContainer: _primaryContainer,
                                secondary: _secondary,
                                tertiary: _tertiary,
                                secondaryFixedDim: _secondaryFixedDim,
                                onPrimary: _onPrimary,
                                onStarTap: (contact, ring) => _openContact(
                                    context, apiService, contact, ring),
                              ),
                            ),

                            // Tappable YOU avatar — opens settings so the
                            // user can change their profile photo via the
                            // existing profile-picture flow there. We don't
                            // build a new uploader; we route to the one
                            // that's already wired.
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.pushNamed(
                                  context, '/settings'),
                              child: _CentralYou(
                                primary: _primary,
                                primaryContainer: _primaryContainer,
                                spaceBackground: _spaceBackground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top app bar overlay (NUDGE wordmark + info button).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _UniverseTopBar(
                      onInfoTap: () =>
                          Navigator.pushNamed(context, '/walkthrough'),
                    ),
                  ),
                ),

                // Note: bottom nav and floating action button are both
                // provided by the dashboard wrapper. The dashboard's nav
                // detects the Universe tab and switches to its dark
                // variant; the FAB does the same. Universe no longer
                // renders its own — it created a duplicate "n" button and
                // a duplicate nav stacked on top of the dashboard's.
              ],
            );
          },
        ),
      ),
    );
  }

  void _openContact(
    BuildContext context,
    ApiService apiService,
    Contact contact,
    String ring,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ContactDetailsModal(
        contact: contact,
        apiService: apiService,
        displayRing: ring,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Starfield background
// ─────────────────────────────────────────────────────────────────────────────

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  // Pre-seeded star positions for stable, non-jittery rendering.
  // Density and sizes mirror the mockup's tiled radial-gradient.
  static const int _seed = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final rng = math.Random(_seed);
    final count = (size.width * size.height / 8000).round().clamp(40, 240);
    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() < 0.18 ? 1.6 : 0.8;
      final opacity = rng.nextDouble() * 0.55 + 0.15;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Universe canvas — rings + avatar + plotted contacts
// ─────────────────────────────────────────────────────────────────────────────

class _UniverseCanvas extends StatelessWidget {
  final List<Contact> contacts;
  final AnimationController pulseController;
  final AnimationController orbitController;
  final double innerDiameter;
  final double middleDiameter;
  final double outerDiameter;
  // Decorative outer rings (no contacts plotted) — give the universe a
  // 'there's more out here' feel when the user zooms out.
  final double decorativeRing1Diameter;
  final double decorativeRing2Diameter;
  final Color ringColor;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color tertiary;
  final Color secondaryFixedDim;
  final Color onPrimary;
  final void Function(Contact contact, String ring) onStarTap;

  const _UniverseCanvas({
    required this.contacts,
    required this.pulseController,
    required this.orbitController,
    required this.innerDiameter,
    required this.middleDiameter,
    required this.outerDiameter,
    required this.decorativeRing1Diameter,
    required this.decorativeRing2Diameter,
    required this.ringColor,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.tertiary,
    required this.secondaryFixedDim,
    required this.onPrimary,
    required this.onStarTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final cy = h / 2;

        // Bucket contacts by computedRing so we can paint each ring's
        // stars in their own loop with the right color.
        final innerStars =
            contacts.where((c) => c.computedRing == 'inner').toList();
        final middleStars =
            contacts.where((c) => c.computedRing == 'middle').toList();
        final outerStars =
            contacts.where((c) => c.computedRing == 'outer').toList();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // Decorative outer rings — drawn fainter, no contacts. Reveal
            // when the user zooms out (minScale 0.3).
            _ring(cx, cy, decorativeRing2Diameter, opacity: 0.55),
            _ring(cx, cy, decorativeRing1Diameter, opacity: 0.75),
            // Functional orbit rings (outer, middle, inner).
            _ring(cx, cy, outerDiameter),
            _ring(cx, cy, middleDiameter),
            _ring(cx, cy, innerDiameter),

            // Plot stars on each ring. Stars must counter-rotate so the
            // labels stay upright while the orbit layer rotates.
            for (final star in _plotStars(
              innerStars,
              cx,
              cy,
              innerDiameter / 2,
              primary,
              ring: 'inner',
            ))
              star,
            for (final star in _plotStars(
              middleStars,
              cx,
              cy,
              middleDiameter / 2,
              secondaryFixedDim,
              ring: 'middle',
            ))
              star,
            for (final star in _plotStars(
              outerStars,
              cx,
              cy,
              outerDiameter / 2,
              tertiary,
              ring: 'outer',
            ))
              star,
          ],
        );
      },
    );
  }

  // opacity is a *multiplier* on the existing ringColor alpha, so the
  // default (1.0) preserves the canonical translucent ring color and
  // values <1.0 fade the decorative outer rings further.
  Widget _ring(double cx, double cy, double diameter, {double opacity = 1.0}) {
    final fadedAlpha = (ringColor.alpha * opacity).round().clamp(0, 255);
    return Positioned(
      left: cx - diameter / 2,
      top: cy - diameter / 2,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor.withAlpha(fadedAlpha),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _plotStars(
    List<Contact> stars,
    double cx,
    double cy,
    double radius,
    Color color, {
    required String ring,
  }) sync* {
    if (stars.isEmpty) return;

    for (int i = 0; i < stars.length; i++) {
      final c = stars[i];
      // Honour the contact's saved angleDeg when set; otherwise distribute
      // evenly so first-time users still see something coherent.
      final angleDeg =
          c.angleDeg != 0 ? c.angleDeg : (i * 360.0 / stars.length);
      final angleRad = angleDeg * math.pi / 180.0;

      final dotX = cx + radius * math.cos(angleRad);
      final dotY = cy + radius * math.sin(angleRad);

      // Size matters per Stitch "Star Sizes" walkthrough.
      // Priority is the dominant signal (1 = largest, 5 = smallest);
      // VIPs get a +2 boost; CDI modulates ±2 within the priority tier.
      final size = _starSizeFor(c);

      yield Positioned(
        left: dotX - 56, // 112px label slot centered on the dot
        top: dotY - size / 2,
        child: SizedBox(
          width: 112,
          child: _StarMarker(
            contact: c,
            ring: ring,
            color: color,
            size: size,
            pulseController: pulseController,
            orbitController: orbitController,
            phaseSeed: i,
            onTap: () => onStarTap(c, ring),
          ),
        ),
      );
    }
  }

  /// Priority-driven base size with VIP boost and CDI modulation.
  /// Mirrors the "Large / Medium / Small" walkthrough copy:
  ///   priority 1 -> ~24px, 2 -> 20, 3 -> 16, 4 -> 12, 5 -> 8.
  static double _starSizeFor(Contact c) {
    final priority = c.priority.clamp(1, 5);
    final base = 24.0 - (priority - 1) * 4.0;
    final vipBoost = c.isVIP ? 2.0 : 0.0;
    final cdiBoost =
        (((c.cdi - 50.0) / 50.0).clamp(-1.0, 1.0)) * 2.0;
    return (base + vipBoost + cdiBoost).clamp(6.0, 28.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Central avatar
// ─────────────────────────────────────────────────────────────────────────────

class _CentralYou extends StatelessWidget {
  final Color primary;
  final Color primaryContainer;
  final Color spaceBackground;
  const _CentralYou({
    required this.primary,
    required this.primaryContainer,
    required this.spaceBackground,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primary, primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.4),
                blurRadius: 50,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: spaceBackground, width: 4),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'YOU',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
            color: primaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF2C2927),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: Colors.white.withOpacity(0.7),
        size: 40,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual star marker (dot + pulse glow + name label)
// ─────────────────────────────────────────────────────────────────────────────

class _StarMarker extends StatelessWidget {
  final Contact contact;
  final String ring;
  final Color color;
  final double size;
  final AnimationController pulseController;
  final AnimationController orbitController;
  final int phaseSeed;
  final VoidCallback onTap;

  const _StarMarker({
    required this.contact,
    required this.ring,
    required this.color,
    required this.size,
    required this.pulseController,
    required this.orbitController,
    required this.phaseSeed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final phase = (phaseSeed * 0.137) % 1.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // Counter-rotate the whole marker by the inverse of the orbit
      // angle so the dot and name label stay visually upright while the
      // parent canvas rotates. Position still moves along the orbit
      // (the rotation is applied at the parent's centre of rotation,
      // which translates this widget's origin around the canvas).
      child: AnimatedBuilder(
        animation: orbitController,
        builder: (context, child) {
          final orbitAngle = orbitController.value * 2 * math.pi;
          return Transform.rotate(
            angle: -orbitAngle,
            child: child,
          );
        },
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, _) {
              final t = (pulseController.value + phase) % 1.0;
              final pulseScale = 1.0 + 0.6 * math.sin(t * 2 * math.pi).abs();
              final glowOpacity =
                  (0.65 - 0.35 * math.sin(t * 2 * math.pi).abs())
                      .clamp(0.25, 0.9);
              return SizedBox(
                width: size + 18,
                height: size + 18,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse halo.
                    Transform.scale(
                      scale: pulseScale,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(glowOpacity * 0.25),
                        ),
                      ),
                    ),
                    // Solid star dot with bloom shadow.
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(glowOpacity),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    if (contact.isVIP)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFB300),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            _firstName(contact.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.75),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top app bar
// ─────────────────────────────────────────────────────────────────────────────

class _UniverseTopBar extends StatelessWidget {
  final VoidCallback onInfoTap;
  const _UniverseTopBar({required this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1816), Color(0x001A1816)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // NUDGE wordmark — light gradient against the dark canvas.
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE7E1DE), Color(0xFF968DA1)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(bounds),
            child: Text(
              'NUDGE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const Spacer(),
          _InfoButton(onTap: onInfoTap),
        ],
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InfoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: 'How to read your Social Universe',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFA775FF).withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF751FE7).withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD4BBFF),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating action button (bottom-right per mockup)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar (dark mode per Stitch sample)
// ─────────────────────────────────────────────────────────────────────────────

// _UniverseBottomNav and _UniverseFab removed — the dashboard wrapper
// renders both, and switches to dark variants automatically when the
// Universe tab is active.

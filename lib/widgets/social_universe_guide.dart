// lib/widgets/social_universe_guide.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/main.dart';
import 'package:nudge/theme/app_theme.dart';

class SocialUniverseGuide extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDarkMode;

  const SocialUniverseGuide({
    Key? key,
    required this.onClose,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<SocialUniverseGuide> createState() => _SocialUniverseGuideState();
}

class _SocialUniverseGuideState extends State<SocialUniverseGuide>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  late AnimationController _sliderAnimCtrl;
  late Animation<double> _sliderAnim;

  static const int _totalPages = 5;

  // ── Colour helpers ──────────────────────────────────────────────────────
  Color get _bg =>
      widget.isDarkMode ? AppColors.darkBackground : const Color(0xFFF2EEE8);
  Color get _textP =>
      widget.isDarkMode ? AppColors.darkOnSurface : AppColors.lightOnSurface;
  Color get _textS => widget.isDarkMode
      ? AppColors.darkOnSurfaceVariant
      : AppColors.lightOnSurfaceVariant;
  Color get _cardBg =>
      widget.isDarkMode ? AppColors.darkSurfaceContainerHigh : Colors.white;

  @override
  void initState() {
    super.initState();
    _sliderAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sliderAnim = CurvedAnimation(
      parent: _sliderAnimCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _sliderAnimCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onClose();
    }
  }

  void _goPrev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onClose();
        return false;
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(children: [
                // Close button
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(Icons.close_rounded,
                      color: _textS, size: 22),
                ),
                const Spacer(),
                // "Social Universe" title
                Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary,
                      shape: BoxShape.circle),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text('Social Universe',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.lightPrimary)),
                ]),
                const Spacer(),
                const SizedBox(width: 34), // balance
              ]),
            ),

            // ── Pages ────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  if (i == 3) {
                    _sliderAnimCtrl.forward(from: 0);
                  }
                },
                children: [
                  _buildWelcomePage(),
                  _buildThreeCirclesPage(),
                  _buildStarSizesPage(),
                  _buildMovementPage(),
                  _buildHowToUsePage(),
                ],
              ),
            ),

            // ── Bottom nav ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back arrow
                  GestureDetector(
                    onTap: _goPrev,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: _currentPage > 0 ? _textS : _textS.withOpacity(0.3),
                      size: 22,
                    ),
                  ),

                  // Page dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_totalPages, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: active ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.lightPrimary
                              : (widget.isDarkMode
                                  ? AppColors.darkSurfaceContainerHighest
                                  : const Color(0xFFD8D4CD)),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      );
                    }),
                  ),

                  // Forward arrow in circle
                  GestureDetector(
                    onTap: _goNext,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lightPrimary.withOpacity(0.35),
                            blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(
                        _currentPage < _totalPages - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded,
                        color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 0 — Welcome to Your Social Universe
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(children: [
        // Illustration card
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(
                    widget.isDarkMode ? 0.25 : 0.07),
                blurRadius: 24, offset: const Offset(0, 6))],
            ),
            child: Stack(children: [
              // Purple gradient squircle with rocket
              Center(
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9C6FE4), Color(0xFF5B9BD5)],
                    ),
                    borderRadius: BorderRadius.circular(38),
                    boxShadow: [BoxShadow(
                      color: AppColors.lightPrimary.withOpacity(0.3),
                      blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.rocket_launch_rounded,
                      color: Colors.white, size: 72),
                ),
              ),
              // Pink star badge (top-right)
              Positioned(
                top: 52, right: 44,
                child: Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4848C),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: Color(0x33F4848C), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
              // Teal people badge (bottom-left)
              Positioned(
                bottom: 52, left: 44,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A7FA0),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: Color(0x331A7FA0), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.people_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 28),

        // Title
        Text('Welcome to Your\nSocial Universe',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26, fontWeight: FontWeight.w800,
            color: _textP, height: 1.2)),
        const SizedBox(height: 10),
        Text(
          'Visualize all your relationships at a glance.\nEach star represents a person in your life.',
          textAlign: TextAlign.center,
          style: GoogleFonts.beVietnamPro(
            fontSize: 14, color: _textS, height: 1.6)),
        const SizedBox(height: 20),

        // Next button
        _ctaButton('Next', _goNext),
        const SizedBox(height: 4),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 1 — The Three Circles
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildThreeCirclesPage() {
    // Social Universe canonical ring colours
    const goldColor   = AppColors.vipGold;           // inner  #FFB300
    const blueColor   = Color(0xFF1A80C4);            // middle vivid blue
    const purpleColor = AppColors.lightPrimary;       // outer  #751FE7

    // Diagram dimensions (fits inside AspectRatio(1))
    const double outerD  = 252;
    const double middleD = 172;
    const double innerD  = 92;  // ring border circle
    const double centerD = 58;  // filled user circle (slightly smaller)

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(children: [
        // Illustration
        Expanded(
          flex: 5,
          child: Center(
            child: SizedBox(
              width: outerD, height: outerD,
              child: Stack(alignment: Alignment.center, children: [

                // ── Outer ring — deep purple ──────────────────────────────
                Container(
                  width: outerD, height: outerD,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: purpleColor.withOpacity(
                          widget.isDarkMode ? 0.55 : 0.45),
                      width: 2.0)),
                ),

                // ── Middle ring — vivid blue ──────────────────────────────
                Container(
                  width: middleD, height: middleD,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: blueColor.withOpacity(
                          widget.isDarkMode ? 0.55 : 0.45),
                      width: 2.0)),
                ),

                // ── Inner ring — gold ────────────────────────────────────
                Container(
                  width: innerD, height: innerD,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: goldColor.withOpacity(
                          widget.isDarkMode ? 0.70 : 0.60),
                      width: 2.0)),
                ),

                // ── Central user — purple filled circle with star ─────────
                Container(
                  width: centerD, height: centerD,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF9C6FE4), Color(0xFF5B21B6)]),
                    boxShadow: [BoxShadow(
                      color: purpleColor.withOpacity(0.45),
                      blurRadius: 16, spreadRadius: 1)],
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 26),
                ),

                // ── Small badge between inner and middle rings ────────────
                // Top-right: person icon (gold tint — near inner ring)
                Positioned(
                  top: outerD / 2 - middleD / 2 + 14,
                  right: outerD / 2 - middleD / 2 - 2,
                  child: _smallBadge(Icons.person_rounded, goldColor),
                ),

                // Bottom-left: people icon (gold tint — near inner ring)
                Positioned(
                  bottom: outerD / 2 - middleD / 2 + 14,
                  left: outerD / 2 - middleD / 2 - 2,
                  child: _smallBadge(Icons.favorite_rounded, goldColor),
                ),

                // ── Small badge between middle and outer rings ────────────
                // Top-left: person-add (blue tint)
                Positioned(
                  top: outerD / 2 - outerD / 2 + 22,
                  left: outerD / 2 - middleD / 2 - 8,
                  child: _smallBadge(Icons.people_rounded, blueColor),
                ),

                // Bottom-right: star outline (purple tint — near outer ring)
                Positioned(
                  bottom: outerD / 2 - outerD / 2 + 22,
                  right: outerD / 2 - middleD / 2 - 8,
                  child: _smallBadge(Icons.person_add_rounded, purpleColor),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text('The Three Circles',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26, fontWeight: FontWeight.w800, color: _textP)),
        const SizedBox(height: 8),
        // Description with coloured ring names
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: _textS, height: 1.6),
            children: const [
              TextSpan(
                text: 'Your connections are organized into three rings based on how active your relationship is: '),
              TextSpan(text: 'Inner',
                style: TextStyle(color: goldColor, fontWeight: FontWeight.w700)),
              TextSpan(text: ', '),
              TextSpan(text: 'Middle',
                style: TextStyle(color: blueColor, fontWeight: FontWeight.w700)),
              TextSpan(text: ', and '),
              TextSpan(text: 'Outer',
                style: TextStyle(color: purpleColor, fontWeight: FontWeight.w700)),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Ring label chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ringChip('INNER', 'Closest Contacts', goldColor),
            _ringChip('MIDDLE', 'Average Contacts', blueColor),
            _ringChip('OUTER', 'Casual Contacts', purpleColor),
          ],
        ),
        const SizedBox(height: 14),

        _ctaButton('Next Step', _goNext),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _floatingBadge(IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
          color: iconColor.withOpacity(0.18), blurRadius: 8)],
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  // Smaller badge used between rings
  Widget _smallBadge(IconData icon, Color accentColor) {
    final bg = widget.isDarkMode
        ? accentColor.withOpacity(0.20)
        : accentColor.withOpacity(0.12);
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withOpacity(0.35), width: 1),
        boxShadow: [BoxShadow(
          color: accentColor.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Icon(icon, color: accentColor, size: 15),
    );
  }

  Widget _ringChip(String label, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(widget.isDarkMode ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: color, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(sub,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, color: _textS)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 2 — Star Sizes Matter
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStarSizesPage() {
    const starColor = AppColors.lightPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(children: [
        // Illustration — three floating cards
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.isDarkMode
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEDE9FE), Color(0xFFF0F4FF)]),
              color: widget.isDarkMode
                  ? AppColors.darkSurfaceContainerHigh
                  : null,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // LARGE
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(clipBehavior: Clip.none, children: [
                        _starCard(88, starColor),
                        // PRIORITY 1 badge
                        Positioned(
                          top: -10, left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B2252),
                              borderRadius: BorderRadius.circular(9999)),
                            child: Text('PRIORITY 1',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 0.5)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text('LARGE',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _textS, letterSpacing: 0.6)),
                    ],
                  ),
                  // MEDIUM
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _starCard(62, starColor),
                      const SizedBox(height: 10),
                      Text('MEDIUM',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _textS, letterSpacing: 0.6)),
                    ],
                  ),
                  // SMALL
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _starCard(44, starColor, circle: true),
                      const SizedBox(height: 10),
                      Text('SMALL',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _textS, letterSpacing: 0.6)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text('Star Sizes Matter',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26, fontWeight: FontWeight.w800, color: _textP)),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: _textS, height: 1.6),
            children: [
              const TextSpan(
                text: 'Larger stars are more important to you (based on your categories). Reorder categories in '),
              const TextSpan(
                text: 'Settings',
                style: TextStyle(
                  color: AppColors.lightPrimary,
                  fontWeight: FontWeight.w700)),
              const TextSpan(text: ' to adjust sizes.'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _ctaButton('Next', _goNext),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _starCard(double size, Color color, {bool circle = false}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: circle
            ? BorderRadius.circular(9999)
            : BorderRadius.circular(size * 0.22),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(widget.isDarkMode ? 0.2 : 0.08),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.55,
          height: size * 0.55,
          child: CustomPaint(
            painter: _StarPainter(
              size: size * 0.27,
              color: color,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 3 — Movement & Engagement
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMovementPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(children: [
        // NUDGE gradient wordmark
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF9C6FE4), Color(0xFF5B9BD5)],
          ).createShader(bounds),
          child: Text('NUDGE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 48, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 2)),
        ),
        const SizedBox(height: 12),

        // Slider illustration card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(
                  widget.isDarkMode ? 0.2 : 0.07),
              blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            // Track + thumb
            AnimatedBuilder(
              animation: _sliderAnim,
              builder: (context, _) {
                final t = _currentPage == 3 ? _sliderAnim.value : 1.0;
                return Column(children: [
                  // Background glow
                  Container(
                    height: 80,
                    child: Stack(alignment: Alignment.center, children: [
                      // Diffuse purple glow (right side)
                      Positioned(
                        right: 0,
                        child: Container(
                          width: 120, height: 80,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.lightPrimary.withOpacity(0.15),
                                Colors.transparent],
                              radius: 1.0,
                            ),
                          ),
                        ),
                      ),
                      // Track
                      Positioned(
                        left: 0, right: 0,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            color: widget.isDarkMode
                                ? AppColors.darkSurfaceContainerHighest
                                : const Color(0xFFE8E4DF),
                          ),
                        ),
                      ),
                      // Active track (left → thumb)
                      Positioned(
                        left: 18,
                        right: 44 + (1 - t) * 100,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A80C4), Color(0xFF751FE7)]),
                          ),
                        ),
                      ),
                      // Left dot (baseline)
                      Positioned(
                        left: 8,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isDarkMode
                                ? AppColors.darkSurfaceContainerHighest
                                : const Color(0xFFD8D4CD)),
                        ),
                      ),
                      // Star thumb
                      Positioned(
                        right: 32 + (1 - t) * 100,
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _cardBg,
                            boxShadow: [BoxShadow(
                              color: AppColors.lightPrimary.withOpacity(0.3),
                              blurRadius: 12, spreadRadius: 2)],
                          ),
                          child: Center(
                            child: Container(
                              width: 36, height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.lightPrimary),
                              child: const Icon(Icons.star_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BASELINE',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _textS, letterSpacing: 0.8)),
                      Text('PEAK ENGAGEMENT',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A80C4),
                          letterSpacing: 0.8)),
                    ],
                  ),
                ]);
              },
            ),
          ]),
        ),
        const SizedBox(height: 24),

        Text('Movement &\nEngagement',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26, fontWeight: FontWeight.w800,
            color: _textP, height: 1.2)),
        const SizedBox(height: 8),
        Text(
          'Stars move closer when you interact more, and drift outward when less active. '
          'Log interactions to strengthen connections!',
          textAlign: TextAlign.center,
          style: GoogleFonts.beVietnamPro(
            fontSize: 14, color: _textS, height: 1.6)),
        const SizedBox(height: 20),

        _ctaButton('Next', _goNext),
        const SizedBox(height: 4),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 4 — How to Use
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHowToUsePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(children: [
        // Big lavender circle illustration
        Expanded(
          flex: 4,
          child: Center(
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDarkMode
                    ? AppColors.darkSurfaceContainerHigh
                    : const Color(0xFFE8E4FC),
              ),
              child: Stack(alignment: Alignment.center, children: [
                // Star (behind)
                Icon(Icons.star_rounded,
                  size: 90,
                  color: widget.isDarkMode
                      ? const Color(0xFF89CFFA)
                      : const Color(0xFF89CFFA)),
                // Tap hand (in front, slightly offset)
                Positioned(
                  right: 44, bottom: 44,
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: AppColors.lightPrimary.withOpacity(0.4),
                        blurRadius: 12)],
                    ),
                    child: const Icon(Icons.touch_app_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('How to Use',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26, fontWeight: FontWeight.w800, color: _textP)),
        const SizedBox(height: 16),

        // Instruction rows
        _instructionRow(
          Icons.touch_app_rounded,
          const Color(0xFFEDE9FE),
          AppColors.lightPrimary,
          'Tap any star to see contact details',
        ),
        const SizedBox(height: 10),
        _instructionRow(
          Icons.edit_note_rounded,
          widget.isDarkMode
              ? AppColors.darkSurfaceContainerHighest
              : const Color(0xFFE8F4F8),
          const Color(0xFF1A80C4),
          'Log interactions from the contact panel',
        ),
        const SizedBox(height: 10),
        _instructionRow(
          Icons.autorenew_rounded,
          widget.isDarkMode
              ? AppColors.darkSurfaceContainerHighest
              : const Color(0xFFFDE8E8),
          const Color(0xFFD05A5A),
          'The system updates automatically',
        ),
        const SizedBox(height: 20),

        _ctaButton('Got It!', widget.onClose),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _instructionRow(
      IconData icon, Color bgColor, Color iconColor, String text) {
    // Outer row pill (warm tinted background)
    final outerBg = widget.isDarkMode
        ? AppColors.darkSurfaceContainerHigh
        : const Color(0xFFF0EDE9);
    // White enclosure wrapping the text
    final innerBg = widget.isDarkMode
        ? AppColors.darkSurfaceContainerHighest
        : Colors.white;

    return Padding(
      padding: EdgeInsets.only(left: 30, right: 30, top: 10, bottom: 10),
      child: Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(
                    widget.isDarkMode ? 0.12 : 0.05),
                blurRadius: 6, offset: const Offset(0, 2))],
            ),
      child: Row(children: [
        // Icon circle
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        // White enclosure around the text
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(text,
              style: GoogleFonts.beVietnamPro(
                fontSize: 16, color: _textP, height: 1.4)),
          ),
        ),
      ]),
    ));
  }

  // ── Shared CTA button ───────────────────────────────────────────────────
  Widget _ctaButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [BoxShadow(
            color: AppColors.lightPrimary.withOpacity(0.35),
            blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Support classes (unchanged API) ──────────────────────────────────────────
class GuidePage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color lightModeColor;

  GuidePage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.lightModeColor,
  });
}

class GuideTheme {
  final Color backgroundColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconColor;
  final List<Color> buttonGradient;
  final Color buttonText;
  final Color cardBackground;
  final Color borderColor;

  GuideTheme({
    required this.backgroundColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconColor,
    required this.buttonGradient,
    required this.buttonText,
    required this.cardBackground,
    required this.borderColor,
  });
}

class _StarPainter extends CustomPainter {
  final double size;
  final Color color;
  final bool isDarkMode;

  _StarPainter({
    required this.size,
    required this.color,
    this.isDarkMode = false,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    const numberOfPoints = 5;
    final halfPi = pi / numberOfPoints;
    final points = <Offset>[];

    for (var i = 0; i < numberOfPoints * 2; i++) {
      final pointRadius = i.isEven ? size : size * 0.42;
      final pointAngle = halfPi * i - pi / 2;
      points.add(Offset(
        center.dx + pointRadius * cos(pointAngle),
        center.dy + pointRadius * sin(pointAngle),
      ));
    }

    final path = Path()..addPolygon(points, true);

    final paint = Paint()
      ..color = isDarkMode ? color.withOpacity(0.9) : color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.size != size || old.color != color;
}
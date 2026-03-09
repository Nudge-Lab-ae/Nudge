// scrollable_roadmap.dart - Enhanced with Social Universe Preview
import 'package:flutter/material.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// Add this new widget for the scrollable roadmap with thinner rocket
class ScrollableRoadmapWidget extends StatefulWidget {
  const ScrollableRoadmapWidget({super.key});

  @override
  State<ScrollableRoadmapWidget> createState() => _ScrollableRoadmapWidgetState();
}

class _ScrollableRoadmapWidgetState extends State<ScrollableRoadmapWidget> {
  final ScrollController _scrollController = ScrollController();
  double _scrollRatio = 0.0;
  String? _expandedFeature;
  
  // Roadmap phases data (ordered from top to bottom: Horizon, Soon, Now)
  final List<Map<String, dynamic>> _phases = [
    {
      'id': 'horizon',
      'label': 'ON THE HORIZON',
      'title': 'Big Things Ahead',
      'color': const Color(0xFF7C3AED),
      'features': [
        {
          'name': 'Calendar Mapping',
          'desc': 'Stop waiting \'til you\'re 80 to meet up — let us find the perfect time in everyone\'s schedule',
        },
        {
          'name': 'AI Relationship Assistant',
          'desc': 'Context-aware conversation starters, hyper-personalised insights, and proactive suggestions to deepen every connection',
        },
        {
          'name': 'Milestones & Greeting Cards',
          'desc': 'Auto-generated celebrations for anniversaries and personalised cards for any occasion — powered by what you know about the people in your life',
        },
        {
          'name': 'Journal & Voice Notes',
          'desc': 'Reflect on your relationships through guided journaling or capture thoughts hands-free with voice notes',
        },
      ],
    },
    {
      'id': 'soon',
      'label': 'NEXT UP',
      'title': 'More Ways to Connect',
      'color': const Color(0xFF2563EB),
      'features': [
        {
          'name': 'Gamification & Streaks',
          'desc': 'Earn points, keep streaks alive, tackle challenges and complete quests — staying connected has never been this fun',
        },
        {
          'name': 'Shareable Awards & Badges',
          'desc': 'Unlock badges at every milestone and share awards that celebrate your strongest connections',
        },
        {
          'name': 'Smarter Insights',
          'desc': 'Deeper patterns, better nudges — your relationship intelligence gets a serious upgrade',
        },
        {
          'name': 'Digest & Widgets',
          'desc': 'Weekly summaries and home screen widgets so your connections are always top of mind',
        },
        {
          'name': 'Mood Reflections',
          'desc': 'Log how interactions make you feel — and unlock richer, more personal insights over time',
        },
      ],
    },
    {
      'id': 'launch',
      'label': 'NOW',
      'title': 'Ready for You',
      'color': const Color(0xFF059669),
      'features': [
        {
          'name': 'Social Universe',
          'desc': 'See your connections come to life — visualize and explore your circles like never before',
        },
        {
          'name': 'Smart Reminders',
          'desc': 'Never miss a birthday, milestone, or the perfect moment to check in on someone you care about',
        },
        {
          'name': 'Connection Profiles',
          'desc': 'Keep track of what matters — preferences, memories, and notes for every relationship',
        },
        {
          'name': 'Social Groups',
          'desc': 'Organize and manage your circles — keep your crew, your colleagues, and your closest connections all in one place',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    // Start scrolled to the bottom (NOW section)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
    _scrollController.addListener(_updateScrollRatio);
  }

  void _updateScrollRatio() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final ratio = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
      setState(() {
        _scrollRatio = ratio;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollRatio);
    _scrollController.dispose();
    super.dispose();
  }

  // Custom thinner rocket painter
  Widget _buildRocket(ThemeProvider themeProvider, double scrollRatio) {
    // Calculate rocket position - starts just above the What's Coming section and moves up as user scrolls
    // When scrollRatio = 0 (at bottom - just before What's Coming), rocket is at starting position
    // When scrollRatio = 1 (at top/HORIZON), rocket is at ending position
    final rocketStartPosition = 30.0; // Starting position - just above What's Coming section
    final rocketEndPosition = 1030.0;     // Ending position at top of phases
    final rocketPosition = rocketStartPosition - (scrollRatio * (rocketStartPosition - rocketEndPosition));
    
    return Container(
      width: 30, // Thinner rocket
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rocket body
          Positioned(
            top: rocketPosition,
            child: CustomPaint(
              size: const Size(14, 80), // Thinner dimensions
              painter: ThinnerRocketPainter(
                scrollRatio: scrollRatio,
              ),
            ),
          ),
          
          // Flame (appears when scrolling up)
          if (scrollRatio >=0)
            Positioned(
              top: rocketPosition + 58,
              left: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 8,
                height: 8 + (16 * (1-scrollRatio)), // Flame grows as you scroll up
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF97316).withOpacity(0.9),
                      const Color(0xFFFB923C).withOpacity(0.6),
                      const Color(0xFFFED7AA).withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Fix: Wrap the entire widget in a Column instead of using Expanded directly
    return Container(
      color: themeProvider.getBackgroundColor(context),
      child: Column(
        children: [
          // Living roadmap text at the very top
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '✨ This is a living roadmap — it evolves as we grow with you ✨',
              style: TextStyle(
                fontSize: 11,
                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Top fade (minimal)
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  themeProvider.getBackgroundColor(context),
                  themeProvider.getBackgroundColor(context).withOpacity(0),
                ],
              ),
            ),
          ),
          
          // Scrollable content - Expanded now properly used inside Column
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content with rocket timeline (only for the three phases)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side with thinner rocket and timeline (only for phases)
                      SizedBox(
                        width: 40, // Reduced width for thinner rocket
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: _buildRocket(themeProvider, _scrollRatio),
                        ),
                      ),
                      
                      // Right side content with phases
                      Expanded(
                        child: Column(
                          children: [
                            // ON THE HORIZON section (top)
                            _buildPhaseSection(_phases[0], themeProvider),
                            
                            // Separator
                            _buildPhaseSeparator(themeProvider),
                            
                            // NEXT UP section (middle)
                            _buildPhaseSection(_phases[1], themeProvider),
                            
                            // Separator
                            _buildPhaseSeparator(themeProvider),
                            
                            // NOW section (bottom)
                            _buildPhaseSection(_phases[2], themeProvider),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Bottom intro section - FULL WIDTH (outside the Row with rocket)
                  Container(
                    width: double.infinity, // Full width
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        // Small up arrow
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, -4 * value),
                              child: Icon(
                                Icons.keyboard_arrow_up,
                                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                                size: 24,
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Live roadmap pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF059669).withOpacity(0.2),
                            ),
                          ),
                          child: const Text(
                            'LIVE ROADMAP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Title
                        const Text(
                          "What's Coming\nto NUDGE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Your relationships are about to get a whole lot stronger. Scroll up to explore what\'s ahead and tell us what you\'d like to add to the list in the feedback forum at any time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseSeparator(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseSection(Map<String, dynamic> phase, ThemeProvider themeProvider) {
    final phaseColor = phase['color'] as Color;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Phase pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: phaseColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: phaseColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: phaseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  phase['label'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: phaseColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Phase title
          Text(
            phase['title'],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Features
          ...List.generate((phase['features'] as List).length, (index) {
            final feature = (phase['features'] as List)[index];
            final featureKey = '${phase['id']}-$index';
            final isExpanded = _expandedFeature == featureKey;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _expandedFeature = isExpanded ? null : featureKey;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? phaseColor.withOpacity(0.05)
                      : (themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isExpanded
                        ? phaseColor.withOpacity(0.3)
                        : (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isExpanded?phaseColor.withOpacity(0.75): phaseColor.withOpacity(0.13),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            feature['name'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isExpanded ? FontWeight.w600 : FontWeight.w500,
                              color: isExpanded
                                  ? (themeProvider.isDarkMode ? Colors.white : Colors.black)
                                  : (themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                          size: 18,
                        ),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 10),
                      Text(
                        feature['desc'],
                        style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Custom painter for short, wide rocket with smooth concave bottom + protruding wings
class ThinnerRocketPainter extends CustomPainter {
  final double scrollRatio;

  ThinnerRocketPainter({required this.scrollRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF818CF8),
          Color.fromARGB(255, 105, 101, 192),
          Color.fromARGB(255, 115, 110, 197),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      // Nose cone (sharp point)
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width * 0.9, size.height * 0.20) // right taper
      ..lineTo(size.width * 0.9, size.height * 0.45) // right body
      // Right wing protruding outward
      ..lineTo(size.width, size.height * 0.65)
      // Smooth concave bottom curve inward
      ..quadraticBezierTo(
        size.width / 2, size.height * 0.55,
        0, size.height * 0.65,
      )
      // Left wing protruding outward
      ..lineTo(size.width * 0.1, size.height * 0.45)
      ..lineTo(size.width * 0.12, size.height * 0.20) // left body
      ..close();

    canvas.drawPath(path, paint);

    // Circular window near the top
    final windowPaint = Paint()
      ..color = const Color.fromARGB(255, 72, 67, 140)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.22),
      size.width * 0.18,
      windowPaint,
    );

    // Window highlight
    final highlightPaint = Paint()
      ..color = const Color(0xFFA5B4FC).withOpacity(0.5);

    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.19),
      1.5,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ThinnerRocketPainter oldDelegate) {
    return oldDelegate.scrollRatio != scrollRatio;
  }
}
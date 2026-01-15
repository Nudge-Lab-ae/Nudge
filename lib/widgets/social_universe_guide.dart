// lib/widgets/social_universe_guide.dart
import 'dart:math';
import 'package:flutter/material.dart';
// import 'package:nudge/providers/theme_provider.dart';
// import 'package:provider/provider.dart';

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

class _SocialUniverseGuideState extends State<SocialUniverseGuide> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // Color schemes for both modes
  final Map<bool, GuideTheme> _themes = {
    true: GuideTheme(
      backgroundColor: Colors.black.withOpacity(0.95),
      primaryColor: Color(0xFF8A9DFF),
      secondaryColor: Color(0xFF5CDEE5),
      accentColor: Color(0xFF2D85F6),
      textPrimary: Colors.white,
      textSecondary: Colors.white70,
      iconColor: Colors.white,
      buttonGradient: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
      buttonText: Colors.white,
      cardBackground: Colors.white10,
      borderColor: Colors.white24,
    ),
    false: GuideTheme(
      backgroundColor: Colors.white,
      primaryColor: Color(0xFF2196F3),
      secondaryColor: Color(0xFF03A9F4),
      accentColor: Color(0xFF00BCD4),
      textPrimary: Color(0xFF212121),
      textSecondary: Color(0xFF757575),
      iconColor: Color(0xFF2196F3),
      buttonGradient: [Color(0xFF2196F3), Color(0xFF03A9F4)],
      buttonText: Colors.white,
      cardBackground: Color(0xFFF5F5F5),
      borderColor: Color(0xFFE0E0E0),
    ),
  };

  late GuideTheme _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = _themes[widget.isDarkMode]!;
  }

  @override
  void didUpdateWidget(covariant SocialUniverseGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      setState(() {
        _currentTheme = _themes[widget.isDarkMode]!;
      });
    }
  }

  final List<GuidePage> _pages = [
    GuidePage(
      title: 'Welcome to Your Social Universe',
      description: 'Visualize all your relationships at a glance. Each star represents a person in your life.',
      icon: Icons.rocket_launch,
      color: Color(0xFF8A9DFF),
      lightModeColor: Color(0xFF2196F3),
    ),
    GuidePage(
      title: 'The Three Circles',
      description: 'Your connections are organized into three rings based on how active your relationship is:\n\n• Inner Circle: Strong, frequent connections\n• Middle Circle: Moderate connections\n• Outer Circle: Less frequent connections',
      icon: Icons.circle_outlined,
      color: Color(0xFF5CDEE5),
      lightModeColor: Color(0xFF03A9F4),
    ),
    GuidePage(
      title: 'Star Sizes Matter',
      description: 'Larger stars are more important to you (based on your categories).\n\nReorder categories in Settings to adjust star sizes.',
      icon: Icons.star,
      color: Color(0xFFFFD700),
      lightModeColor: Color(0xFFFFC107),
    ),
    GuidePage(
      title: 'Movement & Engagement',
      description: 'Stars move closer when you interact more, and drift outward when less active.\n\nLog interactions to strengthen connections!',
      icon: Icons.trending_up,
      color: Colors.green,
      lightModeColor: Color(0xFF4CAF50),
    ),
    GuidePage(
      title: 'How to Use',
      description: '• Tap any star to see contact details\n• Log interactions from the contact panel\n• Use slider to adjust visual depth\n• The system updates automatically',
      icon: Icons.touch_app,
      color: Color(0xFF2D85F6),
      lightModeColor: Color(0xFF2196F3),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pageColor = widget.isDarkMode 
        ? _pages[_currentPage].color 
        : _pages[_currentPage].lightModeColor;

    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SOCIAL UNIVERSE GUIDE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: pageColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(
                      Icons.close,
                      color: _currentTheme.iconColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final indicatorColor = widget.isDarkMode 
                      ? _pages[index].color 
                      : _pages[index].lightModeColor;
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? indicatorColor
                          : widget.isDarkMode 
                              ? Colors.white24 
                              : Color(0xFFE0E0E0),
                    ),
                  );
                }),
              ),
            ),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Previous Button
                  Expanded(
                    child: Opacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.5,
                      child: TextButton(
                        onPressed: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _currentTheme.borderColor),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              size: 16,
                              color: _currentTheme.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'PREVIOUS',
                              style: TextStyle(
                                color: _currentTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 12),

                  // Next / Finish Button
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: _currentTheme.buttonGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: widget.isDarkMode 
                            ? [
                                BoxShadow(
                                  color: _currentTheme.accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.onClose();
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage < _pages.length - 1
                                  ? 'NEXT'
                                  : 'GOT IT!',
                              style: TextStyle(
                                color: _currentTheme.buttonText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_currentPage < _pages.length - 1)
                              const SizedBox(width: 8),
                            if (_currentPage < _pages.length - 1)
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: _currentTheme.buttonText,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(GuidePage page, int pageIndex) {
    final pageColor = widget.isDarkMode ? page.color : page.lightModeColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  pageColor.withOpacity(widget.isDarkMode ? 0.8 : 0.9),
                  pageColor.withOpacity(widget.isDarkMode ? 0.2 : 0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: pageColor.withOpacity(widget.isDarkMode ? 0.3 : 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 48,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _currentTheme.textPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              page.description,
              style: TextStyle(
                fontSize: 16,
                color: _currentTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 40),

          // Visual Example (for relevant pages)
          if (pageIndex == 1) // Circles page
            _buildCirclesExample(pageColor),
          if (pageIndex == 2) // Star sizes page
            _buildStarSizesExample(pageColor),
          if (pageIndex == 3) // Movement page
            _buildMovementExample(pageColor),
        ],
      ),
    );
  }

  Widget _buildCirclesExample(Color pageColor) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _currentTheme.cardBackground,
        border: Border.all(
          color: _currentTheme.borderColor,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Circle
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isDarkMode 
                    ? Colors.redAccent.withOpacity(0.5)
                    : Color(0xFFF44336).withOpacity(0.7),
                width: 2,
              ),
            ),
          ),
          
          // Middle Circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isDarkMode 
                    ? Color(0xFFFFC107).withOpacity(0.5)
                    : Color(0xFFFF9800).withOpacity(0.7),
                width: 2,
              ),
            ),
          ),
          
          // Inner Circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isDarkMode 
                    ? Colors.green.withOpacity(0.5)
                    : Color(0xFF4CAF50).withOpacity(0.7),
                width: 2,
              ),
            ),
          ),
          
          // Center
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _currentTheme.buttonGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: pageColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          
          // Labels
          Positioned(
            top: 5,
            left: 0,
            right: 0,
            child: Text(
              'Outer Circle',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.redAccent : Color(0xFFF44336),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Text(
              'Middle Circle',
              style: TextStyle(
                color: widget.isDarkMode ? Color(0xFFFFC107) : Color(0xFFFF9800),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Positioned(
            top: 130,
            left: 0,
            right: 0,
            child: Text(
              'Inner Circle',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.green : Color(0xFF4CAF50),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarSizesExample(Color pageColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _currentTheme.cardBackground,
        border: Border.all(
          color: _currentTheme.borderColor,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStarExample(24, 'High Priority', pageColor),
              SizedBox(width: 20),
              _buildStarExample(16, 'Medium', pageColor),
              SizedBox(width: 20),
              _buildStarExample(10, 'Low', pageColor),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Size = Category Priority',
            style: TextStyle(
              color: _currentTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Reorder categories in Settings to adjust star sizes',
            style: TextStyle(
              color: _currentTheme.textSecondary.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStarExample(double size, String label, Color pageColor) {
    return Column(
      children: [
        Container(
          width: size * 2,
          height: size * 2,
          child: CustomPaint(
            painter: _StarPainter(
              size: size,
              color: pageColor,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: _currentTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMovementExample(Color pageColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _currentTheme.cardBackground,
        border: Border.all(
          color: _currentTheme.borderColor,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 200,
            height: 100,
            child: Stack(
              children: [
                // Track
                Container(
                  margin: EdgeInsets.symmetric(vertical: 40),
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isDarkMode 
                          ? [Colors.redAccent, Color(0xFFFFC107), Colors.green]
                          : [Color(0xFFF44336), Color(0xFFFF9800), Color(0xFF4CAF50)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                
                // Animated star
                AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    final offset = _currentPage == 3 ? 1.0 : 0.0;
                    return Positioned(
                      left: 160 * offset,
                      top: 33,
                      child: Container(
                        width: 34,
                        height: 34,
                        child: CustomPaint(
                          painter: _StarPainter(
                            size: 14,
                            color: widget.isDarkMode ? Color(0xFFFFD700) : Color(0xFFFFC107),
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Labels
                Positioned(
                  left: 0,
                  top: 50,
                  child: Text(
                    'Less Active',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.redAccent : Color(0xFFF44336),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                Positioned(
                  right: 0,
                  top: 50,
                  child: Text(
                    'More Active',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.green : Color(0xFF4CAF50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Log interactions to move stars inward',
            style: TextStyle(
              color: _currentTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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
    this.isDarkMode = true,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    const numberOfPoints = 5;
    final halfPi = pi / numberOfPoints;
    final points = <Offset>[];
    
    for (var i = 0; i < numberOfPoints * 2; i++) {
      final pointRadius = i.isEven ? this.size : this.size * 0.6;
      final pointAngle = halfPi * i;
      points.add(Offset(
        center.dx + pointRadius * cos(pointAngle),
        center.dy + pointRadius * sin(pointAngle),
      ));
    }
    
    final path = Path()..addPolygon(points, true);
    
    final gradient = RadialGradient(
      center: Alignment.center,
      colors: isDarkMode
          ? [color.withOpacity(0.9), color.withOpacity(0.5)]
          : [color.withOpacity(1.0), color.withOpacity(0.7)],
    );
    
    final starPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: this.size),
      );
    
    canvas.drawPath(path, starPaint);
    
    // Add subtle outline for light mode
    if (!isDarkMode) {
      final outlinePaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      canvas.drawPath(path, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
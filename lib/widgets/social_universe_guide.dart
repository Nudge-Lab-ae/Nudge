// lib/widgets/social_universe_guide.dart
import 'dart:math';

import 'package:flutter/material.dart';

class SocialUniverseGuide extends StatefulWidget {
  final VoidCallback onClose;

  const SocialUniverseGuide({Key? key, required this.onClose}) : super(key: key);

  @override
  State<SocialUniverseGuide> createState() => _SocialUniverseGuideState();
}

class _SocialUniverseGuideState extends State<SocialUniverseGuide> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<GuidePage> _pages = [
    GuidePage(
      title: 'Welcome to Your Social Universe',
      description: 'Visualize all your relationships at a glance. Each star represents a person in your life.',
      icon: Icons.rocket_launch,
      color: Color(0xFF8A9DFF),
    ),
    GuidePage(
      title: 'The Three Circles',
      description: 'Your connections are organized into three rings based on how active your relationship is:\n\n• Inner Circle: Strong, frequent connections\n• Middle Circle: Moderate connections\n• Outer Circle: Less frequent connections',
      icon: Icons.circle_outlined,
      color: Color(0xFF5CDEE5),
    ),
    GuidePage(
      title: 'Star Sizes Matter',
      description: 'Larger stars are more important to you (based on your categories).\n\nReorder categories in Settings to adjust star sizes.',
      icon: Icons.star,
      color: Color(0xFFFFD700),
    ),
    GuidePage(
      title: 'Movement & Engagement',
      description: 'Stars move closer when you interact more, and drift outward when less active.\n\nLog interactions to strengthen connections!',
      icon: Icons.trending_up,
      color: Colors.green,
    ),
    GuidePage(
      title: 'How to Use',
      description: '• Tap any star to see contact details\n• Log interactions from the contact panel\n• Use slider to adjust visual depth\n• The system updates automatically',
      icon: Icons.touch_app,
      color: Color(0xFF2D85F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SOCIAL UNIVERSE GUIDE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A9DFF),
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
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
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? _pages[index].color
                          : Colors.white24,
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
                            side: BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              size: 16,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'PREVIOUS',
                              style: TextStyle(
                                color: Colors.white70,
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
                          colors: [
                            Color(0xFF5CDEE5),
                            Color(0xFF2D85F6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_currentPage < _pages.length - 1)
                              const SizedBox(width: 8),
                            if (_currentPage < _pages.length - 1)
                              const Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Colors.white,
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

  Widget _buildPage(GuidePage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.color.withOpacity(0.8),
                  page.color.withOpacity(0.2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.3),
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 40),

          // Visual Example (for relevant pages)
          if (_pages.indexOf(page) == 1) // Circles page
            _buildCirclesExample(),
          if (_pages.indexOf(page) == 2) // Star sizes page
            _buildStarSizesExample(),
          if (_pages.indexOf(page) == 3) // Movement page
            _buildMovementExample(),
        ],
      ),
    );
  }

  Widget _buildCirclesExample() {
    return Container(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Circle
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
          
          // Middle Circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color(0xFFFFC107).withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
          
          // Inner Circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.withOpacity(0.5),
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
                colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
              ),
            ),
          ),
          
          // Labels
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Text(
              'Outer Circle',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Positioned(
            top: 75,
            left: 0,
            right: 0,
            child: Text(
              'Middle Circle',
              style: TextStyle(
                color: Color(0xFFFFC107),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Positioned(
            top: 135,
            left: 0,
            right: 0,
            child: Text(
              'Inner Circle',
              style: TextStyle(
                color: Colors.green,
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

  Widget _buildStarSizesExample() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStarExample(24, 'High Priority'),
            SizedBox(width: 20),
            _buildStarExample(16, 'Medium'),
            SizedBox(width: 20),
            _buildStarExample(10, 'Low'),
          ],
        ),
        SizedBox(height: 20),
        Text(
          'Size = Category Priority',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStarExample(double size, String label) {
    return Column(
      children: [
        Container(
          width: size * 2,
          height: size * 2,
          child: CustomPaint(
            painter: _StarPainter(size: size),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMovementExample() {
    return Container(
      width: 200,
      height: 100,
      child: Stack(
        children: [
          // Track
          Container(
            margin: EdgeInsets.symmetric(vertical: 40),
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.redAccent, Color(0xFFFFC107), Colors.green],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Animated star
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              final offset = _currentPage == 3 ? 1.0 : 0.0;
              return Positioned(
                left: 160 * offset,
                top: 35,
                child: Container(
                  width: 30,
                  height: 30,
                  child: CustomPaint(
                    painter: _StarPainter(size: 12, color: Color(0xFFFFD700)),
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
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ),
          
          Positioned(
            right: 0,
            top: 50,
            child: Text(
              'More Active',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
              ),
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

  GuidePage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _StarPainter extends CustomPainter {
  final double size;
  final Color color;

  _StarPainter({required this.size, this.color = const Color(0xFFFFD700)});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const numberOfPoints = 6;
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
      colors: [color.withOpacity(0.9), color.withOpacity(0.5)],
    );
    
    final starPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: this.size),
      );
    
    canvas.drawPath(path, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
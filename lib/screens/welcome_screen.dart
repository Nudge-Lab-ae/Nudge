import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nudge/screens/auth/register_screen.dart';
import 'auth/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Cosmic Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF64B5F6), // Light cyan/sky blue
                  const Color(0xFF42A5F5), // Medium sky blue
                  const Color(0xFF2196F3), // Blue
                  const Color(0xFF1E88E5), // Deep blue
                  const Color(0xFF1565C0), // Navy blue
                  const Color(0xFF0D47A1), // Dark navy blue
                  const Color(0xFF1A237E), // Dark purple-blue
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.75, 0.9, 1.0],
              ),
            ),
          ),

          // Natural star distribution with circular concentrations
          Positioned.fill(
            child: CustomPaint(
              painter: NaturalStarPainter(),
            ),
          ),

          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Name
                  const Text(
                    'NUDGE',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                      fontFamily: 'RobotoMono',
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black38,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Hero text
                  const Text(
                    'Stay connected to the people\nwho matter most',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black38,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // Join Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: const Text(
                        'Join',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // Login Link
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Already have an account? Login',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withOpacity(0.5),
                      ),
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
}

// Custom painter for natural star distribution
class NaturalStarPainter extends CustomPainter {
  final Random _random = Random(42);
  final List<Star> _allStars = [];

  NaturalStarPainter() {
    _createNaturalStarDistribution();
  }

  void _createNaturalStarDistribution() {
    // Total star count: ~1000 stars for a generous amount
    final totalStars = 1000;
    
    // Define natural circular concentration centers (3-4 areas)
    final concentrationCenters = [
      // Offset(0.25, 0.3),   // Top-left area
      // Offset(0.75, 0.25),  // Top-right area
      // Offset(0.3, 0.7),    // Bottom-left area
      // Offset(0.7, 0.65),   // Bottom-right area
    ];
    
    // Create stars for each concentration area
    for (final center in concentrationCenters) {
      // Each concentration gets 150-200 stars
      final concentrationStars = 780 + _random.nextInt(40);
      
      for (int i = 0; i < concentrationStars; i++) {
        // Gaussian distribution around center
        final distance = _gaussianRandom(0.0, 0.08) * 0.15;
        final angle = _random.nextDouble() * 2 * pi;
        
        final x = center.dx + cos(angle) * distance.abs();
        final y = center.dy + sin(angle) * distance.abs();
        
        // Stars in concentrations are slightly larger and brighter
        final size = 0.5 + _random.nextDouble() * 1.0; // 0.5-1.5px
        // Brightness decreases with distance from center
        final distanceFromCenter = sqrt(pow(x - center.dx, 2) + pow(y - center.dy, 2));
        final opacity = (0.7 - distanceFromCenter * 2).clamp(0.3, 0.7);
        
        if (x >= 0 && x <= 1 && y >= 0 && y <= 1) {
          _allStars.add(Star(
            x: x,
            y: y,
            size: size,
            opacity: opacity,
            isInConcentration: true,
          ));
        }
      }
    }
    
    // Fill the rest with background stars (~400 stars)
    final backgroundStars = totalStars - _allStars.length;
    
    for (int i = 0; i < backgroundStars; i++) {
      final x = _random.nextDouble();
      final y = _random.nextDouble();
      
      // Check if too close to concentration centers
      bool isNearConcentration = false;
      for (final center in concentrationCenters) {
        final distance = sqrt(pow(x - center.dx, 2) + pow(y - center.dy, 2));
        if (distance < 0.1) {
          isNearConcentration = true;
          break;
        }
      }
      
      // Add background star if not too close to concentrations
      if (!isNearConcentration) {
        final size = 0.3 + _random.nextDouble() * 0.7; // 0.3-1.0px
        final opacity = 0.2 + _random.nextDouble() * 0.4; // 0.2-0.6 opacity
        
        _allStars.add(Star(
          x: x,
          y: y,
          size: size,
          opacity: opacity,
          isInConcentration: false,
        ));
      }
    }
    
    // Add some very small stars throughout (~200 stars)
    for (int i = 0; i < 600; i++) {
      final x = _random.nextDouble();
      final y = _random.nextDouble();
      final size = 0.1 + _random.nextDouble() * 0.6; // Very small: 0.1-0.4px
      final opacity = 0.1 + _random.nextDouble() * 0.5; // Very faint
      
      _allStars.add(Star(
        x: x,
        y: y,
        size: size,
        opacity: opacity,
        isInConcentration: false,
      ));
    }
  }
  
  double _gaussianRandom(double mean, double stdDev) {
    // Generate Gaussian random number using Box-Muller transform
    double u1 = 1.0 - _random.nextDouble();
    double u2 = 1.0 - _random.nextDouble();
    double z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    return mean + stdDev * z;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw defined rings first
    _drawDefinedUniverseRings(canvas, size);
    
    // Draw all stars
    for (final star in _allStars) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(star.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
    
    // Draw subtle connections in concentration areas
    _drawSubtleConnections(canvas, size);
  }

  void _drawDefinedUniverseRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.45;
    
    // Draw 3 defined rings (less blurry, more visible)
    final rings = [
      Ring(radius: maxRadius * 0.5, color: Colors.yellow.withOpacity(0.1)),
      Ring(radius: maxRadius * 0.7, color: const Color(0xff3CB3E9).withOpacity(0.08)),
      Ring(radius: maxRadius * 0.95, color: const Color(0xff897ED6).withOpacity(0.06)),
    ];
    
    for (final ring in rings) {
      // Main ring - sharper, less blurry
      final paint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
        // Minimal blur for sharper edges
      
      canvas.drawCircle(center, ring.radius, paint);
      
      // Very subtle inner glow only
      final innerPaint = Paint()
        ..color = ring.color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
      canvas.drawCircle(center, ring.radius - 0.5, innerPaint);
    }
    
    // Add subtle radial gradient effect for rings
    final radialGradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withOpacity(0.02),
          Colors.transparent,
        ],
        radius: 0.5,
      ).createShader(Rect.fromCircle(
        center: center,
        radius: maxRadius,
      ));
    
    canvas.drawCircle(center, maxRadius, radialGradientPaint);
  }

  void _drawSubtleConnections(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1
      ..strokeCap = StrokeCap.round;
    
    // Only connect stars in concentration areas
    final concentrationStars = _allStars.where((star) => star.isInConcentration).toList();
    
    for (int i = 0; i < concentrationStars.length; i++) {
      final star1 = concentrationStars[i];
      
      for (int j = i + 1; j < min(i + 20, concentrationStars.length); j++) {
        final star2 = concentrationStars[j];
        
        final distance = sqrt(
          pow(star1.x - star2.x, 2) + 
          pow(star1.y - star2.y, 2)
        ) * size.width;
        
        // Connect close stars in concentrations
        if (distance < 25 && _random.nextDouble() > 0.8) {
          canvas.drawLine(
            Offset(star1.x * size.width, star1.y * size.height),
            Offset(star2.x * size.width, star2.y * size.height),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Helper classes
class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final bool isInConcentration;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.isInConcentration,
  });
}

class Ring {
  final double radius;
  final Color color;

  Ring({
    required this.radius,
    required this.color,
  });
}
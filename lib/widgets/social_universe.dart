// lib/widgets/social_universe_widget.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'dart:math';
// import 'package:vector_math/vector_math.dart' as vm;
import '../models/contact.dart';
import '../services/social_universe_service.dart';

class SocialUniverseWidget extends StatefulWidget {
  final List<Contact> contacts;
  final Function(Contact) onContactSelect;
  final double height;
  
  const SocialUniverseWidget({
    Key? key,
    required this.contacts,
    required this.onContactSelect,
    this.height = 420, // Increased height for even larger circle
  }) : super(key: key);

  @override
  State<SocialUniverseWidget> createState() => _SocialUniverseWidgetState();
}

class _SocialUniverseWidgetState extends State<SocialUniverseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  final SocialUniverseService _service = SocialUniverseService();
  Contact? _selectedContact;
  
  // For storing star positions for hit testing
  final Map<String, Offset> _starPositions = {};
  final Map<String, double> _starSizes = {};
  final Map<String, double> _starHitSizes = {}; // Separate hit detection sizes
  final Map<String, double> _starSpreadOffsets = {};
  
  // Touch detection
  final Map<String, Rect> _starHitRegions = {};
  double _currentRotation = 0.0;
  bool _isTouchActive = false;

  @override
  void initState() {
    super.initState();
    
    // Create continuous rotation animation (one full rotation every 180 seconds - very slow)
    _controller = AnimationController(
      duration: const Duration(seconds: 180),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
    
    // Initialize spread offsets for each contact
    _initializeStarSpread();
  }

  void _initializeStarSpread() {
    // final random = Random(42);
    for (var contact in widget.contacts) {
      // Generate a consistent spread offset for each contact
      var hash = 0;
      for (var i = 0; i < contact.id.length; i++) {
        hash = contact.id.codeUnitAt(i) + ((hash << 5) - hash);
      }
      _starSpreadOffsets[contact.id] = (hash.abs() % 35) / 100.0; // 0-0.35 spread
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E21),
            Color(0xFF1A1F38),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with rotation indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOCIAL UNIVERSE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A9DFF),
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your relationship galaxy',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.autorenew,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Living Galaxy',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Universe visualization - takes 80% of height
            Expanded(
              flex: 8,
              child: GestureDetector(
                onTapDown: (details) {
                  _isTouchActive = true;
                  _handleTouch(details.localPosition);
                },
                onTapUp: (details) {
                  _isTouchActive = false;
                },
                onTapCancel: () {
                  _isTouchActive = false;
                },
                onPanStart: (details) {
                  _isTouchActive = true;
                  _handleTouch(details.localPosition);
                },
                onPanUpdate: (details) {
                  // Allow dragging for touch exploration
                  _handleTouch(details.localPosition);
                },
                onPanEnd: (details) {
                  _isTouchActive = false;
                },
                onPanCancel: () {
                  _isTouchActive = false;
                },
                child: MouseRegion(
                  onHover: (event) {
                    _handleHover(event.localPosition);
                  },
                  onExit: (_) {
                    if (!_isTouchActive) {
                      setState(() {
                        _selectedContact = null;
                      });
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      _currentRotation = _rotationAnimation.value;
                      return CustomPaint(
                        painter: SocialUniversePainter(
                          contacts: widget.contacts,
                          selectedContact: _selectedContact,
                          starPositions: _starPositions,
                          starSizes: _starSizes,
                          starHitSizes: _starHitSizes,
                          starSpreadOffsets: _starSpreadOffsets,
                          rotation: _currentRotation,
                          isTouchActive: _isTouchActive,
                          service: _service,
                        ),
                        size: Size(
                          MediaQuery.of(context).size.width - 32,
                          widget.height - 140, // More space for the circle
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Legend row below the circle
            _buildLegendRow(),
            
            // Contact preview card (appears when a star is selected)
            if (_selectedContact != null) 
              _buildContactPreviewCard(_selectedContact!),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow() {
    final totalContacts = widget.contacts.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Inner Circle', Colors.green, Icons.star),
              _buildLegendItem('Middle Circle', Color(0xFFFFC107), Icons.circle),
              _buildLegendItem('Outer Circle', Colors.redAccent, Icons.circle_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$totalContacts Total Stars • Tap any star to view details',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildContactPreviewCard(Contact contact) {
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getTimeAgoText(daysAgo);
    final ringColor = _getRingColor(contact.computedRing);
    
    return GestureDetector(
      onTap: () {
        widget.onContactSelect(contact);
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ringColor.withOpacity(0.2),
              ringColor.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: ringColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: ringColor.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            // Contact avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ringColor,
                    ringColor.withOpacity(0.5),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  contact.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          contact.connectionType,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $lastContactText',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // View button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VIEW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.green;
      case 'middle':
        return Color(0xFFFFC107); // Amber/Yellow
      case 'outer':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgoText(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return '${(days / 7).floor()} weeks ago';
    if (days < 365) return '${(days / 30).floor()} months ago';
    return '${(days / 365).floor()} years ago';
  }

  void _handleHover(Offset position) {
    final contact = _getContactAtPosition(position);
    if (!_isTouchActive) {
      setState(() {
        _selectedContact = contact;
      });
    }
  }

  void _handleTouch(Offset position) {
    final contact = _getContactAtPosition(position);
    setState(() {
      _selectedContact = contact;
    });
  }

  Contact? _getContactAtPosition(Offset position) {
    // First check selected contact (if any) for larger hit area
    if (_selectedContact != null && _starHitRegions.containsKey(_selectedContact!.id)) {
      final region = _starHitRegions[_selectedContact!.id]!;
      if (region.contains(position)) {
        return _selectedContact;
      }
    }
    
    // Check all contacts
    for (var entry in _starHitRegions.entries) {
      final contactId = entry.key;
      final hitRegion = entry.value;
      
      if (hitRegion.contains(position)) {
        return widget.contacts.firstWhere(
          (c) => c.id == contactId,
          orElse: () => widget.contacts.firstWhere((c) => c.id == contactId),
        );
      }
    }
    return null;
  }
}

class SocialUniversePainter extends CustomPainter {
  final List<Contact> contacts;
  final Contact? selectedContact;
  final Map<String, Offset> starPositions;
  final Map<String, double> starSizes;
  final Map<String, double> starHitSizes;
  final Map<String, double> starSpreadOffsets;
  final double rotation;
  final bool isTouchActive;
  final SocialUniverseService service;

  SocialUniversePainter({
    required this.contacts,
    required this.selectedContact,
    required this.starPositions,
    required this.starSizes,
    required this.starHitSizes,
    required this.starSpreadOffsets,
    required this.rotation,
    required this.isTouchActive,
    required this.service,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Use 95% of available space for the circle - MUCH BIGGER
    final maxRadius = min(size.width / 2, size.height / 2) * 0.95;
    
    // Clear previous positions
    starPositions.clear();
    starSizes.clear();
    starHitSizes.clear();

    // Draw cosmic background
    _drawCosmicBackground(canvas, size, rotation);
    
    // Draw large glowing rings
    _drawRing(canvas, center, maxRadius * 0.15, maxRadius * 0.40, Colors.green.withOpacity(0.2), rotation);
    _drawRing(canvas, center, maxRadius * 0.45, maxRadius * 0.70, Color(0xFFFFC107).withOpacity(0.2), rotation);
    _drawRing(canvas, center, maxRadius * 0.75, maxRadius, Colors.redAccent.withOpacity(0.2), rotation);
    
    // Draw central user (smaller to not take too much space)
    _drawCentralUser(canvas, center, rotation);
    
    // Draw stars with spreading
    for (var contact in contacts) {
      _drawStar(canvas, center, contact, maxRadius);
    }

    // Draw subtle selection effect (no blue line)
    if (selectedContact != null && starPositions.containsKey(selectedContact!.id)) {
      _drawSelectionEffect(canvas, starPositions[selectedContact!.id]!, 
                         starSizes[selectedContact!.id]!, 
                         _getRingColor(selectedContact!.computedRing));
    }
  }

  void _drawCosmicBackground(Canvas canvas, Size size, double rotation) {
    // Draw gradient background
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        colors: [
          Color(0xFF1A1F38),
          Color(0xFF0A0E21),
          Colors.black,
        ],
        stops: [0.0, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Draw more background stars for depth
    final random = Random(42);
    for (int i = 0; i < 300; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height);
      final radius = random.nextDouble() * 1.5;
      final opacity = random.nextDouble() * 0.5 + 0.1;
      
      final twinkle = (sin(rotation * 1 + i * 0.05) + 1) / 2;
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(opacity * (0.3 + twinkle * 0.7));
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _drawRing(Canvas canvas, Offset center, double innerRadius, double outerRadius, Color color, double rotation) {
    // Draw subtle ring glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    
    canvas.drawCircle(center, outerRadius, glowPaint);
    
    // Draw ring body with very subtle gradient
    final gradient = RadialGradient(
      colors: [
        color.withOpacity(0.15),
        color.withOpacity(0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, outerRadius, paint);
    
    // Cut out inner circle
    final cutPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    
    canvas.drawCircle(center, innerRadius, cutPaint);
    
    // Draw very subtle ring outline
    final outlinePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;
    
    canvas.drawCircle(center, innerRadius, outlinePaint);
    canvas.drawCircle(center, outerRadius, outlinePaint);
  }

  void _drawCentralUser(Canvas canvas, Offset center, double rotation) {
    // Draw subtle pulsing core
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulse = (sin(time * 1.5) + 1) / 2;
    
    // Core glow
    final glowPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        colors: [
          Color(0xFF5CDEE5),
          Color(0xFF2D85F6),
          Colors.transparent,
        ],
        stops: [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 20 + pulse * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    canvas.drawCircle(center, 20 + pulse * 2, glowPaint);
    
    // Central sphere
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: const [
          Color(0xFF5CDEE5),
          Color(0xFF2D85F6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 12));
    
    canvas.drawCircle(center, 12, spherePaint);
    
    // Draw YOU text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, center.translate(-9, 18));
  }

  void _drawStar(Canvas canvas, Offset center, Contact contact, double maxRadius) {
    final isSelected = selectedContact?.id == contact.id;
    final isVIP = contact.isVIP;
    
    // Get ring boundaries
    double innerRadius, outerRadius;
    Color color;
    
    switch (contact.computedRing) {
      case 'inner':
        innerRadius = maxRadius * 0.15;
        outerRadius = maxRadius * 0.40;
        color = Colors.green;
        break;
      case 'middle':
        innerRadius = maxRadius * 0.45;
        outerRadius = maxRadius * 0.70;
        color = Color(0xFFFFC107); // Amber/Yellow
        break;
      case 'outer':
        innerRadius = maxRadius * 0.75;
        outerRadius = maxRadius;
        color = Colors.redAccent;
        break;
      default:
        innerRadius = maxRadius * 0.45;
        outerRadius = maxRadius * 0.70;
        color = Colors.grey;
    }
    
    // Calculate spread within ring - spread more towards outer edge
    final spreadOffset = starSpreadOffsets[contact.id] ?? 0.2;
    final ringWidth = outerRadius - innerRadius;
    final spreadRadius = innerRadius + (ringWidth * (0.3 + spreadOffset * 0.7));
    
    // Apply rotation
    final angle = (contact.angleDeg * (pi / 180)) + rotation;
    final x = center.dx + spreadRadius * cos(angle);
    final y = center.dy + spreadRadius * sin(angle);
    final position = Offset(x, y);
    
    // Size based on selection and priority
    final nodeSizeFactor = service.calculateNodeSize(contact.priority);
    final baseSize = 9.0 * nodeSizeFactor; // Slightly larger base size
    final visualSize = isSelected ? baseSize * 2.5 : baseSize;
    final hitSize = isSelected ? baseSize * 4.0 : baseSize * 2.5; // Larger hit area
    
    // Store position and sizes
    starPositions[contact.id] = position;
    starSizes[contact.id] = visualSize;
    starHitSizes[contact.id] = hitSize;
    
    // Store hit region for touch detection (50% larger than hit size)
    // final hitRegion = Rect.fromCircle(
    //   center: position,
    //   radius: hitSize * 1.5,
    // );
    
    // Make VIP stars gold
    if (isVIP) {
      color = const Color(0xFFFFD700); // Gold
    }
    
    // Draw star glow (stronger for selected stars)
    final glowOpacity = isSelected ? 0.6 : 0.3;
    final glowPaint = Paint()
      ..color = color.withOpacity(glowOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 12 : 6);
    
    canvas.drawCircle(position, visualSize * (isSelected ? 2.0 : 1.5), glowPaint);
    
    // Draw star body
    final starPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: isSelected
            ? [color, color.withOpacity(0.9), color.withOpacity(0.7)]
            : [color.withOpacity(0.95), color.withOpacity(0.8), color.withOpacity(0.6)],
      ).createShader(Rect.fromCircle(center: position, radius: visualSize));
    
    // Create star shape (simpler 4-point star for better performance)
    const numberOfPoints = 4;
    final halfPi = pi / numberOfPoints;
    final points = <Offset>[];
    
    for (var i = 0; i < numberOfPoints * 2; i++) {
      final pointRadius = i.isEven ? visualSize : visualSize * 0.6;
      final pointAngle = halfPi * i;
      points.add(Offset(
        position.dx + pointRadius * cos(pointAngle),
        position.dy + pointRadius * sin(pointAngle),
      ));
    }
    
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, starPaint);
    
    // Draw star shine (subtle highlight)
    if (isSelected) {
      final shinePaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      canvas.drawPath(path, shinePaint);
    }
    
    // Draw VIP crown for VIP stars (only when selected)
    if (isVIP && isSelected) {
      _drawVIPCrown(canvas, position, visualSize);
    }
    
    // Only draw initials for selected stars
    if (isSelected && visualSize > 12) {
      _drawContactInitials(canvas, position, contact.name, visualSize);
    }
  }

  void _drawVIPCrown(Canvas canvas, Offset position, double size) {
    final crownPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      ).createShader(Rect.fromCircle(center: position, radius: size * 0.5));
    
    // Simple 3-point crown
    final crownPath = Path()
      ..moveTo(position.dx - size * 0.3, position.dy - size * 0.5)
      ..lineTo(position.dx, position.dy - size * 0.9)
      ..lineTo(position.dx + size * 0.3, position.dy - size * 0.5)
      ..close();
    
    canvas.drawPath(crownPath, crownPaint);
  }

  void _drawContactInitials(Canvas canvas, Offset position, String name, double size) {
    if (name.isEmpty) return;
    
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    String initials = '';
    if (parts.length >= 2) {
      initials = '${parts.first[0]}${parts.last[0]}';
    } else if (parts.length == 1) {
      initials = parts.first[0];
    } else {
      initials = '?';
    }
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: max(8, size * 0.45),
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              blurRadius: 3,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      position.translate(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  void _drawSelectionEffect(Canvas canvas, Offset position, double size, Color color) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulse = (sin(time * 4) + 1) / 2;
    
    // Subtle pulsing rings
    final ringPaint = Paint()
      ..color = color.withOpacity(0.3 * (0.5 + pulse * 0.5))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 + pulse;
    
    canvas.drawCircle(position, size * 2.5, ringPaint);
    canvas.drawCircle(position, size * 3.0, ringPaint);
    
    // Draw small orbiting dots
    final dotCount = 4;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * pi / dotCount) + time * 2;
      final dotRadius = size * 3.5;
      final dotX = position.dx + dotRadius * cos(angle);
      final dotY = position.dy + dotRadius * sin(angle);
      
      final dotPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      
      canvas.drawCircle(Offset(dotX, dotY), 2, dotPaint);
    }
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.green;
      case 'middle':
        return Color(0xFFFFC107); // Amber/Yellow
      case 'outer':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant SocialUniversePainter oldDelegate) {
    return oldDelegate.contacts != contacts ||
           oldDelegate.selectedContact != selectedContact ||
           oldDelegate.rotation != rotation ||
           oldDelegate.isTouchActive != isTouchActive;
  }
}
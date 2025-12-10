// lib/widgets/social_universe_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'dart:math';
import '../models/contact.dart';
import '../services/social_universe_service.dart';

class SocialUniverseWidget extends StatefulWidget {
  final List<Contact> contacts;
  final Function(Contact) onContactTap;
  final double size;
  
  const SocialUniverseWidget({
    Key? key,
    required this.contacts,
    required this.onContactTap,
    this.size = 300,
  }) : super(key: key);

  @override
  State<SocialUniverseWidget> createState() => _SocialUniverseWidgetState();
}

class _SocialUniverseWidgetState extends State<SocialUniverseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  final SocialUniverseService _service = SocialUniverseService();
  Contact? _hoveredContact;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.size,
      width: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SOCIAL UNIVERSE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3CB3E9),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your relationship landscape at a glance',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  setState(() {
                    _tapPosition = details.localPosition;
                  });
                },
                onTapUp: (_) {
                  _handleTap();
                  setState(() {
                    _tapPosition = null;
                  });
                },
                onTapCancel: () {
                  setState(() {
                    _tapPosition = null;
                  });
                },
                child: MouseRegion(
                  onHover: (event) {
                    _handleHover(event.localPosition);
                  },
                  onExit: (_) {
                    setState(() {
                      _hoveredContact = null;
                    });
                  },
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: SocialUniversePainter(
                          contacts: widget.contacts,
                          hoveredContact: _hoveredContact,
                          tapPosition: _tapPosition,
                          rotation: _rotationAnimation.value,
                          service: _service,
                        ),
                        size: Size(widget.size - 32, widget.size - 100),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  void _handleHover(Offset position) {
    final contactsWithPositions = _calculateContactPositions();
    
    for (var entry in contactsWithPositions.entries) {
      final contact = entry.key;
      final center = entry.value;
      final nodeSize = _service.calculateNodeSize(contact.priority) * 8;
      
      if ((position - center).distance <= nodeSize) {
        setState(() {
          _hoveredContact = contact;
        });
        return;
      }
    }
    
    setState(() {
      _hoveredContact = null;
    });
  }

  void _handleTap() {
    if (_hoveredContact != null && _tapPosition != null) {
      widget.onContactTap(_hoveredContact!);
    }
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Inner Circle', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Middle Circle', Colors.orange),
        const SizedBox(width: 16),
        _buildLegendItem('Outer Circle', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Map<Contact, Offset> _calculateContactPositions() {
    final Map<Contact, Offset> positions = {};
    final center = Offset((widget.size - 32) / 2, (widget.size - 100) / 2);
    final maxRadius = min((widget.size - 32) / 2, (widget.size - 100) / 2) - 20;
    
    for (var contact in widget.contacts) {
      final radius = _service.calculateRadius(contact, maxRadius);
      final angle = contact.angleDeg * (pi / 180);
      
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      
      positions[contact] = Offset(x, y);
    }
    
    return positions;
  }
}

class SocialUniversePainter extends CustomPainter {
  final List<Contact> contacts;
  final Contact? hoveredContact;
  final Offset? tapPosition;
  final double rotation;
  final SocialUniverseService service;

  SocialUniversePainter({
    required this.contacts,
    required this.hoveredContact,
    required this.tapPosition,
    required this.rotation,
    required this.service,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width / 2, size.height / 2) - 20;

    // Draw rings
    _drawRing(canvas, center, maxRadius * 0.2, maxRadius * 0.4, Colors.green.withOpacity(0.1));
    _drawRing(canvas, center, maxRadius * 0.5, maxRadius * 0.7, Colors.orange.withOpacity(0.1));
    _drawRing(canvas, center, maxRadius * 0.8, maxRadius, Colors.red.withOpacity(0.1));

    // Draw center user
    _drawUser(canvas, center);

    // Draw contacts
    for (var contact in contacts) {
      final radius = service.calculateRadius(contact, maxRadius);
      final angle = (contact.angleDeg * (pi / 180)) + rotation;
      final nodeSize = service.calculateNodeSize(contact.priority);
      
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      
      _drawContact(canvas, Offset(x, y), contact, nodeSize);
    }

    // Draw connection lines for hovered contact
    if (hoveredContact != null) {
      final hoverRadius = service.calculateRadius(hoveredContact!, maxRadius);
      final hoverAngle = (hoveredContact!.angleDeg * (pi / 180)) + rotation;
      final hoverX = center.dx + hoverRadius * cos(hoverAngle);
      final hoverY = center.dy + hoverRadius * sin(hoverAngle);
      
      _drawConnectionLine(canvas, center, Offset(hoverX, hoverY));
    }
  }

  void _drawRing(Canvas canvas, Offset center, double innerRadius, double outerRadius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, outerRadius, paint);
    
    // Cut out inner circle
    final cutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, innerRadius, cutPaint);
    
    // Draw ring border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(center, outerRadius, borderPaint);
    canvas.drawCircle(center, innerRadius, borderPaint);
  }

  void _drawUser(Canvas canvas, Offset center) {
    final gradient = RadialGradient(
      colors: [const Color(0xFF5CDEE5), const Color(0xFF2D85F6)],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: 12));
    
    // Draw pulsing effect
    final pulsePaint = Paint()
      ..color = const Color(0xFF3CB3E9).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, 20, pulsePaint);
    canvas.drawCircle(center, 16, pulsePaint);
    canvas.drawCircle(center, 12, paint);
    
    // Draw user icon
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, center.translate(-10, -4));
  }

  void _drawContact(Canvas canvas, Offset position, Contact contact, double sizeFactor) {
    final isHovered = hoveredContact?.id == contact.id;
    final isVIP = contact.isVIP;
    
    // Determine color based on ring
    Color color;
    switch (contact.computedRing) {
      case 'inner':
        color = Colors.green;
        break;
      case 'middle':
        color = Colors.orange;
        break;
      case 'outer':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    
    // Draw star shape
    final paint = Paint()
      ..color = isHovered ? color.withOpacity(0.8) : color
      ..style = PaintingStyle.fill;
    
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    final baseSize = 8.0 * sizeFactor;
    final size = isHovered ? baseSize * 1.2 : baseSize;
    
    // Draw star with 5 points
    _drawStar(canvas, position, size, paint, starPaint);
    
    // Draw VIP crown for VIP contacts
    if (isVIP) {
      _drawVIPCrown(canvas, position, size);
    }
    
    // Draw CDI indicator (subtle glow)
    final cdiGlow = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(position, size * 1.5, cdiGlow);
    
    // Draw contact name on hover
    if (isHovered) {
      _drawContactLabel(canvas, position, contact.name, size);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint fillPaint, Paint strokePaint) {
    const numberOfPoints = 5;
    final halfPi = pi / numberOfPoints;
    final points = <Offset>[];
    
    for (var i = 0; i < numberOfPoints * 2; i++) {
      final radius = i.isEven ? size : size / 2;
      final angle = halfPi * i;
      points.add(Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      ));
    }
    
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawVIPCrown(Canvas canvas, Offset center, double size) {
    final crownPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    
    final crownPath = Path()
      ..moveTo(center.dx - size, center.dy - size)
      ..lineTo(center.dx, center.dy - size * 1.5)
      ..lineTo(center.dx + size, center.dy - size)
      ..close();
    
    canvas.drawPath(crownPath, crownPaint);
  }

  void _drawContactLabel(Canvas canvas, Offset position, String name, double size) {
    final text = name.split(' ').first;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 2,
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
      position.translate(-textPainter.width / 2, -size - 15),
    );
  }

  void _drawConnectionLine(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = const Color(0xFF3CB3E9).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    
    // Draw animated dotted line
    final distance = (to - from).distance;
    final dashWidth = 5.0;
    final dashSpace = 3.0;
    final steps = (distance / (dashWidth + dashSpace)).floor();
    
    for (var i = 0; i < steps; i++) {
      final startT = (i * (dashWidth + dashSpace)) / distance;
      final endT = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;
      
      if (endT > 1) break;
      
      final start = Offset.lerp(from, to, startT)!;
      final end = Offset.lerp(from, to, endT)!;
      
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SocialUniversePainter oldDelegate) {
    return oldDelegate.contacts != contacts ||
           oldDelegate.hoveredContact != hoveredContact ||
           oldDelegate.tapPosition != tapPosition ||
           oldDelegate.rotation != rotation;
  }
}
// lib/widgets/social_universe.dart - MODIFIED VERSION WITH IMMERSIVE MODE
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/contact.dart';
// import '../services/social_universe_service.dart';

class SocialUniverseWidget extends StatefulWidget {
  final List<Contact> contacts;
  final Function(Contact) onContactView;
  final double height;
  final bool isImmersive;
  final VoidCallback? onExitImmersive;
  
  const SocialUniverseWidget({
    Key? key,
    required this.contacts,
    required this.onContactView,
    this.height = 400,
    this.isImmersive = false,
    this.onExitImmersive,
  }) : super(key: key);

  @override
  State<SocialUniverseWidget> createState() => _SocialUniverseWidgetState();
}

class _SocialUniverseWidgetState extends State<SocialUniverseWidget> {
  Contact? _selectedContact;
  bool _isHovering = false;
  Offset? _hoverPosition;
  String? _hoveredContactId;
  
  // Immersive mode variables
  bool _showControls = false;
  double _immersionLevel = 1.0; // 0.5 = subtle, 1.0 = full

  @override
  Widget build(BuildContext context) {
    if (widget.isImmersive) {
      return _buildImmersiveView();
    } else {
      return _buildCompactView();
    }
  }

  Widget _buildCompactView() {
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
      child: Stack(
        children: [
          // Main universe content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                            'Tap to explore • Tap icon below for full view',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      if (!widget.isImmersive)
                        GestureDetector(
                          onTap: () {
                            // This will be handled by the parent
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.fullscreen,
                              size: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Universe area
                  Expanded(
                    child: _buildUniverseCanvas(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildLegendRow(),
                  
                  // Contact preview card
                  if (_selectedContact != null) 
                    _buildContactPreviewCard(_selectedContact!),
                ],
              ),
            ),
          ),
          
          // Immersion hint overlay
          if (_isHovering)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.fullscreen,
                              size: 32,
                              color: Colors.white,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap bottom icon for\nimmersive experience',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImmersiveView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Universe canvas (full screen)
          Positioned.fill(
            child: _buildUniverseCanvas(),
          ),
          
          // Top controls
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: widget.onExitImmersive,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          
                          const Text(
                            'IMMERSIVE UNIVERSE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A9DFF),
                              letterSpacing: 2,
                            ),
                          ),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${widget.contacts.length} stars',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Immersion level slider
                      Row(
                        children: [
                          const Icon(
                            Icons.remove,
                            color: Colors.white54,
                            size: 20,
                          ),
                          Expanded(
                            child: Slider(
                              value: _immersionLevel,
                              min: 0.5,
                              max: 1.0,
                              divisions: 5,
                              activeColor: const Color(0xFF5CDEE5),
                              inactiveColor: Colors.white24,
                              onChanged: (value) {
                                setState(() {
                                  _immersionLevel = value;
                                });
                              },
                            ),
                          ),
                          const Icon(
                            Icons.add,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Depth: ${(_immersionLevel * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom info panel
          if (_selectedContact != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildImmersiveContactCard(_selectedContact!),
                ),
              ),
            ),
          
          // Hover info
          if (_hoverPosition != null && _hoveredContactId != null)
            Positioned(
              left: _hoverPosition!.dx,
              top: _hoverPosition!.dy,
              child: Transform.translate(
                offset: const Offset(10, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Hover for details',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          
          // Tap anywhere to show controls
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniverseCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onEnter: (_) {
            if (!widget.isImmersive) {
              setState(() {
                _isHovering = true;
              });
            }
          },
          onExit: (_) {
            if (!widget.isImmersive) {
              setState(() {
                _isHovering = false;
                _hoverPosition = null;
                _hoveredContactId = null;
              });
            }
          },
          onHover: (event) {
            if (widget.isImmersive) {
              setState(() {
                _hoverPosition = event.localPosition;
              });
            }
          },
          child: GestureDetector(
            onTapDown: (details) {
              _handleUniverseTap(details.localPosition, constraints);
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: UniversePainter(
                contacts: widget.contacts,
                selectedContact: _selectedContact,
                isImmersive: widget.isImmersive,
                immersionLevel: _immersionLevel,
                hoveredContactId: _hoveredContactId,
                onContactHover: (contactId) {
                  setState(() {
                    _hoveredContactId = contactId;
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleUniverseTap(Offset tapPosition, BoxConstraints constraints) {
    final universeSize = Size(constraints.maxWidth, constraints.maxHeight);
    final normalizedTap = Offset(
      tapPosition.dx / universeSize.width,
      tapPosition.dy / universeSize.height,
    );
    
    String? tappedContactId;
    double closestDistance = double.infinity;
    
    // Simple tap detection based on contact positions
    for (final contact in widget.contacts) {
      final contactAngle = contact.angleDeg * (pi / 180);
      final ringRadius = _getRingRadius(contact.computedRing) * universeSize.width * 0.5;
      
      final contactX = 0.5 + cos(contactAngle) * ringRadius / universeSize.width;
      final contactY = 0.5 + sin(contactAngle) * ringRadius / universeSize.height;
      
      final distance = sqrt(
        pow(contactX - normalizedTap.dx, 2) + 
        pow(contactY - normalizedTap.dy, 2)
      );
      
      // Clickable radius based on immersion level
      final clickRadius = widget.isImmersive ? 0.08 : 0.05;
      
      if (distance < clickRadius && distance < closestDistance) {
        closestDistance = distance;
        tappedContactId = contact.id;
      }
    }
    
    if (tappedContactId != null) {
      final contact = widget.contacts.firstWhere(
        (c) => c.id == tappedContactId,
        orElse: () => widget.contacts.first,
      );
      
      setState(() {
        _selectedContact = contact;
      });
    } else {
      setState(() {
        _selectedContact = null;
      });
    }
  }

  double _getRingRadius(String ring) {
    switch (ring) {
      case 'inner':
        return 0.25;
      case 'middle':
        return 0.5;
      case 'outer':
        return 0.75;
      default:
        return 0.5;
    }
  }

  Widget _buildLegendRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Inner Circle', Colors.green, Icons.star),
          _buildLegendItem('Middle Circle', Color(0xFFFFC107), Icons.circle),
          _buildLegendItem('Outer Circle', Colors.redAccent, Icons.circle_outlined),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
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
    
    return Container(
      height: 80,
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
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 14,
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        contact.connectionType,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• $lastContactText',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          GestureDetector(
            onTap: () {
              widget.onContactView(contact);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Text(
                'VIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveContactCard(Contact contact) {
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getTimeAgoText(daysAgo);
    final ringColor = _getRingColor(contact.computedRing);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ringColor.withOpacity(0.3),
            ringColor.withOpacity(0.1),
            Colors.black.withOpacity(0.5),
          ],
        ),
        border: Border.all(color: ringColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: ringColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  ringColor,
                  ringColor.withOpacity(0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ringColor,
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                contact.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getRingIcon(contact.computedRing),
                            size: 14,
                            color: ringColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            contact.computedRing.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ringColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            contact.connectionType,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Last contact: $lastContactText',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 20),
                    
                    if (contact.isVIP)
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Color(0xFFFFD700),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'VIP CONTACT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFD700).withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  widget.onContactView(contact);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5CDEE5).withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'VIEW DETAILS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedContact = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Clear Selection',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getRingIcon(String ring) {
    switch (ring) {
      case 'inner':
        return Icons.star;
      case 'middle':
        return Icons.circle;
      case 'outer':
        return Icons.circle_outlined;
      default:
        return Icons.circle;
    }
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.green;
      case 'middle':
        return Color(0xFFFFC107);
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
}

class UniversePainter extends CustomPainter {
  final List<Contact> contacts;
  final Contact? selectedContact;
  final bool isImmersive;
  final double immersionLevel;
  final String? hoveredContactId;
  final Function(String)? onContactHover;
  
  UniversePainter({
    required this.contacts,
    required this.selectedContact,
    required this.isImmersive,
    required this.immersionLevel,
    this.hoveredContactId,
    this.onContactHover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width / 2, size.height / 2) * 0.9;
    
    // Draw background based on immersion level
    _drawCosmicBackground(canvas, size, immersionLevel);
    
    // Draw rings with varying opacity based on immersion
    _drawRing(
      canvas,
      center,
      maxRadius * 0.15,
      maxRadius * 0.40,
      Colors.green.withOpacity(0.1 + 0.2 * immersionLevel),
    );
    _drawRing(
      canvas,
      center,
      maxRadius * 0.45,
      maxRadius * 0.70,
      Color(0xFFFFC107).withOpacity(0.1 + 0.2 * immersionLevel),
    );
    _drawRing(
      canvas,
      center,
      maxRadius * 0.75,
      maxRadius,
      Colors.redAccent.withOpacity(0.1 + 0.2 * immersionLevel),
    );
    
    // Draw central user
    _drawCentralUser(canvas, center, immersionLevel);
    
    // Draw all stars
    for (final contact in contacts) {
      _drawStar(canvas, center, contact, maxRadius, size);
    }
    
    // Draw connecting lines for immersive mode
    if (isImmersive && immersionLevel > 0.7) {
      _drawConnections(canvas, center, maxRadius);
    }
  }

  void _drawStar(Canvas canvas, Offset center, Contact contact, double maxRadius, Size size) {
    final isSelected = selectedContact?.id == contact.id;
    final isHovered = hoveredContactId == contact.id;
    final isVIP = contact.isVIP;
    
    // Get ring info
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
        color = Color(0xFFFFC107);
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
    
    // Generate stable position based on contact ID
    final hash = _stringToHash(contact.id);
    final spreadOffset = (hash.abs() % 35) / 100.0;
    
    final ringWidth = outerRadius - innerRadius;
    final spreadRadius = innerRadius + (ringWidth * (0.3 + spreadOffset * 0.7));
    
    // Use the contact's angle or generate one
    final contactAngle = contact.angleDeg != 0 
        ? contact.angleDeg * (pi / 180)
        : (hash % 360) * (pi / 180);
    
    final x = center.dx + spreadRadius * cos(contactAngle);
    final y = center.dy + spreadRadius * sin(contactAngle);
    final position = Offset(x, y);
    
    // Visual size based on immersion and selection
    double baseSize = isImmersive ? 10.0 : 8.0;
    baseSize *= (1 + 0.5 * immersionLevel); // Scale with immersion
    
    final nodeSizeFactor = 1.0; // Simplified size calculation
    final visualSize = baseSize * nodeSizeFactor;
    final finalSize = isSelected 
        ? visualSize * 2.0 
        : isHovered 
          ? visualSize * 1.5 
          : visualSize;
    
    // Make VIP stars gold
    if (isVIP) {
      color = const Color(0xFFFFD700);
    }
    
    // Draw star glow
    final glowOpacity = isSelected 
        ? 0.7 
        : isHovered 
          ? 0.5 
          : 0.3 * immersionLevel;
    
    final glowPaint = Paint()
      ..color = color.withOpacity(glowOpacity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        finalSize * (1 + immersionLevel),
      );
    
    canvas.drawCircle(position, finalSize * 1.5, glowPaint);
    
    // Draw star shape
    _drawStarShape(canvas, position, finalSize, color, isSelected, immersionLevel);
    
    // Draw VIP crown for selected stars
    if (isVIP && isSelected) {
      _drawVIPCrown(canvas, position, finalSize);
    }
    
    // Draw contact name for selected stars in immersive mode
    if (isSelected && isImmersive) {
      _drawContactName(canvas, position, contact.name, finalSize);
    }
    
    // Draw initials for selected stars in compact mode
    if (isSelected && !isImmersive) {
      _drawContactInitials(canvas, position, contact.name, finalSize);
    }
  }

  void _drawStarShape(Canvas canvas, Offset center, double size, Color color, bool isSelected, double immersionLevel) {
    // Create a 4-point star shape with enhanced detail for immersive mode
    var numberOfPoints = isSelected ? 8 : 4;
    final halfPi = pi / numberOfPoints;
    final points = <Offset>[];
    
    for (var i = 0; i < numberOfPoints * 2; i++) {
      final pointRadius = i.isEven ? size : size * 0.6;
      final pointAngle = halfPi * i;
      points.add(Offset(
        center.dx + pointRadius * cos(pointAngle),
        center.dy + pointRadius * sin(pointAngle),
      ));
    }
    
    final path = Path()..addPolygon(points, true);
    
    // Draw star body with gradient based on immersion
    final gradient = RadialGradient(
      center: Alignment.center,
      colors: isSelected
          ? [
              color,
              color.withOpacity(0.9),
              color.withOpacity(0.7),
            ]
          : [
              color.withOpacity(0.9 + 0.1 * immersionLevel),
              color.withOpacity(0.7 + 0.1 * immersionLevel),
              color.withOpacity(0.5 + 0.1 * immersionLevel),
            ],
      stops: const [0.0, 0.6, 1.0],
    );
    
    final starPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: size),
      );
    
    canvas.drawPath(path, starPaint);
    
    // Draw highlight for selected stars
    if (isSelected) {
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawPath(path, highlightPaint);
    }
  }

  int _stringToHash(String str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash;
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
          fontSize: max(6, size * 0.6),
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

  void _drawContactName(Canvas canvas, Offset position, String name, double size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              blurRadius: 4,
              color: Colors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      position.translate(-textPainter.width / 2, -size - 20),
    );
  }

  void _drawCosmicBackground(Canvas canvas, Size size, double immersionLevel) {
    // Base background
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Color.lerp(Color(0xFF1A1F38), Color(0xFF0A0E21), immersionLevel)!,
          Color.lerp(Color(0xFF0A0E21), Colors.black, immersionLevel)!,
          Colors.black,
        ],
        stops: [0.0, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Draw stars with varying density based on immersion
    final random = Random(42);
    final starCount = (150 * (1 + immersionLevel)).toInt();
    
    for (int i = 0; i < starCount; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height);
      final radius = random.nextDouble() * (1.2 + immersionLevel);
      final opacity = random.nextDouble() * (0.5 + 0.3 * immersionLevel);
      
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(opacity);
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _drawRing(Canvas canvas, Offset center, double innerRadius, double outerRadius, Color color) {
    final gradient = RadialGradient(
      colors: [
        color.withOpacity(0.3),
        color.withOpacity(0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: outerRadius),
      )
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, outerRadius, paint);
    
    // Ring outlines
    final outlinePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawCircle(center, innerRadius, outlinePaint);
    canvas.drawCircle(center, outerRadius, outlinePaint);
  }

  void _drawCentralUser(Canvas canvas, Offset center, double immersionLevel) {
    // Core glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Color(0xFF5CDEE5).withOpacity(0.7),
          Color(0xFF2D85F6).withOpacity(0.5),
          Colors.transparent,
        ],
        stops: [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 20 + 10 * immersionLevel))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(center, 20 + 10 * immersionLevel, glowPaint);
    
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
    
    // YOU text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10 + 2 * immersionLevel,
          fontWeight: FontWeight.bold,
          shadows: const [
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
    textPainter.paint(canvas, center.translate(-12, 18));
  }

  void _drawVIPCrown(Canvas canvas, Offset position, double size) {
    final crownPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      ).createShader(Rect.fromCircle(center: position, radius: size * 0.4));
    
    final crownPath = Path()
      ..moveTo(position.dx - size * 0.3, position.dy - size * 0.5)
      ..lineTo(position.dx, position.dy - size * 0.9)
      ..lineTo(position.dx + size * 0.3, position.dy - size * 0.5)
      ..close();
    
    canvas.drawPath(crownPath, crownPaint);
  }

  void _drawConnections(Canvas canvas, Offset center, double maxRadius) {
    final connectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    // Draw connections between VIP contacts and center
    for (final contact in contacts.where((c) => c.isVIP)) {
      final hash = _stringToHash(contact.id);
      final contactAngle = contact.angleDeg != 0 
          ? contact.angleDeg * (pi / 180)
          : (hash % 360) * (pi / 180);
      
      final ringRadius = _getContactRingRadius(contact) * maxRadius;
      final contactX = center.dx + ringRadius * cos(contactAngle);
      final contactY = center.dy + ringRadius * sin(contactAngle);
      final contactPos = Offset(contactX, contactY);
      
      // Draw connection line to center
      canvas.drawLine(center, contactPos, connectionPaint);
    }
  }

  double _getContactRingRadius(Contact contact) {
    switch (contact.computedRing) {
      case 'inner':
        return 0.275;
      case 'middle':
        return 0.575;
      case 'outer':
        return 0.875;
      default:
        return 0.575;
    }
  }

  @override
  bool shouldRepaint(covariant UniversePainter oldDelegate) {
    return oldDelegate.contacts != contacts ||
           oldDelegate.selectedContact != selectedContact ||
           oldDelegate.isImmersive != isImmersive ||
           oldDelegate.immersionLevel != immersionLevel ||
           oldDelegate.hoveredContactId != hoveredContactId;
  }
}
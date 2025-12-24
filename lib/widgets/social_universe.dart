// lib/widgets/social_universe.dart - UPDATED WITH FIXES
import 'package:flutter/material.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/social_universe_guide.dart';
import 'dart:math';
import '../models/contact.dart';
// import '../services/social_universe_service.dart';

class SocialUniverseWidget extends StatefulWidget {
  final List<Contact> contacts;
  final Function(Contact) onContactView;
  final double height;
  final bool isImmersive;
  final VoidCallback? onExitImmersive;
  final VoidCallback? onFullScreenPressed;
  
  const SocialUniverseWidget({
    Key? key,
    required this.contacts,
    required this.onContactView,
    this.height = 400,
    this.isImmersive = false,
    this.onExitImmersive,
    this.onFullScreenPressed,
  }) : super(key: key);

  @override
  State<SocialUniverseWidget> createState() => _SocialUniverseWidgetState();
}

class _SocialUniverseWidgetState extends State<SocialUniverseWidget> 
    with SingleTickerProviderStateMixin {
  Contact? _selectedContact;
  bool _showControls = true;
  double _immersionLevel = 0.5;
  
  // FIX: Improved slider value tracking
  double _sliderValue = 0.5;
  
  // FIX: Add star position tracking for accurate taps
  final Map<String, Offset> _starPositions = {};
  final Map<String, double> _starSizes = {};
  
  // Rotation animation controller
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize rotation animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_rotationController);
    
    // Initialize slider value
    _sliderValue = _immersionLevel;
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

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
          // Main content with fixed size for universe
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
                            'Tap stars to view details',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      // Fullscreen button
                      GestureDetector(
                        onTap: widget.onFullScreenPressed,
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
                  
                  // Universe area - FIXED SIZE
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = min(constraints.maxWidth, constraints.maxHeight);
                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: GestureDetector(
                              onTapDown: (details) {
                                _handleUniverseTap(details.localPosition, Size(size, size));
                              },
                              child: AnimatedBuilder(
                                animation: _rotationAnimation,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: UniversePainter(
                                      contacts: widget.contacts,
                                      selectedContact: _selectedContact,
                                      isImmersive: false,
                                      immersionLevel: 1.0,
                                      rotation: _rotationAnimation.value,
                                      // FIX: Add callback to track star positions
                                      onStarDrawn: (contactId, position, starSize) {
                                        if (mounted) {
                                          _starPositions[contactId] = position;
                                          _starSizes[contactId] = starSize;
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildLegendRow(),
                ],
              ),
            ),
          ),
          
          // Contact preview card - Overlay at bottom
          if (_selectedContact != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildCompactContactCard(_selectedContact!),
            ),
        ],
      ),
    );
  }

  void _showSocialUniverseGuide(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SocialUniverseGuide(
          onClose: () {
            Navigator.pop(context);
          },
        ),
      );
    },
  );
}

  Widget _buildImmersiveView() {
    return Scaffold(
      backgroundColor: Colors.black,
       floatingActionButton: Padding(
                padding: EdgeInsets.only(
                  bottom: 30.0,
                  right: 6.0,
                ),
                child: FeedbackFloatingButton(
                  currentSection: 'social-universe',
                 ),
              ),
      body: Stack(
        children: [
          // Universe takes the entire screen with rotation
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                final screenSize = MediaQuery.of(context).size;
                _handleUniverseTap(details.localPosition, screenSize);
              },
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: UniversePainter(
                      contacts: widget.contacts,
                      selectedContact: _selectedContact,
                      isImmersive: true,
                      immersionLevel: _immersionLevel,
                      rotation: _rotationAnimation.value,
                      // FIX: Add callback to track star positions
                      onStarDrawn: (contactId, position, starSize) {
                        if (mounted) {
                          _starPositions[contactId] = position;
                          _starSizes[contactId] = starSize;
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Top controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () {
                              if (widget.onExitImmersive != null) {
                                widget.onExitImmersive!();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          
                          // Center title
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'IMMERSIVE UNIVERSE',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A9DFF),
                                      letterSpacing: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Explore your ${widget.contacts.length} connections',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Info button
                          GestureDetector(
                            onTap: () {
                              _showSocialUniverseGuide(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Visual intensity controls - FIXED: Proper value tracking
          if (_showControls && _selectedContact == null)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 18,
                          color: Color(0xFF5CDEE5),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Visual Intensity',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.visibility,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.remove,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: _sliderValue, // FIX: Use tracked slider value
                            min: 0.5,
                            max: 1.0,
                            divisions: 5,
                            activeColor: const Color(0xFF5CDEE5),
                            inactiveColor: Colors.white24,
                            onChanged: (value) {
                              setState(() {
                                _sliderValue = value; // FIX: Update slider value
                                _immersionLevel = value; // Update immersion level
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.add,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5CDEE5).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(_sliderValue * 100).toInt()}%', // FIX: Use slider value
                            style: const TextStyle(
                              color: Color(0xFF5CDEE5),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adjust the visual depth of your social connections',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Hint for showing controls
          if (!_showControls)
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Show Controls',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Selected contact card at bottom
          if (_selectedContact != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.95),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildImmersiveContactCard(_selectedContact!),
                  ),
                ),
              ),
            ),
          
          // Visual intensity controls when contact is selected
          if (_showControls && _selectedContact != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  _showIntensityDialog(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5CDEE5).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: Color(0xFF5CDEE5),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Intensity',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
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

  void _showIntensityDialog(BuildContext context) {
    // FIX: Local variable for dialog state
    double tempSliderValue = _sliderValue;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visual Intensity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Adjust the visual depth of your social universe',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(
                          Icons.remove,
                          color: Colors.white70,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Slider(
                            value: tempSliderValue,
                            min: 0.5,
                            max: 1.0,
                            divisions: 5,
                            activeColor: const Color(0xFF5CDEE5),
                            inactiveColor: Colors.white24,
                            onChanged: (value) {
                              setState(() {
                                tempSliderValue = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.add,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5CDEE5).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current: ${(tempSliderValue * 100).toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFF5CDEE5),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _sliderValue = tempSliderValue;
                              _immersionLevel = tempSliderValue;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'APPLY',
                            style: TextStyle(
                              color: Color(0xFF5CDEE5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // FIX: Improved tap detection using stored star positions
  void _handleUniverseTap(Offset tapPosition, Size size) {
    // Clear previous positions if universe size changed
    if (_starPositions.isNotEmpty) {
      // Check if we need to recalc positions (e.g., after rotation)
      // For now, we'll use the current positions
    }
    
    String? tappedContactId;
    double closestDistance = double.infinity;
    
    // Check each star's position
    for (final entry in _starPositions.entries) {
      final contactId = entry.key;
      final starPosition = entry.value;
      
      // Calculate distance from tap to star center
      final distance = (tapPosition - starPosition).distance;
      
      // Get star size with a generous tap area (2x visual size)
      final starSize = _starSizes[contactId] ?? 10.0;
      final tapRadius = starSize * 2.0;
      
      if (distance < tapRadius && distance < closestDistance) {
        closestDistance = distance;
        tappedContactId = contactId;
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

  Widget _buildCompactContactCard(Contact contact) {
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getTimeAgoText(daysAgo);
    final ringColor = _getRingColor(contact.computedRing);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ringColor.withOpacity(0.3),
            ringColor.withOpacity(0.1),
            Colors.black.withOpacity(0.8),
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
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
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
          
          GestureDetector(
            onTap: () {
              widget.onContactView(contact);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  fontSize: 12,
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
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Contact header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Contact name with proper wrapping
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Contact tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                          mainAxisSize: MainAxisSize.min,
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.category,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                contact.connectionType,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (contact.isVIP)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFD700),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'VIP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Contact info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Last contact: $lastContactText',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  widget.onContactView(contact);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5CDEE5).withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            
            const SizedBox(width: 12),
            
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedContact = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ],
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
  final double rotation;
  final Function(String contactId, Offset position, double size)? onStarDrawn; // FIX: Add callback
  
  UniversePainter({
    required this.contacts,
    required this.selectedContact,
    required this.isImmersive,
    required this.immersionLevel,
    required this.rotation,
    this.onStarDrawn, // FIX: Add callback parameter
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width / 2, size.height / 2) * 0.9;
    
    // Draw cosmic background
    _drawCosmicBackground(canvas, size, immersionLevel);
    
    // Draw rings with varying opacity based on immersion
    _drawRing(
      canvas,
      center,
      maxRadius * 0.15,
      maxRadius * 0.40,
      Colors.green.withOpacity(0.1 + 0.3 * immersionLevel),
    );
    _drawRing(
      canvas,
      center,
      maxRadius * 0.45,
      maxRadius * 0.70,
      Color(0xFFFFC107).withOpacity(0.1 + 0.3 * immersionLevel),
    );
    _drawRing(
      canvas,
      center,
      maxRadius * 0.75,
      maxRadius,
      Colors.redAccent.withOpacity(0.1 + 0.3 * immersionLevel),
    );
    
    // Draw central user
    _drawCentralUser(canvas, center, immersionLevel);
    
    // Draw all stars with rotation
    for (final contact in contacts) {
      final starInfo = _drawStar(canvas, center, contact, maxRadius, size);
      
      // FIX: Report star position back to widget
      if (onStarDrawn != null && starInfo != null) {
        onStarDrawn!(contact.id, starInfo.position, starInfo.size);
      }
    }
    
    // Draw connections for immersive mode
    if (isImmersive && immersionLevel > 0.7) {
      _drawConnections(canvas, center, maxRadius);
    }
  }

  StarInfo? _drawStar(Canvas canvas, Offset center, Contact contact, double maxRadius, Size size) {
    final isSelected = selectedContact?.id == contact.id;
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
    
    // Use the contact's angle or generate one, then ADD ROTATION
    final contactAngle = contact.angleDeg != 0 
        ? contact.angleDeg * (pi / 180)
        : (hash % 360) * (pi / 180);
    
    // Apply rotation to the angle
    final angle = contactAngle + rotation;
    
    final x = center.dx + spreadRadius * cos(angle);
    final y = center.dy + spreadRadius * sin(angle);
    final position = Offset(x, y);
    
    // Visual size based on selection and VIP status
    double baseSize = isImmersive ? 14.0 : 8.0;
    baseSize *= (1 + 0.5 * immersionLevel);
    
    if (isVIP) baseSize *= 1.3;
    if (isSelected) baseSize *= 2.0;
    
    final visualSize = baseSize;
    
    // Make VIP stars gold
    if (isVIP) {
      color = const Color(0xFFFFD700);
    }
    
    // Draw star glow
    final glowOpacity = isSelected ? 0.7 : 0.3 * immersionLevel;
    final glowPaint = Paint()
      ..color = color.withOpacity(glowOpacity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        visualSize * (1 + immersionLevel),
      );
    
    canvas.drawCircle(position, visualSize * 2.0, glowPaint);
    
    // Draw star shape
    _drawStarShape(canvas, position, visualSize, color, isSelected);
    
    // Draw VIP crown for VIP stars
    if (isVIP && isSelected) {
      _drawVIPCrown(canvas, position, visualSize);
    }
    
    // Return star info for tap detection
    return StarInfo(position: position, size: visualSize);
  }

  void _drawStarShape(Canvas canvas, Offset center, double size, Color color, bool isSelected) {
    // Create a 6-point star for better visual appeal
    const numberOfPoints = 6;
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
    
    // Draw star body with gradient
    final gradient = RadialGradient(
      center: Alignment.center,
      colors: isSelected
          ? [color, color.withOpacity(0.9), color.withOpacity(0.7)]
          : [color.withOpacity(0.9), color.withOpacity(0.7), color.withOpacity(0.5)],
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
      
      // Draw orbiting particles for selected stars
      final time = DateTime.now().millisecondsSinceEpoch / 1000;
      final particleCount = 6;
      for (int i = 0; i < particleCount; i++) {
        final particleAngle = (i * 2 * pi / particleCount) + time * 2;
        final particleRadius = size * 2.5;
        final particleX = center.dx + particleRadius * cos(particleAngle);
        final particleY = center.dy + particleRadius * sin(particleAngle);
        
        final particlePaint = Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        
        canvas.drawCircle(Offset(particleX, particleY), 2.0, particlePaint);
      }
    }
  }

  int _stringToHash(String str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash;
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
    
    // Draw stars
    final random = Random(42);
    final starCount = (150 * (1 + immersionLevel)).toInt();
    
    for (int i = 0; i < starCount; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height);
      final radius = random.nextDouble() * (1.5 + immersionLevel);
      final opacity = random.nextDouble() * (0.6 + 0.4 * immersionLevel);
      
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(opacity);
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _drawRing(Canvas canvas, Offset center, double innerRadius, double outerRadius, Color color) {
    // Ring gradient
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
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulse = (sin(time * 2) + 1) / 2;
    
    // Core glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Color(0xFF5CDEE5).withOpacity(0.8),
          Color(0xFF2D85F6).withOpacity(0.6),
          Colors.transparent,
        ],
        stops: [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 25 + pulse * 5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    
    canvas.drawCircle(center, 25 + pulse * 5, glowPaint);
    
    // Central sphere
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: const [
          Color(0xFF5CDEE5),
          Color(0xFF2D85F6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 15));
    
    canvas.drawCircle(center, 15, spherePaint);
    
    // "YOU" text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
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
    textPainter.paint(canvas, center.translate(-15, 22));
  }

  void _drawVIPCrown(Canvas canvas, Offset position, double size) {
    final crownPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      ).createShader(Rect.fromCircle(center: position, radius: size * 0.5));
    
    final crownPath = Path()
      ..moveTo(position.dx - size * 0.4, position.dy - size * 0.6)
      ..lineTo(position.dx, position.dy - size * 1.0)
      ..lineTo(position.dx + size * 0.4, position.dy - size * 0.6)
      ..close();
    
    canvas.drawPath(crownPath, crownPaint);
  }

  void _drawConnections(Canvas canvas, Offset center, double maxRadius) {
    final connectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
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
           oldDelegate.rotation != rotation;
  }
}

// FIX: Helper class to return star information
class StarInfo {
  final Offset position;
  final double size;
  
  StarInfo({
    required this.position,
    required this.size,
  });
}
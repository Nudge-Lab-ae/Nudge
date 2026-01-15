// social_universe.dart - Fixed for performance while keeping animations and visual effects
import 'package:flutter/material.dart';
import 'package:nudge/test/mock_data_generator.dart';
import 'package:nudge/widgets/social_universe_guide.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/contact.dart';

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
  double _immersionLevel = 1.0;
  
  double _sliderValue = 1.0;
  final Map<String, Offset> _starPositions = {};
  final Map<String, double> _starSizes = {};
  
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  bool _useMockData = false;
  List<Contact> _mockContacts = [];
  late List<Contact> _displayContacts;

  @override
  void initState() {
    super.initState();
    
    _mockContacts = MockContactsGenerator.generateMockContacts(count: 50);
    MockContactsGenerator.printDistribution(_mockContacts);
    
    _displayContacts = widget.contacts;
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_rotationController);
    
    _sliderValue = _immersionLevel;
    Future.delayed(const Duration(seconds: 1)).then((value){
      setState(() {
        _displayContacts = widget.contacts;
      });
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (widget.isImmersive) {
      return _buildImmersiveView(themeProvider);
    } else {
      return _buildCompactView(themeProvider);
    }
  }

  void _toggleMockData() {
    setState(() {
      _useMockData = !_useMockData;
      _displayContacts = _useMockData ? _mockContacts : widget.contacts;
      _selectedContact = null;
      
      _starPositions.clear();
      _starSizes.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useMockData 
            ? 'Using mock data (${_displayContacts.length} contacts)' 
            : 'Using real data (${_displayContacts.length} contacts)'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Widget _buildCompactView(ThemeProvider themeProvider) {
    final isDarkMode = themeProvider.isDarkMode;
    
    return Container(
      height: widget.height,
      width: double.infinity, // Take full width available
      margin: const EdgeInsets.symmetric(horizontal: 0), // Remove side margins
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDarkMode 
          ? AppTheme.darkUniverseBackground 
          : const Color(0xFFE3F2FD), // LIGHT BLUE container for light mode
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.5 : 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with theme-specific styling
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                        ? Colors.black.withOpacity(0.4) 
                        : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDarkMode 
                          ? Colors.white24 
                          : const Color(0xFF2196F3).withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'SOCIAL UNIVERSE',
                                    style: TextStyle(
                                      fontSize: 16, // Slightly larger
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode 
                                        ? AppTheme.darkUniversePrimary 
                                        : const Color(0xFF1565C0), // Dark blue for light mode
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_useMockData)
                                    GestureDetector(
                                      onTap: _toggleMockData,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.orange),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.psychology, size: 12, color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text(
                                              'TEST MODE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap stars to view details • ${_useMockData ? 'Click TEST MODE to return to real data' : 'Double-tap to test with mock data'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode 
                                    ? Colors.white54 
                                    : const Color(0xFF546E7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onFullScreenPressed,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                ? Colors.white.withOpacity(0.1) 
                                : const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode 
                                  ? Colors.white24 
                                  : const Color(0xFF2196F3).withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.fullscreen,
                              size: 22,
                              color: isDarkMode 
                                ? Colors.white70 
                                : const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // MAIN UNIVERSE DISPLAY - Takes most space
                  Expanded(
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          // Different backgrounds for light/dark mode
                          gradient: isDarkMode 
                            ? RadialGradient(
                                center: Alignment.center,
                                colors: [
                                  const Color(0xFF1A237E).withOpacity(0.8),
                                  const Color(0xFF0D47A1).withOpacity(0.9),
                                  const Color(0xFF01579B),
                                ],
                                radius: 1.5,
                              )
                            : RadialGradient(
                                center: Alignment.center,
                                colors: [
                                  const Color(0xFF64B5F6).withOpacity(0.9),
                                  const Color(0xFF42A5F5).withOpacity(0.95),
                                  const Color(0xFF2196F3),
                                ],
                                radius: 1.2,
                              ),
                        ),
                        child: RepaintBoundary(
                          child: GestureDetector(
                            onDoubleTap: _toggleMockData,
                            onTapDown: (details) {
                              final containerSize = Size(widget.height, widget.height);
                              _handleUniverseTap(details.localPosition, containerSize);
                            },
                            child: AnimatedBuilder(
                              animation: _rotationAnimation,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: UniversePainter(
                                    contacts: _displayContacts,
                                    selectedContact: _selectedContact,
                                    isImmersive: false,
                                    immersionLevel: 0.5,
                                    rotation: _rotationAnimation.value,
                                    onStarDrawn: (contactId, position, starSize) {
                                      if (mounted) {
                                        _starPositions[contactId] = position;
                                        _starSizes[contactId] = starSize;
                                      }
                                    },
                                    isDarkMode: isDarkMode,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Legend - theme specific
                  _buildLegendRow(isDarkMode),
                ],
              ),
            ),
          ),
          
          if (_selectedContact != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildCompactContactCard(_selectedContact!, isDarkMode, themeProvider),
            ),
        ],
      ),
    );
  }
    
  void _showSocialUniverseGuide(ThemeProvider themeProvider) {
    final isDarkMode = themeProvider.isDarkMode;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SocialUniverseGuide(
            onClose: () {
              Navigator.pop(context);
            },
            isDarkMode: isDarkMode,
          ),
        );
      },
    );
  }

  Widget _buildImmersiveView(ThemeProvider themeProvider) {
    final isDarkMode = themeProvider.isDarkMode;
    var size = MediaQuery.of(context).size;
    
    return Container(
      color: isDarkMode ? Colors.black : const Color(0xFFC2D9F7),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GestureDetector(
                onDoubleTap: widget.isImmersive ? _toggleMockData : null,
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
                        contacts: _displayContacts,
                        selectedContact: _selectedContact,
                        isImmersive: true,
                        immersionLevel: _immersionLevel,
                        rotation: _rotationAnimation.value,
                        onStarDrawn: (contactId, position, starSize) {
                          if (mounted) {
                            _starPositions[contactId] = position;
                            _starSizes[contactId] = starSize;
                          }
                        },
                        isDarkMode: isDarkMode,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _showControls ? -10 : -100,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                    ? [
                        Colors.black.withOpacity(0.95),
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFC2D9F7).withOpacity(0.95),
                        const Color(0xFFC2D9F7).withOpacity(0.7),
                        Colors.transparent,
                      ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Update header background for better contrast
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? Colors.black.withOpacity(0.5) 
                            : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode 
                              ? Colors.white24 
                              : const Color(0xFF3B82F6).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Social Universe',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Explore your ${_displayContacts.length} connections${_useMockData ? ' (TEST MODE)' : ''}',
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white70 : Colors.black,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_useMockData)
                                      const SizedBox(height: 4),
                                    if (_useMockData)
                                      GestureDetector(
                                        onTap: _toggleMockData,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.orange),
                                          ),
                                          child: Text(
                                            'Click to return to real data',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            
                            GestureDetector(
                              onTap: () {
                                _showSocialUniverseGuide(themeProvider);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.white.withOpacity(0.15) : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDarkMode ? Colors.white30 : Colors.blue.shade200),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (_showControls && _selectedContact == null)
            Positioned(
              bottom: 90,
              right: 20,
              child: Container(
                width: size.width*0.85,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDarkMode ? Colors.white24 : Colors.blue.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkMode ? 0.5 : 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 18,
                          color: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Visual Intensity',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.blue.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: (){
                            setState(() {
                              _showControls = false;
                            });
                          },
                          child: Icon(
                          Icons.visibility,
                          size: 18,
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade600,
                        ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: (){
                            if (_sliderValue > 0.55){
                              setState(() {
                                 _sliderValue -= 0.1;
                                 _immersionLevel -= 0.1;
                              });
                              print('decreased ${_sliderValue}');
                            }
                          },
                          child: Icon(
                          Icons.remove,
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade600,
                          size: 22,
                        ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: _sliderValue,
                            min: 0.5,
                            max: 1.0,
                            divisions: 5,
                            activeColor: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
                            inactiveColor: isDarkMode ? Colors.white24 : Colors.blue.shade100,
                            onChanged: (value) {
                              setState(() {
                                _sliderValue = value;
                                _immersionLevel = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: (){
                            if (_sliderValue <1.0){
                              setState(() {
                                  _sliderValue += 0.1;
                                  _immersionLevel += 0.1;
                              });
                              print('added');
                            }
                          },
                          child: Icon(
                          Icons.add,
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade600,
                          size: 22,
                        )),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: (isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(_sliderValue * 100).toInt()}%',
                            style: TextStyle(
                              color: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust the visual depth of your social connections',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.blueGrey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
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
                    color: isDarkMode ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Show Controls',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          if (_selectedContact != null)
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                decoration: BoxDecoration(
                  // gradient: LinearGradient(
                  //   begin: Alignment.topCenter,
                  //   end: Alignment.bottomCenter,
                  //   colors: [
                  //     Colors.transparent,
                  //     isDarkMode ? Colors.black.withOpacity(0.95) : Colors.white.withOpacity(0.95),
                  //   ],
                  // ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildImmersiveContactCard(_selectedContact!, isDarkMode, themeProvider),
                  ),
                ),
              ),
            ),
          
          if (_showControls && _selectedContact != null)
            Positioned(
              bottom: 90,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  _showIntensityDialog(context, themeProvider);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDarkMode ? 0.5 : 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Intensity',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
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

  void _showIntensityDialog(BuildContext context, ThemeProvider themeProvider) {
    final isDarkMode = themeProvider.isDarkMode;
    double tempSliderValue = _sliderValue;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: isDarkMode ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visual Intensity',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.blue.shade900,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Adjust the visual depth of your social universe',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.blueGrey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: (){
                            if (tempSliderValue > 0.55){
                              setState(() {
                                 tempSliderValue -= 0.1;
                                //  _immersionLevel -= 0.1;
                              });
                              print('decreased ${_sliderValue}');
                            }
                          },
                          child: Icon(
                          Icons.remove,
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade600,
                          size: 22,
                        ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Slider(
                            value: tempSliderValue,
                            min: 0.5,
                            max: 1.0,
                            divisions: 5,
                            activeColor: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
                            inactiveColor: isDarkMode ? Colors.white24 : Colors.blue.shade100,
                            onChanged: (value) {
                              setState(() {
                                tempSliderValue = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: (){
                            if (tempSliderValue <1.0){
                              setState(() {
                                  tempSliderValue += 0.1;
                                  // _immersionLevel += 0.1;
                              });
                              print('added');
                            }
                          },
                          child: Icon(
                          Icons.add,
                          color: isDarkMode ? Colors.white70 : Colors.blue.shade600,
                          size: 22,
                        )),
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
                          color: (isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current: ${(tempSliderValue * 100).toInt()}%',
                          style: TextStyle(
                            color: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
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
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.blueGrey.shade600,
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
                          child: Text(
                            'APPLY',
                            style: TextStyle(
                              color: isDarkMode ? AppTheme.darkUniverseSecondary : AppTheme.lightUniversePrimary,
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

  void _handleUniverseTap(Offset tapPosition, Size size) {
    String? tappedContactId;
    double closestDistance = double.infinity;
    
    for (final entry in _starPositions.entries) {
      final contactId = entry.key;
      final starPosition = entry.value;
      
      final distance = (tapPosition - starPosition).distance;
      final starSize = _starSizes[contactId] ?? 10.0;
      
      // FIXED: Increased touch sensitivity - use adaptive touch radius
      final touchRadius = starSize * 2.5; // Increased sensitivity
      
      if (distance < touchRadius && distance < closestDistance) {
        closestDistance = distance;
        tappedContactId = contactId;
      }
    }
    
    if (tappedContactId != null) {
      final contact = _displayContacts.firstWhere(
        (c) => c.id == tappedContactId,
        orElse: () => _displayContacts.first,
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
    
  Widget _buildLegendRow(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? Colors.white.withOpacity(0.05) 
          : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
            ? Colors.white12 
            : const Color(0xFF2196F3).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Inner Circle', Colors.yellow, Icons.star, isDarkMode),
          _buildLegendItem('Middle Circle', const Color(0xff3CB3E9), Icons.circle, isDarkMode),
          _buildLegendItem('Outer Circle', const Color(0xff897ED6), Icons.circle_outlined, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon, bool isDarkMode) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
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
          child: Icon(
            icon,
            size: 8,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : const Color(0xFF37474F),
          ),
        ),
      ],
    );
  }
    
  void _showMockContactDetails(Contact contact, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final ringColor = _getRingColor(contact.computedRing);
    final daysSince = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getTimeAgoText(daysSince);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ringColor,
                    ringColor.withOpacity(0.3),
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
              child: Text(contact.name, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.95) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.orange),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a mock contact for testing Social Universe visualization',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              _buildDetailSection('Social Universe Positioning', [
                _buildDetailRow('Computed Ring', contact.computedRing.toUpperCase(), 
                  ringColor, isDarkMode),
                _buildDetailRow('CDI Score', '${contact.cdi.toStringAsFixed(1)}/100',
                  contact.cdi >= 80 ? Colors.green : 
                  contact.cdi >= 50 ? const Color(0xFFFFC107) : Colors.redAccent, isDarkMode),
                _buildDetailRow('Position Angle', '${contact.angleDeg.toStringAsFixed(1)}°',
                  isDarkMode ? Colors.white : Colors.black, isDarkMode),
                _buildDetailRow('VIP Status', contact.isVIP ? 'YES' : 'NO',
                  contact.isVIP ? const Color(0xFFFFD700) : Colors.grey, isDarkMode),
                _buildDetailRow('Raw Band', contact.rawBand.toUpperCase(),
                  isDarkMode ? Colors.white : Colors.black, isDarkMode),
                _buildDetailRow('Band Since', 
                  '${DateTime.now().difference(contact.rawBandSince).inDays} days',
                  isDarkMode ? Colors.white : Colors.black, isDarkMode),
              ], isDarkMode),
              
              const SizedBox(height: 16),
              
              _buildDetailSection('Contact Information', [
                _buildDetailRow('Connection Type', contact.connectionType, isDarkMode ? Colors.white : Colors.black, isDarkMode),
                _buildDetailRow('Period', contact.period, isDarkMode ? Colors.white : Colors.black, isDarkMode),
                _buildDetailRow('Frequency', '${contact.frequency}/period', isDarkMode ? Colors.white : Colors.black, isDarkMode),
                _buildDetailRow('Last Contacted', lastContactText, isDarkMode ? Colors.white : Colors.black, isDarkMode),
                _buildDetailRow('Interaction Count', 
                  '${contact.interactionCountInWindow} in last 90 days', isDarkMode ? Colors.white : Colors.black, isDarkMode),
              ], isDarkMode),
              
              const SizedBox(height: 16),
              
              if (contact.tags.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags:',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: contact.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CDI Interpretation:',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getCDIInterpretation(contact.cdi),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCDIInterpretation(double cdi) {
    if (cdi >= 80) {
      return 'Strong, active connection. In the Inner Circle with regular interactions.';
    } else if (cdi >= 50) {
      return 'Moderate connection. In the Middle Circle, could benefit from more frequent contact.';
    } else {
      return 'Weaker connection. In the Outer Circle, consider reconnecting soon.';
    }
  }

  Widget _buildCompactContactCard(Contact contact, bool isDarkMode, ThemeProvider themeProvider) {
    if (_useMockData && contact.id.startsWith('mock_')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.yellow.withOpacity(0.5),
              Colors.orange.withOpacity(0.3),
              isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
            ],
          ),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mock Contact - Test Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _getRingColor(contact.computedRing),
                        _getRingColor(contact.computedRing).withOpacity(0.5),
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
                            'CDI: ${contact.cdi.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${contact.computedRing.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                GestureDetector(
                  onTap: () {
                    if (_useMockData && contact.id.startsWith('mock_')) {
                      _showMockContactDetails(contact, themeProvider);
                    } else {
                      widget.onContactView(contact);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _useMockData && contact.id.startsWith('mock_') 
                          ? [Colors.orange, const Color(0xFFFF9800)]
                          : const [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      _useMockData && contact.id.startsWith('mock_') ? 'DETAILS' : 'VIEW',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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
            Colors.yellow.withOpacity(0.5),  // Yellow at top-left
            Colors.orange.withOpacity(0.3), 
            // isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
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
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
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
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Text(
                'VIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveContactCard(Contact contact, bool isDarkMode, ThemeProvider themeProvider) {
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getTimeAgoText(daysAgo);
    final ringColor = _getRingColor(contact.computedRing);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
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
                          color: isDarkMode ? Colors.white.withOpacity(0.15) : Colors.blue.shade50,
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
                          color: isDarkMode ? Colors.white.withOpacity(0.15) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category,
                              size: 14,
                              color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                contact.connectionType,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
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
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDarkMode ? Colors.white24 : Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: isDarkMode ? Colors.white54 : Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Last contact: $lastContactText',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_useMockData && contact.id.startsWith('mock_')) {
                    _showMockContactDetails(contact, themeProvider);
                  } else {
                    widget.onContactView(contact);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: _useMockData && contact.id.startsWith('mock_')
                        ? [Colors.orange, const Color(0xFFFF9800)]
                        : const [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_useMockData && contact.id.startsWith('mock_')
                          ? Colors.orange
                          : const Color(0xFF5CDEE5)
                        ).withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _useMockData && contact.id.startsWith('mock_') 
                          ? 'VIEW MOCK DETAILS' 
                          : 'VIEW DETAILS',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _useMockData && contact.id.startsWith('mock_')
                          ? Icons.info_outline
                          : Icons.arrow_forward,
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
                  color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? Colors.white30 : Colors.blue.shade200),
                ),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: isDarkMode ? Colors.white70 : Colors.blue.shade700,
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
        return Colors.yellow;
      case 'middle':
        return const Color(0xff3CB3E9);
      case 'outer':
        return const Color(0xff897ED6);
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
  final Function(String contactId, Offset position, double size)? onStarDrawn;
  final bool isDarkMode;
  
  // Performance optimization: Use pre-allocated Paint objects
  final Paint _backgroundPaint = Paint();
  final Paint _ringPaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _starPaint = Paint();
  final Random _random = Random(42);

  late final Map<String, int> _contactHashCache = {};
  late final Map<String, double> _contactSpreadOffsetCache = {};
  late final Map<String, double> _contactAngleCache = {};
  
  // Pre-calculate ring radii to avoid recalculating every frame
  late final double _innerInnerRadius;
  late final double _innerOuterRadius;
  late final double _middleInnerRadius;
  late final double _middleOuterRadius;
  late final double _outerInnerRadius;
  late final double _outerOuterRadius;
  
  UniversePainter({
    required this.contacts,
    required this.selectedContact,
    required this.isImmersive,
    required this.immersionLevel,
    required this.rotation,
    this.onStarDrawn,
    required this.isDarkMode,
  }) {
    // Pre-calculate ring radii once during construction
    // These are based on maxRadius which will be calculated in paint()
    // We'll store the ratios and multiply by actual maxRadius later
    _innerInnerRadius = 0.15;
    _innerOuterRadius = 0.35;
    _middleInnerRadius = 0.35;
    _middleOuterRadius = 0.55;
    _outerInnerRadius = 0.55;
    _outerOuterRadius = 0.80;
  }


  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width / 2, size.height / 2) * 1.3;
    
    // Draw cosmic background
    _drawCosmicBackground(canvas, size, immersionLevel, isDarkMode);
    
    // Draw rings with theme-specific colors
    _drawRing(
    canvas,
    center,
    maxRadius * 0.15,  // inner radius (not drawn, just for positioning)
    maxRadius * 0.35,  // outer radius (drawn as boundary)
    isDarkMode 
      ? Colors.yellow.withOpacity(0.15 + 0.3 * immersionLevel)
      : Colors.yellow.withOpacity(0.12 + 0.25 * immersionLevel),
    isDarkMode,
    true
  );

  // Middle Circle: radius 45-70% (only outer boundary at 70%)
  _drawRing(
    canvas,
    center,
    maxRadius * 0.35,  // inner radius (not drawn, just for positioning)
    maxRadius * 0.55,  // outer radius (drawn as boundary)
    isDarkMode 
      ? const Color(0xff3CB3E9).withOpacity(0.15 + 0.3 * immersionLevel)
      : const Color(0xff3CB3E9).withOpacity(0.12 + 0.25 * immersionLevel),
    isDarkMode,
    false
  );

  // NEW: Outer Circle: radius 75-100% (only outer boundary at 100%)
  _drawRing(
    canvas,
    center,
    maxRadius * 0.55,  // inner radius (not drawn, just for positioning)
    maxRadius * 0.75,   // outer radius (drawn as boundary) - fits container
    isDarkMode 
      ? const Color(0xff897ED6).withOpacity(0.15 + 0.3 * immersionLevel)
      : const Color(0xff897ED6).withOpacity(0.12 + 0.25 * immersionLevel),
    isDarkMode,
    false
  );
    
    // Draw central user with theme support
    _drawCentralUser(canvas, center, immersionLevel, isDarkMode);
    
    // Draw all stars with rotation
    for (final contact in contacts) {
      final starInfo = _drawStar(canvas, center, contact, maxRadius, size, isDarkMode);
      
      if (onStarDrawn != null && starInfo != null) {
        onStarDrawn!(contact.id, starInfo.position, starInfo.size);
      }
    }

    // _drawShootingStars(canvas, size, immersionLevel, isDarkMode);
  }

  StarInfo? _drawStar(Canvas canvas, Offset center, Contact contact, double maxRadius, Size size, bool isDarkMode) {
    final isSelected = selectedContact?.id == contact.id;
    final isVIP = contact.isVIP;
    
    // CACHE HASH CALCULATIONS
    int hash;
    if (_contactHashCache.containsKey(contact.id)) {
      hash = _contactHashCache[contact.id]!;
    } else {
      hash = _stringToHash(contact.id);
      _contactHashCache[contact.id] = hash;
    }
    
    // CACHE SPREAD OFFSET
    double spreadOffset;
    if (_contactSpreadOffsetCache.containsKey(contact.id)) {
      spreadOffset = _contactSpreadOffsetCache[contact.id]!;
    } else {
      spreadOffset = (hash.abs() % 35) / 100.0;
      _contactSpreadOffsetCache[contact.id] = spreadOffset;
    }
    
    // CACHE ANGLE
    double contactAngleRad;
    if (_contactAngleCache.containsKey(contact.id)) {
      contactAngleRad = _contactAngleCache[contact.id]!;
    } else {
      final contactAngleDeg = contact.angleDeg != 0 
          ? contact.angleDeg 
          : (hash % 360).toDouble();
      contactAngleRad = contactAngleDeg * (pi / 180);
      _contactAngleCache[contact.id] = contactAngleRad;
    }
    
    double innerRadius, outerRadius;
    Color color;
    
    switch (contact.computedRing) {
      case 'inner':
        innerRadius = maxRadius * _innerInnerRadius;
        outerRadius = maxRadius * _innerOuterRadius;
        color = Colors.yellow;
        break;
      case 'middle':
        innerRadius = maxRadius * _middleInnerRadius;
        outerRadius = maxRadius * _middleOuterRadius;
        color = const Color(0xff3CB3E9);
        break;
      case 'outer':
        innerRadius = maxRadius * _outerInnerRadius;
        outerRadius = maxRadius * _outerOuterRadius;
        color = const Color(0xff897ED6);
        break;
      default:
        innerRadius = maxRadius * _outerInnerRadius;
        outerRadius = maxRadius * _outerOuterRadius;
        color = Colors.grey;
    }
    
    final ringWidth = outerRadius - innerRadius;
    // Position stars within the middle 60% of each ring (20% to 80% of ring width)
    final spreadRadius = innerRadius + (ringWidth * (0.2 + spreadOffset * 0.6));
    
    final angle = contactAngleRad + rotation;
    
    final x = center.dx + spreadRadius * cos(angle);
    final y = center.dy + spreadRadius * sin(angle);
    final position = Offset(x, y);
    
    // Base star size - SIMPLIFIED CALCULATION
    double baseSize = isImmersive ? 16.0 : 10.0;
    
    // Simplified size calculations without multiplication chain
    if (contact.computedRing == 'inner') {
      baseSize *= 1.2;
    } else {
      baseSize *= 0.8;
    }

    if (isVIP) baseSize *= 1.4;
    if (isSelected) baseSize *= 2.2;

    final visualSize = baseSize * (1 + 0.5 * immersionLevel);
    
    if (isVIP) {
      color = const Color(0xFFFFD700);
    }
    
    // OPTIMIZED: Use pre-allocated paint objects
    _drawStarCentralGlow(canvas, position, visualSize, color, immersionLevel, isDarkMode, isSelected);
    _drawStarShape(canvas, position, visualSize, color, isSelected, isDarkMode, immersionLevel);
    
    if (isVIP && isSelected) {
      _drawVIPCrown(canvas, position, visualSize);
    }
    
    return StarInfo(position: position, size: visualSize);
  }

  void _drawStarCentralGlow(Canvas canvas, Offset center, double size, Color color, double immersionLevel, bool isDarkMode, bool isSelected) {
    final centralGlowRadius = size * (0.4 + immersionLevel * 0.3);
    
    // Primary central glow - bright and intense
    final primaryGlowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withOpacity(0.9 + immersionLevel * 0.1),
          color.withOpacity(0.8 + immersionLevel * 0.2),
          color.withOpacity(0.4 + immersionLevel * 0.3),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: centralGlowRadius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * (0.4 + immersionLevel * 0.2));
    
    canvas.drawCircle(center, centralGlowRadius, primaryGlowPaint);
    
    // Secondary aura glow - softer
    final auraGlowPaint = Paint()
      ..color = color.withOpacity(0.3 + immersionLevel * 0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * (0.8 + immersionLevel * 0.4));
    
    canvas.drawCircle(center, centralGlowRadius * 1.8, auraGlowPaint);
    
    // White hot core for selected/VIP stars
    if (isSelected || immersionLevel > 0.7) {
      final hotCorePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(0.95),
            color.withOpacity(0.9),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: size * 0.4));
      
      canvas.drawCircle(center, size * 0.4, hotCorePaint);
    }
  }

  // MODIFIED: Remove top highlight from star shape
  void _drawStarShape(Canvas canvas, Offset center, double size, Color color, bool isSelected, bool isDarkMode, double immersionLevel) {
    const numberOfPoints = 5;
    final innerRadiusRatio = 0.45;
    final rotationOffset = -pi / 2;
    
    final points = <Offset>[];
    
    for (var i = 0; i < numberOfPoints * 2; i++) {
      final isEven = i.isEven;
      final pointRadius = isEven ? size : size * innerRadiusRatio;
      final pointAngle = (pi / numberOfPoints) * i + rotationOffset;
      
      points.add(Offset(
        center.dx + pointRadius * cos(pointAngle),
        center.dy + pointRadius * sin(pointAngle),
      ));
    }
    
    final path = Path()..addPolygon(points, true);
    
    // Star gradient - REMOVED TOP HIGHLIGHT
    final starPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withOpacity(0.8 + immersionLevel * 0.2),
          color.withOpacity(0.9 + immersionLevel * 0.1),
          color.withOpacity(0.6 + immersionLevel * 0.2),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: size),
      );
    
    canvas.drawPath(path, starPaint);
    
    // NO TOP HIGHLIGHT - Only central glow remains
    
    // Optional: Add subtle border for selected stars
    if (isSelected) {
      final borderPaint = Paint()
        ..color = isDarkMode
        ?Colors.white.withOpacity(0.5 + immersionLevel * 0.2)
        :Colors.black.withOpacity(0.5 + immersionLevel * 0.2) 
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + immersionLevel * 0.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0);
      
      canvas.drawPath(path, borderPaint);
    }

    if (!isDarkMode) {
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.5 + immersionLevel * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 + immersionLevel * 0.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0);
      
      canvas.drawPath(path, borderPaint);
    }

  }

  void _drawCosmicBackground(Canvas canvas, Size size, double immersionLevel, bool isDarkMode) {
    final clampedImmersionLevel = immersionLevel.clamp(0.0, 1.0);
    
    if (isDarkMode) {
      // DARK MODE: Deep space with bright stars
      _backgroundPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color.fromARGB(255, 3, 4, 10),
            const Color.fromARGB(255, 13, 16, 29),
            const Color.fromARGB(255, 20, 23, 36),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _backgroundPaint);
      
      // Add some nebula effects for dark mode
      // _drawNebula(canvas, size, clampedImmersionLevel, true);
      
    } else {
      // LIGHT MODE: VIVID BLUE COSMOS
      _backgroundPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color.fromARGB(255, 61, 96, 162), // Bright blue center
            const Color.fromARGB(255, 17, 61, 108), // Medium blue
            const Color(0xFF0288D1), // Deep blue
            const Color.fromARGB(255, 35, 139, 195),  
            const Color.fromARGB(255, 117, 179, 227), // Dark blue edges
          ],
          stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _backgroundPaint);
      
      // Add some light mode nebula/cloud effects
      _drawNebula(canvas, size, clampedImmersionLevel, false);
    }
    
    // Draw background stars with CLEAR DIFFERENCE between modes
    _drawBackgroundStars(canvas, size, clampedImmersionLevel, isDarkMode);
  }

  void _drawNebula(Canvas canvas, Size size, double immersionLevel, bool isDarkMode) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Create 2-3 nebula clouds
    final nebulaCount = 2 + (immersionLevel * 2).toInt();
    
    for (int n = 0; n < nebulaCount; n++) {
      final nebulaX = center.dx + (_random.nextDouble() - 0.5) * size.width * 0.6;
      final nebulaY = center.dy + (_random.nextDouble() - 0.5) * size.height * 0.6;
      final nebulaRadius = size.width * (0.15 + _random.nextDouble() * 0.25);
      
      if (isDarkMode) {
        // Dark mode nebula - purples and blues
        _ringPaint
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [
              const Color.fromARGB(255, 38, 23, 78).withOpacity(0.25 + immersionLevel * 0.03),
              const Color.fromARGB(255, 21, 27, 65).withOpacity(0.23 + immersionLevel * 0.02),
              const Color.fromARGB(255, 36, 62, 105).withOpacity(0.22 + immersionLevel * 0.01),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset(nebulaX, nebulaY),
            radius: nebulaRadius,
          ))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, nebulaRadius * 0.7);
        
        canvas.drawCircle(Offset(nebulaX, nebulaY), nebulaRadius, _ringPaint);
      } else {
        // Light mode clouds - light blues and cyans
        _ringPaint
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [
              const Color(0xFF80DEEA).withOpacity(0.08 + immersionLevel * 0.04),
              const Color(0xFF4DD0E1).withOpacity(0.05 + immersionLevel * 0.03),
              const Color(0xFF26C6DA).withOpacity(0.03 + immersionLevel * 0.02),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset(nebulaX, nebulaY),
            radius: nebulaRadius,
          ))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, nebulaRadius * 0.9);
        
        canvas.drawCircle(Offset(nebulaX, nebulaY), nebulaRadius, _ringPaint);
      }
    }
  }

  void _drawBackgroundStars(Canvas canvas, Size size, double immersionLevel, bool isDarkMode) {
      // Increased star count for more vividness without blur
      final baseStarCount = isDarkMode ? 150 : 90; // More stars
      final starCount = (baseStarCount * (0.5 + immersionLevel * 1.2)).toInt();
      
      for (int i = 0; i < starCount; i++) {
        final x = (_random.nextDouble() * size.width);
        final y = (_random.nextDouble() * size.height);
        final starBrightness = _random.nextDouble();
        
        // Star size - keep them small and sharp
        final baseRadius = isDarkMode ? 0.5 : 0.4;
        final radius = baseRadius + starBrightness * 0.4 + (immersionLevel * 0.2);
        
        if (isDarkMode) {
          // DARK MODE STARS: Sharp and bright
          final opacity = (0.5 + starBrightness * 0.4) * (0.6 + immersionLevel * 0.5);
          _starPaint
            ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
            ..maskFilter = null; // No blur for sharp stars
          
          canvas.drawCircle(Offset(x, y), radius, _starPaint);
          
        } else {
          // LIGHT MODE STARS: Sharp and clean
          final opacity = (0.6 + starBrightness * 0.4) * (0.8 + immersionLevel * 0.1);
          _starPaint
            ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
            ..maskFilter = null; // No blur for sharp stars
          
          canvas.drawCircle(Offset(x, y), radius, _starPaint);
        }
      }
    }
  
  void _drawCentralUser(Canvas canvas, Offset center, double immersionLevel, bool isDarkMode) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulse = (sin(time * 2) + 1) / 2;
    
    if (isDarkMode) {
      // DARK MODE central user: Gold/Yellow
      _glowPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color.fromARGB(255, 225, 255, 0).withOpacity(0.9),
            const Color.fromARGB(255, 238, 255, 0).withOpacity(0.7),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 30 + pulse * 8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      
      canvas.drawCircle(center, 30 + pulse * 8, _glowPaint);
      
      // Central sphere
      _starPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: const [Color.fromARGB(255, 234, 255, 0), Color.fromARGB(255, 242, 255, 0)],
        ).createShader(Rect.fromCircle(center: center, radius: 18));
      
      canvas.drawCircle(center, 18, _starPaint);
      
    } else {
      // LIGHT MODE central user: Bright Cyan/Blue
      _glowPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color(0xFFFFD600).withOpacity(0.9),
            const Color.fromARGB(255, 221, 255, 0).withOpacity(0.7),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 28 + pulse * 6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      
      canvas.drawCircle(center, 28 + pulse * 6, _glowPaint);
      
      // Central sphere
      _starPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: const [Color.fromARGB(255, 255, 251, 0), Color.fromARGB(255, 221, 255, 0)],
        ).createShader(Rect.fromCircle(center: center, radius: 16));
      
      canvas.drawCircle(center, 16, _starPaint);
    }
    
    // "YOU" text - theme specific
    final textColor = isDarkMode ? Colors.white : Colors.white;
    final shadowColor = isDarkMode ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.5);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 6,
              color: shadowColor,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, center.translate(-18, 26));
  }

  int _stringToHash(String str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash;
  }

  void _drawRing(Canvas canvas, Offset center, double innerRadius, double outerRadius, Color color, bool isDarkMode, bool isInnerRing) {
    // Make ALL borders thicker and more vivid
    final borderWidth = isDarkMode ? (1.5 + immersionLevel * 1.0) : (2.5 + immersionLevel * 1.5);
    final ringOpacity = immersionLevel * 0.3; // Rings get more visible with immersion
    
    if (isInnerRing) {
      // Inner ring - only draw the outer circle
      _ringPaint
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.4 + ringOpacity),
            color.withOpacity(0.25 + ringOpacity * 0.8),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: outerRadius),
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, outerRadius, _ringPaint);
      
      _glowPaint
        ..color = color.withOpacity((isDarkMode ? 0.45 : 0.6) + ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      
      // ONLY draw the outer circle, not the inner one
      canvas.drawCircle(center, outerRadius, _glowPaint);
      
    } else {
      // Middle/Outer ring - only draw the outer circle
      _ringPaint
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.3 + ringOpacity * 0.8),
            color.withOpacity(0.15 + ringOpacity * 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: outerRadius),
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, outerRadius, _ringPaint);
      
      _glowPaint
        ..color = color.withOpacity((isDarkMode ? 0.15 : 0.25) + ringOpacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth * 0.9;
      
      // ONLY draw the outer circle, not the inner one
      canvas.drawCircle(center, outerRadius, _glowPaint);
    }
  }
  
  void _drawVIPCrown(Canvas canvas, Offset position, double size) {
    _starPaint
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      ).createShader(Rect.fromCircle(center: position, radius: size * 0.5));
    
    final crownPath = Path()
      ..moveTo(position.dx - size * 0.4, position.dy - size * 0.6)
      ..lineTo(position.dx, position.dy - size * 1.0)
      ..lineTo(position.dx + size * 0.4, position.dy - size * 0.6)
      ..close();
    
    canvas.drawPath(crownPath, _starPaint);
  }

  @override
  bool shouldRepaint(covariant UniversePainter oldDelegate) {
    return oldDelegate.contacts != contacts ||
           oldDelegate.selectedContact != selectedContact ||
           oldDelegate.isImmersive != isImmersive ||
           oldDelegate.immersionLevel != immersionLevel ||
           oldDelegate.rotation != rotation ||
           oldDelegate.isDarkMode != isDarkMode;
  }
}

class StarInfo {
  final Offset position;
  final double size;
  
  StarInfo({
    required this.position,
    required this.size,
  });
}
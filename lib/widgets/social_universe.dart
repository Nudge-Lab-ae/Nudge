// social_universe.dart - HYBRID CACHED VERSION (Stars only)
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/test/mock_data_generator.dart';
import 'package:nudge/widgets/social_universe_guide.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/contact.dart';

class SocialUniverseWidget extends StatefulWidget {
  final List<Contact> contacts;
  final Function(Contact, String) onContactView;
  final double height;
  final bool isImmersive;
  final bool showTitle;
  final VoidCallback? onExitImmersive;
  final VoidCallback? onFullScreenPressed;
  final bool? isDarkMode;
  
  const SocialUniverseWidget({
    Key? key,
    required this.contacts,
    required this.onContactView,
    required this.showTitle,
    this.height = 400,
    this.isImmersive = false,
    this.onExitImmersive,
    this.isDarkMode,
    this.onFullScreenPressed,
  }) : super(key: key);

  @override
  State<SocialUniverseWidget> createState() => _SocialUniverseWidgetState();
}

class _SocialUniverseWidgetState extends State<SocialUniverseWidget> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Contact? _selectedContact;
  bool _showControls = true;
  bool _showTitle = true;
  double _immersionLevel = 0.5;
  
  double _sliderValue = 1.0;
  final Map<String, Offset> _starPositions = {};
  final Map<String, double> _starSizes = {};
  
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  
  // New animation controller for selected star spin
  late AnimationController _selectedStarSpinController;
  late Animation<double> _selectedStarSpinAnimation;
  
  bool _useMockData = false;
  List<Contact> _mockContacts = [];
  late List<Contact> _displayContacts;
  Timer? _debounceTimer;
  // String? _selectedContactRing;

  // Star texture caching only
  final Map<String, ui.Image> _starImages = {};
  final Map<String, ui.Image> _vipStarImages = {};
  bool _isCachingComplete = false;
  ui.Image? _lightBackgroundImage;
  ui.Image? _lightImmersiveBackgroundImage;
  bool _isBackgroundCachingComplete = false;
  List<SocialGroup> _socialGroups = [];
  bool darkModeControlled = false;
  // bool _groupsLoaded = false;


  // bool _isExpandedForContact = false;
  // double get _currentHeight => _isExpandedForContact ? widget.height + 80 : widget.height;
  // late Size _universeSize;
  

  Future<void> _loadSocialGroups() async {
    try {
      final apiService = ApiService();
      final groups = await apiService.getGroupsStream().first;
      if (mounted) {
        setState(() {
          _socialGroups = groups;
          // _groupsLoaded = true;
          // Clear positions to recalculate with new group data
          _starPositions.clear();
          _starSizes.clear();
        });
      }
    } catch (e) {
      print('Error loading social groups: $e');
    }
  }

  Future<void> _loadSavedImmersionLevel() async {
    try {
      final apiService = ApiService();
      final userData = await apiService.getUser();
      
      if (mounted) {
        setState(() {
          _immersionLevel = userData.immersionLevel;
          _sliderValue = userData.immersionLevel;
        });
        print('Loaded immersion level: ${userData.immersionLevel}');
      }
    } catch (e) {
      print('Error loading immersion level: $e');
      // Keep default value if loading fails
      if (mounted) {
        setState(() {
          _immersionLevel = 0.5;
          _sliderValue = 0.5;
        });
      }
    }
  }

  Future<void> _saveImmersionLevel(double newLevel) async {
    try {
      final apiService = ApiService();
      await apiService.updateUser({'immersionLevel': newLevel});
      print('Saved immersion level: $newLevel');
    } catch (e) {
      print('Error saving immersion level: $e');
    }
  }

  void _debounceSaveImmersionLevel(double newLevel) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveImmersionLevel(newLevel);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _universeSize = Size(widget.height - 150, widget.height - 150);
    
    _mockContacts = MockContactsGenerator.generateMockContacts(count: 50);
    MockContactsGenerator.printDistribution(_mockContacts);
    
    _displayContacts = widget.contacts;
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_rotationController);
    
    // Initialize selected star spin animation
    _selectedStarSpinController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _selectedStarSpinAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_selectedStarSpinController);
    
    _sliderValue = _immersionLevel;
     _loadSavedImmersionLevel();
    
    // Start caching star shapes only
    _startStarCaching(widget.isDarkMode!);
    _cacheBackgroundImages();
    _showControls = false;
    _loadSocialGroups();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isCachingComplete) {
        _startStarCaching(widget.isDarkMode!);
      }
    }
  }

  @override
  void didUpdateWidget(SocialUniverseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts) {
      _starPositions.clear();
      _starSizes.clear();
      _displayContacts = widget.contacts;
      _startStarCaching(widget.isDarkMode!);
      if (oldWidget.isDarkMode != widget.isDarkMode) {
        _cacheBackgroundImages();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotationController.dispose();
    _selectedStarSpinController.dispose();
    _disposeCachedImages();
    _lightBackgroundImage?.dispose();
    _lightImmersiveBackgroundImage?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _disposeCachedImages() {
    for (var image in _starImages.values) {
      image.dispose();
    }
    for (var image in _vipStarImages.values) {
      image.dispose();
    }
    _starImages.clear();
    _vipStarImages.clear();
  }

  Future<void> _startStarCaching(bool isDarkMode) async {
    _isCachingComplete = false;
    _disposeCachedImages();
    
    Future.microtask(() async {
      try {
        // Cache star types with proper ring names (no _vip suffix in base keys)
        await _cacheStarTypeWithGlow('inner', Colors.yellow, isDarkMode);
        await _cacheStarTypeWithGlow('inner_vip', Colors.yellow, isDarkMode);
        await _cacheStarTypeWithGlow('middle', const Color(0xff3CB3E9), isDarkMode);
        await _cacheStarTypeWithGlow('middle_vip', const Color(0xff3CB3E9), isDarkMode);
        await _cacheStarTypeWithGlow('outer', const Color(0xff897ED6), isDarkMode);
        await _cacheStarTypeWithGlow('outer_vip', const Color(0xff897ED6), isDarkMode);
        
        setState(() {
          _isCachingComplete = true;
        });
      } catch (e) {
        print('Error caching star shapes: $e');
      }
    });
  }


    void _drawVIPCrown(Canvas canvas, Offset position, double size) {
    final Paint _starPaint = Paint();
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

  Future<void> _cacheBackgroundImages() async {
  try {
    // Load compact background image
    final compactImageData = await rootBundle.load('assets/images/light-background.png');
    final compactCodec = await ui.instantiateImageCodec(compactImageData.buffer.asUint8List());
    final compactFrame = await compactCodec.getNextFrame();
    _lightBackgroundImage = compactFrame.image;
    
    // Load immersive background image  
    final immersiveImageData = await rootBundle.load('assets/images/light-bg-immersive.png');
    final immersiveCodec = await ui.instantiateImageCodec(immersiveImageData.buffer.asUint8List());
    final immersiveFrame = await immersiveCodec.getNextFrame();
    _lightImmersiveBackgroundImage = immersiveFrame.image;
    
    setState(() {
      _isBackgroundCachingComplete = true;
    });
  } catch (e) {
    print('Error caching background images: $e');
    // Fallback to gradient background
  }
}

  Future<void> _cacheStarTypeWithGlow(String type, Color baseColor, bool isDarkMode) async {
    const starSize = 128.0;
    
    await _cacheSingleStarWithGlow(type, baseColor, starSize, false, false, isDarkMode);
    
    if (type.contains('vip')) {
      await _cacheSingleStarWithGlow(type, baseColor, starSize, false, true, isDarkMode);
    } 
  }

  Future<void> _cacheSingleStarWithGlow(String key, Color color, double size, bool isSelected, bool isVIP, bool isDarkMode) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final center = ui.Offset(size / 2, size / 2);
      
      // Create a nice rounded central glow (without square artifacts)
      final glowRadius = size * 0.4;
      final glowPaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          center,
          glowRadius,
          [
            color.withOpacity(0.6),
            color.withOpacity(0.4),
            color.withOpacity(0.1),
            Colors.transparent,
          ],
          [0.0, 0.4, 0.7, 1.0],
        );
      
      canvas.drawCircle(center, glowRadius, glowPaint);
      
      const numberOfPoints = 5;
      final innerRadiusRatio = 0.45;
      final rotationOffset = -pi / 2;
      
      final points = <ui.Offset>[];
      
      for (var i = 0; i < numberOfPoints * 2; i++) {
        final isEven = i.isEven;
        final pointRadius = isEven ? size / 2 : size / 2 * innerRadiusRatio;
        final pointAngle = (pi / numberOfPoints) * i + rotationOffset;
        
        points.add(ui.Offset(
          center.dx + pointRadius * cos(pointAngle),
          center.dy + pointRadius * sin(pointAngle),
        ));
      }
      
      final path = ui.Path()..addPolygon(points, true);
      
      final starPaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          center,
          size / 2,
          [
            Colors.white.withOpacity(0.8),
            color.withOpacity(0.9),
            color.withOpacity(0.6),
          ],
          [0.0, 0.5, 1.0],
        );
      
      canvas.drawPath(path, starPaint);
      
      // Add black border to cached stars (for light mode)
      final borderPaint = ui.Paint()
        ..color = Colors.white
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 5.0;
        // Removed maskFilter to avoid square artifacts
      
      canvas.drawPath(path, borderPaint);
      
      if (isVIP || key.contains('vip')) {
        // Draw single line VIP rays
        final rayCount = 5;
        final innerRadius = size * 0.4;
        final outerRadius = size * 2.2;
        // final rayWidth = 1;
        
        for (int i = 0; i < rayCount; i++) {
          final angle = (i * 2 * pi / rayCount);
          final startX = center.dx + innerRadius * cos(angle);
          final startY = center.dy + innerRadius * sin(angle);
          final endX = center.dx + outerRadius * cos(angle);
          final endY = center.dy + outerRadius * sin(angle);
          
          final rayPaint = ui.Paint()
            ..color = color
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = ui.StrokeCap.round;
          
          canvas.drawLine(
            ui.Offset(startX, startY),
            ui.Offset(endX, endY),
            rayPaint,
          );

        }
        _drawVIPCrown(canvas, Offset(center.dx, center.dy), size);
      }
      

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      picture.dispose();
      
      if (key.contains('vip')) {
        _vipStarImages[key] = image;
      } else {
        _starImages[key] = image;
      }
      
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

  void _toggleMockData(ThemeProvider themeProvider) {
    setState(() {
      _useMockData = !_useMockData;
      _displayContacts = _useMockData ? _mockContacts : widget.contacts;
      _selectedContact = null;
      
      _starPositions.clear();
      _starSizes.clear();
      
      _startStarCaching(themeProvider.isDarkMode);
      
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
    final isDarkMode = darkModeControlled;
    
    return AnimatedContainer(
     duration: const Duration(milliseconds: 300),
      height: _selectedContact != null ? widget.height + 100 : widget.height,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Remove the solid background color - let universe show through
        color: isDarkMode?Colors.transparent: ui.Color.fromARGB(234, 4, 11, 62),
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
          // Background Universe - Fills entire container
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30), // <-- Match your container radius
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: _selectedContact != null ? 100 : 0
                ),
                child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotationAnimation, _selectedStarSpinAnimation]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: UniversePainter(
                        contacts: _displayContacts,
                        socialGroups: Map.fromIterable(
                          _socialGroups,
                          key: (group) => (group as SocialGroup).name,
                          value: (group) => group as SocialGroup,
                        ),
                        selectedContact: _selectedContact,
                        groupsList: _socialGroups,
                        isImmersive: false,
                        immersionLevel: 1.0,
                        rotation: _rotationAnimation.value,
                        selectedStarSpin: _selectedStarSpinAnimation.value,
                        onStarDrawn: (contactId, position, starSize, ring) {
                          if (mounted) {
                            _starPositions[contactId] = position;
                            _starSizes[contactId] = starSize;

                             // Find and update the contact in _displayContacts
                            final contactIndex = _displayContacts.indexWhere((c) => c.id == contactId);
                            if (contactIndex != -1) {
                              _displayContacts[contactIndex].computedRing = ring;
                            }
                          }
                        },
                        isDarkMode: isDarkMode,
                        isCachingComplete: _isCachingComplete,
                        starImages: _starImages,
                        vipStarImages: _vipStarImages,
                        lightBackgroundImage: _lightBackgroundImage,
                        lightImmersiveBackgroundImage: _lightImmersiveBackgroundImage,
                        isBackgroundCachingComplete: _isBackgroundCachingComplete,
                      ),
                    );
                  },
                ),
            ))),
          ),
          
          // Content Overlay - Semi-transparent to show universe behind
          widget.showTitle
          ?Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                // Dark overlay for better contrast
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(isDarkMode ? 0.1 : 0.05),
                    Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card - Semi-transparent
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                          ? ui.Color.fromARGB(255, 41, 55, 76).withOpacity(0.7) 
                          :  ui.Color.fromARGB(255, 41, 55, 76).withOpacity(0.7), 
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDarkMode 
                            ? Colors.transparent.withOpacity(0.2)
                            :  Colors.transparent.withOpacity(0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_useMockData)
                                      GestureDetector(
                                        onTap: (){
                                          _toggleMockData(themeProvider);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.orange.withOpacity(0.8)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.psychology, size: 12, color: Colors.orange),
                                              SizedBox(width: 4),
                                              Text(
                                                'TEST',
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
                                      ? Colors.white70 
                                      : Colors.white70,
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
                                  ? Colors.white.withOpacity(0.15) 
                                  : const Color(0xFF2196F3).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDarkMode 
                                    ? Colors.white.withOpacity(0.2)
                                    : const Color(0xFF2196F3).withOpacity(0.4),
                                ),
                              ),
                              child: Icon(
                                Icons.fullscreen,
                                size: 22,
                                color: isDarkMode 
                                  ? Colors.white70 
                                  : Colors.white70
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Universe Visualization Area - Now shows full universe behind
                   Expanded(
                    child: GestureDetector(
                      onDoubleTap: (){
                        _toggleMockData(themeProvider);
                      },
                      onTapDown: (details) {
                        // Calculate the position relative to the ENTIRE widget, not just this container
                        // The universe is drawn in the full container, so we need to get tap position
                        // relative to the entire SocialUniverseWidget
                        final renderBox = context.findRenderObject() as RenderBox;
                        final localOffset = renderBox.globalToLocal(details.globalPosition);
                        
                        // Pass the actual widget size, not just the height
                        final containerSize = Size(widget.height, widget.height);
                        _handleUniverseTap(localOffset, containerSize);
                      },
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          // Semi-transparent overlay for contrast
                          gradient: RadialGradient(
                            center: Alignment.center,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(isDarkMode ? 0.1 : 0.05),
                            ],
                            radius: 1.2,
                          ),
                        ),
                        // Universe is already drawn in background
                      ),
                    ),
                  ),
                    
                    const SizedBox(height: 16),
                    
                    // Legend Row - Semi-transparent
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                          ?ui.Color.fromARGB(255, 41, 55, 76).withOpacity(0.7) 
                          : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode 
                            ? Colors.transparent.withOpacity(0.2)
                            :  Colors.transparent.withOpacity(0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
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
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ):Center(),
          
          // Selected Contact Card - Positioned over universe
          if (_selectedContact != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _buildCompactContactCard(_selectedContact!, isDarkMode, themeProvider),
              ),
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
      color: /* isDarkMode ? ui.Color.fromARGB(255, 21, 25, 46) : */ const ui.Color.fromARGB(255, 6, 13, 76),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GestureDetector(
                onDoubleTap: (){
                  _toggleMockData(themeProvider);
                },
                onTapDown: (details) {
                  final screenSize = MediaQuery.of(context).size;
                  _handleUniverseTap(details.localPosition, screenSize);
                },
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                    _showTitle = _showControls;
                  });
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotationAnimation, _selectedStarSpinAnimation]),
                  builder: (context, child) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: _selectedContact != null ? size.height*0.2 : 0
                      ),
                      child: CustomPaint(
                      painter: UniversePainter(
                        contacts: _displayContacts,
                        socialGroups: Map.fromIterable(
                          _socialGroups,
                          key: (group) => (group as SocialGroup).name,
                          value: (group) => group as SocialGroup,
                        ),
                        selectedContact: _selectedContact,
                        groupsList: _socialGroups,
                        isImmersive: true,
                        immersionLevel: _immersionLevel,
                        rotation: _rotationAnimation.value,
                        selectedStarSpin: _selectedStarSpinAnimation.value,
                        onStarDrawn: (contactId, position, starSize, ring) {
                          if (mounted) {
                            _starPositions[contactId] = position;
                            _starSizes[contactId] = starSize;
                          }

                           // Find and update the contact in _displayContacts
                            final contactIndex = _displayContacts.indexWhere((c) => c.id == contactId);
                            if (contactIndex != -1) {
                              _displayContacts[contactIndex].computedRing = ring;
                            }
                        },
                        isDarkMode: isDarkMode,
                        isCachingComplete: _isCachingComplete,
                        starImages: _starImages,
                        vipStarImages: _vipStarImages,
                        lightBackgroundImage: _lightBackgroundImage,
                        lightImmersiveBackgroundImage: _lightImmersiveBackgroundImage,
                        isBackgroundCachingComplete: _isBackgroundCachingComplete,
                      ),
                    ));
                  },
                ),
              ),
            ),
          ),
          
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _showTitle ? -10 : -100,
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? Colors.black.withOpacity(0.5) 
                            : Colors.white.withOpacity(0.6),
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
                                        color: isDarkMode ? Colors.white : Color(0xff333333),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Explore your ${_displayContacts.length} connections${_useMockData ? ' (TEST MODE)' : ''}',
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white70 :  Color(0xff333333),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_useMockData)
                                      const SizedBox(height: 4),
                                    if (_useMockData)
                                      GestureDetector(
                                        onTap: (){
                                          _toggleMockData(themeProvider);
                                        },
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
                                              color: isDarkMode?Colors.white:Colors.black,
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
                              // onLongPress: (){
                              //    Navigator.pushNamed(context, '/settings');
                              // },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDarkMode ? Colors.white30 : Colors.blue.shade200),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: isDarkMode ? Colors.white70 : const ui.Color.fromARGB(255, 105, 181, 243),
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
          
          // Visual Intensity Control - Collapsed by default
            if (!_showControls)
              Positioned(
                bottom: 190,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showControls = true;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black.withOpacity(0.85) : Colors.grey.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDarkMode ? Colors.white24 : Colors.blue.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.5 : 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 24,
                      color: isDarkMode ? AppTheme.darkUniverseSecondary : const ui.Color.fromARGB(255, 192, 203, 214),
                    ),
                  ),
                ),
              ),

              // Expanded Visual Intensity Panel
              if (_showControls && _selectedContact == null)
                Positioned(
                  bottom: 70,
                  right: 20,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black.withOpacity(0.15) : Colors.grey.withOpacity(0.45),
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
                              color: isDarkMode ? AppTheme.darkUniverseSecondary : const ui.Color.fromARGB(255, 223, 228, 232),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Visual Intensity',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.white,
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
                                Icons.close,
                                size: 18,
                                color: isDarkMode ? Colors.white70 : Colors.white70,
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
                                  _debounceSaveImmersionLevel(_sliderValue);
                                  print('decreased ${_sliderValue}');
                                }
                              },
                              child: Icon(
                              Icons.remove,
                              color: isDarkMode ? Colors.white70 : Colors.white70,
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
                                activeColor: isDarkMode ? AppTheme.darkUniverseSecondary : const ui.Color.fromARGB(255, 192, 203, 214),
                                inactiveColor: isDarkMode ? Colors.white24 : Colors.white24,
                                onChanged: (value) {
                                  setState(() {
                                    _sliderValue = value;
                                    _immersionLevel = value;
                                  });
                                  _debounceSaveImmersionLevel(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: (){
                                if (_sliderValue <0.98){
                                  setState(() {
                                      _sliderValue += 0.1;
                                      _immersionLevel += 0.1;
                                  });
                                  _debounceSaveImmersionLevel(_sliderValue);
                                  print('added');
                                }
                              },
                              child: Icon(
                              Icons.add,
                              color: isDarkMode ? Colors.white70 : Colors.white70,
                              size: 22,
                            )),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: (isDarkMode ? AppTheme.darkUniverseSecondary : const ui.Color.fromARGB(255, 16, 40, 65)).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(_sliderValue * 100).toInt()}%',
                                style: TextStyle(
                                  color: isDarkMode ? AppTheme.darkUniverseSecondary : const ui.Color.fromARGB(255, 133, 173, 213),
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
                            color: isDarkMode ? Colors.white54 : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          
          if (_selectedContact != null)
            Positioned(
              bottom: 70,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildImmersiveContactCard(_selectedContact!, isDarkMode, themeProvider),
                  ),
                ),
              ),
            ),
          
        ],
      ),
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
      
      final touchRadius = starSize * 2.5;
      
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
      
      // Determine the ring for this contact using the same logic as UniversePainter
      // final socialGroupsMap = Map.fromIterable(
      //   _socialGroups,
      //   key: (group) => (group as SocialGroup).name,
      //   value: (group) => group as SocialGroup,
      // );
      
      // String ring = _determineContactRing(contact, socialGroupsMap);
      
      setState(() {
        _selectedContact = contact;
        // _selectedContactRing = ring; // Simple state variable
        _selectedStarSpinController
          ..stop()
          ..repeat();
      });
    } else {
      setState(() {
        _selectedContact = null;
        // _selectedContactRing = null;
        _selectedStarSpinController.stop();
      });
    }
  }

  // Simple helper method
  // String _determineContactRing(Contact contact, Map<String, SocialGroup> socialGroups) {
  //   // VIP always inner
  //   if (contact.isVIP) return 'inner';
    
  //   // Try to find group by connectionType
  //   SocialGroup? group = socialGroups[contact.connectionType];
    
  //   if (group != null) {
  //     if (group.orderIndex <= 2) return 'inner';
  //     if (group.orderIndex <= 5) return 'middle';
  //     return 'outer';
  //   }
    
  //   // Fallback to CDI if we have meaningful data
  //   bool hasMeaningfulData = contact.interactionCountInWindow > 5 || 
  //                           contact.cdi != 50.0 ||
  //                           DateTime.now().difference(contact.lastContacted).inDays < 90;
    
  //   if (hasMeaningfulData) {
  //     if (contact.cdi >= 70) return 'inner';
  //     if (contact.cdi >= 40) return 'middle';
  //   }
    
  //   // Final fallback to frequency/period
  //   if (contact.frequency >= 4) return 'inner';
  //   if (contact.frequency >= 2) return 'middle';
  //   return 'outer';
  // }
      

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
            color: isDarkMode ? Colors.white70 : Colors.white70,
          ),
        ),
      ],
    );
  }
    
  void _showMockContactDetails(Contact contact, ThemeProvider themeProvider) {
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
    final ringToUse = contact.computedRing;
    final ringColor = _getRingColor(ringToUse);

    var size = MediaQuery.of(context).size;
    if (!_useMockData && contact.id.startsWith('mock_')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.yellow.withOpacity(0.6),
              Colors.orange.withOpacity(0.4),
              isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
            ],
          ),
          border: Border.all(color: Colors.orange.withOpacity(0.6)),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: size.width*0.65,
              child: Row(
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
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedContact = null;
                  // _isExpandedForContact = false;
                  _selectedStarSpinController.stop();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
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
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.connectionType,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CDI: ${contact.cdi.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${contact.computedRing.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 9,
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
                      widget.onContactView(contact, ringToUse);
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
                        fontSize: 10,
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
    // final ringColor = _getRingColor(contact.computedRing);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ringColor.withOpacity(0.6),
            ringColor.withOpacity(0.3),
            isDarkMode ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.8),
          ],
        ),
        border: Border.all(color: ringColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: ringColor.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color:Colors.white
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        contact.connectionType,
                        style: TextStyle(
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
              widget.onContactView(contact, ringToUse);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // border: Border.all(color: Colors.black),
                // gradient: LinearGradient(
                //   colors: [ringColor, ringColor.withOpacity(0.8)],
                //   begin: Alignment.topLeft,
                //   end: Alignment.bottomRight,
                // ),
                color: const ui.Color.fromARGB(255, 29, 69, 136),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
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
    
  Widget _buildImmersiveContactCard(Contact contact, bool isDarkMode, ThemeProvider themeProvider) {
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getTimeAgoText(daysAgo);
    // final ringColor = _getRingColor(contact.computedRing);

    final ringToUse =contact.computedRing;
    print(ringToUse); print(' is the ring to use');
    final ringColor = _getRingColor(ringToUse);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12), // High transparency white box
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 25,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: Colors.white, // White text on semi-transparent background
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
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               SvgPicture.asset(
                                'assets/contact-icons/connection-type.svg',
                                width: 15,
                                height: 15,
                                color: Colors.white
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  contact.connectionType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
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
                                  'FAVOURITE',
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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last contact: $lastContactText',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
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
                    if (!_useMockData && contact.id.startsWith('mock_')) {
                      _showMockContactDetails(contact, themeProvider);
                    } else {
                      widget.onContactView(contact, ringToUse);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: !_useMockData && contact.id.startsWith('mock_')
                          ? [Colors.orange, const Color(0xFFFF9800)]
                          : const [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (!_useMockData && contact.id.startsWith('mock_')
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
                          !_useMockData && contact.id.startsWith('mock_') 
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
                          !_useMockData && contact.id.startsWith('mock_')
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
                    _selectedStarSpinController.stop();
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
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.white.withOpacity(0.9),
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
        return Colors.yellow;
      case 'middle':
        return const Color(0xff3CB3E9);
      case 'outer':
        return const Color(0xff897ED6);
      default:
        return Colors.yellow;
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
  final double selectedStarSpin;
  final Function(String contactId, Offset position, double size, String ring)? onStarDrawn;
  final bool isDarkMode;
  final bool isCachingComplete;
  final Map<String, ui.Image> starImages;
  final Map<String, ui.Image> vipStarImages;
  final ui.Image? lightBackgroundImage;
  final ui.Image? lightImmersiveBackgroundImage;
  final bool isBackgroundCachingComplete;
  final Map<String, SocialGroup> socialGroups;
  final List<SocialGroup>? groupsList;
  
  // Performance optimization: Use pre-allocated Paint objects
  final Paint _backgroundPaint = Paint();
  final Paint _ringPaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _starPaint = Paint();
  final Paint _imagePaint = Paint();
  final Paint _centralGlowPaint = Paint();
  // final Paint _spinningElementPaint = Paint();
  final Random _random = Random(42);

  // Pre-calculate ring radii to avoid recalculating every frame
  late final double _innerInnerRadius;
  late final double _innerOuterRadius;
  late final double _middleInnerRadius;
  late final double _middleOuterRadius;
  late final double _outerInnerRadius;
  late final double _outerOuterRadius;
  
  // Cache for calculations
  final Map<String, _StarPositionCache> _positionCache = {};
  
  UniversePainter({
    required this.contacts,
    required this.selectedContact,
    required this.isImmersive,
    required this.immersionLevel,
    required this.rotation,
    required this.selectedStarSpin,
    this.onStarDrawn,
    required this.isDarkMode,
    required this.isCachingComplete,
    required this.starImages,
    required this.vipStarImages,
    this.lightBackgroundImage,
    this.groupsList,
    required this.socialGroups, 
    this.lightImmersiveBackgroundImage,
    required this.isBackgroundCachingComplete,
  }) {
    // Pre-calculate ring radii once during construction
    _innerInnerRadius = 0.15;
    _innerOuterRadius = 0.35;
    _middleInnerRadius = 0.35;
    _middleOuterRadius = 0.55;
    _outerInnerRadius = 0.55;
    _outerOuterRadius = 0.80;
    
    _imagePaint.filterQuality = FilterQuality.medium;
    _centralGlowPaint.blendMode = BlendMode.plus;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Adjust max radius based on whether it's immersive or compact
    final maxRadius = min(size.width / 2, size.height / 2) * (isImmersive ? 1.3 : 1.1);
    
    // Draw cosmic background - MODIFIED TO USE IMAGES FOR LIGHT MODE
    _drawCosmicBackground(canvas, size, immersionLevel, isDarkMode);
    
    // Draw rings with theme-specific colors - ORIGINAL EXACT IMPLEMENTATION
    // Adjust ring sizes for compact view
    final innerRingOuter = maxRadius * (isImmersive ? 0.35 : 0.35);
    final middleRingOuter = maxRadius * (isImmersive ? 0.55 : 0.55);
    final outerRingOuter = maxRadius * (isImmersive ? 0.75 : 0.75);
    
    _drawRing(
      canvas,
      center,
      maxRadius * 0.15,
      innerRingOuter,
      isDarkMode 
        ? Colors.yellow.withOpacity(0.15 + 0.3 * immersionLevel)
        : Colors.yellow.withOpacity(0.12 + 0.25 * immersionLevel),
      isDarkMode,
      true
    );

    _drawRing(
      canvas,
      center,
      innerRingOuter,
      middleRingOuter,
      isDarkMode 
        ? const ui.Color.fromARGB(255, 198, 214, 218).withOpacity(0.45 + 0.3 * immersionLevel)
        : const ui.Color.fromARGB(255, 203, 214, 220).withOpacity(0.42 + 0.25 * immersionLevel),
      isDarkMode,
      false
    );

    _drawRing(
      canvas,
      center,
      middleRingOuter,
      outerRingOuter,
      isDarkMode 
        ? const ui.Color.fromARGB(255, 189, 183, 224).withOpacity(0.65 + 0.3 * immersionLevel)
        : const ui.Color.fromARGB(255, 173, 173, 224).withOpacity(0.62 + 0.25 * immersionLevel),
      isDarkMode,
      false
    );
    
    // Draw central user with theme support - ORIGINAL EXACT IMPLEMENTATION
    _drawCentralUser(canvas, center, immersionLevel, isDarkMode);
    
    // Draw all stars with rotation - USING CACHED SHAPES
    for (final contact in contacts) {
      final starInfo = _drawStar(canvas, center, contact, maxRadius, size, isDarkMode);
      
      if (onStarDrawn != null && starInfo != null) {
        onStarDrawn!(contact.id, starInfo.position, starInfo.size, starInfo.ring);
      }
    }
  }

  StarInfo? _drawStar(Canvas canvas, Offset center, Contact contact, double maxRadius, Size size, bool isDarkMode) {
    final isSelected = selectedContact?.id == contact.id;
    final isVIP = contact.isVIP;
    
    // Get cached position which now includes the determined ring
    final positionCache = _getPositionCache(contact, maxRadius);
    final spreadRadius = positionCache.spreadRadius;
    final angle = positionCache.contactAngleRad + rotation;
    final determinedRing = positionCache.determinedRing; // Use this for color
    
    final x = center.dx + spreadRadius * cos(angle);
    final y = center.dy + spreadRadius * sin(angle);
    final position = Offset(x, y);
    
    // Calculate visual size
    double baseSize = isImmersive ? 9.0 : 7.0;
    
    if (determinedRing == 'inner') {
      baseSize *= 1;
    } else {
      baseSize *= 0.8;
    }

    if (isVIP) baseSize *= 1.1;
    if (isSelected) baseSize *= 2.2;

    final visualSize = baseSize * (1 + 0.5 * immersionLevel);
    
    // Get color based on determinedRing, NOT contact.computedRing
    Color color;
    switch (determinedRing) {
      case 'inner':
        color = Colors.yellow;
        break;
      case 'middle':
        color = const Color(0xff3CB3E9); // Blue
        break;
      case 'outer':
        color = const Color(0xff897ED6); // Purple
        break;
      default:
        color = Colors.grey;
    }
    
    // Draw star using cached image if available
    if (isCachingComplete) {
      // Use determinedRing to get the correct cached image
      final imageKey = isVIP ? '${determinedRing}_vip' : determinedRing;
      final image = isVIP ? vipStarImages[imageKey] : starImages[imageKey];
      
      if (image != null) {
        if (isSelected) {
          _drawSelectedStarCentralGlow(canvas, position, visualSize, color);
          _drawSpinningElements(canvas, position, visualSize, color);
        }
        
        canvas.save();
        if (isSelected) {
          canvas.translate(position.dx, position.dy);
          canvas.rotate(selectedStarSpin);
          canvas.translate(-position.dx, -position.dy);
        }
        
        canvas.translate(position.dx, position.dy);
        canvas.scale(visualSize / (image.width / 2));
        canvas.translate(-image.width / 2, -image.height / 2);
        canvas.drawImage(image, Offset.zero, _imagePaint);
        canvas.restore();
        
        if (isSelected) {
          _drawSelectionGlow(canvas, position, visualSize, determinedRing);
        }
      } else {
        // Fallback drawing
        _drawStarFallback(canvas, position, visualSize, color, isSelected, isDarkMode, immersionLevel, isVIP);
      }
    } else {
      // Fallback drawing
      _drawStarFallback(canvas, position, visualSize, color, isSelected, isDarkMode, immersionLevel, isVIP);
    }
    
    return StarInfo(position: position, size: visualSize, ring: determinedRing);
  }

  // Helper method for fallback drawing
  void _drawStarFallback(Canvas canvas, Offset position, double size, Color color, 
      bool isSelected, bool isDarkMode, double immersionLevel, bool isVIP) {
    if (isSelected) {
      _drawSelectedStarCentralGlow(canvas, position, size, color);
      _drawSpinningElements(canvas, position, size, color);
    }
    
    canvas.save();
    if (isSelected) {
      canvas.translate(position.dx, position.dy);
      canvas.rotate(selectedStarSpin);
      canvas.translate(-position.dx, -position.dy);
    }
    
    _drawStarCentralGlow(canvas, position, size, color, immersionLevel, isDarkMode, isSelected);
    _drawStarShape(canvas, position, size, color, isSelected, isDarkMode, immersionLevel);
    
    if (isVIP) {
      _drawVIPCrown(canvas, position, size);
    }
    
    canvas.restore();
  }
    
  void _drawSelectedStarCentralGlow(Canvas canvas, Offset center, double size, Color color) {
    // Bright central circular glow for selected stars
    final glowRadius = size * 1.5;
    
    _centralGlowPaint
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withOpacity(0.9),
          color.withOpacity(0.8),
          color.withOpacity(0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    
    canvas.drawCircle(center, glowRadius, _centralGlowPaint);
    
    // Add a pulsing inner glow
    final pulse = (sin(selectedStarSpin * 2) + 1) / 2;
    final pulseRadius = size * (0.8 + pulse * 0.3);
    
    final pulsePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withOpacity(0.7),
          color.withOpacity(0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: pulseRadius));
    
    canvas.drawCircle(center, pulseRadius, pulsePaint);
  }

  void _drawSpinningElements(Canvas canvas, Offset center, double size, Color color) {
    final elementCount = 8;
    final elementRadius = size * 0.1;
    final orbitRadius = size * 1.2;
    
    for (int i = 0; i < elementCount; i++) {
      final elementAngle = selectedStarSpin * 3 + (i * 2 * pi / elementCount);
      final x = center.dx + orbitRadius * cos(elementAngle);
      final y = center.dy + orbitRadius * sin(elementAngle);
      final elementCenter = Offset(x, y);
      
      // Each element spins at its own speed
      // final elementSpin = selectedStarSpin * 5 + (i * pi / 4);
      
      // Draw a small spinning circle (CHANGED FROM TRIANGLE)
      final circleSize = elementRadius * 0.6;
      final circlePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white,
            color.withOpacity(0.9),
            color.withOpacity(0.6),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: elementCenter, radius: circleSize));
      
      // Create a rotating circle
      canvas.drawCircle(elementCenter, circleSize, circlePaint);
      
      // Add a glowing effect around the circles
      final circleGlowPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, circleSize * 0.8);
      
      canvas.drawCircle(elementCenter, circleSize * 1.2, circleGlowPaint);
      
      // Add a subtle trail/glow behind the element (ENHANCED)
      final trailPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, circleSize);
      
      canvas.drawCircle(
        Offset(
          elementCenter.dx - orbitRadius * 0.15 * cos(elementAngle),
          elementCenter.dy - orbitRadius * 0.15 * sin(elementAngle),
        ),
        circleSize * 0.5,
        trailPaint,
      );
    }
  }
    
  _StarPositionCache _getPositionCache(Contact contact, double maxRadius) {
  if (_positionCache.containsKey(contact.id)) {
    return _positionCache[contact.id]!;
  }
  
  final hash = _stringToHash(contact.id);
  final spreadOffset = (hash.abs() % 35) / 100.0;
  final contactAngleDeg = contact.angleDeg != 0 ? contact.angleDeg : (hash % 360).toDouble();
  final contactAngleRad = contactAngleDeg * (pi / 180);
  
  // STEP 1: VIP always inner circle
  if (contact.isVIP) {
    final innerRadius = maxRadius * _innerInnerRadius;
    final outerRadius = maxRadius * _innerOuterRadius;
    final ringWidth = outerRadius - innerRadius;
    // Ensure star stays within bounds - use 80% of ring width max
    final spreadRadius = innerRadius + (ringWidth * (0.1 + spreadOffset * 0.7));
    
    final cache = _StarPositionCache(
      spreadRadius: spreadRadius,
      contactAngleRad: contactAngleRad,
      determinedRing: 'inner', // Store the ring for color consistency
    );
    _positionCache[contact.id] = cache;
    return cache;
  }
  
  // STEP 2: Find the contact's group by connectionType
  SocialGroup? contactGroup;
  for (final group in socialGroups.values) {
    if (group.name == contact.connectionType) {
      contactGroup = group;
      break;
    }
  }
  
  // STEP 3: Determine group-based ring using orderIndex (smaller = higher priority)
  String groupBasedRing = 'outer'; // default
  int groupLength = groupsList!.length;
  if (contactGroup != null) {
    if (contactGroup.orderIndex <= (groupLength/3).toInt()) {
      groupBasedRing = 'inner';
    } else if (contactGroup.orderIndex <= (groupLength/1.5).toInt()) {
      groupBasedRing = 'middle';
    } else {
      groupBasedRing = 'outer';
    }
  } else {
    // Fallback if group not found
    if (contact.frequency >= 4) groupBasedRing = 'inner';
    else if (contact.frequency >= 2) groupBasedRing = 'middle';
    else groupBasedRing = 'outer';
  }
  
  // STEP 4: Calculate interaction-based ring
  String interactionBasedRing = 'outer';
  if (contact.cdi >= 70) interactionBasedRing = 'inner';
  else if (contact.cdi >= 40) interactionBasedRing = 'middle';
  else interactionBasedRing = 'outer';
  
  // STEP 5: Determine if we have meaningful interaction data
  bool hasMeaningfulInteractions = contact.interactionCountInWindow > 5 
                                   //  || DateTime.now().difference(contact.lastContacted).inDays < 90
                                   ;
                                   
                                  
  
  // STEP 6: Calculate final ring with weighting
  String finalRing;
  if (!hasMeaningfulInteractions) {
    // No meaningful data yet - use group priority
    finalRing = groupBasedRing;
  } else {
    // Have some data - weight based on interaction count (max 70% interaction)
    double interactionWeight = (contact.interactionCountInWindow / 20).clamp(0.2, 0.7);
    double groupWeight = 1.0 - interactionWeight;
    
    // Convert rings to numbers for weighted average
    int groupVal = groupBasedRing == 'inner' ? 3 : groupBasedRing == 'middle' ? 2 : 1;
    int interactionVal = interactionBasedRing == 'inner' ? 3 : interactionBasedRing == 'middle' ? 2 : 1;
    
    double weightedAvg = (groupVal * groupWeight) + (interactionVal * interactionWeight);
    int roundedVal = weightedAvg.round().clamp(1, 3);
    
    finalRing = roundedVal == 3 ? 'inner' : roundedVal == 2 ? 'middle' : 'outer';
  }
  
  // STEP 7: Calculate position based on final ring with strict boundaries
  double innerRadius, outerRadius;
  switch (finalRing) {
    case 'inner':
      innerRadius = maxRadius * _innerInnerRadius;
      outerRadius = maxRadius * _innerOuterRadius;
      break;
    case 'middle':
      innerRadius = maxRadius * _middleInnerRadius;
      outerRadius = maxRadius * _middleOuterRadius;
      break;
    default: // outer
      innerRadius = maxRadius * _outerInnerRadius;
      outerRadius = maxRadius * _outerOuterRadius;
  }
  
  // Ensure stars stay within ring boundaries with some padding
  // Use only 70% of the ring width to keep stars away from edges
  final ringWidth = outerRadius - innerRadius;
  final usableWidth = ringWidth * 0.5;
  final startOffset = innerRadius + (ringWidth * 0.15); // Start 15% into the ring
  
  // Use hash for deterministic but varied positioning
  final randomFactor = (hash.abs() % 100) / 100.0;
  final spreadRadius = startOffset + (usableWidth * randomFactor);
  
  // Final safety clamp to ensure we never exceed boundaries
  final clampedRadius = spreadRadius.clamp(innerRadius * 1.05, outerRadius * 0.95);
  
  final cache = _StarPositionCache(
    spreadRadius: clampedRadius,
    contactAngleRad: contactAngleRad,
    determinedRing: finalRing, // Store the ring for color consistency
  );
  
  _positionCache[contact.id] = cache;
  return cache;
}

  // =========== ORIGINAL DRAWING METHODS ===========
  
  void _drawStarCentralGlow(Canvas canvas, Offset center, double size, Color color, double immersionLevel, bool isDarkMode, bool isSelected) {
      // Create a nice rounded central glow that scales with immersionLevel
      final glowIntensity = 0.4 + immersionLevel * 0.4; // 0.4 to 0.8 based on immersion
      final glowRadius = size * (0.3 + immersionLevel * 0.2); // 0.3 to 0.5 based on immersion
      
      // Central glow - smooth rounded gradient
      final centralGlowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            color.withOpacity(glowIntensity),
            color.withOpacity(glowIntensity * 0.8),
            color.withOpacity(glowIntensity * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
      
      canvas.drawCircle(center, glowRadius, centralGlowPaint);
      
      // Add a subtle inner core for more depth
      if (immersionLevel > 0.5) {
        final corePaint = Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [
              Colors.white.withOpacity(0.6 * immersionLevel),
              color.withOpacity(0.7 * immersionLevel),
            ],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: size * 0.2));
        
        canvas.drawCircle(center, size * 0.2, corePaint);
      }

      final coreIntensity = 0.5 + immersionLevel * 0.5; // More prominent core
      final corePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(coreIntensity),
            color.withOpacity(coreIntensity * 0.8),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: size * 0.3)); // Increased from 0.2
      
      canvas.drawCircle(center, size * 0.3, corePaint);
    }
    
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
      
      // Star gradient
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
      
      // Add theme-appropriate border
      final borderColor = Colors.white;
      final borderOpacity = 0.7 + immersionLevel * 0.3; // 0.7 to 1.0 based on immersion
      
      final borderPaint = Paint()
        ..color = borderColor.withOpacity(borderOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 + immersionLevel * 0.5; // 1.0 to 1.5 based on immersion
        // Removed maskFilter to avoid square artifacts
      
      canvas.drawPath(path, borderPaint);
      
      // Optional: Add a subtle highlight border for selected stars
      if (isSelected) {
        final highlightBorderPaint = Paint()
          ..color = isDarkMode 
            ? Colors.white.withOpacity(0.9) 
            : Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + immersionLevel * 1.0;
        
        canvas.drawPath(path, highlightBorderPaint);
      }
    }
    
  void _drawSelectionGlow(Canvas canvas, Offset center, double size, String ring) {
    final glowPaint = Paint()
      ..color = _getRingColor(ring).withOpacity(0.3)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, size * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(center, size * 1.2, glowPaint);
  }

// =========== ORIGINAL DRAWING METHODS ===========
  
  void _drawCosmicBackground(Canvas canvas, Size size, double immersionLevel, bool isDarkMode) {
    final clampedImmersionLevel = immersionLevel.clamp(0.0, 1.0);
    
    // if (isDarkMode) {
    //   // DARK MODE: Deep space with bright stars - ORIGINAL
    //   _backgroundPaint
    //     ..shader = RadialGradient(
    //       center: Alignment.center,
    //       colors: [
    //         const Color.fromARGB(255, 3, 4, 10),
    //         const Color.fromARGB(255, 13, 16, 29),
    //         const Color.fromARGB(255, 20, 23, 36),
    //       ],
    //       stops: const [0.0, 0.6, 1.0],
    //     ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
    //   canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _backgroundPaint);
      
    //   // _drawNebula(canvas, size, clampedImmersionLevel, false);
    //   // Draw background stars with CLEAR DIFFERENCE between modes - ORIGINAL
    //   _drawBackgroundStars(canvas, size, clampedImmersionLevel, isDarkMode);
      
    // } else {
      // LIGHT MODE: Use background image if available
      if (isBackgroundCachingComplete) {
        final backgroundImage = isImmersive ? lightImmersiveBackgroundImage : lightBackgroundImage;
        
        if (backgroundImage != null) {
          // Draw the background image
          final srcRect = Rect.fromLTWH(0, 0, backgroundImage.width.toDouble(), backgroundImage.height.toDouble());
          final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
          
          _imagePaint
            ..colorFilter = null
            ..filterQuality = FilterQuality.high;
          
          canvas.drawImageRect(backgroundImage, srcRect, dstRect, _imagePaint);
        } else {
          // Fallback to gradient if image not available
          _drawFallbackLightBackground(canvas, size);
        }
      } else {
        // Fallback to gradient while images are loading
        _drawFallbackLightBackground(canvas, size);
      }
      
      // Add some light mode nebula/cloud effects - ORIGINAL
      
      // Still draw some background stars but fewer
      _drawBackgroundStars(canvas, size, clampedImmersionLevel, isDarkMode);
    // }
  }
  
  void _drawFallbackLightBackground(Canvas canvas, Size size) {
    _backgroundPaint
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          const Color(0xFF64B5F6).withOpacity(0.9),
          const Color(0xFF42A5F5).withOpacity(0.95),
          const Color(0xFF2196F3),
        ],
        radius: 1.2,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _backgroundPaint);
  }

  // void _drawNebula(Canvas canvas, Size size, double immersionLevel, bool isDarkMode) {
  //   final center = Offset(size.width / 2, size.height / 2);
    
  //   // Create 2-3 nebula clouds - ORIGINAL
  //   final nebulaCount = 2 + (immersionLevel * 2).toInt();
    
  //   for (int n = 0; n < nebulaCount; n++) {
  //     final nebulaX = center.dx + (_random.nextDouble() - 0.5) * size.width * 0.6;
  //     final nebulaY = center.dy + (_random.nextDouble() - 0.5) * size.height * 0.6;
  //     final nebulaRadius = size.width * (0.15 + _random.nextDouble() * 0.25);
      
  //     if (isDarkMode) {
  //       // Dark mode nebula - purples and blues - ORIGINAL
  //       _ringPaint
  //         ..shader = RadialGradient(
  //           center: Alignment.center,
  //           colors: [
  //             const Color.fromARGB(255, 38, 23, 78).withOpacity(0.25 + immersionLevel * 0.03),
  //             const Color.fromARGB(255, 21, 27, 65).withOpacity(0.23 + immersionLevel * 0.02),
  //             const Color.fromARGB(255, 36, 62, 105).withOpacity(0.22 + immersionLevel * 0.01),
  //             Colors.transparent,
  //           ],
  //           stops: const [0.0, 0.3, 0.6, 1.0],
  //         ).createShader(Rect.fromCircle(
  //           center: Offset(nebulaX, nebulaY),
  //           radius: nebulaRadius,
  //         ))
  //         ..maskFilter = MaskFilter.blur(BlurStyle.normal, nebulaRadius * 0.7);
        
  //       canvas.drawCircle(Offset(nebulaX, nebulaY), nebulaRadius, _ringPaint);
  //     } else {
  //       // Light mode clouds - light blues and cyans - ORIGINAL
  //       _ringPaint
  //         ..shader = RadialGradient(
  //           center: Alignment.center,
  //           colors: [
  //             const Color(0xFF80DEEA).withOpacity(0.08 + immersionLevel * 0.04),
  //             const Color(0xFF4DD0E1).withOpacity(0.05 + immersionLevel * 0.03),
  //             const Color(0xFF26C6DA).withOpacity(0.03 + immersionLevel * 0.02),
  //             Colors.transparent,
  //           ],
  //           stops: const [0.0, 0.4, 0.7, 1.0],
  //         ).createShader(Rect.fromCircle(
  //           center: Offset(nebulaX, nebulaY),
  //           radius: nebulaRadius,
  //         ))
  //         ..maskFilter = MaskFilter.blur(BlurStyle.normal, nebulaRadius * 0.9);
        
  //       canvas.drawCircle(Offset(nebulaX, nebulaY), nebulaRadius, _ringPaint);
  //     }
  //   }
  // }

  void _drawBackgroundStars(Canvas canvas, Size size, double immersionLevel, bool isDarkMode) {
      // Increased star count for more vividness without blur - ORIGINAL
      final baseStarCount = isImmersive ? 850: 450; // More stars
      final starCount = (baseStarCount * (0.1 + pow(immersionLevel, 2) * 0.9)).toInt();
      
      for (int i = 0; i < starCount; i++) {
        final x = (_random.nextDouble() * size.width);
        final y = (_random.nextDouble() * size.height);
        final starBrightness = _random.nextDouble();
        
        // Star size - keep them small and sharp - ORIGINAL
        final baseRadius = isDarkMode ? 0.5 : 0.4;
        final radius = baseRadius + starBrightness * 0.4 + (immersionLevel * 0.2);
        
        if (isDarkMode) {
          // DARK MODE STARS: Sharp and bright - ORIGINAL
          final opacity = (0.5 + starBrightness * 0.4) * (0.6 + immersionLevel * 0.5);
          _starPaint
            ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
            ..maskFilter = null; // No blur for sharp stars
          
          canvas.drawCircle(Offset(x, y), radius, _starPaint);
          
        } else {
          // LIGHT MODE STARS: Sharp and clean - ORIGINAL
          final opacity = (0.6 + starBrightness * 0.4) * (0.6 + immersionLevel * 0.5);
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
    
    // Calculate shine intensity based on immersionLevel
    // No shine at 0.5, full shine at 1.0, linear interpolation
    final shineIntensity = (immersionLevel - 0.4) / 0.5;
    final clampedShineIntensity = shineIntensity.clamp(0.0, 1.0);
    
    // Draw the base central sphere (unchanged from original)
    if (isDarkMode) {
      // DARK MODE central user: Gold/Yellow - ORIGINAL
      _glowPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const ui.Color.fromARGB(255, 255, 225, 0).withOpacity(0.9),
            const ui.Color.fromARGB(255, 255, 247, 0).withOpacity(0.7),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 30 + pulse * 8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      
      canvas.drawCircle(center, 30 + pulse * 8, _glowPaint);
      
      // Central sphere - ORIGINAL
      _starPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: const [ui.Color.fromARGB(255, 255, 251, 0), ui.Color.fromARGB(255, 255, 234, 0)],
        ).createShader(Rect.fromCircle(center: center, radius: 18));
      
      canvas.drawCircle(center, 18, _starPaint);
      
    } else {
      // LIGHT MODE central user: Bright Cyan/Blue - ORIGINAL
      _glowPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color(0xFFFFD600).withOpacity(0.9),
            const ui.Color.fromARGB(255, 251, 255, 0).withOpacity(0.7),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 28 + pulse * 6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      
      canvas.drawCircle(center, 28 + pulse * 6, _glowPaint);
      
      // Central sphere - ORIGINAL
      _starPaint
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: const [ui.Color.fromARGB(255, 255, 255, 0), ui.Color.fromARGB(255, 255, 238, 0)],
        ).createShader(Rect.fromCircle(center: center, radius: 16));
      
      canvas.drawCircle(center, 16, _starPaint);
    }
    
    // ===== NEW: ADD BRIGHT WHITE GLOWING CENTER =====
    if (clampedShineIntensity > 0) {
      // Inner white core glow - grows with immersion
      final innerCoreRadius = 4.0 + clampedShineIntensity * 6.0; // 4 to 10 pixels
      final innerCorePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(0.4 + clampedShineIntensity * 0.1), // 0.9 to 1.0
            Colors.white.withOpacity(0.3 + clampedShineIntensity * 0.3), // 0.6 to 0.9
            Colors.white.withOpacity(0.1 + clampedShineIntensity * 0.4), // 0.2 to 0.6
            Colors.transparent,
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: innerCoreRadius))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 
          3.0 + clampedShineIntensity * 7.0 // 3 to 10 blur
        );
      
      canvas.drawCircle(center, innerCoreRadius, innerCorePaint);
      
      // Outer white glow halo - extends beyond the main circle at high immersion
      final haloRadius = 25.0 + clampedShineIntensity * 15.0; // 25 to 40 pixels
      final haloPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(0.1 * clampedShineIntensity), // 0 to 0.1
            Colors.white.withOpacity(0.05 * clampedShineIntensity), // 0 to 0.05
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 
          10.0 + clampedShineIntensity * 20.0 // 10 to 30 blur
        );
      
      canvas.drawCircle(center, haloRadius, haloPaint);
      
      // Bright white center dot - very intense at high immersion
      final centerDotRadius = 12.0 + clampedShineIntensity * 3.0; // 2 to 5 pixels
      final centerDotPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(0.45 + clampedShineIntensity * 0.05), // 0.95 to 1.0
            Colors.white.withOpacity(0.2 + clampedShineIntensity * 0.3),  // 0.7 to 1.0
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: centerDotRadius))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 
          1.0 + clampedShineIntensity * 2.0 // 1 to 3 blur
        );
      
      canvas.drawCircle(center, centerDotRadius, centerDotPaint);
      
      // Add subtle pulsing effect to the white glow
      final pulseFactor = 1.0 + pulse * 0.2 * clampedShineIntensity;
      final pulsedInnerCorePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(0.3 * clampedShineIntensity), // 0 to 0.8
            Colors.white.withOpacity(0.1 * clampedShineIntensity), // 0 to 0.4
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: innerCoreRadius * pulseFactor))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 
          5.0 * clampedShineIntensity // 0 to 5 blur
        );
      
      canvas.drawCircle(center, innerCoreRadius * pulseFactor, pulsedInnerCorePaint);
    }
    
    // "YOU" text - theme specific - ORIGINAL
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
    // Make ALL borders thicker and more vivid - ORIGINAL
    final borderWidth = isDarkMode ? (1 + immersionLevel * 1.0) : (1 + immersionLevel * 1.5);
    final ringOpacity = immersionLevel * 0.3;
    
    if (isInnerRing) {
      // Inner ring - only draw the outer circle - ORIGINAL
      _ringPaint
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.5 + ringOpacity*0.4),
            color.withOpacity(0.25 + ringOpacity * 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: outerRadius),
        )
        ..style = PaintingStyle.fill;
      
      // if (isDarkMode) {
      //   canvas.drawCircle(center, outerRadius, _ringPaint);
      // }
      
      // Only draw glow border in dark mode
      
        _glowPaint
          ..color = color.withOpacity((isDarkMode ? 0.7 : 0.7) + ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;
        
        canvas.drawCircle(center, outerRadius, _glowPaint);
      
    } else {
      // Middle/Outer ring - only draw the outer circle - ORIGINAL
      _ringPaint
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.3 + ringOpacity * 0.4),
            color.withOpacity(0.15 + ringOpacity * 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: outerRadius),
        )
        ..style = PaintingStyle.fill;
      
      // if (isDarkMode) {
      //   canvas.drawCircle(center, outerRadius, _ringPaint);
      // }
      
      // Only draw glow border in dark mode
      _glowPaint
          ..color = color.withOpacity((isDarkMode ? 0.35 : 0.45) + ringOpacity * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth * 0.9;
        
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

  @override
  bool shouldRepaint(covariant UniversePainter oldDelegate) {
    return oldDelegate.contacts != contacts ||
          oldDelegate.selectedContact != selectedContact ||
          oldDelegate.isImmersive != isImmersive ||
          oldDelegate.immersionLevel != immersionLevel ||
          oldDelegate.rotation != rotation ||
          oldDelegate.selectedStarSpin != selectedStarSpin ||
          oldDelegate.isDarkMode != isDarkMode ||
          oldDelegate.isBackgroundCachingComplete != isBackgroundCachingComplete ||
          oldDelegate.lightBackgroundImage != lightBackgroundImage ||
          oldDelegate.lightImmersiveBackgroundImage != lightImmersiveBackgroundImage;
  }
  
  // @override
  // bool get isComplex => true;
}

class _StarPositionCache {
  final double spreadRadius;
  final double contactAngleRad;
  final String determinedRing; // Add this to store which ring the star belongs to
  
  _StarPositionCache({
    required this.spreadRadius,
    required this.contactAngleRad,
    required this.determinedRing, // Make it required
  });
}

class StarInfo {
  final Offset position;
  final double size;
  final String ring;
  
  StarInfo({
    required this.position,
    required this.size,
    required this.ring,
  });
}
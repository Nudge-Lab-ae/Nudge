import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/screens/feedback/feedback_bottom_sheet.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
import 'package:provider/provider.dart';
// import 'package:nudge/providers/theme_provider.dart';
// import 'package:provider/provider.dart';

class FeedbackAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  FeedbackAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

class FeedbackFloatingButton extends StatefulWidget {
  final String? currentSection;
  final List<FeedbackAction>? extraActions;
  final bool isDeleteMode;
  final VoidCallback? onDeletePressed;
  final String? deleteButtonLabel;
  final VoidCallback? onMenuStateChanged;
  final bool fromDashboard;

  const FeedbackFloatingButton({
    super.key,
    this.currentSection,
    this.extraActions,
    this.isDeleteMode = false,
    this.onDeletePressed,
    this.deleteButtonLabel = 'Delete',
    this.onMenuStateChanged, 
    this.fromDashboard = false
  });

  @override
  State<FeedbackFloatingButton> createState() => _FeedbackFloatingButtonState();
}

class _FeedbackFloatingButtonState extends State<FeedbackFloatingButton> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _toggleExpanded() {
  setState(() {
    _isExpanded = !_isExpanded;
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    // Update the global provider
    context.read<FeedbackProvider>().setFabMenuState(_isExpanded);
    widget.onMenuStateChanged?.call();
  });
}

// Update _closeMenu:
void _closeMenu() {
  if (_isExpanded) {
    setState(() {
      _isExpanded = false;
      _controller.reverse();
    });
    // Update the global provider
    context.read<FeedbackProvider>().setFabMenuState(false);
    widget.onMenuStateChanged?.call();
  }
}

  void _showFeedbackDialog(BuildContext context, String section, {String? initialType}) {
    final currentSection = widget.currentSection ?? section;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedbackBottomSheet(
        currentSection: currentSection,
        initialType: initialType,
      ),
    ).whenComplete(() {
      _closeMenu();
    });
  }

  void _openFeedbackForum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackForumScreen(),
      ),
    ).whenComplete(() {
      _closeMenu();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    var size = MediaQuery.of(context).size;
    
    // Build all menu items including fixed and extra actions
    final allMenuItems = <Map<String, dynamic>>[];
    
    // Fixed actions
    if (!widget.fromDashboard){
      allMenuItems.add({
        'icon': Icons.forum,
        'text': 'View Forum',
        'onTap': () {
          _openFeedbackForum(context);
        },
      });
    }
    
     allMenuItems.add({
        'icon': Icons.feedback,
        'text': 'Give Feedback',
        'onTap': () {
          final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
          _showFeedbackDialog(context, currentRoute);
        },
      });
    
    // Extra actions (now we'll have 3 extra to make total of 5)
    if (widget.extraActions != null) {
      for (var action in widget.extraActions!) {
        allMenuItems.add({
          'icon': action.icon,
          'text': action.label,
          'onTap': action.onPressed,
        });
      }
    }
    
    // Delete mode action
    if (widget.isDeleteMode && widget.onDeletePressed != null) {
      allMenuItems.add({
        'icon': Icons.delete,
        'text': widget.deleteButtonLabel ?? 'Delete',
        'onTap': widget.onDeletePressed!,
      });
    }
    
    final totalItems = allMenuItems.length;
    
    return SizedBox(
      width: _isExpanded ? size.width * 2 : size.width,  // Increase width when expanded
      height: _isExpanded ? size.height * 2 : size.width,  // Increase height when expanded
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          
          // White glow circle (appears when menu is open)
          if (_isExpanded)
            Positioned(
              right: -40,
              bottom: -50,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.65),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.15),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Radial menu items
          if (_isExpanded)
            for (int i = 0; i < totalItems; i++)
              _buildRadialMenuItem(
                index: i,
                totalItems: totalItems,
                icon: allMenuItems[i]['icon'] as IconData,
                text: allMenuItems[i]['text'] as String,
                onTap: allMenuItems[i]['onTap'] as VoidCallback,
              ),
          
          // Main floating button
          Positioned(
            right: 0,
            bottom: 50,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isExpanded
                        ? Container(
                            key: const ValueKey('close'),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 221, 44, 44),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            key: const ValueKey('logo'),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              image: const DecorationImage(
                                image: AssetImage('assets/Nudge-logo.png'),
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                // BoxShadow(
                                //   color: Colors.black.withOpacity(0.2),
                                //   blurRadius: 8,
                                //   offset: const Offset(0, 2),
                                // ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadialMenuItem({
    required int index,
    required int totalItems,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    // Calculate angle from 90° (top) to 270° (bottom)
     double startAngle = 90 * (pi / 180);   // 90° - Top
     double endAngle = 270 * (pi / 180);    // 270° - Bottom

     if (totalItems < 4) {
       startAngle = 130 * (pi / 180);   
        endAngle = 270 * (pi / 180);
     }
     
     if (totalItems < 3) {
       startAngle = 180 * (pi / 180); 
        endAngle = 270 * (pi / 180);
     }
    
    // Spread items evenly in the range
    final double angleStep = totalItems > 1 ? (endAngle - startAngle) / (totalItems - 1) : 0;
    final double angle = startAngle + (index * angleStep);
    
    // Calculate vertical offset based on sine of angle
    // sin(90°) = 1 (top) -> offset -15
    // sin(180°) = 0 (middle) -> offset 0
    // sin(270°) = -1 (bottom) -> offset 15
    double verticalOffset = 0;
    if (index == 0 || index == 4) {
      verticalOffset = 20 * sin(angle);
    }
    
    // Radius for compact layout
    final double radius = 75.0;
    
    // Calculate position from button center
    final double x = radius * cos(angle);
    final double y = radius * sin(angle);
    
    // Button center (right: 30, bottom: 30 for 60px button)
    final double centerX = 30.0;
    final double centerY = 30.0;
    
    // Get gradient colors based on action type
    final List<Color> gradientColors = _getActionGradient(text);
    
    return Positioned(
      right: centerX - x - 25,
      bottom: centerY - y + 30,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: index==4
              ?Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text label with dynamic vertical positioning
                    Transform.translate(
                      offset: Offset(0, verticalOffset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff333333),
                            fontFamily: 'OpenSans',
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // Circular button
                    GestureDetector(
                // behavior: HitTestBehavior.opaque,
                // padding: EdgeInsets.zero,
                onTap: () {
                  //print('Tapped on: $text'); 
                  onTap();
                  _closeMenu();
                },
                child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    )),
                  ],
                )
              :MaterialButton(
                // behavior: HitTestBehavior.opaque,
                padding: EdgeInsets.zero,
                onPressed: () {
                  //print('Tapped on: $text'); 
                  onTap();
                  _closeMenu();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text label with dynamic vertical positioning
                    Transform.translate(
                      offset: Offset(0, verticalOffset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff333333),
                            fontFamily: 'OpenSans',
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // Circular button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
    
  List<Color> _getActionGradient(String actionText) {
    switch (actionText) {
      case 'Give Feedback':
        return [const Color.fromARGB(255, 15, 194, 222), const Color.fromARGB(255, 12, 196, 228)];
      case 'Go to Settings':
        return [const Color(0xff4CAF50), const Color(0xff2E7D32)];
      case 'Report Bug':
        return [const Color(0xffF44336), const Color(0xffC62828)];
      case 'Delete':
        return [const Color(0xffF44336), const Color(0xffC62828)];
      case 'Log Interaction':
        return [const Color(0xff9C27B0), const Color(0xff7B1FA2)];
      case 'Add Group':
        return [const Color(0xffFF9800), const Color(0xffF57C00)];
      case 'Add Contact':
        return [const Color(0xff2196F3), const Color(0xff1976D2)];
      case 'View Stats':
        return [const Color(0xff4CAF50), const Color(0xff388E3C)];
      case 'Settings':
        return [const Color(0xff9E9E9E), const Color(0xff616161)];
      default:
        return [const Color(0xff9C27B0), const Color(0xff7B1FA2)];
    }
  }
}
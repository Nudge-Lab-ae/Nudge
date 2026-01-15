import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nudge/screens/feedback/feedback_bottom_sheet.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';

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

  const FeedbackFloatingButton({
    super.key,
    this.currentSection,
    this.extraActions,
    this.isDeleteMode = false,
    this.onDeletePressed,
    this.deleteButtonLabel = 'Delete',
  });

  @override
  State<FeedbackFloatingButton> createState() => _FeedbackFloatingButtonState();
}

class _FeedbackFloatingButtonState extends State<FeedbackFloatingButton> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250), // Faster animation
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate( // Start from 0.8 instead of 0.7
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
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
    });
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
      _toggleExpanded();
    });
  }

  void _openFeedbackForum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackForumScreen(),
      ),
    ).whenComplete(() {
      _toggleExpanded();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build all menu items including fixed and extra actions
    final allMenuItems = <Map<String, dynamic>>[];
    
    // Fixed actions
    allMenuItems.add({
      'icon': Icons.feedback,
      'text': 'Give Feedback',
      'onTap': () {
        final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
        _showFeedbackDialog(context, currentRoute);
      },
    });
    
    allMenuItems.add({
      'icon': Icons.forum,
      'text': 'View Forum',
      'onTap': () {
        _openFeedbackForum(context);
      },
    });
    
    // allMenuItems.add({
    //   'icon': Icons.bug_report,
    //   'text': 'Report Bug',
    //   'onTap': () {
    //     final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    //     _showFeedbackDialog(context, currentRoute, initialType: 'Bug Report');
    //   },
    // });
    
    // Extra actions
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
      width: _isExpanded ? 130 : 40,
      height: _isExpanded ? 130 : 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Radial menu items on LEFT hemisphere only
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
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 55,  // You can change this to any size
                  height: 55, // You can change this to any size
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isExpanded
                        ? Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: Color(0xff3CB3E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.close, size: 18, color: Colors.white,),
                          )
                        : Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/Nudge-logo.png'),
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(10),
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
  // Calculate angle for a compact quarter sphere (top-left focused)
  // We'll use 60° to 120° range for a tighter spread
  final double startAngle = 120 * (pi / 180);  // Slightly right of top
  final double endAngle = 280 * (pi / 180);   // Slightly left of top
  
  // For multiple items, spread them in the quarter sphere
  final double angleStep = totalItems > 1 ? (endAngle - startAngle) / (totalItems - 1) : 0;
  final double angle = startAngle + (index * angleStep);
  
  // Use a smaller radius for compactness
  final double radius = 45.0;
  
  // Calculate position
  final double x = radius * cos(angle);
  final double y = radius * sin(angle);
  
  // Main button center
  final double centerX = 20.0;
  final double centerY = 30.0;
  
  // Get gradient colors based on action type
  final List<Color> gradientColors = _getActionGradient(text);
  
  return Positioned(
    right: centerX - x - 20, // Smaller offset (20 instead of 30)
    bottom: centerY - y - 20,
    child: FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: MaterialButton(
          padding: text == 'Give Feedback'?EdgeInsets.all(10):EdgeInsets.zero,
          onPressed: () {
            onTap();
            _toggleExpanded();
          },
          child: Container(
            width: 44, // Smaller container
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Icon in center
               
                Center(
                  child: Icon(
                    icon,
                    size: 18, // Smaller icon
                    color: Colors.white,
                  ),
                ),
                 _buildTextTooltip(text, angle),
                // Text tooltip positioned intelligently
                
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildTextTooltip(String text, double angle) {
  // Position text based on angle to avoid cutoff
  // final bool isOnLeftSide = angle > 90 * (pi / 180);
  final bool isOnRightSide = angle < 90 * (pi / 180);
  
  return Positioned(
    left: text == 'Give Feedback' ? -90 : -80,
    right: isOnRightSide ? -80 : null,
    top: angle>250 * (pi / 180) ?0:12,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
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
          fontSize: 10, // Smaller font
          fontWeight: FontWeight.w600,
          color: Color(0xff555555),
        ),
      ),
    ),
  );
}

List<Color> _getActionGradient(String actionText) {
  switch (actionText) {
    case 'Give Feedback':
      return [const Color(0xff3CB3E9), const Color(0xff2D85F6)];
    case 'View Forum':
      return [const Color(0xff4CAF50), const Color(0xff2E7D32)];
    case 'Report Bug':
      return [const Color(0xffF44336), const Color(0xffC62828)];
    case 'Delete':
      return [const Color(0xffF44336), const Color(0xffC62828)];
    default:
      return [const Color(0xff9C27B0), const Color(0xff7B1FA2)];
  }
}
}
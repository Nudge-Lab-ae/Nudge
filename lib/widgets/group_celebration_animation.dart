import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';

class GroupCelebrationAnimation extends StatefulWidget {
  final String groupName;
  final VoidCallback onComplete;
  
  const GroupCelebrationAnimation({
    Key? key,
    required this.groupName,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<GroupCelebrationAnimation> createState() => _GroupCelebrationAnimationState();
}

class _GroupCelebrationAnimationState extends State<GroupCelebrationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Create a curved animation for smooth scaling
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _controller.forward();
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Particle effect - using a simpler approach
        ...List.generate(15, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Calculate progress with individual timing for each particle
              final double progress = (_controller.value - (index * 0.05)).clamp(0.0, 1.0);
              
              if (progress <= 0) return const SizedBox.shrink();
              
              // Random angles based on index
              final double angle = (index * 24.0) * (3.14159 / 180.0);
              final double distance = 150.0 * progress;
              final double xOffset = distance * cos(angle);
              final double yOffset = distance * sin(angle);
              
              // Fade out as they travel
              final double opacity = (1.0 - progress).clamp(0.0, 1.0);
              
              return Positioned(
                left: (MediaQuery.of(context).size.width / 2) - 15 + xOffset,
                top: (MediaQuery.of(context).size.height / 2) - 15 + yOffset,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 20.0 + (index * 2.0),
                    height: 20.0 + (index * 2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [
                        AppColors.lightPrimary,
                        AppColors.vipGold,
                        AppColors.success,
                        AppColors.warning,
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ][index % 6],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        
        // Main celebration animation
        Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Create a pulsing effect by multiplying with a sine wave
              final double pulseFactor = 1.0 + (0.1 * sin(_controller.value * 3.14159 * 4));
              final double scale = _scaleAnimation.value * pulseFactor;
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.lightPrimary.withOpacity(0.9),
                        AppColors.lightPrimary.withOpacity(0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.2, 0.6, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon
                      Transform.scale(
                        scale: 1.0 + (0.2 * sin(_controller.value * 3.14159 * 3)),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          child: Icon(
                            Icons.group_add,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Animated text
                      Opacity(
                        opacity: _controller.value,
                        child: Column(
                          children: [
                            Text(
                              'NEW GROUP!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.groupName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
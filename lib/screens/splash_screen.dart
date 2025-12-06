// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nudge/helpers/restart_helper.dart';
// import '../helpers/app_restart_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _skipAnimation = false;

  @override
  void initState() {
    super.initState();
    
    // Check if we should skip the splash
    _skipAnimation = AppRestartHelper.shouldSkipSplash;
    
    if (_skipAnimation) {
      // Skip animation and navigate immediately
      Timer(const Duration(milliseconds: 50), () {
        _navigateToMain();
      });
      return;
    }
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.forward().then((_) {
          _navigateToMain();
        });
      }
    });
  }

  void _navigateToMain() {
    // Clear the flag after using it
    if (_skipAnimation) {
      AppRestartHelper.clearSkipSplashFlag();
    }
    
    // Navigate to main auth wrapper
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_skipAnimation) {
      // Return empty container during brief delay
      return Container(color: Colors.white);
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: Image.asset(
            'assets/Nudge-logo.jpg',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
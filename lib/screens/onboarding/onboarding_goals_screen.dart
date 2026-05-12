// lib/screens/onboarding/onboarding_goals_screen.dart
// Step 1 of the onboarding sequence — "What matters most to you?"
// Mirrors stitch_nudge_mock_up_v4/onboarding_updated_goals/code.html.
//
// Sits between WelcomeScreen ("Get Started") and the
// register/complete-profile screens. Selected goals are held in
// memory and passed forward via OnboardingState (see main.dart
// routing), so the user can change their mind without an account.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';

/// Canonical onboarding goal options, in the order shown in the mockup.
const List<String> kOnboardingGoals = [
  'Stay connected with people I\'m drifting from',
  'Be more intentional about my relationships',
  'Strengthen my close relationships',
  'Grow and maintain my professional network',
  'Stay close to long-distance family and friends',
  'Reconnect with people from my past',
];

class OnboardingGoalsScreen extends StatefulWidget {
  const OnboardingGoalsScreen({super.key});

  @override
  State<OnboardingGoalsScreen> createState() => _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends State<OnboardingGoalsScreen> {
  final Set<int> _selected = <int>{};

  void _toggle(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _continue() {
    final picked = _selected
        .map((i) => kOnboardingGoals[i])
        .toList(growable: false);
    Navigator.pushNamed(
      context,
      '/register',
      arguments: {'onboardingGoals': picked},
    );
  }

  void _skip() {
    Navigator.pushNamed(
      context,
      '/register',
      arguments: const {'onboardingGoals': <String>[]},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Onboarding is always rendered in the light "Illuminated Scholar"
    // palette — matches Stitch mockup, mirrors walkthrough decision.
    return Theme(
      data: AppTheme.lightTheme(),
      child: Builder(
        builder: (themedContext) {
          final scheme = Theme.of(themedContext).colorScheme;
          return Scaffold(
            backgroundColor: const Color(0xFFFBF6F1),
            body: SafeArea(
              child: Column(
                children: [
                  _OnboardingTopBar(scheme: scheme),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              _ProgressDots(
                                currentStep: 0,
                                total: 3,
                                scheme: scheme,
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'What matters most\nto you?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Select your focus to help us personalize your nudges and reminders.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 28),
                              for (int i = 0; i < kOnboardingGoals.length; i++) ...[
                                _GoalCard(
                                  label: kOnboardingGoals[i],
                                  selected: _selected.contains(i),
                                  onTap: () => _toggle(i),
                                  scheme: scheme,
                                ),
                                const SizedBox(height: 10),
                              ],
                              const SizedBox(height: 16),
                              _ContinueButton(
                                enabled: _selected.isNotEmpty,
                                onTap: _continue,
                                scheme: scheme,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _skip,
                                child: Text(
                                  'I\'ll decide later',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  final ColorScheme scheme;
  const _OnboardingTopBar({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withOpacity(0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            iconSize: 22,
            color: scheme.onSurfaceVariant,
            tooltip: 'Back',
          ),
          const Spacer(),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1A1A1A), Color(0xFF666666)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(bounds),
            child: Text(
              'NUDGE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int currentStep;
  final int total;
  final ColorScheme scheme;
  const _ProgressDots({
    required this.currentStep,
    required this.total,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Container(
            width: 44,
            height: 6,
            decoration: BoxDecoration(
              color: i == currentStep
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  const _GoalCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withOpacity(0.0),
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  key: ValueKey(selected),
                  color: selected ? scheme.primary : scheme.outline,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme scheme;
  const _ContinueButton({
    required this.enabled,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary,
          disabledForegroundColor: scheme.onPrimary,
          elevation: enabled ? 6 : 0,
          shadowColor: scheme.primary.withOpacity(0.35),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        child: const Text('Continue'),
      ),
    );
  }
}

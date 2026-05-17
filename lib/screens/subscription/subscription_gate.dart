// lib/screens/subscription/subscription_gate.dart
//
// Usage:
//   SubscriptionGate(
//     feature: SubscriptionFeature.analytics,
//     child: AnalyticsScreen(),
//   )
//
// Or for contact limit checks:
//   SubscriptionGate.contactLimit(
//     currentCount: contacts.length,
//     child: AddContactButton(),
//   )

import 'package:flutter/material.dart';
import 'package:nudge/models/subscription.dart';
import 'package:nudge/providers/subscription_provider.dart';
import 'package:nudge/screens/subscription/paywall_screen.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';

enum SubscriptionFeature {
  dashboard,
  calendarView,
  groups,
  advancedAnalytics,
  aiInsights,
}

class SubscriptionGate extends StatelessWidget {
  final SubscriptionFeature feature;
  final Widget child;
  final SubscriptionTier? requiredTier;

  const SubscriptionGate({
    super.key,
    required this.feature,
    required this.child,
    this.requiredTier,
  });

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final hasAccess = _hasAccess(sub);

    if (hasAccess) return child;

    return _LockedFeatureScreen(
      feature: feature,
      suggestedTier: requiredTier ?? _minimumTierFor(feature),
    );
  }

  bool _hasAccess(SubscriptionProvider sub) {
    switch (feature) {
      case SubscriptionFeature.dashboard:
        return sub.hasDashboard;
      case SubscriptionFeature.calendarView:
        return sub.hasCalendarView;
      case SubscriptionFeature.groups:
        return sub.hasGroups;
      case SubscriptionFeature.advancedAnalytics:
        return sub.hasAdvancedAnalytics;
      case SubscriptionFeature.aiInsights:
        return sub.hasAIInsights;
    }
  }

  static SubscriptionTier _minimumTierFor(SubscriptionFeature feature) {
    switch (feature) {
      case SubscriptionFeature.advancedAnalytics:
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.plus;
    }
  }
}

// ── Contact limit gate ────────────────────────────────────────────────────────

class ContactLimitGate extends StatelessWidget {
  final int currentCount;
  final Widget child;

  const ContactLimitGate({
    super.key,
    required this.currentCount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    if (sub.canAddContact(currentCount)) return child;

    return _ContactLimitBanner(
      limit: sub.limits.maxContacts,
      tier: sub.tier,
    );
  }
}

// ── Locked feature screen ─────────────────────────────────────────────────────

class _LockedFeatureScreen extends StatelessWidget {
  final SubscriptionFeature feature;
  final SubscriptionTier suggestedTier;

  const _LockedFeatureScreen({
    required this.feature,
    required this.suggestedTier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierName = suggestedTier == SubscriptionTier.pro ? 'Pro' : 'Plus';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                _featureTitle(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Montserrat',
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${_featureTitle()} is available on the $tierName plan and above.',
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PaywallScreen(highlightTier: suggestedTier),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF751FE7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Upgrade to $tierName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe later',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _featureTitle() {
    switch (feature) {
      case SubscriptionFeature.dashboard:
        return 'Analytics Dashboard';
      case SubscriptionFeature.calendarView:
        return 'Calendar View';
      case SubscriptionFeature.groups:
        return 'Groups Management';
      case SubscriptionFeature.advancedAnalytics:
        return 'Advanced Analytics';
      case SubscriptionFeature.aiInsights:
        return 'AI Insights';
    }
  }
}

// ── Contact limit banner ──────────────────────────────────────────────────────

class _ContactLimitBanner extends StatelessWidget {
  final int limit;
  final SubscriptionTier tier;

  const _ContactLimitBanner({required this.limit, required this.tier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextTier =
        tier == SubscriptionTier.free ? SubscriptionTier.plus : SubscriptionTier.pro;
    final nextTierName = nextTier == SubscriptionTier.pro ? 'Pro' : 'Plus';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Contact Limit Reached',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve reached your $limit contact limit on the current plan.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(highlightTier: nextTier),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF751FE7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Upgrade to $nextTierName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline upgrade prompt (for embedding inside lists/screens) ────────────────

class UpgradePromptCard extends StatelessWidget {
  final String message;
  final SubscriptionTier targetTier;

  const UpgradePromptCard({
    super.key,
    required this.message,
    this.targetTier = SubscriptionTier.plus,
  });

  @override
  Widget build(BuildContext context) {
    final tierName = targetTier == SubscriptionTier.pro ? 'Pro' : 'Plus';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaywallScreen(highlightTier: targetTier),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF751FE7).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF751FE7).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline,
                size: 18, color: Color(0xFF751FE7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF751FE7)),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: Color(0xFF751FE7)),
          ],
        ),
      ),
    );
  }
}

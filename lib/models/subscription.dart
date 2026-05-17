// lib/models/subscription.dart

enum SubscriptionTier { free, plus, pro }

enum SubscriptionStatus { active, trial, expired, cancelled, inactive }

class SubscriptionLimits {
  final int maxContacts;
  final bool hasDashboard;
  final bool hasCalendarView;
  final bool hasGroups;
  final bool hasAdvancedAnalytics;
  final bool hasUnlimitedGroups;
  final bool hasSocialUniverse;

  const SubscriptionLimits({
    required this.maxContacts,
    required this.hasDashboard,
    required this.hasCalendarView,
    required this.hasGroups,
    required this.hasAdvancedAnalytics,
    required this.hasUnlimitedGroups,
    required this.hasSocialUniverse,
  });
}

class NudgeSubscription {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? periodEnd;

  const NudgeSubscription({
    required this.tier,
    required this.status,
    this.periodEnd,
  });

  static const NudgeSubscription free = NudgeSubscription(
    tier: SubscriptionTier.free,
    status: SubscriptionStatus.inactive,
  );

  static const Map<SubscriptionTier, SubscriptionLimits> limits = {
    SubscriptionTier.free: SubscriptionLimits(
      maxContacts: 15,
      hasDashboard: false,
      hasCalendarView: false,
      hasGroups: false,
      hasAdvancedAnalytics: false,
      hasUnlimitedGroups: false,
      hasSocialUniverse: true,
    ),
    SubscriptionTier.plus: SubscriptionLimits(
      maxContacts: 50,
      hasDashboard: true,
      hasCalendarView: true,
      hasGroups: true,
      hasAdvancedAnalytics: false,
      hasUnlimitedGroups: false,
      hasSocialUniverse: true,
    ),
    SubscriptionTier.pro: SubscriptionLimits(
      maxContacts: 150,
      hasDashboard: true,
      hasCalendarView: true,
      hasGroups: true,
      hasAdvancedAnalytics: true,
      hasUnlimitedGroups: true,
      hasSocialUniverse: true,
    ),
  };

  // Trial gives all Pro features but keeps the free contact cap (15).
  // Users can explore every feature without needing to add more contacts.
  static const SubscriptionLimits trialLimits = SubscriptionLimits(
    maxContacts: 15,
    hasDashboard: true,
    hasCalendarView: true,
    hasGroups: true,
    hasAdvancedAnalytics: true,
    hasUnlimitedGroups: true,
    hasSocialUniverse: true,
  );

  SubscriptionLimits get currentLimits {
    if (isTrial) return trialLimits;
    return limits[tier] ?? limits[SubscriptionTier.free]!;
  }

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trial;

  bool get isTrial => status == SubscriptionStatus.trial;

  String get tierName {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.plus:
        return 'Plus';
      case SubscriptionTier.pro:
        return 'Pro';
    }
  }

  String get tierTagline {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Stay Connected';
      case SubscriptionTier.plus:
        return 'Nurture Intentionally';
      case SubscriptionTier.pro:
        return 'Master Your Relationships';
    }
  }

  static SubscriptionTier tierFromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'plus':
        return SubscriptionTier.plus;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  static SubscriptionStatus statusFromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'trial':
        return SubscriptionStatus.trial;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.inactive;
    }
  }
}

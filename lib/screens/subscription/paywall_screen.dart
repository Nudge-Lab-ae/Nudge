// lib/screens/subscription/paywall_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/subscription.dart';
import 'package:nudge/providers/subscription_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaywallScreen extends StatelessWidget {
  /// Pre-select a tier to highlight (optional)
  final SubscriptionTier? highlightTier;

  const PaywallScreen({super.key, this.highlightTier});

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Choose Your Plan',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontFamily: 'Montserrat',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sub.isTrial) _buildTrialBanner(context, sub),
            const SizedBox(height: 16),
            _PlanCard(
              tier: SubscriptionTier.free,
              title: 'Free',
              tagline: 'Stay Connected',
              price: 'Free forever',
              features: const [
                '15 contacts',
                'Full Social Universe',
                'Basic nudge reminders',
              ],
              lockedFeatures: const [
                'Analytics dashboard',
                'Calendar view',
                'Groups management',
              ],
              isCurrent: sub.tier == SubscriptionTier.free && !sub.isTrial,
              isHighlighted: false,
              onUpgrade: null,
            ),
            const SizedBox(height: 16),
            _PlanCard(
              tier: SubscriptionTier.plus,
              title: 'Plus',
              tagline: 'Nurture Intentionally',
              price: '\$7.99/mo',
              priceSub: 'or \$59.99/yr — save 37%',
              features: const [
                '50 contacts',
                'Analytics dashboard',
                'Calendar view',
                'Groups management',
                'Full Social Universe',
              ],
              lockedFeatures: const [
                'Advanced analytics',
                'Unlimited groups',
              ],
              isCurrent: sub.tier == SubscriptionTier.plus && sub.isActive,
              isHighlighted: highlightTier == SubscriptionTier.plus ||
                  highlightTier == null,
              onUpgrade: () => _openPricing(context, 'plus'),
            ),
            const SizedBox(height: 16),
            _PlanCard(
              tier: SubscriptionTier.pro,
              title: 'Pro',
              tagline: 'Master Your Relationships',
              price: '\$14.99/mo',
              priceSub: 'or \$119.99/yr — save 33%',
              features: const [
                '150 contacts',
                'Advanced analytics',
                'Unlimited groups',
                'Calendar view',
                'Full Social Universe',
                'Priority features',
              ],
              lockedFeatures: const [],
              isCurrent: sub.tier == SubscriptionTier.pro && sub.isActive &&
                  !sub.isTrial,
              isHighlighted: highlightTier == SubscriptionTier.pro,
              onUpgrade: () => _openPricing(context, 'pro'),
            ),
            const SizedBox(height: 24),
            Text(
              'All plans include a 14-day free Pro trial for new members.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openUrl('https://nudgeapp.ae/terms'),
              child: Text(
                'Terms of Service  ·  Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialBanner(BuildContext context, SubscriptionProvider sub) {
    final daysLeft = sub.subscription.periodEnd != null
        ? sub.subscription.periodEnd!.difference(DateTime.now()).inDays
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You\'re on a Pro trial — $daysLeft day${daysLeft == 1 ? '' : 's'} left. Upgrade to keep full access.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPricing(BuildContext context, String plan) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final uri = Uri.parse(
      'https://nudgeapp.ae/pricing?email=${Uri.encodeComponent(email)}&source=app&plan=$plan',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open pricing page')),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final String title;
  final String tagline;
  final String price;
  final String? priceSub;
  final List<String> features;
  final List<String> lockedFeatures;
  final bool isCurrent;
  final bool isHighlighted;
  final VoidCallback? onUpgrade;

  const _PlanCard({
    required this.tier,
    required this.title,
    required this.tagline,
    required this.price,
    this.priceSub,
    required this.features,
    required this.lockedFeatures,
    required this.isCurrent,
    required this.isHighlighted,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPurple = tier == SubscriptionTier.plus || tier == SubscriptionTier.pro;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted && isPurple
            ? const Color(0xFF751FE7).withOpacity(0.08)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted && isPurple
              ? const Color(0xFF751FE7)
              : theme.colorScheme.outline.withOpacity(0.3),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Montserrat',
                            color: isPurple
                                ? const Color(0xFF751FE7)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      tagline,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (priceSub != null)
                    Text(
                      priceSub!,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => _FeatureRow(label: f, locked: false)),
          ...lockedFeatures.map((f) => _FeatureRow(label: f, locked: true)),
          if (onUpgrade != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: isCurrent ? null : onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent
                      ? theme.colorScheme.surfaceContainerHighest
                      : const Color(0xFF751FE7),
                  foregroundColor: isCurrent
                      ? theme.colorScheme.onSurfaceVariant
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isCurrent ? 'Current Plan' : 'Upgrade to $title',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final bool locked;

  const _FeatureRow({required this.label, required this.locked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            locked ? Icons.lock_outline : Icons.check_circle_outline,
            size: 16,
            color: locked
                ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                : AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: locked
                  ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

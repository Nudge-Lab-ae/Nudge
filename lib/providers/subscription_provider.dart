// lib/providers/subscription_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';

class SubscriptionProvider extends ChangeNotifier {
  static const _cacheKey = 'nudge_subscription_cache';
  static const _trialKey = 'nudge_trial_started_at';
  static const _trialDays = 14;
  static const _apiBase = 'https://nudgeapp.ae/api/subscription';

  NudgeSubscription _subscription = NudgeSubscription.free;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _firestoreListener;

  NudgeSubscription get subscription => _subscription;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SubscriptionLimits get limits => _subscription.currentLimits;
  SubscriptionTier get tier => _subscription.tier;
  bool get isFree => _subscription.tier == SubscriptionTier.free;
  bool get isPlus => _subscription.tier == SubscriptionTier.plus;
  bool get isPro => _subscription.tier == SubscriptionTier.pro;
  bool get isPaid => !isFree;
  bool get isTrial => _subscription.isTrial;

  bool canAddContact(int currentCount) =>
      currentCount < _subscription.currentLimits.maxContacts;

  bool get hasDashboard => _subscription.currentLimits.hasDashboard;
  bool get hasCalendarView => _subscription.currentLimits.hasCalendarView;
  bool get hasGroups => _subscription.currentLimits.hasGroups;
  bool get hasAdvancedAnalytics =>
      _subscription.currentLimits.hasAdvancedAnalytics;
  bool get hasUnlimitedGroups =>
      _subscription.currentLimits.hasUnlimitedGroups;

  /// -1 means unlimited
  int get dailyAILimit => isFree ? 5 : -1;
  bool get hasAIInsights => !isFree;

  /// Call once after the user is authenticated.
  Future<void> init(String userEmail) async {
    await _loadFromCache();
    await _checkTrial();
    await refreshFromApi(userEmail);
    _listenToFirestore();
  }

  /// Re-poll after returning from the payment website via deep link.
  Future<void> refreshFromApi(String userEmail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$_apiBase?email=${Uri.encodeComponent(userEmail)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tier = NudgeSubscription.tierFromString(data['plan'] as String?);
        final status =
            NudgeSubscription.statusFromString(data['status'] as String?);
        final periodEndStr = data['periodEnd'] as String?;
        final periodEnd =
            periodEndStr != null ? DateTime.tryParse(periodEndStr) : null;

        // Only upgrade/change if API returned something meaningful
        if (status == SubscriptionStatus.active) {
          _subscription = NudgeSubscription(
            tier: tier,
            status: status,
            periodEnd: periodEnd,
          );
          await _saveToCache();
        } else if (status == SubscriptionStatus.cancelled ||
            status == SubscriptionStatus.expired) {
          // Revert to free if subscription lapsed
          _subscription = NudgeSubscription.free;
          await _saveToCache();
        }
        // If API returns inactive/unknown and user is still in trial, keep trial
      }
    } catch (_) {
      // API unreachable — keep whatever state we have (cache or trial)
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Called when the `nudge://subscription/success` deep link fires.
  Future<void> handleDeepLink(String plan, String email) async {
    // Optimistically apply the tier right away so the UI updates instantly
    final tier = NudgeSubscription.tierFromString(plan);
    _subscription = NudgeSubscription(
      tier: tier,
      status: SubscriptionStatus.active,
      periodEnd: DateTime.now().add(const Duration(days: 30)),
    );
    notifyListeners();

    // Then confirm with the real API
    await refreshFromApi(email);
  }

  // ── Trial logic ──────────────────────────────────────────────────────────

  Future<void> _checkTrial() async {
    // Skip trial check if already on a paid plan from cache
    if (_subscription.tier != SubscriptionTier.free) return;

    final prefs = await SharedPreferences.getInstance();
    final trialStartMs = prefs.getInt(_trialKey);

    if (trialStartMs == null) {
      // First launch for this user — start the trial and persist it.
      // Also try to sync with Firestore.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_trialKey, now);
        await _persistTrialToFirestore(uid, now);
        _subscription = NudgeSubscription(
          tier: SubscriptionTier.pro,
          status: SubscriptionStatus.trial,
          periodEnd: DateTime.now().add(const Duration(days: _trialDays)),
        );
        notifyListeners();
      }
      return;
    }

    final trialStart = DateTime.fromMillisecondsSinceEpoch(trialStartMs);
    final trialEnd = trialStart.add(const Duration(days: _trialDays));
    if (DateTime.now().isBefore(trialEnd)) {
      _subscription = NudgeSubscription(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.trial,
        periodEnd: trialEnd,
      );
      notifyListeners();
    }
    // else: trial expired, stays on free
  }

  Future<void> _persistTrialToFirestore(String uid, int trialStartMs) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'trialStartedAt': trialStartMs,
      });
    } catch (_) {
      // Non-critical — SharedPreferences is the primary source for trial
    }
  }

  // ── Firestore listener (catches webhook-driven updates) ──────────────────

  void _listenToFirestore() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _firestoreListener?.cancel();
    _firestoreListener = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final tierStr = data['subscriptionTier'] as String?;
      final statusStr = data['subscriptionStatus'] as String?;
      final expiryMs = data['subscriptionExpiresAt'] as int?;

      if (tierStr != null && statusStr != null) {
        final tier = NudgeSubscription.tierFromString(tierStr);
        final status = NudgeSubscription.statusFromString(statusStr);
        final expiry = expiryMs != null
            ? DateTime.fromMillisecondsSinceEpoch(expiryMs)
            : null;

        // Only update from Firestore if it reflects an active paid subscription
        if (status == SubscriptionStatus.active) {
          _subscription = NudgeSubscription(
            tier: tier,
            status: status,
            periodEnd: expiry,
          );
          _saveToCache();
          notifyListeners();
        }
      }
    });
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'tier': _subscription.tier.name,
      'status': _subscription.status.name,
      'periodEnd': _subscription.periodEnd?.millisecondsSinceEpoch,
    };
    await prefs.setString(_cacheKey, jsonEncode(data));
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tier = NudgeSubscription.tierFromString(data['tier'] as String?);
      final status =
          NudgeSubscription.statusFromString(data['status'] as String?);
      final periodEndMs = data['periodEnd'] as int?;
      final periodEnd = periodEndMs != null
          ? DateTime.fromMillisecondsSinceEpoch(periodEndMs)
          : null;

      // Don't trust a cached paid subscription that has clearly expired
      if (status == SubscriptionStatus.active &&
          periodEnd != null &&
          periodEnd.isBefore(DateTime.now())) {
        _subscription = NudgeSubscription.free;
      } else {
        _subscription = NudgeSubscription(
          tier: tier,
          status: status,
          periodEnd: periodEnd,
        );
      }
    } catch (_) {
      // Ignore corrupt cache
    }
  }

  Future<void> clearSubscription() async {
    _subscription = NudgeSubscription.free;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_trialKey);
    _firestoreListener?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreListener?.cancel();
    super.dispose();
  }
}

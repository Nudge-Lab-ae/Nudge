// lib/screens/digest/reflection_digest_modal.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReflectionDigestModal
//
// A 3-step bottom sheet that runs bi-weekly (default) to help users reflect
// on their Close Circle. Results feed the Needs Attention list and Smart
// Scheduling logic.
//
// Usage — call from DashboardScreen after checking digest due date:
//
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => ReflectionDigestModal(
//       closeCircleContacts: innerRingContacts,
//       apiService: apiService,
//       isDarkMode: themeProvider.isDarkMode,
//     ),
//   );
// ─────────────────────────────────────────────────────────────────────────────

class ReflectionDigestModal extends StatefulWidget {
  /// Contacts in the user's inner ring ('inner' computedRing value).
  final List<Contact> closeCircleContacts;
  final ApiService apiService;
  final bool isDarkMode;
  // final Function onComplete;

  const ReflectionDigestModal({
    super.key,
    required this.closeCircleContacts,
    required this.apiService,
    required this.isDarkMode,
    // required this.onComplete,
  });

  @override
  State<ReflectionDigestModal> createState() => _ReflectionDigestModalState();
}

class _ReflectionDigestModalState extends State<ReflectionDigestModal>
    with SingleTickerProviderStateMixin {
  // ── Step state ─────────────────────────────────────────────────────────────
  int _step = 0; // 0 = Q1 (connected), 1 = Q2 (intentional), 2 = Q3 (avatar grid)

  // ── Answer state ───────────────────────────────────────────────────────────
  int _connectedScore = 0;    // 1–5, 0 = unanswered
  int _intentionalScore = 0;  // 1–5, 0 = unanswered
  final Set<String> _needsAttentionIds = {};
  bool _allGoodSelected = false;

  // ── Submission state ───────────────────────────────────────────────────────
  bool _isSubmitting = false;
  bool _submitted = false;

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // ── Question copy ──────────────────────────────────────────────────────────
  static const List<String> _connectedEmojis   = ['😔', '😐', '🙂', '😄', '💞'];
  static const List<String> _intentionalEmojis = ['😔', '😐', '🙂', '😄', '🔥'];
  static const List<String> _moodLabels = [
    'Distant', 'Okay', 'Good', 'Great', 'Amazing',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _connectedScore > 0;
      case 1:
        return _intentionalScore > 0;
      case 2:
        return _allGoodSelected || _needsAttentionIds.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _advance() async {
    HapticFeedback.lightImpact();
    if (_step < 2) {
      await _fadeController.reverse();
      setState(() => _step++);
      await _fadeController.forward();
    } else {
      await _submitDigest();
    }
  }

  Future<void> _submitDigest() async {
    setState(() => _isSubmitting = true);
    print('submitting digest');

    try {
      await widget.apiService.saveDigestReflection(
        connectedScore: _connectedScore,
        intentionalScore: _intentionalScore,
        needsAttentionContactIds: _needsAttentionIds.toList(),
      );

      // Persist the timestamp so we don't prompt again for 14 days
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_digest_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });

        // Auto-close after showing the confirmation message
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong — please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bg = themeProvider.getSurfaceColor(context);
    final textPrimary = themeProvider.getTextPrimaryColor(context);
    final textSecondary = themeProvider.getTextSecondaryColor(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.87,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────────────
          _buildHandle(),

          // ── Progress bar ───────────────────────────────────────────────────
          if (!_submitted) _buildProgressBar(),

          // ── Header ─────────────────────────────────────────────────────────
          _buildHeader(textPrimary, textSecondary),

          // ── Content (fades between steps) ──────────────────────────────────
          Expanded(
            child: _submitted
                ? _buildConfirmation(textPrimary, textSecondary)
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildCurrentStep(textPrimary, textSecondary),
                  ),
          ),

          // ── CTA button ─────────────────────────────────────────────────────
          if (!_submitted)
            _buildCTAButton(themeProvider),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.grey.shade600
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: List.generate(3, (i) {
          final filled = i <= _step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: filled
                    ? AppTheme.primaryColor
                    : (widget.isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade200),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bi-Weekly Reflection',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'OpenSans',
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Take a moment to reflect on your Close Circle 🌿',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'OpenSans',
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(Color textPrimary, Color textSecondary) {
    switch (_step) {
      case 0:
        return _buildEmojiScale(
          question: 'How connected did you feel with your Close Circle this week?',
          emojis: _connectedEmojis,
          selected: _connectedScore,
          onSelect: (v) => setState(() => _connectedScore = v),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 1:
        return _buildEmojiScale(
          question: 'How intentional were your interactions with them?',
          emojis: _intentionalEmojis,
          selected: _intentionalScore,
          onSelect: (v) => setState(() => _intentionalScore = v),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 2:
        return _buildAvatarGrid(textPrimary, textSecondary);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmojiScale({
    required String question,
    required List<String> emojis,
    required int selected,
    required ValueChanged<int> onSelect,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'OpenSans',
              color: textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(emojis.length, (i) {
              final value = i + 1;
              final isSelected = selected == value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  width: isSelected ? 64 : 54,
                  height: isSelected ? 64 : 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(
                            widget.isDarkMode ? 0.25 : 0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      emojis[i],
                      style: TextStyle(fontSize: isSelected ? 34 : 28),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(emojis.length, (i) {
              final value = i + 1;
              final isSelected = selected == value;
              return SizedBox(
                width: 54,
                child: Text(
                  _moodLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'OpenSans',
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : textSecondary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid(Color textPrimary, Color textSecondary) {
    // Sort so already-selected contacts appear first
    final sorted = List<Contact>.from(widget.closeCircleContacts)
      ..sort((a, b) {
        final aSelected = _needsAttentionIds.contains(a.id) ? 0 : 1;
        final bSelected = _needsAttentionIds.contains(b.id) ? 0 : 1;
        return aSelected.compareTo(bSelected);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(
            'Was there anyone you wish you\'d connected with more?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'OpenSans',
              color: textPrimary,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 20,
              childAspectRatio: 0.72,
            ),
            // +1 for the "All good!" option at the end
            itemCount: sorted.length + 1,
            itemBuilder: (context, index) {
              if (index == sorted.length) {
                return _buildAllGoodTile(textSecondary);
              }
              return _buildContactTile(sorted[index], textSecondary);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContactTile(Contact contact, Color textSecondary) {
    final isSelected = _needsAttentionIds.contains(contact.id);
    final initials = contact.name.isNotEmpty
        ? contact.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _allGoodSelected = false;
          if (isSelected) {
            _needsAttentionIds.remove(contact.id);
          } else {
            _needsAttentionIds.add(contact.id);
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Selection ring
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              // Avatar
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: contact.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: contact.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _avatarFallback(initials),
                          errorWidget: (_, __, ___) => _avatarFallback(initials),
                        )
                      : _avatarFallback(initials),
                ),
              ),
              // Check badge
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor,
                      border: Border.all(
                        color: widget.isDarkMode
                            ? AppTheme.darkSurface
                            : AppTheme.lightSurface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            contact.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'OpenSans',
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected ? AppTheme.primaryColor : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllGoodTile(Color textSecondary) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _allGoodSelected = !_allGoodSelected;
          if (_allGoodSelected) _needsAttentionIds.clear();
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _allGoodSelected
                  ? AppTheme.successColor.withOpacity(
                      widget.isDarkMode ? 0.25 : 0.12)
                  : (widget.isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade100),
              border: Border.all(
                color: _allGoodSelected
                    ? AppTheme.successColor
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '👌',
                style: TextStyle(fontSize: _allGoodSelected ? 30 : 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All good!',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'OpenSans',
              fontWeight: _allGoodSelected
                  ? FontWeight.w700
                  : FontWeight.normal,
              color: _allGoodSelected
                  ? AppTheme.successColor
                  : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              'Thanks for checking in!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'OpenSans',
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _needsAttentionIds.isNotEmpty
                  ? 'We\'ll prioritize your Close Circle over the next two weeks based on your reflections.'
                  : 'Great — your Close Circle is looking healthy. Keep it up!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'OpenSans',
                color: textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTAButton(ThemeProvider themeProvider) {
    final isLastStep = _step == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _canAdvance && !_isSubmitting ? _advance : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: widget.isDarkMode
                ? Colors.grey.shade700
                : Colors.grey.shade200,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isLastStep ? 'Done reflecting' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'OpenSans',
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String initials) {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.15),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'OpenSans',
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Static helper — call from DashboardScreen.initState() to check if the
// digest is due and show the modal automatically.
//
// Example usage in DashboardScreen:
//
//   @override
//   void initState() {
//     super.initState();
//     // ... existing init calls ...
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkAndShowDigest();
//     });
//   }
//
//   Future<void> _checkAndShowDigest() async {
//     final contacts = await apiService.getAllContacts();
//     final innerRing = contacts
//         .where((c) => c.computedRing == 'inner')
//         .toList();
//     if (innerRing.isEmpty) return;
//
//     await DigestScheduler.showIfDue(
//       context: context,
//       closeCircleContacts: innerRing,
//       apiService: apiService,
//       isDarkMode: themeProvider.isDarkMode,
//     );
//   }
// ─────────────────────────────────────────────────────────────────────────────

class DigestScheduler {
  /// Default interval in days between digest prompts.
  static const int _defaultIntervalDays = 14;
  static bool _shownThisSession = false;

  /// SharedPreferences key for the last digest timestamp.
  static const String _lastDigestKey = 'last_digest_timestamp';

  /// Returns true if the digest is due based on the stored last-shown date.
  static Future<bool> isDue() async {
    if (_shownThisSession) return false;   
    final prefs = await SharedPreferences.getInstance();
    final lastTimestamp = prefs.getInt(_lastDigestKey) ?? 0;
    if (lastTimestamp == 0) return true; // First time ever
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastTimestamp))
        .inDays;
    return daysSince >= _defaultIntervalDays;
  }

  /// Checks if the digest is due and, if so, shows the modal.
  /// Adds a short delay so the dashboard can fully render first.
  static Future<void> showIfDue({
    required BuildContext context,
    required List<Contact> closeCircleContacts,
    required ApiService apiService,
    required bool isDarkMode,
  }) async {
    if (closeCircleContacts.isEmpty) return;
    if (!await isDue()) return;

    _shownThisSession = true;

    // Small delay so the dashboard renders before the sheet appears
    await Future.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // User must complete or swipe to dismiss
      enableDrag: true,
      builder: (_) => ReflectionDigestModal(
        closeCircleContacts: closeCircleContacts,
        apiService: apiService,
        isDarkMode: isDarkMode,
      ),
    );
  }
}
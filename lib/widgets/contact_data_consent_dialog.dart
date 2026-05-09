// lib/widgets/contact_data_consent_dialog.dart
//
// Shows a one-time consent dialog before any contact data is uploaded.
// Stores acceptance in SharedPreferences so it is only shown once.
// Apple Guideline 5.1.2 compliance.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:provider/provider.dart';

const String _kConsentKey = 'nudge_contact_upload_consent_v1';
const String _kPrivacyPolicyUrl =
    'https://www.freeprivacypolicy.com/live/25cee199-538c-4c40-8fae-dbc5f4a128a0';

/// Returns true if the user has already accepted consent in a previous session.
Future<bool> hasContactUploadConsent() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kConsentKey) ?? false;
}

/// Persists the user's acceptance.
Future<void> saveContactUploadConsent() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kConsentKey, true);
}

/// Shows the consent dialog if consent has not been given yet.
/// Returns true if the user agrees (either now or previously).
/// Returns false if the user cancels — caller should abort the import.
Future<bool> requestContactUploadConsentIfNeeded(BuildContext context) async {
  if (await hasContactUploadConsent()) return true;

  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ContactConsentDialog(),
  );

  return agreed == true;
}

class _ContactConsentDialog extends StatelessWidget {
  const _ContactConsentDialog();

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_kPrivacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    final bg = isDark
        ? AppColors.darkSurfaceContainerHigh
        : Colors.white;
    final textPrimary = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final textSecondary = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;
    const brandPurple = Color(0xFF751FE7);

    final bulletStyle = TextStyle(
      fontSize: 13,
      height: 1.55,
      color: textSecondary,
      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    );

    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: brandPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: bulletStyle)),
            ],
          ),
        );

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon + title ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: brandPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.contacts_rounded,
                      color: brandPurple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Before we import your contacts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Intro line ────────────────────────────────────────────────
            Text(
              'Nudge will securely upload your selected contacts to our servers to power your Social Universe and nudge reminders. Here is what you should know:',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: textSecondary,
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
              ),
            ),

            const SizedBox(height: 14),

            // ── Bullet points ─────────────────────────────────────────────
            bullet(
              'Contact names, phone numbers, and email addresses will be uploaded to Nudge\'s secure servers.',
            ),
            bullet(
              'This data is used exclusively to build your Social Universe, schedule nudge reminders, and help you manage your relationships.',
            ),
            bullet(
              'We do not sell or share your contact data with third parties.',
            ),
            bullet(
              'You can delete all your contacts and account data at any time from Settings → Delete Account.',
            ),

            const SizedBox(height: 14),

            // ── Privacy Policy link ───────────────────────────────────────
            GestureDetector(
              onTap: _openPrivacyPolicy,
              child: Text(
                'Read our full Privacy Policy →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: brandPurple,
                  decoration: TextDecoration.underline,
                  decorationColor: brandPurple,
                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Buttons ───────────────────────────────────────────────────
            Row(
              children: [
                // Cancel
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : const Color(0xFFD0CCC8)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Agree
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await saveContactUploadConsent();
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'I Agree',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

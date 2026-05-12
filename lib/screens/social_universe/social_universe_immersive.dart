// lib/screens/social_universe/social_universe_immersive.dart
//
// Wrapper for the immersive Social Universe view. Per
// `social_universe_brighter_glow_2` mockup: top app bar with the NUDGE
// wordmark (near-black gradient) plus a strategic info button at the
// right that surfaces the 5-page walkthrough. The underlying
// SocialUniverseWidget visualization is unchanged — re-styling the
// widget itself is scoped for a separate phase.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/contact_detail_modal.dart';
import 'package:nudge/widgets/social_universe.dart';
import 'package:provider/provider.dart';

class SocialUniverseImmersiveScreen extends StatelessWidget {
  const SocialUniverseImmersiveScreen({super.key});

  // Near-black background per Stitch brighter-glow mockup (#1A1816).
  static const Color _spaceBackground = Color(0xFF1A1816);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: _spaceBackground,
      body: Stack(
        children: [
          // Universe visualization (unchanged).
          StreamProvider<List<Contact>>.value(
            value: apiService.getContactsStream(),
            initialData: const [],
            child: Consumer<List<Contact>>(
              builder: (context, contacts, child) {
                return SocialUniverseWidget(
                  contacts: contacts,
                  showTitle: true,
                  onContactView: (contact, ringToUse) {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      isScrollControlled: true,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      builder: (context) {
                        return ContactDetailsModal(
                          contact: contact,
                          apiService: apiService,
                          displayRing: ringToUse,
                        );
                      },
                    );
                  },
                  isImmersive: true,
                  isDarkMode: themeProvider.isDarkMode,
                  onExitImmersive: () {
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),

          // Top app bar overlay (NUDGE wordmark + info button).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _UniverseTopBar(
                onInfoTap: () => Navigator.pushNamed(context, '/walkthrough'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UniverseTopBar extends StatelessWidget {
  final VoidCallback onInfoTap;
  const _UniverseTopBar({required this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1A1816),
            Color(0x001A1816),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // NUDGE wordmark — light gradient against dark canvas
          // (mirrors the near-black gradient used elsewhere, inverted
          // for legibility on the dark Social Universe background).
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE7E1DE), Color(0xFF968DA1)],
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
          _InfoButton(onTap: onInfoTap),
        ],
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InfoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: 'How to read your Social Universe',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFA775FF).withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF751FE7).withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD4BBFF),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

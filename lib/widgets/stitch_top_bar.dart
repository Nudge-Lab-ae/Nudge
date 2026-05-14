import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';

/// Stitch v4 canonical top bar: NUDGE wordmark with optional back arrow on the
/// left and a configurable trailing affordance (avatar, settings cog, etc.) on
/// the right. Sized to slot into a SliverAppBar(title:) or as a Row in a
/// Column-based layout.
class StitchTopBar extends StatelessWidget {
  final bool showBack;
  final String? avatarUrl;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onBack;

  const StitchTopBar({
    super.key,
    this.showBack = false,
    this.avatarUrl,
    this.trailingIcon,
    this.onTrailingTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    Widget trailing;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      trailing = GestureDetector(
        onTap: onTrailingTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.lightPrimary.withOpacity(0.15),
              width: 2,
            ),
            image: DecorationImage(
              image: NetworkImage(avatarUrl!),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else if (trailingIcon != null) {
      trailing = GestureDetector(
        onTap: onTrailingTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceContainerHigh,
          ),
          child: Icon(trailingIcon, size: 20, color: scheme.onSurface),
        ),
      );
    } else {
      trailing = const SizedBox(width: 40, height: 40);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBack) ...[
                GestureDetector(
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHigh,
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20, color: scheme.onSurface),
                  ),
                ),
              ],
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isDark
                      ? const [Color(0xFFE7E1DE), Color(0xFF968DA1)]
                      : const [Color(0xFF1A1A1A), Color(0xFF666666)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ).createShader(bounds),
                child: Text(
                  'NUDGE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          trailing,
        ],
      ),
    );
  }
}

/// A shared "section title + subtitle" hero used at the top of redesigned
/// screens (Settings, Contacts, Groups, Notifications, Feedback Forum).
class StitchScreenTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsets padding;

  const StitchScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cream/dark surface card with the canonical 32px corner radius and the
/// soft drop shadow used across Stitch v4 mockups.
class StitchCard extends StatelessWidget {
  final EdgeInsets padding;
  final Widget child;
  final Color? color;
  final Border? border;

  const StitchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // Cards are pure white (no border) per Stitch v4 spec.
        // Dark theme keeps the darker surface tone.
        color: color ??
            (isDark ? scheme.surfaceContainerHigh : Colors.white),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

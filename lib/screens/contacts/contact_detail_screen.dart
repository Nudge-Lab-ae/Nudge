// contact_detail_screen.dart - Updated with StreamBuilder for real-time updates
import 'dart:io';
import 'dart:math';
// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
// import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/message_service.dart';
// import 'package:nudge/widgets/add_touchpoint_modal.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/log_interaction_modal.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
import '../../providers/theme_provider.dart';
// import '../../theme/app_theme.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:confetti/confetti.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;
  final bool showConfetti;
  final Function? navigate;
  
  const ContactDetailScreen({super.key, required this.contact, this.showConfetti = false, this.navigate});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  bool _isUpdatingVIP = false;
  late ConfettiController _confettiController; // Add this
  bool _showConfetti = false; 
  bool _isUpdatingAttention = false;
  late FeedbackFloatingButtonController _fabController;

  @override
  void initState() {
    super.initState();
     _confettiController = ConfettiController(duration: const Duration(seconds: 8));
    
    // Check if we should show confetti (newly created contact)
    if (widget.showConfetti) {
      // Small delay to ensure the UI is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showConfetti = true;
        });
        _confettiController.play();

        // Flushbar(
        //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
        //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
        //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
        //   backgroundColor: AppColors.success,
        //   messageText: Center(
        //       child: Text('Successfully added contact', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
        //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
        // ).show(context);

        TopMessageService().showMessage(
                  context: context,
                  message: 'Successfully added contact!',
                  backgroundColor: AppColors.success,
                  icon: Icons.check_circle,
                );
        
        // Auto-hide confetti after animation
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showConfetti = false;
            });
          }
        });
      });
    }
     _fabController = FeedbackFloatingButtonController();

  }

  @override
  void dispose() {
    _confettiController.dispose(); // Add this
    _fabController = FeedbackFloatingButtonController();
    super.dispose();
  }

  Future<void> _toggleVIPStatus(bool isVIP, Contact contact) async {
    if (_isUpdatingVIP) return;
    
    setState(() {
      _isUpdatingVIP = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final updatedContact = contact.copyWith(isVIP: isVIP);
        await apiService.updateContact(updatedContact);
        
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(isVIP ? 'Added to Favourites' : 'Removed from Favourites')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: isVIP ? 'Added to Favourites' : 'Removed from Favourites',
          backgroundColor: isVIP?AppColors.success:Colors.blueGrey,
          icon: Icons.check,
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error updating Favourites status: $e')),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'Error updating Favourites status: $e',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
    } finally {
      setState(() {
        _isUpdatingVIP = false;
      });
    }
  }

  Future<void> _toggleNeedsAttention(bool mark, Contact contact) async {
    if (_isUpdatingAttention) return;

    setState(() {
      _isUpdatingAttention = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Build the updated contact locally so the StreamBuilder re-renders
      // immediately without waiting for Firestore to echo back.
      final updatedContact = mark
          ? contact.copyWith(
              needsAttention: true,
              attentionSource: 'manual',
              attentionSince: DateTime.now(),
            )
          : contact.copyWith(
              needsAttention: false,
              // Sentinel pattern clears the nullable fields entirely.
              attentionSource: null,
              attentionSince: null,
            );

      await apiService.updateContact(updatedContact);

      TopMessageService().showMessage(
        context: context,
        message: mark
            ? '${contact.name} added to Needs Attention'
            : 'Removed from Needs Attention',
        backgroundColor: mark ? Color(0xFF1D9E75) : Colors.blueGrey,
        icon: mark ? Icons.flag_rounded : Icons.flag_outlined,
      );
    } catch (e) {
      TopMessageService().showMessage(
        context: context,
        message: 'Could not update Needs Attention: $e',
        backgroundColor: AppColors.lightError,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        _isUpdatingAttention = false;
      });
    }
  }

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    
    // Trim and split the name by spaces
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      // Has at least first and last name - get first letter of first and last name
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      // Only first name available
      return parts.first[0].toUpperCase();
    }
    
    return '?';
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return AppColors.vipGold;
      case 'middle':
        return Colors.lightBlue;
      case 'outer':
        return AppColors.lightPrimary;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  // IconData _getRingIcon(String ring) {
  //   switch (ring) {
  //     case 'inner':
  //       return Icons.star;
  //     case 'middle':
  //       return Icons.circle;
  //     case 'outer':
  //       return Icons.circle_outlined;
  //     default:
  //       return Icons.circle;
  //   }
  // }

  String _getFormattedRingName(String ring) {
    switch (ring) {
      case 'inner':
        return 'Inner Circle';
      case 'middle':
        return 'Middle Circle';
      case 'outer':
        return 'Outer Circle';
      default:
        return 'Unknown';
    }
  }

  int getRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return (hash.abs() % 6) + 1;
  }

  Future<void> _showLogInteractionModal(BuildContext context, ThemeProvider themeProvider, Contact contact) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: themeProvider.isDarkMode?AppColors.darkSurfaceContainerLow:Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: LogInteractionModal(
            apiService: apiService,
            contact: contact,
            isDarkMode: themeProvider.isDarkMode,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context);
    final feedbackProvider = Provider.of<FeedbackProvider>(context);
    var width = MediaQuery.of(context).size.width;
    
    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 20, right: 6),
        child: FeedbackFloatingButton(
          controller: _fabController,
        ),
      ),
      body: Stack(
                children: [
                  Scaffold(
                    appBar: AppBar(
                title: Text(
                  'Contact Details', 
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 22)),
                centerTitle: true,
                leading: IconButton(
                  onPressed: (){
                    Navigator.pop(context);
                    if (widget.showConfetti){
                      widget.navigate!();
                    }
                  },
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface)),
                iconTheme: IconThemeData(color: AppColors.lightPrimary),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                surfaceTintColor: Colors.transparent,
                actions: [
                  MaterialButton(
                    padding: EdgeInsets.zero,
                    child: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditContactScreen(contactId: widget.contact.id),
                        ),
                      );
                    },
                    onLongPress: () {
                      // apiService.sendTestBirthdayNotification(widget.contact);
                      // apiService.sendTestEventNotification();
                      apiService.scheduleTestNudges([widget.contact.id]);
                    },
                  ),
                ],
              ),
            body: StreamBuilder<List<Contact>>(
        stream: apiService.getContactsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Color.fromARGB(255, 206, 37, 85)),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading contact',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.lightPrimary,
              ),
            );
          }
          
          // Find the current contact in the updated list
          final currentContact = snapshot.data!.firstWhere(
            (c) => c.id == widget.contact.id,
            orElse: () => widget.contact,
          );
          
          return _buildContactDetails(context, themeProvider, currentContact);
        },
      )),
      if (feedbackProvider.isFabMenuOpen)
                  GestureDetector(
                    onTap: () {
                      // Optional: Close the menu when tapping the overlay
                      // You'll need to access the FeedbackFloatingButton's state
                      // This is handled automatically if the button listens to provider changes
                       _fabController.closeMenu();
                    },
                    child: Container(
                      color: Colors.transparent,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),

                  if (_showConfetti)
                  SizedBox(
                    width: width,
                    child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              numberOfParticles: 20,
              blastDirection: pi*1.3,
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                AppColors.success,
                Theme.of(context).colorScheme.secondary,
                Theme.of(context).colorScheme.tertiary,
                AppColors.warning,
                Theme.of(context).colorScheme.primary
              ],
            ),
          ),
                  )
    ]),
    );
  }

  Widget _buildContactDetails(BuildContext context, ThemeProvider themeProvider, Contact contact) {
    final initials = _getContactInitials(contact.name);
    final isDark   = themeProvider.isDarkMode;
    final scheme   = Theme.of(context).colorScheme;

    // final bg     = isDark ? AppColors.darkBackground : const Color(0xFFF5F2EE);
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final textP  = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final textS  = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    final fieldBg = isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFF0EDE9);

    bool isLocalImage = contact.imageUrl.isNotEmpty &&
        (contact.imageUrl.startsWith('/') || contact.imageUrl.startsWith('file://'));

    // CSS label & colour helpers (inline for context access)
    final cssPercent = contact.css.clamp(0.0, 100.0);
    final cssLabel   = _getCSSLabel(contact.css);
    final cssColor   = _getCSSColor(contact.css, context);
    final ringName   = _getFormattedRingName(contact.computedRing);
    final ringColor  = _getRingColor(contact.computedRing);

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Hero: avatar + name + ring pill ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Center(
              child: Column(children: [
                // Avatar
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
                      blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 120, height: 120,
                      child: contact.imageUrl.isNotEmpty
                          ? Image(
                              image: isLocalImage
                                  ? FileImage(File(contact.imageUrl.replaceFirst('file://', '')))
                                  : NetworkImage(contact.imageUrl) as ImageProvider,
                              fit: BoxFit.cover)
                          : Stack(fit: StackFit.expand, children: [
                              Image.asset(
                                'assets/contact-icons/${getRandomIndex(contact.id)}.png',
                                fit: BoxFit.cover),
                              Container(color: Colors.black.withOpacity(
                                  isDark ? 0.38 : 0.20)),
                              Center(child: Text(
                                contact.name.isNotEmpty ? initials.toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: [Shadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 4)]))),
                            ]),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Name
                Text(contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26, fontWeight: FontWeight.w800, color: textP)),
                if (contact.profession != null && contact.profession!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(contact.profession!,
                    style: GoogleFonts.beVietnamPro(fontSize: 14, color: textS)),
                ],
                const SizedBox(height: 12),

                // Ring pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: ringColor.withOpacity(isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: ringColor.withOpacity(isDark ? 0.4 : 0.25)),
                  ),
                  child: Text(ringName.toUpperCase(),
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: ringColor, letterSpacing: 0.8)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Closeness card ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
                  blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                // Circular progress
                SizedBox(
                  width: 72, height: 72,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 72, height: 72,
                      child: CircularProgressIndicator(
                        value: cssPercent / 100,
                        strokeWidth: 6,
                        backgroundColor: fieldBg,
                        valueColor: AlwaysStoppedAnimation<Color>(cssColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${cssPercent.toStringAsFixed(0)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: textP)),
                  ]),
                ),
                const SizedBox(width: 18),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CLOSENESS',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: textS, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(cssLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: cssColor)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // ── Favourites toggle ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Icon(contact.isVIP ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: contact.isVIP
                      ? AppColors.vipGold
                      : textS,
                  size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('Favourite contact',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15, fontWeight: FontWeight.w500, color: textP))),
                _isUpdatingVIP
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.lightPrimary))
                    : Switch(
                        value: contact.isVIP,
                        onChanged: (v) => _toggleVIPStatus(v, contact),
                        thumbColor: WidgetStateProperty.resolveWith((s) =>
                            s.contains(WidgetState.selected)
                                ? Colors.white
                                : themeProvider.isDarkMode?Colors.white:Colors.blueGrey),
                        trackColor: WidgetStateProperty.resolveWith((s) =>
                            s.contains(WidgetState.selected)
                                ? AppColors.lightPrimary
                                : scheme.surfaceContainerHigh),
                        trackOutlineColor: WidgetStateProperty.all(themeProvider.isDarkMode?Colors.white:Colors.black),
                      ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Contact Information ───────────────────────────────────────
          if (contact.phoneNumber.isNotEmpty || contact.email.isNotEmpty) ...[
            _sectionHeader(
              icon: Icons.contact_page_rounded,
              label: 'Contact Information',
              isDark: isDark, textP: textP,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
                    blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(children: [
                  if (contact.phoneNumber.isNotEmpty)
                    _infoRow(
                      label: 'MOBILE',
                      value: contact.phoneNumber,
                      trailingIcon: Icons.phone_rounded,
                      trailingColor: AppColors.lightSecondary,
                      isDark: isDark, textP: textP, textS: textS,
                      divider: contact.email.isNotEmpty,
                    ),
                  if (contact.email.isNotEmpty)
                    _infoRow(
                      label: 'EMAIL',
                      value: contact.email,
                      trailingIcon: Icons.email_rounded,
                      trailingColor: AppColors.lightPrimary,
                      isDark: isDark, textP: textP, textS: textS,
                      divider: false,
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Connection Details ─────────────────────────────────────────
          _sectionHeader(
            icon: Icons.device_hub_rounded,
            label: 'Connection Details',
            isDark: isDark, textP: textP,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
                  blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(children: [
                _detailRow(
                  label: 'Connection Type',
                  value: contact.connectionType.isNotEmpty
                      ? contact.connectionType : '—',
                  isDark: isDark, textP: textP, textS: textS,
                  divider: true,
                ),
                _detailRow(
                  label: 'Frequency',
                  value: FrequencyPeriodMapper.getConversationalChoice(
                      contact.frequency, contact.period),
                  isDark: isDark, textP: textP, textS: textS,
                  divider: contact.socialGroups.isNotEmpty,
                ),
                if (contact.socialGroups.isNotEmpty)
                  _detailRow(
                    label: 'Groups',
                    value: contact.socialGroups.join(', '),
                    isDark: isDark, textP: textP, textS: textS,
                    divider: false,
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Needs Attention toggle ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Icon(
                  contact.needsAttention
                      ? Icons.flag_rounded : Icons.flag_outlined,
                  color: contact.needsAttention
                      ? (contact.attentionSource == 'digest'
                          ? const Color(0xFF1D9E75)
                          : AppColors.warning)
                      : textS,
                  size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Needs Attention',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w500, color: textP)),
                    if (contact.needsAttention)
                      Text(_attentionSubtitle(contact),
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12, color: textS)),
                  ],
                )),
                _isUpdatingAttention
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.lightPrimary))
                    : Switch(
                        value: contact.needsAttention,
                        onChanged: (v) => _toggleNeedsAttention(v, contact),
                         thumbColor: WidgetStateProperty.resolveWith((s) =>
                            s.contains(WidgetState.selected)
                                ? Colors.white
                                : themeProvider.isDarkMode?Colors.white:Colors.blueGrey),
                        trackColor: WidgetStateProperty.resolveWith((s) =>
                            s.contains(WidgetState.selected)
                                ? AppColors.lightPrimary
                                : scheme.surfaceContainerHigh),
                        trackOutlineColor: WidgetStateProperty.all(themeProvider.isDarkMode?Colors.white:Colors.black),
                      ),
              ]),
            ),
          ),

          // ── Important Dates ───────────────────────────────────────────
          if (contact.birthday != null || contact.anniversary != null ||
              contact.workAnniversary != null) ...[
            const SizedBox(height: 20),
            _sectionHeader(
              icon: Icons.cake_rounded,
              label: 'Important Dates',
              isDark: isDark, textP: textP,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
                    blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(children: [
                  if (contact.birthday != null)
                    _detailRow(
                      label: 'Birthday',
                      value: DateFormat('MMMM d, y').format(contact.birthday!),
                      isDark: isDark, textP: textP, textS: textS,
                      divider: contact.anniversary != null ||
                          contact.workAnniversary != null,
                    ),
                  if (contact.anniversary != null)
                    _detailRow(
                      label: 'Anniversary',
                      value: DateFormat('MMMM d, y').format(contact.anniversary!),
                      isDark: isDark, textP: textP, textS: textS,
                      divider: contact.workAnniversary != null,
                    ),
                  if (contact.workAnniversary != null)
                    _detailRow(
                      label: 'Work Anniversary',
                      value: DateFormat('MMMM d, y').format(contact.workAnniversary!),
                      isDark: isDark, textP: textP, textS: textS,
                      divider: false,
                    ),
                ]),
              ),
            ),
          ],

          // ── Relationship Notes ────────────────────────────────────────
          if (contact.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader(
              icon: Icons.sticky_note_2_rounded,
              label: 'Relationship Notes',
              isDark: isDark, textP: textP,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.lightPrimary.withOpacity(0.08)
                      : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.lightPrimary.withOpacity(
                        isDark ? 0.25 : 0.15)),
                ),
                child: Text(
                  '"${contact.notes}"',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14, color: textP, height: 1.6,
                    fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),

          // ── Log Interaction button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => _showLogInteractionModal(context, themeProvider, contact),
              child: Container(
                width: double.infinity, height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)]),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [BoxShadow(
                    color: AppColors.lightPrimary.withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 5))],
                ),
                child: Center(child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('LOG INTERACTION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                  ],
                )),
              ),
            ),
          ),

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ── Section header helper ─────────────────────────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color textP,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.lightPrimary.withOpacity(isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: AppColors.lightPrimary)),
        const SizedBox(width: 10),
        Text(label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w700, color: textP)),
      ]),
    );
  }

  // ── Info row (phone/email with trailing action icon) ──────────────────────
  Widget _infoRow({
    required String label,
    required String value,
    required IconData trailingIcon,
    required Color trailingColor,
    required bool isDark,
    required Color textP,
    required Color textS,
    required bool divider,
  }) {
    // final fieldBg = isDark
    //     ? AppColors.darkSurfaceContainerHighest
    //     : const Color(0xFFF0EDE9);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: textS, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w600, color: textP)),
          ])),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: trailingColor.withOpacity(0.12),
              shape: BoxShape.circle),
            child: Icon(trailingIcon, size: 18, color: trailingColor)),
        ]),
      ),
      if (divider)
        Divider(height: 1, indent: 18, endIndent: 18,
          color: (isDark
              ? AppColors.darkSurfaceContainerHighest
              : const Color(0xFFECE7E2))),
    ]);
  }

  // ── Detail row (key-value with pill badge) ────────────────────────────────
  Widget _detailRow({
    required String label,
    required String value,
    required bool isDark,
    required Color textP,
    required Color textS,
    required bool divider,
  }) {
    final pillBg = isDark
        ? AppColors.darkSurfaceContainerHighest
        : const Color(0xFFF0EDE9);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(children: [
          Expanded(child: Text(label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: textS))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(9999)),
            child: Text(value,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13, fontWeight: FontWeight.w600, color: textP)),
          ),
        ]),
      ),
      if (divider)
        Divider(height: 1, indent: 18, endIndent: 18,
          color: (isDark
              ? AppColors.darkSurfaceContainerHighest
              : const Color(0xFFECE7E2))),
    ]);
  }

    // Add these methods to _ContactDetailScreenState
  String _getCSSLabel(double css) {
    if (css >= 76) return 'Strong';
    if (css >= 41) return 'Growing';
    return 'Needs care';
  }

  Color _getCSSColor(double css, BuildContext context) {
    if (css >= 76) return const Color(0xFF1D9E75); // teal - strong
    if (css >= 41) return const Color(0xFFEF9F27); // amber - developing
    return const Color(0xFFE24B4A); // red - fragile
  }

  String _attentionSubtitle(Contact contact) {
    if (!contact.needsAttention) {
      return 'Flag this contact for priority follow-up';
    }

    final since = contact.attentionSince;
    final daysAgo = since != null
        ? DateTime.now().difference(since).inDays
        : null;

    final sourceLabel = contact.attentionSource == 'digest'
        ? 'Added via your Reflection Digest'
        : 'Manually flagged by you';

    if (daysAgo == null) return sourceLabel;
    if (daysAgo == 0) return '$sourceLabel · today';
    if (daysAgo == 1) return '$sourceLabel · yesterday';
    return '$sourceLabel · $daysAgo days ago';
  }
}
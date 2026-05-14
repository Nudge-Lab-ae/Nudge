// dashboard_screen.dart - Updated for theme support
// import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nudge/helpers/deletion_retry_helper.dart';
import 'package:nudge/models/analytics.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/screens/contacts/contacts_list_screen.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/screens/digest/reflection_digest_modal.dart';
import 'package:nudge/screens/groups/groups_list_screen.dart';
import 'package:nudge/screens/notifications/notifications_screen.dart';
import 'package:nudge/screens/social_universe/social_universe_immersive.dart';
// import 'package:nudge/screens/settings/settings_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/social_universe_service.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/widgets/add_touchpoint_modal.dart';
import 'package:nudge/widgets/contact_detail_modal.dart';
// import 'package:nudge/widgets/contact_quick_panel.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/interactive_donut_chart.dart';
// import 'package:nudge/widgets/gradient_text.dart';
import 'package:nudge/widgets/screen_tracker.dart';
// import 'package:nudge/widgets/simple_contact_panel.dart';
import 'package:nudge/widgets/social_universe.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
import '../../services/auth_service.dart';
import '../../services/nudge_service.dart';
import '../../models/contact.dart';
import 'package:confetti/confetti.dart';
// import '../../widgets/vip_badge.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;
  final bool onboarding;
  
  const DashboardScreen({super.key, this.initialTab = 1, this.onboarding = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NudgeService nudgeService = NudgeService();
  int _currentIndex = 1;
  bool vipFilter = false;
  bool attentionFilter = false;
  List<Contact> totalContacts = [];
  bool hideFloatingActionButton = false;
  final Map<String, int> _cachedAvatarIndices = {};
  List<Nudge> allNudges = [];
  List<Nudge> overDueNudges = [];
  StreamSubscription<List<Nudge>>? _nudgesSubscription;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = true;
  double _lastOffset = 0.0;

  int _selectedPieSegmentIndex = -1;
  String? _explodedCategory;

  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3)
  );
  bool _showConfetti = false;
  late final ApiService apiService;
  late final ThemeProvider themeProvider;
  late FeedbackFloatingButtonController _fabController;

  // final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _subscribeToNudges();
    _checkDeletionRetry();
    _currentIndex = widget.initialTab;
    _initializeNotifications();
    _initializeSocialUniverse();
    _scrollController.addListener(() {
      _handleScroll();
    });
    _fabController = FeedbackFloatingButtonController();

    apiService = Provider.of<ApiService>(context, listen: false);
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final contacts = await apiService.getAllContacts();
      final innerRing = contacts.where((c) => c.computedRing == 'inner').toList();
      if (!mounted) return;
      await DigestScheduler.showIfDue(
        context: context,
        closeCircleContacts: innerRing,
        apiService: apiService,
        isDarkMode: themeProvider.isDarkMode,
      );
    });
  }

    @override
  void dispose() {
    _confettiController.dispose();
    _nudgesSubscription?.cancel();
    _fabController = FeedbackFloatingButtonController(); // Add this
    super.dispose();
  }
  

  // Future<void> _checkDigestDue() async {
  //   final apiService = ApiService();
  //   final prefs = await SharedPreferences.getInstance();
  //   final lastDigest = prefs.getInt('last_digest_timestamp') ?? 0;
  //   final daysSince = DateTime.now()
  //     .difference(DateTime.fromMillisecondsSinceEpoch(lastDigest)).inDays;

  //   if (daysSince >= 14) { // bi-weekly default
  //     await Future.delayed(const Duration(seconds: 2)); // let dashboard load first
  //     if (mounted) {
  //       showModalBottomSheet(
  //         context: context,
  //         isScrollControlled: true,
  //         backgroundColor: Colors.transparent,
  //         builder: (_) => ReflectionDigestModal(
  //           apiService: apiService,
  //           isDarkMode: ,
  //           closeCircleContacts: totalContacts
  //               .where((c) => c.computedRing == 'inner').toList(),
  //           onComplete: () async {
  //             await prefs.setInt('last_digest_timestamp',
  //               DateTime.now().millisecondsSinceEpoch);
  //           },
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _initializeSocialUniverse() async {
    try {
      final apiService = ApiService();
      
      // Get all contacts and assign initial angles if missing
      final contacts = await apiService.getAllContacts();
      
      final socialUniverseService = SocialUniverseService();
      for (var contact in contacts) {
        if (contact.angleDeg == 0) {
          final updatedContact = contact.copyWith(
            angleDeg: socialUniverseService.generateStableAngle(contact.id),
          );
          await apiService.updateContact(updatedContact);
        }
      }
      
      // Run batch CDI update if not done today
      await _runDailyCDIUpdate(apiService);
      
    } catch (e) {
      //print('Error initializing Social Universe: $e');
    }
  }

  Future<void> _runDailyCDIUpdate(ApiService apiService) async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateKey = 'last_cdi_update_${DateTime.now().day}_${DateTime.now().hour}';
    final shouldUpdate = prefs.getBool(lastUpdateKey) != true;
    
    if (shouldUpdate || widget.onboarding) {
      try {
        await apiService.batchUpdateCDI();
        await prefs.setBool(lastUpdateKey, true);
        //print('Daily CDI update completed');
      } catch (e) {
        //print('Error in daily CDI update: $e');
      }
    }
  }

  void _handleScroll() {
    final currentOffset = _scrollController.offset;
    
    // Show app bar when scrolling up, hide when scrolling down
    if (currentOffset > _lastOffset && currentOffset > 50) {
      // Scrolling down
      if (_showAppBar) {
        setState(() {
          _showAppBar = false;
        });
      }
    } else if (currentOffset < _lastOffset && _scrollController.offset <= 50) {
      // Scrolling up or at top
      if (!_showAppBar) {
        setState(() {
          _showAppBar = true;
        });
      }
    }
    
    _lastOffset = currentOffset;
  }

  Future<void> _initializeNotifications() async {
    await nudgeService.initialize();
  }

  void _subscribeToNudges() {
    final uid = Provider.of<AuthService>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null) return;
    _nudgesSubscription?.cancel();
    _nudgesSubscription =
        NudgeService().getNudgesStream(uid).listen((nudges) {
      if (mounted) {
        setState(() {
          allNudges = nudges;
        });
      }
    });
  }

  String getCurrentSection() {
    return ScreenTracker.getDashboardSection(_currentIndex);
  }

  List<Nudge> _getOverdueNudges(List<Nudge> nudges) {
    var now = DateTime.now();
    return nudges.where((nudge) {
      return !nudge.isCompleted && nudge.scheduledTime.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    
    //print('DashboardScreen building with _currentIndex: $_currentIndex, initialTab: ${widget.initialTab}');
    
    if (user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'Please log in to view dashboard',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily,),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          StreamProvider<List<Contact>>.value(
            value: apiService.getContactsStream(),
            initialData: const [],
            child: StreamProvider<List<SocialGroup>>.value(
              value: apiService.getGroupsStream(),
              initialData: const [],
              child: Consumer2<List<Contact>, List<SocialGroup>>(
                builder: (context, contacts, groups, child) {
                  totalContacts = contacts;
                  
                  // Return different screens based on current index
                  switch (_currentIndex) {
                    // case 0:
                    //   return _buildDashboardWithSliver(themeProvider, contacts, groups, apiService);
                    case 1: // Social Universe is now at index 1
                      return const SocialUniverseImmersiveScreen();
                    case 2: // Notifications moved to index 4
                      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                      final pendingNudgeId = args?['pendingNudgeId'];
                      return  NotificationsScreen(showAppBar: false, pendingNudgeId: pendingNudgeId);
                      case 3: // Groups moved to index 3
                      return const GroupsListScreen(showAppBar: false);
                    case 4: // Contacts moved to index 2
                      return ContactsListScreen(
                        showAppBar: false,
                        filter: vipFilter ? 'vip' : attentionFilter ? 'needs_attention' : '',
                        hideButton: hideButton,
                      );
                    default:
                      return _buildDashboardWithSliver(themeProvider, contacts, groups, apiService);
                  }
                },
              ),
            ),
          ),
          // Bottom Navigation Bar (full-width, anchored to bottom; dark
          // variant on Universe per social_universe_brighter_glow_2).
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: StreamBuilder<List<Nudge>>(
              stream: NudgeService().getNudgesStream(user.uid),
              builder: (context, snap) {
                final liveNudges = snap.data ?? allNudges;
                return _buildFloatingNavigationBar(
                    context, themeProvider, liveNudges);
              },
            ),
          ),
          
          Consumer<FeedbackProvider>(
            builder: (context, feedbackProvider, child) {
              return feedbackProvider.isFabMenuOpen
                  ? GestureDetector(
                      onTap: () {
                        _fabController.closeMenu(); // Call this to close the menu
                      },
                      child: Container(
                        color: Colors.transparent,
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
          
          Consumer<FeedbackProvider>(
            builder: (context, feedbackProvider, child) {
              // Lifted to clear the new full-width nav bar (Section 4).
              // Mockup uses bottom-32 (128px); 116 gives a tighter sit
              // against the nav with safe-area inset accounted for.
              return Positioned(
                bottom: 116,
                right: 20,
                child: FeedbackFloatingButton(
                  currentSection: getCurrentSection(),
                  fromDashboard: true,
                  onDarkBackground: _currentIndex == 1, // Social Universe tab
                  controller: _fabController,
                  extraActions: [
                    FeedbackAction(
                      label: 'Add Contact',
                      icon: Icons.person_add,
                      onPressed: () {
                        _showAddContactOptions(context, themeProvider);
                      },
                    ),
                    FeedbackAction(
                      label: 'Log Interaction',
                      icon: Icons.add,
                      onPressed: () {
                        _showAddTouchpointModal(context, themeProvider);
                      },
                    ),
                    FeedbackAction(
                      label: 'Add Group',
                      icon: Icons.group,
                      onPressed: () {
                       setState(() {
                         _currentIndex = 3;
                       });
                      },
                    ),
                    
                    FeedbackAction(
                      label: 'Go to Settings',
                      icon: Icons.settings,
                      onPressed: () {
                       Navigator.pushNamed(context, '/settings');
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          if (_showConfetti)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                numberOfParticles: 20,
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
          
        ],
      ),
    );
  }

  Widget _buildDashboardWithSliver(ThemeProvider themeProvider, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    return _buildStitchDashboard(themeProvider, contacts, apiService);
  }

  Widget _legacyDashboardWithSliver(ThemeProvider themeProvider, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<Nudge>>(
        stream: NudgeService().getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
        builder: (context, nudgeSnapshot) {
          final nudges = nudgeSnapshot.data ?? [];
          final analytics = _calculateAnalytics(contacts, nudges);
          final weeklyNudgePerformance = _calculateWeeklyNudgePerformance(nudges);
          final vipContacts = contacts.where((c) => c.isVIP).toList();
          // final needsAttention = contacts.where((c) => c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Sliver App Bar
              SliverAppBar(
                title: Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 22, 
                      fontFamily: GoogleFonts.plusJakartaSans().fontFamily, 
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: const Center(),
                iconTheme: IconThemeData(color: theme.colorScheme.primary),
                elevation: 0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 0),
                    child: MaterialButton(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode 
                            ? Colors.white.withOpacity(0.1)
                            : Color(0xff888888).withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface, size: 20),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      onLongPress: () {
                        apiService.sendTestEventNotification();
                      },
                    ),
                  )
                ],
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                floating: true,
                snap: true,
                pinned: false,
              ),
              
              // Main content
              SliverPadding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Social Universe - Updated with consistent spacing
                    Container(
                      margin: const EdgeInsets.only(top: 4, left: 4),
                      child: SocialUniverseWidget(
                        contacts: contacts,
                        onContactView: (contact, ringToUse) {
                          _showContactQuickPanel(themeProvider, contact, ringToUse, apiService);
                        },
                        showTitle: true,
                        height: 550,
                        isDarkMode: themeProvider.isDarkMode,
                        onFullScreenPressed: () {
                          setState(() {
                            _currentIndex = 1; // Navigate to immersive universe
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Quick Actions - Now in card
                    _buildQuickActionsCard(context, themeProvider),
                    const SizedBox(height: 20),
                    // Quick Insights - Now in card

                    _buildQuickInsightsCard(analytics, contacts.length, context, groups.length),
                    const SizedBox(height: 20),

                     // Nudge Performance
                    _buildWeeklyNudgePerformanceSection(weeklyNudgePerformance, context),
                    const SizedBox(height: 20),

                    // VIP Contacts
                    if (vipContacts.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(top: 4, left: 24, right: 4),
                        child: Row(
                          children: [
                            Text(
                              'FAVOURITES',
                              style: TextStyle(
                                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentIndex = 4;
                                  attentionFilter = false;
                                  vipFilter = true;
                                });
                              },
                              child: Text('View All', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily,)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: Padding(
                          padding: EdgeInsets.only(left: 15),
                          child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: vipContacts.length,
                          itemBuilder: (context, index) {
                            final contact = vipContacts[index];
                            return _buildContactCard(contact, apiService, showConnectionType: true, context: context);
                          },
                        ),
                          )
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Needs Care Section
                    // if (needsAttention.isNotEmpty) ...[
                    //   Container(
                    //     margin: const EdgeInsets.only(top: 4, left: 4),
                    //     child: Row(
                    //       children: [
                    //         Text(
                    //           'NEEDS CARE',
                    //           style: TextStyle(
                    //             fontSize: 16,
                    //             fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                    //             fontWeight: FontWeight.w500,
                    //             color: Theme.of(context).colorScheme.onSurfaceVariant,
                    //           ),
                    //         ),
                    //         const Spacer(),
                    //         TextButton(
                    //           onPressed: () {
                    //             setState(() => _currentIndex = 2);
                    //           },
                    //           child: Text(
                    //             'View All',
                    //             style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily,),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    //   const SizedBox(height: 10),
                    //   SizedBox(
                    //     height: 120,
                    //     child: ListView.builder(
                    //       scrollDirection: Axis.horizontal,
                    //       itemCount: needsAttention.length,
                    //       itemBuilder: (context, index) {
                    //         final contact = needsAttention[index];
                    //         return _buildContactCard(contact, apiService, showConnectionType: false, context: context);
                    //       },
                    //     ),
                    //   ),
                    //   const SizedBox(height: 20),
                    // ],

                    // Pie Chart
                    Container(
                      margin: const EdgeInsets.only(top: 4, left: 4),
                      child: _buildInteractivePieChartSection(contacts, context),
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkDeletionRetry() async {
    final shouldShowPrompt = await DeletionRetryHelper.shouldShowRetryPrompt();
    if (shouldShowPrompt && mounted) {
      await DeletionRetryHelper.clearRetryPromptFlag();
      
      // Wait for dashboard to fully load
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Navigate to settings
          Navigator.pushNamed(context, '/settings');
        }
      });
    }
  }

  void showConfetti() {
    setState(() {
      _showConfetti = true;
    });
    // Start confetti
    _confettiController.play();
    
    // Close after animation
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showConfetti = false;
        });
      }
    });
  }

  void _handleImportResult(dynamic result) {
    if (result != null && result is Map<String, dynamic>) {
      if (result['showConfetti'] == true) {
        setState(() {
          _currentIndex = 4;
        });
        showConfetti();
      }
    }
  }
  

  void _showAddContactOptions(BuildContext context, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'ADD CONTACTS',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary),
                title: Text('ADD CONTACT MANUALLY', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: GoogleFonts.beVietnamPro().fontFamily, color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Create a new contact from scratch', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily,)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/add_contact');
                },
              ),
              ListTile(
                leading: Icon(Icons.import_contacts, color: Theme.of(context).colorScheme.primary),
                title: Text('IMPORT CONTACTS', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: GoogleFonts.beVietnamPro().fontFamily, color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Import from your device contacts', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily,)),
                onTap: () async{
                  Navigator.pop(context);
                  // Navigator.pushNamed(context, '/import_contacts');
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImportContactsScreen(
                        isOnboarding: false,
                        // No preSelectedGroup means it's from FAB
                        ),
                      ),
                    );

                  _handleImportResult(result);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void hideButton() {
    setState(() {
      hideFloatingActionButton = true;
    });
  }

  Widget _buildFloatingNavigationBar(
      BuildContext context, ThemeProvider themeProvider,
      [List<Nudge>? nudgeOverride]) {
    final overdueNudges = _getOverdueNudges(nudgeOverride ?? allNudges);
    final hasOverdue = overdueNudges.isNotEmpty;
    // Use the Social-Universe dark nav variant whenever the app is in dark
    // mode, regardless of tab — Section 1. The Universe tab is always dark so
    // it also forces the dark variant in light mode.
    final isUniverse = _currentIndex == 1 || themeProvider.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        color: isUniverse
            ? const Color(0xE61A1816)
            : Colors.white.withOpacity(0.92),
        boxShadow: [
          BoxShadow(
            color: isUniverse
                ? const Color(0x10751FE7)
                : Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 1,
            label: 'UNIVERSE',
            iconAsset: 'assets/navbar-icons/nav_universe.svg',
            isUniverse: isUniverse,
            themeProvider: themeProvider,
          ),
          _buildNavItem(
            index: 2,
            label: 'NUDGES',
            iconAsset: 'assets/navbar-icons/nav_nudges.svg',
            isUniverse: isUniverse,
            themeProvider: themeProvider,
            badge: hasOverdue,
          ),
          _buildNavItem(
            index: 3,
            label: 'GROUPS',
            iconAsset: 'assets/navbar-icons/nav_groups.svg',
            isUniverse: isUniverse,
            themeProvider: themeProvider,
          ),
          _buildNavItem(
            index: 4,
            label: 'CONTACTS',
            iconAsset: 'assets/navbar-icons/nav_contacts.svg',
            isUniverse: isUniverse,
            themeProvider: themeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String iconAsset,
    required String label,
    required ThemeProvider themeProvider,
    required bool isUniverse,
    bool badge = false,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = themeProvider.isDarkMode;
    final scheme = Theme.of(context).colorScheme;
    // Active/inactive colors per Stitch v4 — light variant uses brand primary,
    // dark variant uses the muted-purple/stone-500 palette from
    // social_universe_brighter_glow_2.
    final activeFg = isUniverse ? const Color(0xFFD1B3FF) : scheme.primary;
    final inactiveFg = isUniverse ? const Color(0xFF6E6A66) : scheme.outline;
    final fg = isSelected ? activeFg : inactiveFg;
    final activeBg = isUniverse
        ? const Color(0x33751FE7)
        : scheme.primary.withOpacity(isDark ? 0.18 : 0.10);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          hideFloatingActionButton = false;
          attentionFilter = false;
          vipFilter = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                ),
                if (badge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isUniverse
                                ? const Color(0xFF1A1816)
                                : (isDark ? Colors.black : Colors.white),
                            blurRadius: 1,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactQuickPanel(ThemeProvider themeProvider, Contact contact, String ringToUse, ApiService apiService) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) {
        return ContactDetailsModal(
          contact: contact,
          apiService: apiService,
          displayRing: ringToUse,
        );
      },
    );
  }

  // QUICK INSIGHTS card
  Widget _buildQuickInsightsCard(Analytics analytics, int totalContacts, BuildContext context, int groups) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.15 : 0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUICK INSIGHTS',
              style: TextStyle(
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  title: 'Contacts',
                  value: totalContacts.toString(),
                  iconSize: 35,
                  iconAsset: 'assets/quick-insights/total-contacts.svg',
                  backgroundAsset: 'assets/card-backgrounds/nudges-this-week.jpg',
                  iconColor: theme.colorScheme.primary,
                  onTap: () => setState(() => _currentIndex = 4),
                  context: context,
                ),
                _buildStatCard(
                  title: 'Favourites',
                  value: analytics.vipContacts.toString(),
                  iconSize: 35,
                  iconAsset: 'assets/quick-insights/close circle-star.svg',
                  backgroundAsset: 'assets/card-backgrounds/nudges-this-week.jpg',
                  iconColor: themeProvider.isDarkMode ? theme.colorScheme.primary : Colors.white,
                  onTap: () {
                    setState(() {
                      _currentIndex = 4;
                      vipFilter = true;
                      attentionFilter = false;
                    });
                  },
                  context: context,
                ),
                _buildStatCard(
                  title: 'Social Groups',
                  value: groups.toString(),
                  iconSize: 35,
                  iconAsset: 'assets/quick-actions/add group-icon.svg',
                  backgroundAsset: 'assets/card-backgrounds/nudges-this-week.jpg',
                  iconColor: themeProvider.isDarkMode ? theme.colorScheme.primary : Colors.white,
                  onTap: () {
                    setState(() {
                      _currentIndex = 3;
                      // attentionFilter = true;
                      // vipFilter = false;
                    });
                  },
                  context: context,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WEEKLY NUDGE PERFORMANCE card
  Widget _buildWeeklyNudgePerformanceSection(Map<String, int> weeklyNudgePerformance, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.15 : 0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NUDGES THIS WEEK',
              style: TextStyle(
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  title: 'Scheduled',
                  value: (weeklyNudgePerformance['scheduled'] ?? 0).toString(),
                  iconSize: 35,
                  iconAsset: 'assets/performance-icons/clock-scheduled.svg',
                  backgroundAsset: 'assets/card-backgrounds/needs-care.png',
                  iconColor: themeProvider.isDarkMode ? theme.colorScheme.primary : Colors.white,
                  context: context,
                ),
                _buildStatCard(
                  title: 'Completed',
                  value: (weeklyNudgePerformance['completed'] ?? 0).toString(),
                  iconSize: 35,
                  iconAsset: 'assets/performance-icons/check-completed.svg',
                  backgroundAsset: 'assets/card-backgrounds/needs-care.png',
                  iconColor: AppColors.success,
                  context: context,
                ),
                _buildStatCard(
                  title: 'Missed',
                  value: (weeklyNudgePerformance['missed'] ?? 0).toString(),
                  iconSize: 35,
                  iconAsset: 'assets/performance-icons/x-missed.svg',
                  backgroundAsset: 'assets/card-backgrounds/needs-care.png',
                  iconColor: themeProvider.isDarkMode ? theme.colorScheme.primary : Colors.white,
                  context: context,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Nudge Completion Rate',
              style: TextStyle(fontSize: 10, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            LinearPercentIndicator(
              animation: true,
              lineHeight: 20.0,
              animationDuration: 1000,
              percent: (weeklyNudgePerformance['completionRate'] ?? 0) / 100,
              center: Text(
                "${(weeklyNudgePerformance['completionRate'] ?? 0).toStringAsFixed(1)}%",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 12),
              ),
              barRadius: const Radius.circular(10),
              linearGradient: const LinearGradient(
                colors: [AppColors.lightPrimary, AppColors.lightSecondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // QUICK ACTIONS card
  Widget _buildQuickActionsCard(BuildContext context, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.15 : 0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildCenteredQuickActions(context, themeProvider),
          ],
        ),
      ),
    );
  }

  // GENERIC STAT CARD
  Widget _buildStatCard({
    required String title,
    required String value,
    required String iconAsset,
    required Color iconColor,
    String? backgroundAsset,
    double? iconSize,
    VoidCallback? onTap,
    required BuildContext context,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var size = MediaQuery.of(context).size;
    
    final card = Container(
      width: size.width * 0.25,
      height: 120,
      decoration: BoxDecoration(
        // Always show the background image if available, regardless of theme
        image: backgroundAsset != null
          ? DecorationImage(
              image: AssetImage(backgroundAsset), 
              fit: BoxFit.cover,
              // Add opacity overlay for dark mode to make text more readable
              colorFilter: themeProvider.isDarkMode
                  ? ColorFilter.mode(
                      Colors.black.withOpacity(0.6),
                      BlendMode.darken,
                    )
                  : null,
            )
          : null,
        // Fallback background color when no image
        color: backgroundAsset == null
            ? (themeProvider.isDarkMode 
                ? Theme.of(context).colorScheme.surfaceContainerHighest 
                : Colors.white)
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? AppColors.darkSurfaceContainerHighest 
              : AppColors.lightSurfaceContainerHigh, 
          width: 0.6
        ),
      ),
      child: Stack(
        children: [
          // Add an additional gradient overlay for dark mode to improve text contrast
          if (backgroundAsset != null && themeProvider.isDarkMode)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    iconAsset,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(
                      // Use white icons for dark mode with background images
                      backgroundAsset != null && themeProvider.isDarkMode
                          ? Colors.white
                          // : iconColor,
                          : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: backgroundAsset != null
                          // White text for cards with background images
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: backgroundAsset != null
                          // White text for cards with background images
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(onTap: onTap, child: MouseRegion(cursor: SystemMouseCursors.click, child: card));
  }

  // Quick actions row
  Widget _buildCenteredQuickActions(BuildContext context, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildQuickActionButton(
              title: 'Add Contacts',
              value: '',
              iconSize: 35,
              iconAsset: 'assets/quick-actions/add contact icon.svg',
              backgroundAsset: 'assets/card-backgrounds/nudges-this-week.jpg',
              iconColor: theme.colorScheme.primary,
              onTap: () {
                _showAddContactOptions(context, themeProvider);
              },
              context: context,
            ),
         const SizedBox(width: 8),
          _buildQuickActionButton(
              title: 'Create Group',
              value: '',
              iconSize: 35,
              iconAsset: 'assets/quick-actions/add group-icon.svg',
              backgroundAsset: 'assets/card-backgrounds/nudges-this-week.jpg',
              iconColor: theme.colorScheme.primary,
              onTap: () {
                setState(() {
                  _currentIndex = 3; // Groups is now at index 3
                  attentionFilter = false;
                  vipFilter = false;
                });
              },
              context: context,
            ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            iconAsset: 'assets/quick-actions/touchpoint-icon.svg',
            backgroundAsset: 'assets/card-backgrounds/nudges-this-week.jpg',
            context: context,
              title: 'Add Touchpoint',
              value: '',
              iconSize: 45,
              iconColor: theme.colorScheme.primary,
              onTap: () {
                _showAddTouchpointModal(context, themeProvider);
              },
            ),
        ],
      ),
    );
  }

  void _showAddTouchpointModal(BuildContext context, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
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
          child: AddTouchpointModal(
            apiService: Provider.of<ApiService>(context, listen: false),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required String value,
    required String iconAsset,
    required Color iconColor,
    String? backgroundAsset,
    double? iconSize,
    VoidCallback? onTap,
    required BuildContext context,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var size = MediaQuery.of(context).size;
    
    final card = Container(
      width: size.width * 0.25,
      height: 120,
      decoration: BoxDecoration(
        // Always show the background image if available, regardless of theme
        image: backgroundAsset != null
          ? DecorationImage(
              image: AssetImage(backgroundAsset), 
              fit: BoxFit.cover,
              // Add opacity overlay for dark mode to make text more readable
              colorFilter: themeProvider.isDarkMode
                  ? ColorFilter.mode(
                      Colors.black.withOpacity(0.6),
                      BlendMode.darken,
                    )
                  : null,
            )
          : null,
        // Fallback background color when no image
        color: backgroundAsset == null
            ? (themeProvider.isDarkMode 
                ? Theme.of(context).colorScheme.surfaceContainerHighest 
                : Colors.white)
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? AppColors.darkSurfaceContainerHighest 
              : AppColors.lightSurfaceContainerHigh, 
          width: 0.6
        ),
      ),
      child: Stack(
        children: [
          // Add an additional gradient overlay for dark mode to improve text contrast
          if (backgroundAsset != null && themeProvider.isDarkMode)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 50,
                    child: SvgPicture.asset(
                    iconAsset,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(
                      // Use white icons for dark mode with background images
                      backgroundAsset != null && themeProvider.isDarkMode
                          ? Colors.white
                          // : iconColor,
                          : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  ),
                  const SizedBox(height: 10),
                  
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: backgroundAsset != null
                          // White text for cards with background images
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(onTap: onTap, child: MouseRegion(cursor: SystemMouseCursors.click, child: card));
  }

  int _getCachedRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    
    if (_cachedAvatarIndices.containsKey(seed)) {
      return _cachedAvatarIndices[seed]!;
    }
    
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    final index = (hash.abs() % 6) + 1;
    _cachedAvatarIndices[seed] = index;
    
    return index;
  }

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    
    return '?';
  }


  // Pie chart section
  Widget _buildInteractivePieChartSection(List<Contact> contacts, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final distributionData = _calculateContactDistribution(contacts);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.15 : 0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR SOCIAL LANDSCAPE',
              style: TextStyle(
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (distributionData.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64, color: themeProvider.isDarkMode ? AppColors.darkOutline : Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('No contacts yet', style: TextStyle(fontSize: 16, fontFamily: GoogleFonts.beVietnamPro().fontFamily, color: themeProvider.isDarkMode ? AppColors.darkOutline : Theme.of(context).colorScheme.outline)),
                  ],
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 370,
                    child: InteractiveDonutChart(distributionData: distributionData),
                  ),
                  if (_explodedCategory != null && _selectedPieSegmentIndex >= 0)
                    _buildSegmentDetails(
                      distributionData[_selectedPieSegmentIndex],
                      distributionData.fold(0, (sum, item) => sum + (item['count'] as int)),
                      context,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentDetails(Map<String, dynamic> segmentData, int totalContacts, BuildContext context) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    final count = segmentData['count'] as int;
    final percentage = ((count / totalContacts) * 100).toStringAsFixed(2);
    final category = segmentData['category'];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCategoryColor(category, 0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getCategoryColor(category, 0).withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: TextStyle(fontSize: 16, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text('$count contact${count != 1 ? 's' : ''}', style: TextStyle(fontSize: 14, fontFamily: GoogleFonts.beVietnamPro().fontFamily, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 18, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text('of total contacts', style: TextStyle(fontSize: 12, fontFamily: GoogleFonts.beVietnamPro().fontFamily, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  // Utilities
  List<Map<String, dynamic>> _calculateContactDistribution(List<Contact> contacts) {
    final categoryCounts = <String, int>{};
    for (var contact in contacts) {
      final category = contact.connectionType.isEmpty ? 'Uncategorized' : contact.connectionType;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }
    final distributionList = categoryCounts.entries
        .map((entry) => {'category': entry.key, 'count': entry.value})
        .toList();

    distributionList.sort((a, b) {
      int bcount = b['count'] as int;
      int acount = a['count'] as int;
      return bcount.compareTo(acount);
    });
    return distributionList;
  }

  Map<String, int> _calculateWeeklyNudgePerformance(List<Nudge> nudges) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final weeklyNudges = nudges.where((nudge) {
      return nudge.scheduledTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          nudge.scheduledTime.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();

    final scheduled = weeklyNudges.length;
    final completed = weeklyNudges.where((nudge) => nudge.isCompleted).length;
    final missed = weeklyNudges.where((nudge) => !nudge.isCompleted && nudge.scheduledTime.isBefore(DateTime.now())).length;
    final completionRate = scheduled == 0 ? 0 : (completed / scheduled * 100).round();

    return {
      'scheduled': scheduled,
      'completed': completed,
      'missed': missed,
      'completionRate': completionRate,
    };
  }

  Color _getCategoryColor(String category, int index) {
    final List<List<Color>> gradientColors = const [
      [AppColors.lightPrimary, AppColors.lightSecondary],
      [Color(0xFF4CAF50), Color(0xFF8BC34A)],
      [Color(0xFF9C27B0), Color(0xFFE040FB)],
      [Color(0xFFFF9800), Color(0xFFFFC107)],
      [Color(0xFFF44336), AppColors.lightError],
      [AppColors.lightPrimary, AppColors.lightPrimaryContainer],
      [Color(0xFFFFC107), Color(0xFFFFEB3B)],
      [Color(0xFF795548), Color(0xFFA1887F)],
      [Color(0xFF607D8B), Color(0xFF90A4AE)],
      [Color(0xFFE91E63), Color(0xFFF06292)],
      [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
      [Color(0xFF8BC34A), Color(0xFFAED581)],
      [Color(0xFF673AB7), Color(0xFF9575CD)],
      [Color(0xFFFF5722), Color(0xFFFF8A65)],
      [Color(0xFF009688), Color(0xFF4DB6AC)],
      [Color(0xFF3F51B5), Color(0xFF7986CB)],
      [Color(0xFFCDDC39), Color(0xFFE6EE9C)],
      [Color(0xFFFFEB3B), Color(0xFFFFF59D)],
      [AppColors.lightOutline, AppColors.lightSurfaceContainerHigh],
      [Color(0xFF00E676), Color(0xFF69F0AE)],
    ];
    
    final int colorIndex = index % gradientColors.length;
    return gradientColors[colorIndex][0];
  }

  Analytics _calculateAnalytics(List<Contact> contacts, List<Nudge> nudges) {
    final vipCount = contacts.where((c) => c.isVIP).length;
    final needsAttention = contacts
        .where((c) => c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30))))
        .length;

    return Analytics(
      totalContacts: contacts.length,
      vipContacts: vipCount,
      completedNudges: nudges.where((nudge) => nudge.isCompleted).length,
      contactsNeedingAttention: needsAttention,
      contactsByType: {},
      relationshipHealth: 0,
      nudgeCompletionRate: 0,
      weeklyConnections: 0,
      monthlyCatchups: 0,
      vipInteractions: 0,
      newConnections: 0,
      lastUpdated: DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stitch v4 dashboard ("today agenda" layout) — replaces the legacy
  // analytics-style dashboard. Mockup refs:
  //   light: stitch_nudge_mock_up_v4/dashboard_consistent_titles
  //   dark:  stitch_nudge_mock_up_v4/dashboard_dark_mode_3
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStitchDashboard(
      ThemeProvider themeProvider, List<Contact> contacts, ApiService apiService) {
    final user = Provider.of<AuthService>(context).currentUser;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<Nudge>>(
        stream: NudgeService().getNudgesStream(user!.uid),
        builder: (context, nudgeSnapshot) {
          final nudges = nudgeSnapshot.data ?? [];
          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                title: _buildStitchTopBar(user.photoURL, themeProvider),
                floating: true,
                snap: true,
                pinned: false,
                centerTitle: false,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildUpcomingNudgesCard(nudges, themeProvider),
                    const SizedBox(height: 20),
                    _buildTodaysNudgesCard(nudges, contacts, themeProvider),
                    const SizedBox(height: 20),
                    _buildDailyMomentumCard(nudges),
                    const SizedBox(height: 20),
                    _buildGrowUniverseCard(themeProvider),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStitchTopBar(String? photoUrl, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.lightPrimary.withOpacity(0.15),
                  width: 2,
                ),
                image: photoUrl != null && photoUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                    : null,
                color: photoUrl == null || photoUrl.isEmpty
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
              ),
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(Icons.person,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingNudgesCard(List<Nudge> nudges, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final week = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              'PLAN AHEAD',
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.secondary,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upcoming Nudges',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay on track with your scheduled reconnections this week.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 7; i++)
                _buildWeekDayCell(
                  label: dayLabels[i],
                  date: week[i],
                  isToday: week[i] == today,
                  nudgeCount: nudges.where((n) {
                    final s = n.scheduledTime;
                    return DateTime(s.year, s.month, s.day) == week[i] &&
                        !n.isCompleted;
                  }).length,
                  themeProvider: themeProvider,
                ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Expand Calendar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: theme.colorScheme.onSurface),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayCell({
    required String label,
    required DateTime date,
    required bool isToday,
    required int nudgeCount,
    required ThemeProvider themeProvider,
  }) {
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 56,
          decoration: BoxDecoration(
            color: isToday
                ? theme.colorScheme.primary
                : (isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : const Color(0xFFF4EFE9)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isToday
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (nudgeCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    nudgeCount.clamp(1, 3),
                    (i) => Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.white
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysNudgesCard(
      List<Nudge> nudges, List<Contact> contacts, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final pendingToday = nudges.where((n) {
      if (n.isCompleted) return false;
      return n.scheduledTime.isBefore(tomorrow);
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final visible = pendingToday.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Nudges",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.white,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '${pendingToday.length} Pending',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              alignment: Alignment.center,
              child: Text(
                "You're all caught up for today.",
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...visible.map((nudge) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildTodayNudgeRow(nudge, contacts, themeProvider),
                )),
        ],
      ),
    );
  }

  Widget _buildTodayNudgeRow(
      Nudge nudge, List<Contact> contacts, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final contact = contacts.cast<Contact?>().firstWhere(
          (c) => c?.id == nudge.contactId,
          orElse: () => null,
        );
    final imageUrl = contact?.imageUrl.isNotEmpty == true
        ? contact!.imageUrl
        : nudge.contactImageUrl;
    final hasImage = imageUrl.isNotEmpty;
    final initials = _getNudgeContactInitials(nudge.contactName);
    final isBirthday = nudge.nudgeType.toLowerCase().contains('birthday');
    final actionIcon = isBirthday ? Icons.cake_rounded : Icons.send_rounded;
    final daysSince = contact != null
        ? DateTime.now().difference(contact.lastContacted).inDays
        : null;
    final subtitle = nudge.message.isNotEmpty
        ? nudge.message
        : daysSince != null
            ? 'Time to reconnect • $daysSince days since last talk'
            : 'Scheduled for today';

    return GestureDetector(
      onTap: () {
        if (contact != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ContactDetailScreen(contact: contact)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHigh,
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: hasImage
                  ? null
                  : Text(
                      initials,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nudge.contactName.isNotEmpty
                        ? nudge.contactName.split(' ').first
                        : 'Friend',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.10),
              ),
              child:
                  Icon(actionIcon, size: 18, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  String _getNudgeContactInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  Widget _buildDailyMomentumCard(List<Nudge> nudges) {
    final streak = _computeStreakDays(nudges);
    final progress = (streak.clamp(0, 7) / 7.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF751FE7), Color(0xFF6800D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF751FE7).withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 30, color: Colors.white),
              Text(
                'DAILY MOMENTUM',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '$streak',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            streak == 1 ? 'Day Streak' : 'Days Streak',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.20),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  int _computeStreakDays(List<Nudge> nudges) {
    final completedDates = <DateTime>{};
    for (final n in nudges) {
      final t = n.completedAt;
      if (t == null) continue;
      completedDates.add(DateTime(t.year, t.month, t.day));
    }
    if (completedDates.isEmpty) return 0;
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!completedDates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!completedDates.contains(cursor)) return 0;
    }
    var count = 0;
    while (completedDates.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  Widget _buildGrowUniverseCard(ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    return GestureDetector(
      onTap: () => _showAddContactOptions(context, themeProvider),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiary.withOpacity(isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: theme.colorScheme.tertiary.withOpacity(0.30),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                size: 28,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grow your Universe',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add a new meaningful contact to your orbit.',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.tertiary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(Contact contact, ApiService apiService, {bool showConnectionType = false, required BuildContext context}) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final cachedIndex = _getCachedRandomIndex(contact.id);
    final fallbackAsset = 'assets/contact-icons/$cachedIndex.png';
    final hasImage = contact.imageUrl.isNotEmpty;
    final initials = _getContactInitials(contact.name);
    var size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ContactDetailScreen(contact: contact)),
        );
      },
      child: Container(
        width: size.width * 0.3,
        margin: const EdgeInsets.only(right: 10),
        child: Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: hasImage
                              ? NetworkImage(contact.imageUrl) as ImageProvider
                              : AssetImage(fallbackAsset),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: !hasImage
                          ? Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            )
                          : null,
                    ),
                    contact.isVIP
                        ? Positioned(
                            bottom: -4,
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: SvgPicture.asset(
                                'assets/quick-insights/close circle-star.svg',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFFFFD500),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          )
                        : Center(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  contact.name.split(' ').first,
                  style: TextStyle(fontSize: 12, fontFamily: GoogleFonts.beVietnamPro().fontFamily, color: Theme.of(context).colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                // Connection type indicator - only for Close Circle
                if (showConnectionType && contact.connectionType.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contact.connectionType,
                      style: TextStyle(
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get text hint color based on theme
  // Color _getTextHintColor(BuildContext context, ThemeProvider themeProvider) {
  //   return themeProvider.isDarkMode ? AppColors.darkOutline : AppColors.lightOutline;
  // }
}

// Add extension method to ThemeProvider for convenience
extension ThemeProviderExtension on ThemeProvider {
  Color getTextHintColor(BuildContext context) {
    return isDarkMode ? AppColors.darkOutline : AppColors.lightOutline;
  }
}
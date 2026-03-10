// dashboard_screen.dart - Updated for theme support
// import 'dart:math';
import 'package:flutter/material.dart';
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
  
  const DashboardScreen({super.key, this.initialTab = 1});

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
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = true;
  double _lastOffset = 0.0;

  int _selectedPieSegmentIndex = -1;
  String? _explodedCategory;

  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3)
  );
  bool _showConfetti = false;

  // final Random _random = Random();

  @override
  void initState() {
    super.initState();
    getNudges();
    _checkDeletionRetry();
    _currentIndex = widget.initialTab;
    _initializeNotifications();
    _initializeSocialUniverse();
    _scrollController.addListener(() {
      _handleScroll();
    });

  }

    @override
  void dispose() {
    _confettiController.dispose(); // Add this
    super.dispose();
  }

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
      print('Error initializing Social Universe: $e');
    }
  }

  Future<void> _runDailyCDIUpdate(ApiService apiService) async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateKey = 'last_cdi_update_${DateTime.now().day}';
    final shouldUpdate = prefs.getBool(lastUpdateKey) != true;
    
    if (shouldUpdate) {
      try {
        await apiService.batchUpdateCDI();
        await prefs.setBool(lastUpdateKey, true);
        print('Daily CDI update completed');
      } catch (e) {
        print('Error in daily CDI update: $e');
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

  Future<void> getNudges () async {
    ApiService apiService = ApiService();
    var allOfNudges =  await apiService.getAllNudges();
    print('all nudges are'); print(allOfNudges);
    setState(() {
      allNudges = allOfNudges;
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
    
    print('DashboardScreen building with _currentIndex: $_currentIndex, initialTab: ${widget.initialTab}');
    
    if (user == null) {
      return Scaffold(
        backgroundColor: themeProvider.getBackgroundColor(context),
        body: Center(
          child: Text(
            'Please log in to view dashboard',
            style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans',),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: themeProvider.getBackgroundColor(context),
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
          // Floating Navigation Bar
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: _buildFloatingNavigationBar(context, themeProvider),
          ),
          
          Consumer<FeedbackProvider>(
            builder: (context, feedbackProvider, child) {
              return feedbackProvider.isFabMenuOpen
                  ? Container(
                      color: Colors.black.withOpacity(0.55),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    )
                  : const SizedBox.shrink();
            },
          ),
          
          Consumer<FeedbackProvider>(
            builder: (context, feedbackProvider, child) {
              return Positioned(
                bottom: 70,
                right: 20,
                child: FeedbackFloatingButton(
                  currentSection: getCurrentSection(),
                  fromDashboard: true,
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
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ),
          
        ],
      ),
    );
  }

  Widget _buildDashboardWithSliver(ThemeProvider themeProvider, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: themeProvider.getBackgroundColor(context),
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
                      fontFamily: 'Inter', 
                      fontWeight: FontWeight.w800,
                      color: themeProvider.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                backgroundColor: themeProvider.getBackgroundColor(context),
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
                        child: Icon(Icons.settings, color: themeProvider.isDarkMode ? Colors.white : Color(0xff555555), size: 20),
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
                                fontFamily: 'OpenSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: themeProvider.getTextSecondaryColor(context),
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
                              child: Text('View All', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans',)),
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
                    //             fontFamily: 'OpenSans',
                    //             fontWeight: FontWeight.w500,
                    //             color: themeProvider.getTextSecondaryColor(context),
                    //           ),
                    //         ),
                    //         const Spacer(),
                    //         TextButton(
                    //           onPressed: () {
                    //             setState(() => _currentIndex = 2);
                    //           },
                    //           child: Text(
                    //             'View All',
                    //             style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans',),
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
      backgroundColor: themeProvider.getSurfaceColor(context),
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
                    color: themeProvider.getTextPrimaryColor(context),
                    fontSize: 18,
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.person_add, color: themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor),
                title: Text('ADD CONTACT MANUALLY', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'OpenSans', color: themeProvider.getTextPrimaryColor(context))),
                subtitle: Text('Create a new contact from scratch', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans',)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/add_contact');
                },
              ),
              ListTile(
                leading: Icon(Icons.import_contacts, color: themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor),
                title: Text('IMPORT CONTACTS', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'OpenSans', color: themeProvider.getTextPrimaryColor(context))),
                subtitle: Text('Import from your device contacts', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans',)),
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

  Widget _buildFloatingNavigationBar(BuildContext context, ThemeProvider themeProvider) {
    final overdueNudges = _getOverdueNudges(allNudges);
    final hasOverdue = overdueNudges.isNotEmpty;
    
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: themeProvider.isDarkMode
            ? Color(0xff111111).withOpacity(0.7)
            : Colors.white.withOpacity(0.7),
        border: Border.all(color: themeProvider.isDarkMode ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.7),
            blurRadius: themeProvider.isDarkMode ?35: 50,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home
          // _buildNavItem(
          //   index: 0,
          //   icon: SvgPicture.asset(
          //     'assets/navbar-icons/home-icon.svg',
          //     width: 22,
          //     height: 22,
          //     colorFilter: ColorFilter.mode(
          //       _currentIndex == 0 
          //         ? themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor 
          //         : themeProvider.getTextHintColor(context),
          //       BlendMode.srcIn,
          //     ),
          //   ),
          //   themeProvider: themeProvider,
          // ),
          
          // Social Universe
          _buildNavItem(
            index: 1,
            icon: SvgPicture.asset(
                  'assets/navbar-icons/star.svg',
                  width: 30,
                  height: 30,
                  colorFilter: ColorFilter.mode(
                    _currentIndex == 1 
                      ? themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor 
                      : themeProvider.getTextHintColor(context),
                    BlendMode.srcIn,
                  ),
                ),
            themeProvider: themeProvider,
          ),
          
         // Notifications
          _buildNavItem(
            index: 2,
            icon: Stack(
              children: [
                SvgPicture.asset(
                  'assets/navbar-icons/nudges.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    _currentIndex == 2 
                      ? themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor 
                      : themeProvider.getTextHintColor(context),
                    BlendMode.srcIn,
                  ),
                ),
                if (hasOverdue)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                            blurRadius: 1,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            themeProvider: themeProvider,
          ),
          
          // Groups
          _buildNavItem(
            index: 3,
            icon: SvgPicture.asset(
              'assets/navbar-icons/groups-icon.svg',
              width: 25,
              height: 25,
              colorFilter: ColorFilter.mode(
                _currentIndex == 3 
                  ? themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor 
                  : themeProvider.getTextHintColor(context),
                BlendMode.srcIn,
              ),
            ),
            themeProvider: themeProvider,
          ),
          
          // Contacts
           _buildNavItem(
            index: 4,
            icon: SvgPicture.asset(
              'assets/navbar-icons/contacts.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                _currentIndex == 4 
                  ? themeProvider.isDarkMode ? AppTheme.darkIconColor : AppTheme.primaryColor 
                  : themeProvider.getTextHintColor(context),
                BlendMode.srcIn,
              ),
            ),
            themeProvider: themeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required Widget icon,
    required ThemeProvider themeProvider,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          hideFloatingActionButton = false;
          attentionFilter = false;
          vipFilter = false;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _currentIndex == index 
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Center(child: icon),
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
      backgroundColor: themeProvider.getSurfaceColor(context),
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
        color: themeProvider.getSurfaceColor(context),
        border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : AppTheme.lightCardBorder, width: 0.6),
        borderRadius: BorderRadius.circular(12),
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
                fontFamily: 'OpenSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: themeProvider.getTextSecondaryColor(context),
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
        color: themeProvider.getSurfaceColor(context),
        border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : AppTheme.lightCardBorder, width: 0.6),
        borderRadius: BorderRadius.circular(12),
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
                fontFamily: 'OpenSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: themeProvider.getTextSecondaryColor(context),
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
                  iconColor: AppTheme.successColor,
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
              style: TextStyle(fontSize: 10, fontFamily: 'OpenSans', fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            LinearPercentIndicator(
              animation: true,
              lineHeight: 20.0,
              animationDuration: 1000,
              percent: (weeklyNudgePerformance['completionRate'] ?? 0) / 100,
              center: Text(
                "${(weeklyNudgePerformance['completionRate'] ?? 0).toStringAsFixed(1)}%",
                style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans', fontSize: 12),
              ),
              barRadius: const Radius.circular(10),
              linearGradient: const LinearGradient(
                colors: [Color(0xFF2D85F6), Color(0xFF5CDEE5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              backgroundColor: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[300],
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
        color: themeProvider.getSurfaceColor(context),
        border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : AppTheme.lightCardBorder, width: 0.6),
        borderRadius: BorderRadius.circular(12),
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
                fontFamily: 'OpenSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: themeProvider.getTextSecondaryColor(context),
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
                ? AppTheme.darkSurfaceVariant 
                : Colors.white)
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? AppTheme.darkCardBorder 
              : AppTheme.lightCardBorder, 
          width: 0.6
        ),
      ),
      child: Stack(
        children: [
          // Add an additional gradient overlay for dark mode to improve text contrast
          if (backgroundAsset != null && themeProvider.isDarkMode)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                      fontFamily: 'OpenSans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: backgroundAsset != null
                          // White text for cards with background images
                          ? Colors.white
                          : themeProvider.getTextPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: backgroundAsset != null
                          // White text for cards with background images
                          ? Colors.white
                          : themeProvider.getTextSecondaryColor(context),
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
      backgroundColor: themeProvider.getSurfaceColor(context),
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
                ? AppTheme.darkSurfaceVariant 
                : Colors.white)
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? AppTheme.darkCardBorder 
              : AppTheme.lightCardBorder, 
          width: 0.6
        ),
      ),
      child: Stack(
        children: [
          // Add an additional gradient overlay for dark mode to improve text contrast
          if (backgroundAsset != null && themeProvider.isDarkMode)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                      fontFamily: 'OpenSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: backgroundAsset != null
                          // White text for cards with background images
                          ? Colors.white
                          : themeProvider.getTextSecondaryColor(context),
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
        color: themeProvider.getSurfaceColor(context),
        border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : AppTheme.lightCardBorder, width: 0.6),
        borderRadius: BorderRadius.circular(12),
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
                fontFamily: 'OpenSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: themeProvider.getTextSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            if (distributionData.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64, color: themeProvider.isDarkMode ? AppTheme.darkTextHint : Colors.grey),
                    const SizedBox(height: 16),
                    Text('No contacts yet', style: TextStyle(fontSize: 16, fontFamily: 'OpenSans', color: themeProvider.isDarkMode ? AppTheme.darkTextHint : Colors.grey)),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final count = segmentData['count'] as int;
    final percentage = ((count / totalContacts) * 100).toStringAsFixed(2);
    final category = segmentData['category'];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCategoryColor(category, 0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getCategoryColor(category, 0).withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: TextStyle(fontSize: 16, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context))),
              const SizedBox(height: 4),
              Text('$count contact${count != 1 ? 's' : ''}', style: TextStyle(fontSize: 14, fontFamily: 'OpenSans', color: themeProvider.getTextSecondaryColor(context))),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 18, fontFamily: 'OpenSans', fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text('of total contacts', style: TextStyle(fontSize: 12, fontFamily: 'OpenSans', color: themeProvider.getTextSecondaryColor(context))),
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
      [Color(0xFF2D85F6), Color(0xFF5CDEE5)],
      [Color(0xFF4CAF50), Color(0xFF8BC34A)],
      [Color(0xFF9C27B0), Color(0xFFE040FB)],
      [Color(0xFFFF9800), Color(0xFFFFC107)],
      [Color(0xFFF44336), Color(0xFFFF5252)],
      [Color(0xFF2196F3), Color(0xFF64B5F6)],
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
      [Color(0xFF9E9E9E), Color(0xFFE0E0E0)],
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

  Widget _buildContactCard(Contact contact, ApiService apiService, {bool showConnectionType = false, required BuildContext context}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
          color: themeProvider.getSurfaceColor(context),
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
                                style: const TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
                  style: TextStyle(fontSize: 12, fontFamily: 'OpenSans', color: themeProvider.getTextPrimaryColor(context)),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      contact.connectionType,
                      style: TextStyle(
                        fontFamily: 'OpenSans',
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
  //   return themeProvider.isDarkMode ? AppTheme.darkTextHint : AppTheme.lightTextHint;
  // }
}

// Add extension method to ThemeProvider for convenience
extension ThemeProviderExtension on ThemeProvider {
  Color getTextHintColor(BuildContext context) {
    return isDarkMode ? AppTheme.darkTextHint : AppTheme.lightTextHint;
  }
}
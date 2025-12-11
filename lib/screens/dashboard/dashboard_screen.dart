// import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nudge/helpers/deletion_retry_helper.dart';
import 'package:nudge/models/analytics.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/screens/contacts/contacts_list_screen.dart';
import 'package:nudge/screens/groups/groups_list_screen.dart';
import 'package:nudge/screens/notifications/notifications_screen.dart';
// import 'package:nudge/screens/settings/settings_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/social_universe_service.dart';
// import 'package:nudge/widgets/contact_quick_panel.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:nudge/widgets/screen_tracker.dart';
import 'package:nudge/widgets/simple_contact_panel.dart';
import 'package:nudge/widgets/social_universe.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../services/auth_service.dart';
import '../../services/nudge_service.dart';
import '../../models/contact.dart';
// import '../../widgets/vip_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NudgeService nudgeService = NudgeService();
  int _currentIndex = 0;
  bool vipFilter = false;
  bool attentionFilter = false;
  List<Contact> totalContacts = [];
  bool hideFloatingActionButton = false;
  final Map<String, int> _cachedAvatarIndices = {};
  List<Nudge> allNudges = [];
  List<Nudge> overDueNudges = [];

  int _selectedPieSegmentIndex = -1;
  String? _explodedCategory;

  // final Random _random = Random();

  @override
  void initState() {
    super.initState();
    getNudges();
    _checkDeletionRetry();
    _initializeNotifications();
     _initializeSocialUniverse();
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


  // Future<DateTime?> _getLastCDIUpdate() async {
  //   // Implement storage for last update time
  //   final prefs = await SharedPreferences.getInstance();
  //   final timestamp = prefs.getInt('last_cdi_update');
  //   return timestamp != null 
  //       ? DateTime.fromMillisecondsSinceEpoch(timestamp)
  //       : null;
  // }

  // Future<void> _saveLastCDIUpdate(DateTime time) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setInt('last_cdi_update', time.millisecondsSinceEpoch);
  // }


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
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view dashboard')),
      );
    }

    return StreamProvider<List<Contact>>(
      create: (context) => apiService.getContactsStream(),
      initialData: const [],
      child: StreamProvider<List<SocialGroup>>(
        initialData: const [],
        create: (context) => apiService.getGroupsStream(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: _buildAppBar(apiService),
          drawer: _buildNavigationDrawer(context, authService),
          body: Stack(
            children: [
              Consumer2<List<Contact>, List<SocialGroup>>(
                builder: (context, contacts, groups, child) {
                  totalContacts = contacts;
                  return _buildCurrentView(context, contacts, groups, apiService);
                },
              ),
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).size.height * 0.4,
                child: FeedbackFloatingButton(
                  currentSection: getCurrentSection(),
                ),
              ),
            ],
          ),
          floatingActionButton: hideFloatingActionButton ? Container() : _buildFloatingActionButton(context),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
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

    AppBar _buildAppBar(ApiService apiService) {
    // final hasOverdueNudges = _hasOverdueNudges();
    
    final overdueNudges = _getOverdueNudges(allNudges);
    final hasOverdue = overdueNudges.isNotEmpty;
   
    return AppBar(
      title: GradientText(
        text: 'NUDGE',
        style: const TextStyle(
          fontSize: 25,
          fontFamily: 'RobotoMono',
          fontWeight: FontWeight.bold,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
      elevation: 0,
      actions: _currentIndex == 0
        ?[Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    setState(() => _currentIndex = 3); // Switch to nudges view
                  },
                  tooltip: 'Notifications',
                ),
                if (hasOverdue)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            )
      ]:null,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    );
  }

  Widget _buildCurrentView(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardContent(context, contacts, groups, apiService);
      case 1:
        return ContactsListScreen(
          showAppBar: false,
          filter: vipFilter ? 'vip' : attentionFilter ? 'needs_attention' : '',
          hideButton: hideButton,
        );
      case 2:
        return const GroupsListScreen(showAppBar: false);
      case 3:
        return const NotificationsScreen(showAppBar: false);
      default:
        return _buildDashboardContent(context, contacts, groups, apiService);
    }
  }

  // bool _hasOverdueNudges() {
  //   final authService = Provider.of<AuthService>(context, listen: false);
  //   final user = authService.currentUser;
  //   if (user == null) return false;
    
  //   // This is a simplified check - in practice you'd want to use a stream or provider
  //   return false;
  // }

  Widget _buildFloatingActionButton(BuildContext context) {
    switch (_currentIndex) {
      case 0:
        return Container();
      case 1:
        return FloatingActionButton(
          onPressed: () {
            _showAddContactOptions(context);
          },
          backgroundColor: const Color(0xff3CB3E9),
          child: const Icon(Icons.add, color: Colors.white),
        );
      case 2:
        return Container();
      default:
        return Container();
    }
  }

  void _showAddContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'ADD CONTACTS',
                  style: TextStyle(
                    color: Color(0xff555555),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Color(0xff3CB3E9)),
                title: const Text('ADD CONTACT MANUALLY', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff555555)),),
                subtitle: const Text('Create a new contact from scratch', style: TextStyle(color: Color(0xff555555)),),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/add_contact');
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_contacts, color: Color(0xff3CB3E9)),
                title: const Text('IMPORT CONTACTS', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff555555)),),
                subtitle: const Text('Import from your device contacts', style: TextStyle(color: Color(0xff555555)),),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/import_contacts');
                },
              ),
              // if (Theme.of(context).platform == TargetPlatform.android)
              //   ListTile(
              //     leading: const Icon(Icons.smartphone, color: Color(0xff3CB3E9)),
              //     title: const Text('SMART IMPORT', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff555555)),),
              //     subtitle: const Text('Automatically organize and categorize contacts', style: TextStyle(color: Color(0xff555555)),),
              //     onTap: () {
              //       Navigator.pop(context);
              //       _showSmartImportDialog(context);
              //     },
              //   ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // void _showSmartImportDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Smart Import'),
  //       content: const Text(
  //         'Smart import will analyze your contacts and automatically categorize them based on communication patterns and social groups.',
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               const SnackBar(
  //                 content: Text('Smart import feature coming soon!'),
  //                 backgroundColor: Color(0xff3CB3E9),
  //               ),
  //             );
  //           },
  //           child: const Text('Start Import'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void hideButton() {
    setState(() {
      hideFloatingActionButton = true;
    });
  }

  Widget _buildBottomNavigationBar() {
    final overdueNudges = _getOverdueNudges(allNudges);
    final hasOverdue = overdueNudges.isNotEmpty;
        
        return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        border: const Border(
          top: BorderSide(
            color: Color(0xF2FFFFFF),
            width: 4.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: const Color(0xFF3CB3E9),
        unselectedItemColor: const Color(0xFF8A8A8A),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            hideFloatingActionButton = false;
            attentionFilter = false;
            vipFilter = false;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/navbar-icons/home-icon.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                _currentIndex == 0 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                BlendMode.srcIn,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/navbar-icons/contacts-icon.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                _currentIndex == 1 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                BlendMode.srcIn,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/navbar-icons/groups-icon.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                _currentIndex == 2 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                BlendMode.srcIn,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Stack(
                  children: [
                    SvgPicture.asset(
                      'assets/navbar-icons/notifications-icon.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        _currentIndex == 3 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                        BlendMode.srcIn,
                      ),
                    ),
                    if (hasOverdue)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: '',
              ),
            ],
          ),
       );  
  }

  void _showContactQuickPanel(BuildContext context, Contact contact, ApiService apiService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SimpleContactPanel(
          contact: contact,
          apiService: apiService,
        );
      },
    );
  }

  // DASHBOARD CONTENT
  Widget _buildDashboardContent(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    return StreamBuilder<List<Nudge>>(
      stream: NudgeService().getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
      builder: (context, nudgeSnapshot) {
        final nudges = nudgeSnapshot.data ?? [];
        final analytics = _calculateAnalytics(contacts, nudges);
        final weeklyNudgePerformance = _calculateWeeklyNudgePerformance(nudges);

        final vipContacts = contacts.where((c) => c.isVIP).toList();
        final needsAttention = contacts.where((c) => c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text('DASHBOARD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, fontFamily: 'Inter', color: Color(0xff555555))),
              const SizedBox(height: 20),
            SocialUniverseWidget(
              contacts: contacts,
              onContactSelect: (contact) {
                _showContactQuickPanel(context, contact, apiService);
              },
              height: 400, // Increased height
            ),
            const SizedBox(height: 20),
              // Quick Insights (cards with icon + value + label)
              _buildQuickInsights(analytics, contacts.length),
              const SizedBox(height: 20),

              // Nudge Performance (cards + gradient bar)
              _buildWeeklyNudgePerformanceSection(weeklyNudgePerformance),
              const SizedBox(height: 20),

              // Quick Actions BELOW nudges (per your latest screenshot)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('QUICK ACTIONS', style: TextStyle(
                  fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
              // letterSpacing: 1.0,
                )),
              ),
              const SizedBox(height: 10),
              _buildCenteredQuickActions(context),
              const SizedBox(height: 20),

              if (vipContacts.isNotEmpty) ...[
                Row(
                  children: [
                     Text('CLOSE CIRCLE', style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff6e6e6e),
                      // letterSpacing: 1.0,
                    )),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 1;
                          attentionFilter = false;
                          vipFilter = true;
                        });
                      },
                      child: const Text('View All', style: TextStyle(color: Color(0xff3CB3E9))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140, // Increased height to accommodate the tag
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vipContacts.length,
                    itemBuilder: (context, index) {
                      final contact = vipContacts[index];
                      return _buildContactCard(contact, apiService, showConnectionType: true);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Needs Care Section
              if (needsAttention.isNotEmpty) ...[
                Row(
                  children: [
                     Text(
                      'NEEDS CARE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff6e6e6e),
                      // letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _currentIndex = 1);
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(color: Color(0xff3CB3E9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                 SizedBox(
                  height: 120, // Keep original height for Needs Care
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: needsAttention.length,
                    itemBuilder: (context, index) {
                      final contact = needsAttention[index];
                      return _buildContactCard(contact, apiService, showConnectionType: false);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              _buildInteractivePieChartSection(contacts),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // QUICK INSIGHTS row with stat cards
  Widget _buildQuickInsights(Analytics analytics, int totalContacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'QUICK INSIGHTS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
              // letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard(
          title: 'Total Contacts',
          value: totalContacts.toString(),
          iconSize: 35,
          iconAsset: 'assets/quick-insights/total-contacts.svg',
          backgroundAsset: null, // white background
          iconColor: const Color(0xff3CB3E9),
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _buildStatCard(
          title: 'Close Circle',
          value: analytics.vipContacts.toString(),
          iconSize: 30,
          iconAsset: 'assets/quick-insights/close circle-star.svg',
          backgroundAsset: 'assets/card-backgrounds/close-circle.png',
          iconColor: Colors.white,
          onTap: () {
            setState(() {
              _currentIndex = 1;
              vipFilter = true;
              attentionFilter = false;
            });
          },
        ),
        _buildStatCard(
          title: 'Needs Care',
          value: analytics.contactsNeedingAttention.toString(),
          iconSize: 30,
          iconAsset: 'assets/quick-insights/needs care.svg',
          backgroundAsset: 'assets/card-backgrounds/needs-care.png',
          iconColor: Colors.white,
          onTap: () {
            setState(() {
              _currentIndex = 1;
              attentionFilter = true;
              vipFilter = false;
            });
          },
        ),
      ],
    )]);
  }

  // WEEKLY NUDGE PERFORMANCE with stat cards and gradient bar
  Widget _buildWeeklyNudgePerformanceSection(Map<String, int> weeklyNudgePerformance) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFFFEFEFE), width: 0.6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'NUDGES THIS WEEK',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
              // letterSpacing: 1.0,
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
                backgroundAsset: 'assets/card-backgrounds/scheduled.png', // matches your note
                iconColor: Colors.white,
              ),
              _buildStatCard(
                title: 'Completed',
                value: (weeklyNudgePerformance['completed'] ?? 0).toString(),
                iconSize: 35,
                iconAsset: 'assets/performance-icons/check-completed.svg',
                backgroundAsset: null, // white
                iconColor: Color(0xff00dd00),
              ),
              _buildStatCard(
                title: 'Missed',
                value: (weeklyNudgePerformance['missed'] ?? 0).toString(),
                iconSize: 35,
                iconAsset: 'assets/performance-icons/x-missed.svg',
                backgroundAsset: 'assets/card-backgrounds/missed.png',
                iconColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '      Nudge Completion Rate',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xff3CB3E9)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            animation: true,
            lineHeight: 20.0,
            animationDuration: 1000,
            percent: (weeklyNudgePerformance['completionRate'] ?? 0) / 100,
            center: Text(
              "${(weeklyNudgePerformance['completionRate'] ?? 0).toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.black, fontSize: 12),
            ),
            barRadius: const Radius.circular(10),
            linearGradient: const LinearGradient(
              colors: [Color(0xFF2D85F6), Color(0xFF5CDEE5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            backgroundColor: Colors.grey[300],
          ),
        ]),
      ),
    );
  }

  // GENERIC STAT CARD (used for Quick Insights + Performance)
  Widget _buildStatCard({
    required String title,
    required String value,
    required String iconAsset,
    required Color iconColor,
    String? backgroundAsset,
    double? iconSize,
    VoidCallback? onTap,
  }) {
    var size = MediaQuery.of(context).size;
    final card = Container(
      width: size.width*0.28,
      height: 120,
      decoration: BoxDecoration(
        color: backgroundAsset == null ? Colors.white : null,
        image: backgroundAsset != null
            ? DecorationImage(image: AssetImage(backgroundAsset), fit: BoxFit.cover)
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        border: backgroundAsset == null
            ? Border.all(color: const Color(0xFFFEFEFE), width: 0.6)
            : null,
      ),
      child: Stack(
        children: [
          if (backgroundAsset != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.35)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                // Icon at top
                SvgPicture.asset(
                  iconAsset,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
                const SizedBox(height: 8),
                // Value
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: backgroundAsset == null ? Color(0xff555555) : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: backgroundAsset == null ? const Color(0xFF444444) : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )),
        ],
      ),
    );

    return GestureDetector(onTap: onTap, child: MouseRegion(cursor: SystemMouseCursors.click, child: card));
  }

  // Quick actions row (uses SVG icons from assets/quick-icons/)
  Widget _buildCenteredQuickActions(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildQuickActionButton(
            svgAsset: 'assets/quick-actions/add contact icon.svg',
            label: 'Add Contacts',
            onPressed: () {
              _showAddContactOptions(context);
            },
          ),
          const SizedBox(width: 12),
          _buildQuickActionButton(
            svgAsset: 'assets/quick-actions/add group-icon.svg',
            label: 'Create Group', // corrected label
            onPressed: () {
              setState(() {
                _currentIndex = 2;
                attentionFilter = false;
                vipFilter = false;
              });
            },
          ),
        ],
      ),
    );
  }

Widget _buildQuickActionButton({
  required String svgAsset,
  required String label,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: 150,
    height: 120, // increased height
    child: Card(
      elevation: 4, // shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                svgAsset,
                width: 52,
                height: 52,
                colorFilter: const ColorFilter.mode(
                  Colors.grey, // dark grey icon
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff555555),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  int _getCachedRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    
    // Return cached index if exists
    if (_cachedAvatarIndices.containsKey(seed)) {
      return _cachedAvatarIndices[seed]!;
    }
    
    // Generate new index based on seed
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

    // Contact avatar with randomized background for no-image, and star overlay for VIP
  // Widget _buildContactAvatar(Contact contact) {
  //   final hasImage = contact.imageUrl.isNotEmpty;
  //   final cachedIndex = _getCachedRandomIndex(contact.id);
  //   final fallbackAsset = 'assets/contact-icons/$cachedIndex.png';
  //   final firstLetter = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';

  //   final avatar = Container(
  //     width: 56,
  //     height: 56,
  //     decoration: BoxDecoration(
  //       shape: BoxShape.circle,
  //       image: DecorationImage(
  //         image: hasImage 
  //             ? NetworkImage(contact.imageUrl) as ImageProvider
  //             : AssetImage(fallbackAsset),
  //         fit: BoxFit.cover,
  //       ),
  //     ),
  //     child: !hasImage
  //         ? Center(
  //             child: Text(
  //               firstLetter,
  //               style: const TextStyle(
  //                 fontSize: 20,
  //                 fontWeight: FontWeight.bold,
  //                 color: Colors.white,
  //               ),
  //             ),
  //           )
  //         : null,
  //   );

  //   if (contact.isVIP) {
  //     return Stack(
  //       clipBehavior: Clip.none,
  //       alignment: Alignment.center,
  //       children: [
  //         avatar,
  //         Positioned(
  //           bottom: -4,
  //           child: Container(
  //             decoration: BoxDecoration(
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black.withOpacity(0.4),
  //                   blurRadius: 4,
  //                   offset: const Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: SvgPicture.asset(
  //               'assets/quick-insights/close circle-star.svg',
  //               width: 12,
  //               height: 12,
  //               colorFilter: const ColorFilter.mode(
  //                 Color(0xFFFFC500),
  //                 BlendMode.srcIn,
  //               ),
  //             ),
  //           ),
  //         ),
  //       ],
  //     );
  //   } else {
  //     return avatar;
  //   }
  // }
  // Pie chart section
  Widget _buildInteractivePieChartSection(List<Contact> contacts) {
    final distributionData = _calculateContactDistribution(contacts);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFFFEFEFE), width: 0.6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR SOCIAL LANDSCAPE',
           style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
              // letterSpacing: 1.0,
              )),
          const SizedBox(height: 16),
          if (distributionData.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No contacts yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 300,
                  child: SfCircularChart(
                    legend: Legend(
                      isVisible: true,
                      overflowMode: LegendItemOverflowMode.wrap,
                      position: LegendPosition.bottom,
                      itemPadding: 5,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    series: <CircularSeries>[
                      DoughnutSeries<Map<String, dynamic>, String>(
                        dataSource: distributionData,
                        xValueMapper: (Map<String, dynamic> data, _) => data['category'],
                        yValueMapper: (Map<String, dynamic> data, _) => data['count'],
                        dataLabelMapper: (Map<String, dynamic> data, _) {
                          final total = distributionData.fold(0, (sum, item) => sum + (item['count'] as int));
                          final percentage = ((data['count'] as int) / total * 100).toStringAsFixed(2);
                          if (_explodedCategory == data['category']) {
                            return '${data['count']} (${percentage}%)';
                          } else {
                            return '$percentage%';
                          }
                        },
                        dataLabelSettings: DataLabelSettings(
                          isVisible: true,
                          connectorLineSettings: ConnectorLineSettings(
                           
                          ),
                          textStyle: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          labelPosition: ChartDataLabelPosition.inside,
                        ),
                        pointColorMapper: (Map<String, dynamic> data, _) =>
                            _getCategoryColor(data['category'], distributionData.indexOf(data)),
                        innerRadius: '60%',
                        explode: true,
                        explodeAll: false,
                        explodeOffset: _explodedCategory != null ? '25%' : '15%',
                        explodeGesture: ActivationMode.singleTap,
                        onPointTap: (ChartPointDetails details) {
                          setState(() {
                            final tappedIndex = details.pointIndex ?? -1;
                            if (tappedIndex >= 0 && tappedIndex < distributionData.length) {
                              final tappedCategory = distributionData[tappedIndex]['category'];
                              if (_explodedCategory == tappedCategory) {
                                _explodedCategory = null;
                                _selectedPieSegmentIndex = -1;
                              } else {
                                _explodedCategory = tappedCategory;
                                _selectedPieSegmentIndex = tappedIndex;
                              }
                            }
                          });
                        },
                        onPointDoubleTap: (ChartPointDetails details) {
                          setState(() {
                            _explodedCategory = null;
                            _selectedPieSegmentIndex = -1;
                          });
                        },
                      ),
                    ],
                    tooltipBehavior: TooltipBehavior(
                      enable: false,
                      format: 'point.x : point.y contacts (point.percentage%)',
                      canShowMarker: true,
                    ),
                  ),
                ),
                if (_explodedCategory != null && _selectedPieSegmentIndex >= 0)
                  _buildSegmentDetails(
                    distributionData[_selectedPieSegmentIndex],
                    distributionData.fold(0, (sum, item) => sum + (item['count'] as int)),
                  ),
              ],
            ),
        ]),
      ),
    );
  }

  Widget _buildSegmentDetails(Map<String, dynamic> segmentData, int totalContacts) {
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
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$count contact${count != 1 ? 's' : ''}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff3CB3E9)),
              ),
              const SizedBox(height: 4),
              const Text('of total contacts', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
    final List<Color> distinctColors = const [
      Color(0xff3CB3E9),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFFF44336),
      Color(0xFF2196F3),
      Color(0xFFFFC107),
      Color(0xFF795548),
      Color(0xFF607D8B),
      Color(0xFFE91E63),
      Color(0xFF00BCD4),
      Color(0xFF8BC34A),
      Color(0xFF673AB7),
      Color(0xFFFF5722),
      Color(0xFF009688),
      Color(0xFF3F51B5),
      Color(0xFFCDDC39),
      Color(0xFFFFEB3B),
      Color(0xFF9E9E9E),
      Color(0xFF00E676),
    ];
    final int colorIndex = index % distinctColors.length;
    return distinctColors[colorIndex];
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

  Widget _buildContactCard(Contact contact, ApiService apiService, {bool showConnectionType = false}) {
    final cachedIndex = _getCachedRandomIndex(contact.id);
    final fallbackAsset = 'assets/contact-icons/$cachedIndex.png';
    final hasImage = contact.imageUrl.isNotEmpty;
    // final firstLetter = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    final initials = _getContactInitials(contact.name);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ContactDetailScreen(contact: contact)),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        child: Card(
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
                          initials, // Use initials instead of firstLetter
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
                ),
                contact.isVIP
                ?Positioned(
                  bottom: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1), // shadow color
                          blurRadius: 4, // softness of shadow
                          offset: const Offset(0, 2), // position of shadow
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/quick-insights/close circle-star.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFFFD500), // vibrant orange
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ):Center(),
                ]),
                const SizedBox(height: 8),
                Text(
                  contact.name.split(' ').first,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                // Connection type indicator - only for Close Circle
                if (showConnectionType && contact.connectionType.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xff3CB3E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      contact.connectionType,
                      style: const TextStyle(
                        color: Color(0xff3CB3E9),
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

  Widget _buildNavigationDrawer(BuildContext context, AuthService authService) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xff3CB3E9)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(children: [
                  SizedBox(width: 20),
                  Text(
                    'NUDGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontFamily: 'RobotoMono',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
                SizedBox(height: 10),
                Text(
                  'Nurture your relationships',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Color(0xff555555)),
            title: const Text('DASHBOARD', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.contacts, color: Color(0xff555555)),
            title: const Text('ALL CONTACTS', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 1;
                attentionFilter = false;
                vipFilter = false;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.group, color: Color(0xff555555)),
            title: const Text('GROUPS', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications, color: Color(0xff555555)),
            title: const Text('NUDGES & REMINDERS', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.import_contacts, color: Color(0xff555555)),
            title: const Text('IMPORT CONTACTS', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/import_contacts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Color(0xff555555)),
            title: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Color(0xff555555)),
            title: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            onTap: () async {
              _showLogoutConfirmation(authService);
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LOGGING OUT', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
        content: const Text('Are you sure you want to log out of your account?', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.signOut();
              // Force navigation to welcome screen
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/welcome', 
                (route) => false
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

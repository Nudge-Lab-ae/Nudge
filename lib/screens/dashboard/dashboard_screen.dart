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
import 'package:nudge/screens/social_universe/social_universe_immersive.dart';
// import 'package:nudge/screens/settings/settings_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/social_universe_service.dart';
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
// import '../../widgets/vip_badge.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;
  
  const DashboardScreen({super.key, this.initialTab = 0});

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
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = true;
  double _lastOffset = 0.0;

  int _selectedPieSegmentIndex = -1;
  String? _explodedCategory;

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

    print('DashboardScreen building with _currentIndex: $_currentIndex, initialTab: ${widget.initialTab}');
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view dashboard')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamProvider<List<Contact>>.value(
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
              case 0:
                return _buildDashboardWithSliver(context, contacts, groups, apiService);
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
              case 4: // NEW: Immersive Social Universe
                return const SocialUniverseImmersiveScreen();
              default:
                return _buildDashboardWithSliver(context, contacts, groups, apiService);
            }
            },
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }


  Widget _buildDashboardWithSliver(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<List<Nudge>>(
        stream: NudgeService().getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
        builder: (context, nudgeSnapshot) {
          final nudges = nudgeSnapshot.data ?? [];
          final analytics = _calculateAnalytics(contacts, nudges);
          final weeklyNudgePerformance = _calculateWeeklyNudgePerformance(nudges);
          final vipContacts = contacts.where((c) => c.isVIP).toList();
          final needsAttention = contacts.where((c) => c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Sliver App Bar - This is the smooth collapsing app bar
              SliverAppBar(
                title: Padding(
                  padding: EdgeInsets.only(left: 0),
                  child: Text( 'Dashboard',style: TextStyle(fontSize: 22, fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xff555555))),
                  ),
                backgroundColor: Color(0xFFF9FAFB),
                leading: Center(),
                iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
                elevation: 0,
                actions: [
                 Padding(
                  padding: EdgeInsets.only(right: 0),
                  child: MaterialButton(
                        child: const Icon(Icons.settings, color:  Color(0xff3CB3E9),),
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                        onLongPress: () {
                          apiService.cancelHourlyNotifications();
                        },
                        // tooltip: 'Notifications',
                      ),
                 )
                ],
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                floating: true, // Makes the app bar appear immediately when scrolling up
                snap: true, // Makes the app bar snap into view when scrolling up
                pinned: false, // Don't pin - let it fully disappear when scrolling down
              ),
              
              // Main content
              SliverPadding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Social Universe
                    SocialUniverseWidget(
                      contacts: contacts,
                      onContactView: (contact) {
                        _showContactQuickPanel(context, contact, apiService);
                      },
                      height: 500,
                       onFullScreenPressed: () {
                          setState(() {
                            _currentIndex = 4; // Navigate to immersive universe
                          });
                        },
                    ),
                    const SizedBox(height: 20),
                    
                    // Quick Insights
                    _buildQuickInsights(analytics, contacts.length),
                    const SizedBox(height: 20),

                    // Nudge Performance
                    _buildWeeklyNudgePerformanceSection(weeklyNudgePerformance),
                    const SizedBox(height: 20),

                    // Quick Actions
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'QUICK ACTIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xff6e6e6e),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCenteredQuickActions(context),
                    const SizedBox(height: 20),

                    // VIP Contacts
                    if (vipContacts.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'CLOSE CIRCLE',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff6e6e6e),
                            ),
                          ),
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
                        height: 140,
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
                        height: 120,
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

                    // Pie Chart
                    _buildInteractivePieChartSection(contacts),
                    const SizedBox(height: 20), // Bottom padding for FAB
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      
      // Feedback button for dashboard only
      floatingActionButton: _currentIndex == 0
          ? Padding(
        padding: EdgeInsets.only(right: 6,bottom: 30,),
        child: FeedbackFloatingButton(
                currentSection: getCurrentSection(),
              ),
            )
          : null,
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

//   List<Color> _getGradientPair(int index) {
//   final List<List<Color>> gradientColors = [
//     [Color(0xFF2D85F6), Color(0xFF5CDEE5)], // Blue gradient
//     [Color(0xFF4CAF50), Color(0xFF8BC34A)], // Green gradient
//     [Color(0xFF9C27B0), Color(0xFFE040FB)], // Purple gradient
//     [Color(0xFFFF9800), Color(0xFFFFC107)], // Orange gradient
//     [Color(0xFFF44336), Color(0xFFFF5252)], // Red gradient
//     [Color(0xFF2196F3), Color(0xFF64B5F6)], // Light blue gradient
//     [Color(0xFFFFC107), Color(0xFFFFEB3B)], // Yellow gradient
//     [Color(0xFF795548), Color(0xFFA1887F)], // Brown gradient
//     [Color(0xFF607D8B), Color(0xFF90A4AE)], // Blue grey gradient
//     [Color(0xFFE91E63), Color(0xFFF06292)], // Pink gradient
//     [Color(0xFF00BCD4), Color(0xFF4DD0E1)], // Cyan gradient
//     [Color(0xFF8BC34A), Color(0xFFAED581)], // Light green gradient
//     [Color(0xFF673AB7), Color(0xFF9575CD)], // Deep purple gradient
//     [Color(0xFFFF5722), Color(0xFFFF8A65)], // Deep orange gradient
//     [Color(0xFF009688), Color(0xFF4DB6AC)], // Teal gradient
//     [Color(0xFF3F51B5), Color(0xFF7986CB)], // Indigo gradient
//     [Color(0xFFCDDC39), Color(0xFFE6EE9C)], // Lime gradient
//     [Color(0xFFFFEB3B), Color(0xFFFFF59D)], // Amber gradient
//     [Color(0xFF9E9E9E), Color(0xFFE0E0E0)], // Grey gradient
//     [Color(0xFF00E676), Color(0xFF69F0AE)], // Green accent gradient
//   ];
  
//   final int colorIndex = index % gradientColors.length;
//   return gradientColors[colorIndex];
// }

  //   AppBar? _buildAppBar(ApiService apiService) {
  //   // final hasOverdueNudges = _hasOverdueNudges();
    
  //   // final overdueNudges = _getOverdueNudges(allNudges);
  //   // final hasOverdue = overdueNudges.isNotEmpty;

  //   if (!_showAppBar && _currentIndex == 0) {
  //     return null;
  //   }

  //   String title = 'Dashboard';
  //   if (_currentIndex == 1) {
  //     title = 'Contacts';
  //   } else if (_currentIndex == 2) {
  //     title = 'Social Groups';
  //   } else if (_currentIndex == 3) {
  //     title = 'Nudges';
  //   }
   
  //   return AppBar(
  //     title: Text(
  //       title, style: TextStyle(
  //         fontSize: 25,
  //         fontFamily: 'Inter',
  //         fontWeight: FontWeight.bold,
  //         color: Color(0xff555555)
  //       ),
  //     ),
  //     backgroundColor: Color(0xFFF9FAFB),
  //     iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
  //     elevation: 0,
  //     leading: Center(),
  //     actions: _currentIndex == 0
  //       ?[Stack(
  //             children: [
  //               IconButton(
  //                 icon: const Icon(Icons.settings),
  //                 onPressed: () {
  //                   Navigator.pushNamed(context, '/settings');
  //                 },
  //                 tooltip: 'Notifications',
  //               ),
  //             ],
  //           )
  //     ]:null,
  //     surfaceTintColor: Colors.transparent,
  //     centerTitle: false,
  //   );
  // }

  // Widget _buildCurrentView(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
  //   switch (_currentIndex) {
  //     case 0:
  //       return _buildDashboardContent(context, contacts, groups, apiService);
  //     case 1:
  //       return ContactsListScreen(
  //         showAppBar: false,
  //         filter: vipFilter ? 'vip' : attentionFilter ? 'needs_attention' : '',
  //         hideButton: hideButton,
  //       );
  //     case 2:
  //       return const GroupsListScreen(showAppBar: false);
  //     case 3:
  //       return const NotificationsScreen(showAppBar: false);
  //     default:
  //       return _buildDashboardContent(context, contacts, groups, apiService);
  //   }
  // }

  // Widget _buildFloatingActionButton(BuildContext context) {
  //   switch (_currentIndex) {
  //     case 0:
  //       return Container();
  //     case 1:
  //       return FloatingActionButton(
  //         onPressed: () {
  //           _showAddContactOptions(context);
  //         },
  //         backgroundColor: const Color(0xff3CB3E9),
  //         child: const Icon(Icons.add, color: Colors.white),
  //       );
  //     case 2:
  //       return Container();
  //     default:
  //       return Container();
  //   }
  // }

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

  Widget _buildBottomNavigationBar() {
    final overdueNudges = _getOverdueNudges(allNudges);
    final hasOverdue = overdueNudges.isNotEmpty;
    
    return Container(
      height: 70, // Slightly taller for 5 icons
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          canvasColor: Colors.transparent,
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
          selectedIconTheme: const IconThemeData(size: 24),
          unselectedIconTheme: const IconThemeData(size: 24),
          selectedFontSize: 0,
          unselectedFontSize: 0,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(top: 10),
                child: SvgPicture.asset(
                  'assets/navbar-icons/home-icon.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    _currentIndex == 0 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(top: 10),
                child: SvgPicture.asset(
                  'assets/navbar-icons/contacts-icon.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    _currentIndex == 1 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(top: 10),
                child: SvgPicture.asset(
                  'assets/navbar-icons/groups-icon.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    _currentIndex == 2 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(top: 10),
                child: Stack(
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
              ),
              label: '',
            ),
            // NEW: Immersive Universe Icon
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(top: 10),
                child: Icon(
                        Icons.star_border,
                        size: 22,
                        color: _currentIndex == 4 ? const Color(0xFF3CB3E9) : const Color(0xFF8A8A8A),
                      ),
              ),
              label: '',
            ),
          ],
        ),
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
    backgroundColor: Colors.white,
    builder: (context) {
      return ContactDetailsModal(
        contact: contact,
        apiService: apiService,
      );
    },
  );
}
  // DASHBOARD CONTENT

  // Widget _buildDashboardContent(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
  //   return StreamBuilder<List<Nudge>>(
  //     stream: NudgeService().getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
  //     builder: (context, nudgeSnapshot) {
  //       final nudges = nudgeSnapshot.data ?? [];
  //       final analytics = _calculateAnalytics(contacts, nudges);
  //       final weeklyNudgePerformance = _calculateWeeklyNudgePerformance(nudges);

  //       final vipContacts = contacts.where((c) => c.isVIP).toList();
  //       final needsAttention = contacts.where((c) => c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))).toList();

  //        return NotificationListener<ScrollNotification>(
  //         onNotification: (scrollNotification) {
  //           // Handle scroll for app bar visibility
  //           if (scrollNotification is ScrollUpdateNotification) {
  //             final currentOffset = _scrollController.offset;
  //             if (currentOffset > _lastOffset && currentOffset > 50) {
  //               if (_showAppBar) {
  //                 setState(() {
  //                   _showAppBar = false;
  //                 });
  //               }
  //             } else if (currentOffset < _lastOffset && _scrollController.offset <= 50) {
  //               if (!_showAppBar) {
  //                 setState(() {
  //                   _showAppBar = true;
  //                 });
  //               }
  //             }
  //             _lastOffset = currentOffset;
  //           }
  //           return false;
  //         },
  //         child: SingleChildScrollView(
  //           controller: _scrollController,
  //           physics: const BouncingScrollPhysics(),
  //           padding: const EdgeInsets.only(left: 16.0, right: 16.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const SizedBox(height: 10),
  //               const SizedBox(height: 10),
  //               SocialUniverseWidget(
  //                 contacts: contacts,
  //                 onContactView: (contact) {
  //                   _showContactQuickPanel(context, contact, apiService);
  //                 },
  //                 height: 500,
  //               ),
  //           const SizedBox(height: 20),
  //             // Quick Insights (cards with icon + value + label)
  //             _buildQuickInsights(analytics, contacts.length),
  //             const SizedBox(height: 20),

  //             // Nudge Performance (cards + gradient bar)
  //             _buildWeeklyNudgePerformanceSection(weeklyNudgePerformance),
  //             const SizedBox(height: 20),

  //             // Quick Actions BELOW nudges (per your latest screenshot)
  //             Padding(
  //               padding: EdgeInsets.symmetric(horizontal: 8.0),
  //               child: Text('QUICK ACTIONS', style: TextStyle(
  //                 fontWeight: FontWeight.w500,
  //             color: Color(0xff6e6e6e),
  //               )),
  //             ),
  //             const SizedBox(height: 10),
  //             _buildCenteredQuickActions(context),
  //             const SizedBox(height: 20),

  //             if (vipContacts.isNotEmpty) ...[
  //               Row(
  //                 children: [
  //                    Text('CLOSE CIRCLE', style: TextStyle(
  //                     fontSize: 15,
  //                     fontWeight: FontWeight.w500,
  //                     color: Color(0xff6e6e6e),
  //                   )),
  //                   const Spacer(),
  //                   TextButton(
  //                     onPressed: () {
  //                       setState(() {
  //                         _currentIndex = 1;
  //                         attentionFilter = false;
  //                         vipFilter = true;
  //                       });
  //                     },
  //                     child: const Text('View All', style: TextStyle(color: Color(0xff3CB3E9))),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 10),
  //               SizedBox(
  //                 height: 140,
  //                 child: ListView.builder(
  //                   scrollDirection: Axis.horizontal,
  //                   itemCount: vipContacts.length,
  //                   itemBuilder: (context, index) {
  //                     final contact = vipContacts[index];
  //                     return _buildContactCard(contact, apiService, showConnectionType: true);
  //                   },
  //                 ),
  //               ),
  //               const SizedBox(height: 20),
  //             ],

  //             // Needs Care Section
  //             if (needsAttention.isNotEmpty) ...[
  //               Row(
  //                 children: [
  //                    Text(
  //                     'NEEDS CARE',
  //                     style: TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xff6e6e6e),
  //                     ),
  //                   ),
  //                   const Spacer(),
  //                   TextButton(
  //                     onPressed: () {
  //                       setState(() => _currentIndex = 1);
  //                     },
  //                     child: const Text(
  //                       'View All',
  //                       style: TextStyle(color: Color(0xff3CB3E9)),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 10),
  //                SizedBox(
  //                 height: 120,
  //                 child: ListView.builder(
  //                   scrollDirection: Axis.horizontal,
  //                   itemCount: needsAttention.length,
  //                   itemBuilder: (context, index) {
  //                     final contact = needsAttention[index];
  //                     return _buildContactCard(contact, apiService, showConnectionType: false);
  //                   },
  //                 ),
  //               ),
  //               const SizedBox(height: 20),
  //             ],

  //             _buildInteractivePieChartSection(contacts),
  //             const SizedBox(height: 20),
  //           ],
  //         ),
  //       ));
  //     },
  //   );
  // }

  // QUICK INSIGHTS row with stat cards
  Widget _buildQuickInsights(Analytics analytics, int totalContacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'QUICK INSIGHTS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
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
          backgroundAsset: null,
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
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
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
                backgroundAsset: 'assets/card-backgrounds/scheduled.png',
                iconColor: Colors.white,
              ),
              _buildStatCard(
                title: 'Completed',
                value: (weeklyNudgePerformance['completed'] ?? 0).toString(),
                iconSize: 35,
                iconAsset: 'assets/performance-icons/check-completed.svg',
                backgroundAsset: null,
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
          label: 'Create Group',
          onPressed: () {
            setState(() {
              _currentIndex = 2;
              attentionFilter = false;
              vipFilter = false;
            });
          },
        ),
        const SizedBox(width: 12),
        _buildQuickActionButton(
          svgAsset: 'assets/quick-actions/touchpoint-icon.svg',
          label: 'Add Touchpoint',
          onPressed: () {
            _showAddTouchpointModal(context);
          },
        ),
      ],
    ),
  );
}

void _showAddTouchpointModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
  required String svgAsset,
  required String label,
  required VoidCallback onPressed,
}) {
  var size = MediaQuery.of(context).size;
  return SizedBox(
    width: size.width*0.28,
    height: 120,
    child: Card(
      elevation: 4,
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
                  Colors.grey,
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
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xff6e6e6e),
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
                  height: 370,
                  child: InteractiveDonutChart(distributionData: distributionData)
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
    // Create gradient colors for each category
    final List<List<Color>> gradientColors = const [
      [Color(0xFF2D85F6), Color(0xFF5CDEE5)], // Blue gradient
      [Color(0xFF4CAF50), Color(0xFF8BC34A)], // Green gradient
      [Color(0xFF9C27B0), Color(0xFFE040FB)], // Purple gradient
      [Color(0xFFFF9800), Color(0xFFFFC107)], // Orange gradient
      [Color(0xFFF44336), Color(0xFFFF5252)], // Red gradient
      [Color(0xFF2196F3), Color(0xFF64B5F6)], // Light blue gradient
      [Color(0xFFFFC107), Color(0xFFFFEB3B)], // Yellow gradient
      [Color(0xFF795548), Color(0xFFA1887F)], // Brown gradient
      [Color(0xFF607D8B), Color(0xFF90A4AE)], // Blue grey gradient
      [Color(0xFFE91E63), Color(0xFFF06292)], // Pink gradient
      [Color(0xFF00BCD4), Color(0xFF4DD0E1)], // Cyan gradient
      [Color(0xFF8BC34A), Color(0xFFAED581)], // Light green gradient
      [Color(0xFF673AB7), Color(0xFF9575CD)], // Deep purple gradient
      [Color(0xFFFF5722), Color(0xFFFF8A65)], // Deep orange gradient
      [Color(0xFF009688), Color(0xFF4DB6AC)], // Teal gradient
      [Color(0xFF3F51B5), Color(0xFF7986CB)], // Indigo gradient
      [Color(0xFFCDDC39), Color(0xFFE6EE9C)], // Lime gradient
      [Color(0xFFFFEB3B), Color(0xFFFFF59D)], // Amber gradient
      [Color(0xFF9E9E9E), Color(0xFFE0E0E0)], // Grey gradient
      [Color(0xFF00E676), Color(0xFF69F0AE)], // Green accent gradient
    ];
    
    final int colorIndex = index % gradientColors.length;
    // Return the base color (darker shade) for the segment
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

  Widget _buildContactCard(Contact contact, ApiService apiService, {bool showConnectionType = false}) {
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
        width: size.width*0.3,
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
                          initials,
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
}

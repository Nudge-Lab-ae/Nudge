import 'package:flutter/material.dart';
import 'package:nudge/models/analytics.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/screens/contacts/contacts_list_screen.dart';
import 'package:nudge/screens/groups/groups_list_screen.dart';
import 'package:nudge/screens/notifications/notifications_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:nudge/widgets/screen_tracker.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../services/auth_service.dart';
import '../../services/nudge_service.dart';
import '../../models/contact.dart';
import '../../widgets/vip_badge.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await nudgeService.initialize();
  }

  String getCurrentSection() {
    return ScreenTracker.getDashboardSection(_currentIndex);
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
        initialData: [],
        create: (context) => apiService.getGroupsStream(),
        child: Scaffold(
          appBar: _buildAppBar(context),
          drawer: _buildNavigationDrawer(context, authService),
          body: Stack( // Wrap body in Stack
          children: [
            Consumer2<List<Contact>, List<SocialGroup>>(
            builder: (context, contacts, groups, child) {
              totalContacts = contacts;
              return _buildCurrentView(context, contacts, groups, apiService);
            },
          ),
           Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.4, // Center vertically
              child: FeedbackFloatingButton(
                currentSection: getCurrentSection(),
              ),
            ),
          ]),
          floatingActionButton: hideFloatingActionButton?Center():_buildFloatingActionButton(context),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    String title;
    List<Widget> actions = [];

    switch (_currentIndex) {
      case 0: // Dashboard
        title = 'Dashboard';
        actions = [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _currentIndex = 1;
                attentionFilter = false;
                vipFilter = false;
              }); // Switch to contacts view
            },
            tooltip: 'Search Contacts',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              setState(() => _currentIndex = 3); // Switch to nudges view
            },
            tooltip: 'Notifications',
          ),
        ];
        break;
      case 1: // Contacts
        title = 'Contacts';
        actions = [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              setState(() => _currentIndex = 3); // Switch to contacts view
            },
          ),
        ];
        break;
      case 2: // Groups
        title = 'Social Groups';
        break;
        case 3: // Groups
        title = 'Nudges';
        break;
      default:
        title = 'NUDGE';
    }
    print(title);

    return AppBar(
      title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
      gradient: LinearGradient(
        colors: [
          Color(0xFF5CDEE5), // #5CDEE5
          Color(0xFF2D85F6), // #2D85F6
          Color(0xFF7A4BFF), // #7A4BFF
        ], stops: [0.0, 0.6, 1.0], begin: Alignment.topCenter, end: Alignment.bottomCenter,
  ),
),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Color(0xff3CB3E9),),
      actions: actions,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    );
  }

  Widget _buildCurrentView(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardContent(context, contacts, groups, apiService);
      case 1:
        return ContactsListScreen(showAppBar: false, filter: vipFilter?'vip':attentionFilter?'needs_attention':'', hideButton: hideButton);
      case 2:
        return GroupsListScreen(showAppBar: false,);
      case 3:
        return NotificationsScreen(showAppBar: false,);
      default:
        return _buildDashboardContent(context, contacts, groups, apiService);
    }
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    switch (_currentIndex) {
      case 0: // Dashboard - Add Contact
        return Container();
      case 1: // Contacts - Add Contact
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/add_contact');
          },
          backgroundColor: const Color(0xff3CB3E9),
          child: const Icon(Icons.add, color: Colors.white),
        );
        case 2: // Groups - Create Group
          return Center();
      default:
        return Container();
    }
  }

  hideButton() {
    setState(() {
      hideFloatingActionButton = true;
    });
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
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
          icon: Icon(Icons.dashboard, color: _currentIndex == 0 ? Color(0xff3CB3E9) : Colors.grey),
          label: 'Dashboard',
          backgroundColor: Color(0xff3CB3E9),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contacts, color: _currentIndex == 1 ? Color(0xff3CB3E9) : Colors.grey),
          label: 'Contacts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group, color: _currentIndex == 2 ? Color(0xff3CB3E9) : Colors.grey),
          label: 'Groups',
        ),
         BottomNavigationBarItem(
          icon: Icon(Icons.notifications, color: _currentIndex == 3 ? Color(0xff3CB3E9) : Colors.grey),
          label: 'Nudges',
        ),
      ],
      selectedItemColor: Color(0xff3CB3E9),
      selectedLabelStyle: TextStyle(color: Color(0xff3CB3E9), fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, AuthService authService) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color(0xff3CB3E9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                   
                    SizedBox(width: 20),
                    Text(
                      'NUDGE',
                      style: TextStyle(color: Colors.white, fontSize: 23, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)
                    ),
                  ]),
                SizedBox(height: 10),
                Text(
                  'Nurture your relationships',
                  style: AppTextStyles.primarySemiBold.copyWith(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('All Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
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
            leading: const Icon(Icons.group),
            title: const Text('Groups', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Nudges & Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
               setState(() => _currentIndex = 3);
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.analytics),
          //   title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.pushNamed(context, '/analytics');
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.import_contacts),
            title: const Text('Import Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/import_contacts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
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
      title: const Text('Logging Out', style: TextStyle(fontWeight: FontWeight.w800),),
      content: const Text(
        'Are you sure you want to log out of your account?',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await authService.signOut();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}


  Widget _buildDashboardContent(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    // Filter contacts that need attention (not contacted in a while)
    final needsAttention = contacts.where((contact) => 
      contact.lastContacted.isBefore(
        DateTime.now().subtract(const Duration(days: 30))
      )
    ).toList();

    // var size = MediaQuery.of(context).size;
    
    // Filter VIP contacts
    final vipContacts = contacts.where((contact) => contact.isVIP).toList();

    return StreamBuilder<List<Nudge>>(
      stream: NudgeService().getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
      builder: (context, nudgeSnapshot) {
        final nudges = nudgeSnapshot.data ?? [];
        final analytics = _calculateAnalytics(contacts, nudges);
        final nudgePerformance = _calculateNudgePerformance(nudges);

        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 20),
              
              // Relationship Summary Card (replaces the row of cards)
              _buildSummarySection(analytics, contacts.length),
              const SizedBox(height: 20),
              
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // Updated Quick Actions with better styling
              _buildQuickActions(context, contacts, groups),
              const SizedBox(height: 20),
              
              // Nudge Performance Card (moved up)
              _buildNudgePerformanceSection(nudgePerformance),
              const SizedBox(height: 20),
              
              // VIP Contacts Section
              if (vipContacts.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'Close Circle',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vipContacts.length,
                    itemBuilder: (context, index) {
                      final contact = vipContacts[index];
                      return _buildContactCard(contact, apiService);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Needs Attention Section
              if (needsAttention.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'Needs Care',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _currentIndex = 1);
                      },
                      child: const Text('View All', style: TextStyle(color: Color(0xff3CB3E9)),),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                Column(
                  children: needsAttention.take(3).map((contact) => 
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: contact.imageUrl.isNotEmpty
                            ? NetworkImage(contact.imageUrl)
                            : null,
                        backgroundColor: Color(0xff3CB3E9),
                        child: contact.imageUrl.isEmpty 
                            ? const Icon(Icons.person, color: Colors.white,) 
                            : null,
                      ),
                      title: Text(contact.name, style: TextStyle(fontWeight: FontWeight.w600),),
                      subtitle: Text(
                        'Last contacted: ${DateFormat('MMM d, y').format(contact.lastContacted)}',
                      ),
                      trailing: const VIPBadge(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContactDetailScreen(contact: contact)
                          ),
                        );
                      },
                    )
                  ).toList(),
                ),
                
                const SizedBox(height: 20),
              ],

              // Analytics Section
              _buildAnalyticsSection(contacts),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Analytics Section
  Widget _buildAnalyticsSection(List<Contact> contacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: EdgeInsets.only(left: 0),
        //   child: Text('Analytics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        // ),
        // const SizedBox(height: 16),
        
        // Contact Distribution Pie Chart
        _buildContactDistributionSection(contacts),
        const SizedBox(height: 24),
        
        // Additional insights
        _buildAdditionalInsightsSection(contacts),
      ],
    );
  }

  Widget _buildContactDistributionSection(List<Contact> contacts) {
    final distributionData = _calculateContactDistribution(contacts);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your social landscape',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            if (distributionData.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No contacts yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 300,
                child: SfCircularChart(
                  legend: Legend(
                    isVisible: true,
                    overflowMode: LegendItemOverflowMode.wrap,
                    position: LegendPosition.bottom,
                  ),
                  series: <CircularSeries>[
                    DoughnutSeries<Map<String, dynamic>, String>(
                      dataSource: distributionData,
                      xValueMapper: (Map<String, dynamic> data, _) => data['category'],
                      yValueMapper: (Map<String, dynamic> data, _) => data['count'],
                      dataLabelMapper: (Map<String, dynamic> data, _) {
                        final total = distributionData.fold(0, (sum, item) => sum + (item['count'] as int));
                        final percentage = ((data['count'] as int) / total * 100).round();
                        return percentage > 0 ? '$percentage%' : '';
                      },
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        labelPosition: ChartDataLabelPosition.inside,
                      ),
                      pointColorMapper: (Map<String, dynamic> data, _) => _getCategoryColor(data['category'], distributionData.indexOf(data)),
                      innerRadius: '60%',
                    )
                  ],
                  tooltipBehavior: TooltipBehavior(enable: true),
                ),
              ),
            
            const SizedBox(height: 16),
            if (distributionData.isNotEmpty)
              _buildDistributionLegend(distributionData),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionLegend(List<Map<String, dynamic>> distributionData) {
    // final total = distributionData.fold(0, (sum, item) => sum + (item['count'] as int));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribution Summary',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Column(
          children: distributionData.map((data) {
            // final percentage = ((data['count'] as int) / total * 100).round();
            final index = distributionData.indexOf(data);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(data['category'], index),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['category'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${data['count']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdditionalInsightsSection(List<Contact> contacts) {
    final totalContacts = contacts.length;
    final vipContacts = contacts.where((c) => c.isVIP).length;
    final needsAttention = contacts.where((c) => 
      c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
    ).length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInsightItem('Total Contacts', totalContacts.toString(), Icons.people),
                _buildInsightItem('Close Circle', vipContacts.toString(), Icons.star),
                _buildInsightItem('Needs Care', needsAttention.toString(), Icons.warning),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'More detailed analytics coming soon as your network grows!',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xff3CB3E9)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _calculateContactDistribution(List<Contact> contacts) {
    final categoryCounts = <String, int>{};
    
    for (var contact in contacts) {
      final category = contact.connectionType.isEmpty ? 'Uncategorized' : contact.connectionType;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }
    
    // Convert to list and sort by count (descending)
    final distributionList = categoryCounts.entries.map((entry) {
      return {
        'category': entry.key,
        'count': entry.value,
      };
    }).toList();
    
    distributionList.sort((a, b) {
      int bcount = b['count'] as int;
      int acount = a['count'] as int;
      return (bcount.compareTo(acount));
    });
    
    return distributionList;
  }

  Color _getCategoryColor(String category, int index) {
  // Extended color palette with 20 distinct colors
  final List<Color> distinctColors = [
    const Color(0xff3CB3E9), // Primary teal
    const Color(0xFF4CAF50), // Green
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFFF9800), // Orange
    const Color(0xFFF44336), // Red
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFFC107), // Amber
    const Color(0xFF795548), // Brown
    const Color(0xFF607D8B), // Blue Grey
    const Color(0xFFE91E63), // Pink
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF8BC34A), // Light Green
    const Color(0xFF673AB7), // Deep Purple
    const Color(0xFFFF5722), // Deep Orange
    const Color(0xFF009688), // Teal
    const Color(0xFF3F51B5), // Indigo
    const Color(0xFFCDDC39), // Lime
    const Color(0xFFFFEB3B), // Yellow
    const Color(0xFF9E9E9E), // Grey
    const Color(0xFF00E676), // Green Accent
  ];

  // Use a combination of category hash and index for consistent but varied coloring
  final int colorIndex = (index) % distinctColors.length;
  return distinctColors[colorIndex];
}

  // Updated Quick Actions with better styling
  Widget _buildQuickActions(BuildContext context, List<Contact> contacts, List<SocialGroup> groups) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionButton(
          icon: Icons.person_add,
          label: 'Add Contact',
          onPressed: () {
            Navigator.pushNamed(context, '/add_contact');
          },
        ),
        _buildActionButton(
          icon: Icons.import_contacts,
          label: 'Import Contacts',
          onPressed: () {
            Navigator.pushNamed(context, '/import_contacts');
          },
        ),
        _buildActionButton(
          icon: Icons.group_add,
          label: 'Create Group',
          onPressed: () {
            setState(() {
              _currentIndex = 2;
              attentionFilter = false;
              vipFilter = false;
            });
          },
        ),
        _buildActionButton(
          icon: Icons.notifications_active,
          label: 'Schedule Nudges',
          onPressed: () async {
            final nudgeService = NudgeService();
            final authService = Provider.of<AuthService>(context, listen: false);
            nudgeService.showNudgeScheduleDialog(context, contacts, groups, authService.currentUser!.uid);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Container(
      width: 150,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xff3CB3E9),
          elevation: 2,
          shadowColor: Colors.grey.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xff3CB3E9), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Updated Summary Section with tappable icons
  Widget _buildSummarySection(Analytics analytics, int totalContacts) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relationship Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTappableStatCard(
                  'Total Contacts', 
                  totalContacts.toString(), 
                  Icons.people,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _buildTappableStatCard(
                  'Close Circle', 
                  analytics.vipContacts.toString(), 
                  Icons.star,
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                      vipFilter = true;
                      attentionFilter = false;
                    });
                  },
                ),
                _buildTappableStatCard(
                  'Needs Care', 
                  analytics.contactsNeedingAttention.toString(), 
                  Icons.notifications_active,
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                      attentionFilter = true;
                      vipFilter = false;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTappableStatCard(String title, String value, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff3CB3E9).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: const Color(0xff3CB3E9)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgePerformanceSection(Map<String, int> nudgePerformance) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nudge Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNudgeStat('Scheduled', nudgePerformance['scheduled'] ?? 0, Icons.schedule),
                _buildNudgeStat('Completed', nudgePerformance['completed'] ?? 0, Icons.check_circle),
                _buildNudgeStat('Missed', nudgePerformance['missed'] ?? 0, Icons.not_interested),
              ],
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              animation: true,
              lineHeight: 20.0,
              animationDuration: 1000,
              percent: (nudgePerformance['completionRate'] ?? 0) / 100,
              center: Text("${(nudgePerformance['completionRate'] ?? 0).toStringAsFixed(1)}%", 
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              barRadius: const Radius.circular(10),
              progressColor: _getProgressColor(nudgePerformance['completionRate']?.toDouble() ?? 0),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            const Text(
              'Nudge Completion Rate',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgeStat(String title, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xff3CB3E9)),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return const Color(0xff3CB3E9);
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  Analytics _calculateAnalytics(List<Contact> contacts, List<Nudge> nudges) {
    final vipCount = contacts.where((c) => c.isVIP).length;
    
    // Calculate contacts needing attention (not contacted in the last 30 days)
    final needsAttention = contacts.where((c) => 
      c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
    ).length;
    
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

  Map<String, int> _calculateNudgePerformance(List<Nudge> nudges) {
    final scheduled = nudges.length;
    final completed = nudges.where((nudge) => nudge.isCompleted).length;
    final missed = nudges.where((nudge) => !nudge.isCompleted && nudge.scheduledTime.isBefore(DateTime.now())).length;
    final completionRate = scheduled == 0 ? 0 : (completed / scheduled * 100).round();
    
    return {
      'scheduled': scheduled,
      'completed': completed,
      'missed': missed,
      'completionRate': completionRate,
    };
  }

  Widget _buildContactCard(Contact contact, ApiService apiService) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetailScreen(contact: contact)
          ),
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
                CircleAvatar(
                  backgroundImage: contact.imageUrl.isNotEmpty
                      ? NetworkImage(contact.imageUrl)
                      : null,
                  backgroundColor: Color(0xff3CB3E9),
                  radius: 20,
                  child: contact.imageUrl.isEmpty 
                      ? const Icon(Icons.person, size: 20) 
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  contact.name.split(' ').first,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (contact.isVIP)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Icon(Icons.star, size: 12, color: Colors.amber),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
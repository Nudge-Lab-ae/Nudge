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
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
          body: Consumer2<List<Contact>, List<SocialGroup>>(
            builder: (context, contacts, groups, child) {
              totalContacts = contacts;
              return _buildCurrentView(context, contacts, groups, apiService);
            },
          ),
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
        // actions = [
        //   IconButton(
        //     icon: const Icon(Icons.add),
        //     onPressed: () => _showCreateGroupDialog(context),
        //   ),
        // ];
        break;
        case 3: // Groups
        title = 'Nudges';
        // actions = [
        //   IconButton(
        //     icon: const Icon(Icons.add),
        //     onPressed: () => _showCreateGroupDialog(context),
        //   ),
        // ];
        break;
      default:
        title = 'NUDGE';
    }
    print(title);

    return AppBar(
      title: Text('NUDGE', style: TextStyle(color: Color.fromRGBO(45, 161, 175, 1), fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Color.fromRGBO(45, 161, 175, 1),),
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
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/add_contact');
          },
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          child: const Icon(Icons.add, color: Colors.white),
        );
      case 1: // Contacts - Add Contact
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/add_contact');
          },
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          child: const Icon(Icons.add, color: Colors.white),
        );
        case 2: // Groups - Create Group
          return Center();
      default:
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/add_contact');
          },
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          child: const Icon(Icons.add, color: Colors.white),
        );
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
          icon: Icon(Icons.dashboard, color: _currentIndex == 0 ? Color.fromRGBO(45, 161, 175, 1) : Colors.grey),
          label: 'Dashboard',
          backgroundColor: Color.fromRGBO(45, 161, 175, 1),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contacts, color: _currentIndex == 1 ? Color.fromRGBO(45, 161, 175, 1) : Colors.grey),
          label: 'Contacts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group, color: _currentIndex == 2 ? Color.fromRGBO(45, 161, 175, 1) : Colors.grey),
          label: 'Groups',
        ),
         BottomNavigationBarItem(
          icon: Icon(Icons.notifications, color: _currentIndex == 3 ? Color.fromRGBO(45, 161, 175, 1) : Colors.grey),
          label: 'Nudges',
        ),
      ],
      selectedItemColor: Color.fromRGBO(45, 161, 175, 1),
      selectedLabelStyle: TextStyle(color: Color.fromRGBO(45, 161, 175, 1), fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    );
  }

  // Rest of your existing methods remain the same...
  Widget _buildNavigationDrawer(BuildContext context, AuthService authService) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(45, 161, 175, 1),
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
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/analytics');
            },
          ),
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


  // Update the _buildDashboardContent method in dashboard_screen.dart
  Widget _buildDashboardContent(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, ApiService apiService) {
    // Filter contacts that need attention (not contacted in a while)
    final needsAttention = contacts.where((contact) => 
      contact.lastContacted.isBefore(
        DateTime.now().subtract(const Duration(days: 30))
      )
    ).toList();

    var size = MediaQuery.of(context).size;
    
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
              
              Row(
                children: [
                  _buildSummaryCard(
                    'Total Contacts',
                    contacts.length.toString(),
                    Icons.contacts,
                    true,
                    size.width*0.25,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  const SizedBox(width: 10),
                  _buildSummaryCard(
                    'Close Circle',
                    vipContacts.length.toString(),
                    Icons.star,
                    true,
                    size.width*0.22,
                    onTap: () {
                      setState(() {
                        _currentIndex = 1;
                        vipFilter = true;
                        attentionFilter = false;
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildSummaryCard(
                    'Needs Care',
                    needsAttention.length.toString(),
                    Icons.notifications_active,
                    false,
                    size.width*0.22,
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
              
              const SizedBox(height: 20),
              
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.person_add, size: 18, color: Color.fromRGBO(45, 161, 175, 1)),
                    label: Text('Add Contact', style: AppTextStyles.primary.copyWith(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_contact');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.import_contacts, size: 18, color: Color.fromRGBO(45, 161, 175, 1)),
                    label: Text('Import Contacts', style: AppTextStyles.primary.copyWith(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.pushNamed(context, '/import_contacts');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.group_add, size: 18, color: Color.fromRGBO(45, 161, 175, 1)),
                    label: Text('Create Group', style: AppTextStyles.primary.copyWith(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 2;
                        attentionFilter = false;
                        vipFilter = false;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.notifications_active, size: 18, color: Color.fromRGBO(45, 161, 175, 1)),
                    label: Text('Schedule Nudges', style: AppTextStyles.primary.copyWith(fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final nudgeService = NudgeService();
                      final authService = Provider.of<AuthService>(context, listen: false);
                      nudgeService.showNudgeScheduleDialog(context, contacts, groups, authService.currentUser!.uid);
                    },
                  ),
                ],
              ),
              
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
                      child: const Text('View All', style: TextStyle(color: Color.fromRGBO(45, 161, 175, 1))),
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
                      child: const Text('View All'),
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
                        child: contact.imageUrl.isEmpty 
                            ? const Icon(Icons.person) 
                            : null,
                      ),
                      title: Text(contact.name),
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
                
                if (needsAttention.length > 3)
                  TextButton(
                    onPressed: () {
                      setState(() => _currentIndex = 1);
                    },
                    child: const Text('View All Contacts Needing Attention'),
                  ),
                
                const SizedBox(height: 20),
                  // Relationship Summary Section (moved from Analytics)
              _buildSummarySection(analytics, contacts.length),
              const SizedBox(height: 20),
              
              // Nudge Performance Section (moved from Analytics)
              _buildNudgePerformanceSection(nudgePerformance),
              const SizedBox(height: 20),
              
              ],
            ],
          ),
        );
      },
    );
  }

  // Add these methods to the _DashboardScreenState class
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
                _buildStatCard('Total Contacts', totalContacts.toString(), Icons.people),
                _buildStatCard('Close Circle', analytics.vipContacts.toString(), Icons.star),
                _buildStatCard('Needs Care', analytics.contactsNeedingAttention.toString(), Icons.notifications_active),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color.fromRGBO(45, 161, 175, 1)),
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
        Icon(icon, size: 30, color: const Color.fromRGBO(45, 161, 175, 1)),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return const Color.fromRGBO(45, 161, 175, 1);
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

  Widget _buildSummaryCard(String title, String value, IconData icon, bool primary, double width, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color.fromRGBO(45, 161, 175, 1)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Container(
                width: width,
                child: Text(
                title,
                style: TextStyle(fontSize: primary?12:10, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              )
            ],
          ),
        ),
      ),
    );
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
                  backgroundColor: Color.fromRGBO(45, 161, 175, 1),
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

  // List<Widget> _buildContactStats(List<Contact> contacts) {
  //   final typeCounts = <String, int>{};
  //   for (var contact in contacts) {
  //     typeCounts[contact.connectionType] = (typeCounts[contact.connectionType] ?? 0) + 1;
  //   }
    
  //   return typeCounts.entries.map((entry) {
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(vertical: 4.0),
  //       child: Row(
  //         children: [
  //           Text(entry.key, style: TextStyle(fontWeight: FontWeight.w700)),
  //           const Spacer(),
  //           Text('${entry.value}'),
  //           const SizedBox(width: 4),
  //           Text('(${((entry.value / contacts.length) * 100).toStringAsFixed(1)}%)'),
  //         ],
  //       ),
  //     );
  //   }).toList();
  // }
}
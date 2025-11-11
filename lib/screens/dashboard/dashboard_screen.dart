import 'package:flutter/material.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/screens/contacts/contacts_list_screen.dart';
import 'package:nudge/screens/groups/groups_list_screen.dart';
import 'package:nudge/screens/notifications/notifications_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
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
        title = 'Nudges & Reminders';
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

    return AppBar(
      title: Text(title, style: TextStyle(color: Color.fromRGBO(45, 161, 175, 1), fontSize: 22, fontFamily: 'Quicksand', fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Color.fromRGBO(45, 161, 175, 1),),
      actions: actions,
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
              Navigator.pop(context);
              await authService.signOut();
            },
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

    var size = MediaQuery.of(context).size;
    
    // Filter VIP contacts
    final vipContacts = contacts.where((contact) => contact.isVIP).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card(
          //   color: Colors.blue[50],
          //   child: Padding(
          //     padding: const EdgeInsets.all(12.0),
          //     child: Row(
          //       children: [
          //         const Icon(Icons.cloud_upload, color: Color.fromRGBO(45, 161, 175, 1)),
          //         const SizedBox(width: 10),
          //         Expanded(
          //           child: Column(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             children: [
          //               const Text(
          //                 'Contact Import Status',
          //                 style: TextStyle(
          //                   fontWeight: FontWeight.bold,
          //                   fontSize: 16,
          //                 ),
          //               ),
          //               const SizedBox(height: 4),
          //               Text(
          //                 '${contacts.length} contacts imported',
          //                 style: const TextStyle(fontSize: 14),
          //               ),
          //             ],
          //           ),
          //         ),
          //         IconButton(
          //           icon: const Icon(Icons.import_contacts),
          //           onPressed: () {
          //             Navigator.pushNamed(context, '/import_contacts');
          //           },
          //           tooltip: 'Import More Contacts',
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          
          const SizedBox(height: 50),
          
          // Summary Cards
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
                  // Could implement VIP filter in contacts view
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
                  // Could implement needs attention filter in contacts view
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
          ],
          
          // Analytics Preview
          if (contacts.isNotEmpty) ...[
            const Text(
              'Relationship Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            // Simple analytics preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Distribution',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    // Simple chart or stats preview
                    ..._buildContactStats(contacts),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/analytics');
              },
              child: const Text('View Detailed Analytics', style: TextStyle(color: Color.fromRGBO(45, 161, 175, 1))),
            ),
          ],
        ],
      ),
    );
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

  List<Widget> _buildContactStats(List<Contact> contacts) {
    final typeCounts = <String, int>{};
    for (var contact in contacts) {
      typeCounts[contact.connectionType] = (typeCounts[contact.connectionType] ?? 0) + 1;
    }
    
    return typeCounts.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Text(entry.key, style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${entry.value}'),
            const SizedBox(width: 4),
            Text('(${((entry.value / contacts.length) * 100).toStringAsFixed(1)}%)'),
          ],
        ),
      );
    }).toList();
  }
}
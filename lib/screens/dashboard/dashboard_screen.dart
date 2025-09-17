import 'package:flutter/material.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
// import 'package:nudge/screens/notifications/notifications_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/nudge_service.dart';
import '../../models/contact.dart';
// import '../../widgets/nudge_card.dart';
import '../../widgets/vip_badge.dart';
// import '../../widgets/analytics_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NudgeService nudgeService = NudgeService();
  int _currentIndex = 0;
  List<Contact> totalContacts = [];

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
    
    // final databaseService = DatabaseService(uid: user.uid);
    
    return StreamProvider<List<Contact>>(
      create: (context) => apiService.getContactsStream(),
      initialData: const [],
      child: StreamProvider<List<SocialGroup>>(
        initialData: [],
        create: (context) => apiService.getGroupsStream(),
        child: Scaffold(
        appBar: AppBar(
          title:  Text('NUDGE Dashboard', style: AppTextStyles.title3.copyWith(color: Colors.white)),
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.pushNamed(context, '/contacts');
              },
              tooltip: 'Search Contacts',
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () async {
                Navigator.pushNamed(context, '/notifications');
              },
              tooltip: 'Notifications',
            ),
          ],
        ),
        drawer: _buildNavigationDrawer(context, authService),
        // drawerScrimColor: Colors.white,
        body: Consumer2<List<Contact>, List<SocialGroup>>(
          builder: (context, contacts, groups, child) {
            totalContacts = contacts;
            return _buildDashboardContent(context, contacts, groups, apiService);
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/add_contact');
          },
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            // Navigate to different sections based on index
            switch (index) {
              case 0:
                // Already on dashboard
                break;
              case 1:
                Navigator.pushNamed(context, '/contacts').then((_) {
                  // Reset index to Dashboard when returning
                  setState(() => _currentIndex = 0);
                });
                break;
              case 2:
                Navigator.pushNamed(context, '/groups').then((_) {
                  // Reset index to Dashboard when returning
                  setState(() => _currentIndex = 0);
                });
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: 'Groups',
            ),
          ],
        ),
    ),
    ));
  }

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
                    Icon(Icons.favorite, size: 40, color: Colors.white),
                    SizedBox(width: 20,),
                     Text(
                  'NUDGE',
                  style: AppTextStyles.primaryBold.copyWith(color: Colors.white, fontSize: 23)
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
            title: Text('Dashboard', style: AppTextStyles.primary),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('All Contacts'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/contacts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Groups'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/groups');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Nudges & Reminders'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/analytics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.import_contacts),
            title: const Text('Import Contacts'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/import_contacts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Logout'),
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
    
    // Filter VIP contacts
    final vipContacts = contacts.where((contact) => contact.isVIP).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

           Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Import Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${contacts.length} contacts imported',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.import_contacts),
                  onPressed: () {
                    Navigator.pushNamed(context, '/import_contacts');
                  },
                  tooltip: 'Import More Contacts',
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
          // Summary Cards
          Row(
            children: [
             Row(
              children: [
                // Expanded(
                //   child: _buildSummaryCard(
                //     'Total Contacts',
                //     contacts.length.toString(),
                //     Icons.contacts,
                //     true,
                //     onTap: () => Navigator.pushNamed(context, '/contacts'),
                //   ),
                // ),
                _buildSummaryCard(
                    'Total Contacts',
                    contacts.length.toString(),
                    Icons.contacts,
                    true,
                    onTap: () => Navigator.pushNamed(context, '/contacts'),
                  ),
                const SizedBox(width: 10),
                // Expanded(
                //   child: _buildSummaryCard(
                //     'VIP Contacts',
                //     vipContacts.length.toString(),
                //     Icons.star,
                //     true,
                //     onTap: () {
                //       Navigator.pushNamed(
                //         context, 
                //         '/contacts',
                //         arguments: {'filter': 'vip'},
                //       );
                //     },
                //   ),
                // ),
                _buildSummaryCard(
                    'VIP Contacts',
                    vipContacts.length.toString(),
                    Icons.star,
                    true,
                    onTap: () {
                      Navigator.pushNamed(
                        context, 
                        '/contacts',
                        arguments: {'filter': 'vip'},
                      );
                    },
                  ),
                const SizedBox(width: 10),
                // Expanded(
                //   child: _buildSummaryCard(
                //     'Needs Attention',
                //     needsAttention.length.toString(),
                //     Icons.notifications_active,
                //     false,
                //     onTap: () {
                //       Navigator.pushNamed(
                //         context, 
                //         '/contacts',
                //         arguments: {'filter': 'needs_attention'},
                //       );
                //     },
                //   ),
                // ),
                _buildSummaryCard(
                    'Needs Attention',
                    needsAttention.length.toString(),
                    Icons.notifications_active,
                    false,
                    onTap: () {
                      Navigator.pushNamed(
                        context, 
                        '/contacts',
                        arguments: {'filter': 'needs_attention'},
                      );
                    },
                  ),
              ],
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
                avatar: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Contact', style: AppTextStyles.primary,),
                onPressed: () {
                  Navigator.pushNamed(context, '/add_contact');
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.import_contacts, size: 18),
                label: const Text('Import Contacts', style: AppTextStyles.primary,),
                onPressed: () {
                  Navigator.pushNamed(context, '/import_contacts');
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.group_add, size: 18),
                label: const Text('Create Group', style: AppTextStyles.primary,),
                onPressed: () {
                  // Navigate to create group screen
                  Navigator.pushNamed(
                    context, 
                    '/groups',
                    arguments: {'action': 'create'},
                  );
                },
              ),
             ActionChip(
                avatar: const Icon(Icons.notifications_active, size: 18),
                label: const Text('Schedule Nudges', style: AppTextStyles.primary,),
                onPressed: () async {
                  final nudgeService = NudgeService();
                  final authService = Provider.of<AuthService>(context, listen: false);
                  // final apiService = Provider.of<ApiService>(context, listen: false);
                  
                  nudgeService.showNudgeScheduleDialog(context, contacts, groups,authService.currentUser!.uid);
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
                  'VIP Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context, 
                      '/contacts',
                      arguments: {'filter': 'vip'},
                    );
                  },
                  child: const Text('View All'),
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
                  'Needs Attention',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context, 
                      '/contacts',
                      arguments: {'filter': 'needs_attention'},
                    );
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
                    // Navigator.pushNamed(
                    //   context, 
                    //   '/contact_detail',
                    //   arguments: contact.id,
                    // );
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
                  Navigator.pushNamed(
                    context, 
                    '/contacts',
                    arguments: {'filter': 'needs_attention'},
                  );
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
              child: const Text('View Detailed Analytics'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, bool primary, {VoidCallback? onTap}) {
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
              Text(
                title,
                style: TextStyle(fontSize: primary?12:10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

    // Update the _buildContactCard method
  Widget _buildContactCard(Contact contact, ApiService apiService) {
    // final authService = Provider.of<AuthService>(context, listen: false);
    // final nudgeService = NudgeService();
    
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
    // Count contacts by type
    final typeCounts = <String, int>{};
    for (var contact in contacts) {
      typeCounts[contact.connectionType] = (typeCounts[contact.connectionType] ?? 0) + 1;
    }
    
    return typeCounts.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Text(entry.key),
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
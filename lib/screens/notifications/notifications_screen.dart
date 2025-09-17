// lib/screens/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/models/nudge.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  String _filter = 'all'; // 'all', 'upcoming', 'completed'
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications')),
      );
    }
    
    final nudgeService = NudgeService();
    
    return StreamBuilder<List<Nudge>>(
      stream: nudgeService.getNudgesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        
        final nudges = snapshot.data ?? [];
        final now = DateTime.now();
        
        // Filter nudges for the "Upcoming" tab (next 7 days)
        final upcomingNudges = nudges.where((nudge) => 
          nudge.scheduledTime.isAfter(now) && 
          nudge.scheduledTime.isBefore(now.add(const Duration(days: 7))) &&
          !nudge.isCompleted
        ).toList();
        
        // Filter nudges for the "All" tab (based on current filter)
        List<Nudge> filteredNudges;
        switch (_filter) {
          case 'upcoming':
            filteredNudges = nudges.where((nudge) => 
              nudge.scheduledTime.isAfter(now) && !nudge.isCompleted
            ).toList();
            break;
          case 'completed':
            filteredNudges = nudges.where((nudge) => nudge.isCompleted).toList();
            break;
          default:
            filteredNudges = List.from(nudges);
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Nudges & Reminders', style: AppTextStyles.title3.copyWith(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
            // fromRGBO(45, 161, 175, 1)
            // (37, 150, 190, 1)
            bottom: TabBar(
              controller: _tabController,
              unselectedLabelColor: Colors.grey,
              labelColor: Colors.white,
              tabs: [
                Tab(
                  // text: 'Upcoming (7 days)',
                  child: Text('Upcoming (7 days)', style: AppTextStyles.primaryBold.copyWith(
                    color: _tabController.index == 0?Colors.white: Colors.black
                  ),),
                ),
                Tab(
                   child: Text('All Nudges', style: AppTextStyles.primaryBold.copyWith(
                    color: _tabController.index == 1?Colors.white: Colors.black
                  ),),
                ),
              ],
            ),
            actions: [
              if (_currentTabIndex == 1) // Only show filter on "All Nudges" tab
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    _showFilterDialog(context);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.add_alarm),
                onPressed: () {
                  _showScheduleOptions(context);
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Upcoming Tab (next 7 days)
              _buildTabContent(upcomingNudges, user.uid, true),
              
              // All Nudges Tab
              _buildTabContent(filteredNudges, user.uid, false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent(List<Nudge> nudges, String userId, bool isUpcomingTab) {
    return Column(
      children: [
        if (!isUpcomingTab) _buildStatsRow(nudges),
        Expanded(
          child: nudges.isEmpty
              ? _buildEmptyState(isUpcomingTab)
              : _buildNudgeList(nudges, context, userId, isUpcomingTab),
        ),
      ],
    );
  }

  Widget _buildStatsRow(List<Nudge> nudges) {
    final now = DateTime.now();
    final upcoming = nudges.where((nudge) => nudge.scheduledTime.isAfter(now) && !nudge.isCompleted).length;
    final completed = nudges.where((nudge) => nudge.isCompleted).length;
    final overdue = nudges.where((nudge) => nudge.scheduledTime.isBefore(now) && !nudge.isCompleted).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Upcoming', upcoming.toString(), Colors.blue),
          _buildStatItem('Completed', completed.toString(), Colors.green),
          _buildStatItem('Overdue', overdue.toString(), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNudgeList(List<Nudge> nudges, BuildContext context, String userId, bool isUpcomingTab) {
    // For upcoming tab, sort by scheduled time (soonest first)
    // For all tab, sort by scheduled time but keep completed at the bottom
    if (isUpcomingTab) {
      nudges.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    } else {
      nudges.sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
    }
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: nudges.length,
      itemBuilder: (context, index) {
        return _buildNudgeCard(nudges[index], context, userId);
      },
    );
  }

  Widget _buildNudgeCard(Nudge nudge, BuildContext context, String userId) {
    final nudgeService = NudgeService();
    final isOverdue = nudge.scheduledTime.isBefore(DateTime.now()) && !nudge.isCompleted;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOverdue ? Colors.orange[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue
              ? Colors.orange
              : nudge.isCompleted
                  ? Colors.green
                  : const Color.fromRGBO(45, 161, 175, 1),
          child: Icon(
            isOverdue
                ? Icons.warning
                : nudge.isCompleted
                    ? Icons.check
                    : Icons.notifications,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Connect with ${nudge.contactName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: nudge.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMM dd, yyyy • hh:mm a').format(nudge.scheduledTime)} • ${nudge.frequency}',
            ),
            if (isOverdue)
              const Text(
                'Overdue',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!nudge.isCompleted)
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () {
                  nudgeService.markNudgeAsComplete(nudge.id, userId, nudge.contactId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nudge marked as complete')),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.snooze, color: Colors.blue),
              onPressed: () {
                _snoozeNudge(nudge, userId);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _deleteNudge(nudge, userId);
              },
            ),
          ],
        ),
        onTap: () {
          _showNudgeDetails(nudge, context, userId);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUpcomingTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isUpcomingTab ? 'No upcoming nudges' : 'No nudges yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUpcomingTab 
              ? 'You have no nudges scheduled for the next 7 days'
              : 'Schedule your first nudge to stay connected',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _showScheduleOptions(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
            ),
            child:  Text('Schedule Nudges', style: AppTextStyles.button.copyWith(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Nudges'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(
                title: const Text('All Nudges'),
                value: 'all',
                groupValue: _filter,
                onChanged: (value) {
                  setState(() {
                    _filter = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile(
                title: const Text('Upcoming'),
                value: 'upcoming',
                groupValue: _filter,
                onChanged: (value) {
                  setState(() {
                    _filter = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile(
                title: const Text('Completed'),
                value: 'completed',
                groupValue: _filter,
                onChanged: (value) {
                  setState(() {
                    _filter = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showScheduleOptions(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamProvider<List<Contact>>.value(
          initialData: [],
          value: apiService.getContactsStream(),
          child: StreamProvider<List<SocialGroup>>.value(
            value: apiService.getGroupsStream(),
            initialData: [],
            child: Consumer2<List<Contact>, List<SocialGroup>>(
              builder: (context, contacts, groups, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Schedule Nudges',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('For all contacts'),
                        onTap: () {
                          Navigator.of(context).pop();
                          final nudgeService = NudgeService();
                          nudgeService.showNudgeScheduleDialog(
                            context, contacts, groups, authService.currentUser!.uid
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.group),
                        title: const Text('By group'),
                        onTap: () {
                          Navigator.of(context).pop();
                          final nudgeService = NudgeService();
                          nudgeService.showNudgeScheduleDialog(
                            context, contacts, groups, authService.currentUser!.uid
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Manual selection'),
                        onTap: () {
                          Navigator.of(context).pop();
                          final nudgeService = NudgeService();
                          nudgeService.showNudgeScheduleDialog(
                            context, contacts, groups, authService.currentUser!.uid
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
            )
          )
        );
      },
    );
  }

  void _snoozeNudge(Nudge nudge, String userId) {
    final nudgeService = NudgeService();
    
    showDialog(
      context: context,
      builder: (context) {
        String snoozeDuration = '1 day';
        
        return AlertDialog(
          title: const Text('Snooze Nudge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How long would you like to snooze this nudge?'),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: snoozeDuration,
                onChanged: (String? newValue) {
                  snoozeDuration = newValue!;
                },
                items: <String>['1 hour', '1 day', '3 days', '1 week']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Calculate duration
                Duration duration;
                switch (snoozeDuration) {
                  case '1 hour':
                    duration = const Duration(hours: 1);
                    break;
                  case '3 days':
                    duration = const Duration(days: 3);
                    break;
                  case '1 week':
                    duration = const Duration(days: 7);
                    break;
                  default:
                    duration = const Duration(days: 1);
                }
                
                await nudgeService.snoozeNudge(
                  nudge.id, 
                  userId, 
                  duration,
                  nudge.contactName
                );
                
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nudge snoozed')),
                );
              },
              child: const Text('Snooze'),
            ),
          ],
        );
      },
    );
  }

  void _deleteNudge(Nudge nudge, String userId) {
    final nudgeService = NudgeService();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Nudge'),
          content: Text('Are you sure you want to delete the nudge for ${nudge.contactName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await nudgeService.cancelNudge(nudge.id, userId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nudge deleted')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showNudgeDetails(Nudge nudge, BuildContext context, String userId) {
    final nudgeService = NudgeService();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nudge: ${nudge.contactName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scheduled: ${DateFormat('MMM dd, yyyy • hh:mm a').format(nudge.scheduledTime)}'),
              Text('Frequency: ${nudge.frequency}'),
              const SizedBox(height: 10),
              Text('Status: ${nudge.isCompleted ? 'Completed' : 'Pending'}'),
              if (nudge.isCompleted && nudge.completedAt != null)
                Text('Completed: ${DateFormat('MMM dd, yyyy').format(nudge.completedAt!)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (!nudge.isCompleted)
              ElevatedButton(
                onPressed: () {
                  nudgeService.markNudgeAsComplete(nudge.id, userId, nudge.contactId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nudge marked as complete')),
                  );
                },
                child: const Text('Mark Complete'),
              ),
          ],
        );
      },
    );
  }
}
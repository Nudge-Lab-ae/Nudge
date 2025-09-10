// lib/screens/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
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

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _filter = 'all'; // 'all', 'upcoming', 'completed'

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications')),
      );
    }
    
    final apiService = Provider.of<ApiService>(context);
    
    return StreamProvider<List<Nudge>>.value(
      value: apiService.getNudgesStream(),
      initialData: const [],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Nudges & Reminders', style: AppTextStyles.title3.copyWith(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
          actions: [
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
        body: Consumer<List<Nudge>>(
          builder: (context, nudges, child) {
            // Filter nudges based on selected filter
            final now = DateTime.now();
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
            
            // Sort by scheduled time
            filteredNudges.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
            
            return Column(
              children: [
                _buildStatsRow(nudges),
                Expanded(
                  child: filteredNudges.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: filteredNudges.length,
                          itemBuilder: (context, index) {
                            return _buildNudgeCard(filteredNudges[index], context, apiService);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
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

  Widget _buildEmptyState() {
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
          const Text(
            'No nudges yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Schedule your first nudge to stay connected',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _showScheduleOptions(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
            ),
            child: const Text('Schedule Nudges'),
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeCard(Nudge nudge, BuildContext context, ApiService apiService) {
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
                  : const Color.fromRGBO(37, 150, 190, 1),
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
              DateFormat('MMM dd, yyyy • hh:mm a').format(nudge.scheduledTime),
              style: TextStyle(
                color: isOverdue ? Colors.orange : null,
              ),
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
                  _markAsComplete(nudge, apiService);
                },
              ),
            IconButton(
              icon: const Icon(Icons.snooze, color: Colors.blue),
              onPressed: () {
                _snoozeNudge(nudge, apiService);
              },
            ),
          ],
        ),
        onTap: () {
          _showNudgeDetails(nudge, context);
        },
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

  void _showScheduleOptions(BuildContext context) {
    final nudgeService = NudgeService();
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
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
                onTap: () async {
                  Navigator.of(context).pop();
                  final contacts = await _getAllContacts(apiService);
                  nudgeService.showNudgeScheduleDialog(context, contacts, authService.currentUser!.uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('For a specific group'),
                onTap: () {
                  Navigator.of(context).pop();
                  // Navigate to groups screen or show group selector
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('For individual contacts'),
                onTap: () {
                  Navigator.of(context).pop();
                  // Navigate to contacts screen with selection mode
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Contact>> _getAllContacts(ApiService apiService) async {
    try {
      // Assuming you have a method to get all contacts
      // This is a simplified version - you'll need to implement based on your data structure
      return []; // Replace with actual contact fetching
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  void _markAsComplete(Nudge nudge, ApiService apiService) {
    // Implement mark as complete functionality
  }

  void _snoozeNudge(Nudge nudge, ApiService apiService) {
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
              onPressed: () {
                // Implement snooze functionality
                Navigator.of(context).pop();
              },
              child: const Text('Snooze'),
            ),
          ],
        );
      },
    );
  }

  void _showNudgeDetails(Nudge nudge, BuildContext context) {
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
                  // Implement contact now functionality
                  Navigator.of(context).pop();
                },
                child: const Text('Contact Now'),
              ),
          ],
        );
      },
    );
  }
}
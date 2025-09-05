import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/nudge.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications')),
      );
    }
    
    final databaseService = DatabaseService(uid: user.uid);
    
    return StreamProvider<List<Nudge>>.value(
      value: databaseService.nudges,
      initialData: const [],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NUDGE'),
          backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        ),
        body: Consumer<List<Nudge>>(
          builder: (context, nudges, child) {
            // Separate nudges into today and upcoming
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            // final tomorrow = today.add(const Duration(days: 1));
            
            final todayNudges = nudges.where((nudge) {
              final nudgeDate = DateTime(nudge.scheduledTime.year, nudge.scheduledTime.month, nudge.scheduledTime.day);
              return nudgeDate.isAtSameMomentAs(today) && !nudge.isCompleted;
            }).toList();
            
            final upcomingNudges = nudges.where((nudge) {
              return nudge.scheduledTime.isAfter(now) && 
                     !nudge.isCompleted && 
                     !todayNudges.contains(nudge);
            }).toList();
            
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Today's updates",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (todayNudges.isEmpty)
                    const Text('No nudges for today')
                  else
                    ...todayNudges.map((nudge) => 
                      _buildNotificationItem(nudge, context)
                    ).toList(),
                  
                  const SizedBox(height: 30),
                  const Text(
                    'Coming up',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (upcomingNudges.isEmpty)
                    const Text('No upcoming nudges')
                  else
                    ...upcomingNudges.map((nudge) => 
                      _buildNotificationItem(nudge, context)
                    ).toList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Nudge nudge, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMM dd').format(nudge.scheduledTime),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nudge!',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Time to catch up with ${nudge.contactName}!'),
            ],
          ),
        ),
      ],
    );
  }
}
// lib/services/nudge_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nudge/services/api_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';
import '../models/contact.dart';
import '../models/nudge.dart';
import '../models/social_group.dart';
import '../services/notification_service.dart';
import 'package:provider/provider.dart';

class NudgeService {
  static final NudgeService _instance = NudgeService._internal();
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();

  factory NudgeService() {
    return _instance;
  }

  NudgeService._internal();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(initializationSettings);
    
    // Initialize notification service
    await _notificationService.initialize();
    
    // Request notification permissions
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+, we need to request notification permission
      // final status = await Permission.notification.request();
    }
  }

  Future<bool> scheduleNudgeForContact(Contact contact, String userId) async {
    try {
      // Calculate next nudge time based on frequency
      DateTime nextNudgeTime = _calculateNextNudgeTime(contact);
      
      // Create a nudge object
      final nudge = Nudge(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        contactId: contact.id,
        contactName: contact.name,
        nudgeType: 'followup',
        message: 'Time to connect with ${contact.name}',
        scheduledTime: nextNudgeTime,
        userId: userId,
      );
      
      // Save using ApiService
      final apiService = ApiService();
      await apiService.addNudge(nudge);
      
      // Schedule notification
      await _notificationService.scheduleNudgeNotification(
        contact.id.hashCode,
        'Time to connect!',
        'Remember to reach out to ${contact.name}',
        nextNudgeTime,
      );
      
      // Update contact's last nudge time
      print('Nudge scheduled for ${contact.name} at $nextNudgeTime');
      return true;
    } catch (e) {
      print('Error scheduling nudge for ${contact.name}: $e');
      return false;
    }
  }

  DateTime _calculateNextNudgeTime(Contact contact) {
    DateTime now = DateTime.now();
    
    switch (contact.frequency) {
      case 'Weekly':
        return now.add(const Duration(days: 7));
      case 'Monthly':
        return now.add(const Duration(days: 30));
      case 'Quarterly':
        return now.add(const Duration(days: 90));
      case 'Annually':
        return now.add(const Duration(days: 365));
      default:
        return now.add(const Duration(days: 30));
    }
  }

  Future<Map<String, dynamic>> scheduleAllNudges(List<Contact> contacts, String userId) async {
    int successCount = 0;
    int failCount = 0;
    List<String> failedContacts = [];
    
    for (var contact in contacts) {
      final success = await scheduleNudgeForContact(contact, userId);
      if (success) {
        successCount++;
      } else {
        failCount++;
        failedContacts.add(contact.name);
      }
      
      // Add a small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return {
      'successCount': successCount,
      'failCount': failCount,
      'failedContacts': failedContacts,
    };
  }

  Future<void> showNudgeScheduleDialog(BuildContext context, List<Contact> contacts, String userId) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final groups = await _getUserGroups(apiService);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Schedule Nudges'),
          content: SizedBox(
            width: double.maxFinite,
            child: NudgeScheduleDialogContent(
              contacts: contacts,
              groups: groups,
              onSchedule: () async {
                Navigator.of(context).pop();
                final result = await _showSchedulingProgress(context, contacts, userId);
                _showSchedulingResult(context, result);
              },
            ),
          ),
        );
      },
    );
  }

  Future<List<SocialGroup>> _getUserGroups(ApiService apiService) async {
    try {
      final user = await apiService.getUser();
      return user.groups!.map((groupData) => SocialGroup.fromMap(groupData)).toList();
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    }
  }

  Future<dynamic> _showSchedulingProgress(BuildContext context, List<Contact> contacts, String userId) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scheduling nudges...'),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                FutureBuilder<Map<String, dynamic>>(
                  future: scheduleAllNudges(contacts, userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context).pop(snapshot.data);
                      });
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSchedulingResult(BuildContext context, Map<String, dynamic> result) {
    final successCount = result['successCount'] as int;
    final failCount = result['failCount'] as int;
    final failedContacts = result['failedContacts'] as List<String>;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Scheduling Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Successfully scheduled: $successCount nudges'),
              Text('Failed: $failCount nudges'),
              if (failedContacts.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Failed contacts:'),
                ...failedContacts.map((name) => Text('• $name')).toList(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            if (failCount > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showNudgeScheduleDialog(context, [], '');
                },
                child: const Text('Retry Failed'),
              ),
          ],
        );
      },
    );
  }

  Future<void> cancelNudge(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNudges() async {
    await notificationsPlugin.cancelAll();
  }
}

class NudgeScheduleDialogContent extends StatefulWidget {
  final List<Contact> contacts;
  final List<SocialGroup> groups;
  final VoidCallback onSchedule;

  const NudgeScheduleDialogContent({
    super.key,
    required this.contacts,
    required this.groups,
    required this.onSchedule,
  });

  @override
  State<NudgeScheduleDialogContent> createState() => _NudgeScheduleDialogContentState();
}

class _NudgeScheduleDialogContentState extends State<NudgeScheduleDialogContent> {
  bool _useCurrentSettings = true;
  Map<String, String> _frequencyOverrides = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('How would you like to schedule your nudges?'),
        const SizedBox(height: 20),
        Row(
          children: [
            Radio(
              value: true,
              groupValue: _useCurrentSettings,
              onChanged: (value) {
                setState(() {
                  _useCurrentSettings = value!;
                });
              },
            ),
            const Text('Use current contact settings', style: TextStyle(overflow: TextOverflow.ellipsis, fontSize: 12),),
          ],
        ),
        Row(
          children: [
            Radio(
              value: false,
              groupValue: _useCurrentSettings,
              onChanged: (value) {
                setState(() {
                  _useCurrentSettings = value!;
                });
              },
            ),
            const Text('Customize frequencies'),
          ],
        ),
        if (!_useCurrentSettings) ...[
          const SizedBox(height: 20),
          const Text('Customize frequencies:'),
          const SizedBox(height: 10),
          ...widget.contacts.take(3).map((contact) => _buildFrequencySelector(contact)).toList(),
          if (widget.contacts.length > 3)
            TextButton(
              onPressed: () {
                // Show all contacts in a separate dialog
              },
              child: const Text('Show all contacts'),
            ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: widget.onSchedule,
          child: const Text('Schedule Nudges'),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector(Contact contact) {
    final currentFrequency = _frequencyOverrides[contact.id] ?? contact.frequency;
    
    return ListTile(
      title: Text(contact.name),
      trailing: DropdownButton<String>(
        value: currentFrequency,
        onChanged: (String? newValue) {
          setState(() {
            _frequencyOverrides[contact.id] = newValue!;
          });
        },
        items: <String>['Weekly', 'Monthly', 'Quarterly', 'Annually']
            .map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }
}
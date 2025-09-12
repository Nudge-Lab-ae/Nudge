// lib/services/nudge_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
// import 'dart:io';
import '../models/contact.dart';
import '../models/nudge.dart';
import '../models/social_group.dart';
import '../services/notification_service.dart';
// import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class NudgeService {
  static final NudgeService _instance = NudgeService._internal();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory NudgeService() {
    return _instance;
  }

  NudgeService._internal();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    await _notificationService.initialize();
  }

  // Get all nudges for a user
  Stream<List<Nudge>> getNudgesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('nudges')
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Nudge.fromMap(doc.data()))
            .toList());
  }

  // Schedule a nudge for a single contact
  Future<bool> scheduleNudgeForContact(Contact contact, String userId, 
      {String? period, int? frequency}) async {
    try {
      // Use group settings if not overridden
      String effectivePeriod = period ?? contact.period;
      int effectiveFrequency = frequency ?? contact.frequency;
      
      // Calculate next nudge time
      DateTime nextNudgeTime = _calculateNextNudgeTime(effectivePeriod, effectiveFrequency);
      
      // Create nudge
      final nudge = Nudge(
        id: const Uuid().v4(),
        nudgeId: '',
        contactId: contact.id,
        contactName: contact.name,
        nudgeType: 'scheduled',
        message: 'Time to connect with ${contact.name}',
        scheduledTime: nextNudgeTime,
        userId: userId,
        period: effectivePeriod,
        frequency: effectiveFrequency,
      );

      nudge.nudgeId = nudge.id;
      
      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .doc(nudge.id)
          .set(nudge.toMap());
      
      // Schedule notification
      await _notificationService.scheduleNudgeNotification(
        nudge.id.hashCode,
        'Time to connect with ${contact.name}!',
        'Remember to reach out to ${contact.name}. You scheduled this reminder.',
        nextNudgeTime,
      );
      
      // Update contact's last nudge time
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .doc(contact.id)
          .update({
        'lastNudged': DateTime.now().millisecondsSinceEpoch,
        'nextNudge': nextNudgeTime.millisecondsSinceEpoch,
      });
      
      print('Nudge scheduled for ${contact.name} at $nextNudgeTime');
      return true;
    } catch (e) {
      print('Error scheduling nudge for ${contact.name}: $e');
      return false;
    }
  }

  DateTime _calculateNextNudgeTime(String period, int frequency) {
    DateTime now = DateTime.now();
    
    switch (period) {
      case 'weeks':
        return now.add(Duration(days: frequency * 7));
      case 'months':
        return now.add(Duration(days: frequency * 30));
      case 'years':
        return now.add(Duration(days: frequency * 365));
      default: // days
        return now.add(Duration(days: frequency));
    }
  }

  // Send a test nudge (immediate notification)
  Future<void> sendTestNudge(Contact contact, String userId) async {
    try {
      // Show immediate notification
      await _notificationService.showInstantNotification(
        '${contact.id}-test-${DateTime.now().millisecondsSinceEpoch}'.hashCode,
        'Test Nudge: ${contact.name}',
        'This is a test nudge for ${contact.name}. Time to connect!',
      );
      
      print('Test nudge sent for ${contact.name}');
    } catch (e) {
      print('Error sending test nudge: $e');
    }
  }

  // Schedule nudges for a group of contacts
  Future<Map<String, dynamic>> scheduleNudgesForGroup(
    List<Contact> contacts, 
    String userId, 
  ) async {
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

  // Mark a nudge as complete
  Future<void> markNudgeAsComplete(String nudgeId, String userId, String contactId) async {
    try {
      // Update the nudge
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .doc(nudgeId)
          .update({
        'isCompleted': true,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Update the contact's last contacted date
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .doc(contactId)
          .update({
        'lastContacted': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Cancel the notification
      await _notificationService.cancelNotification(nudgeId.hashCode);
    } catch (e) {
      print('Error marking nudge as complete: $e');
      rethrow;
    }
  }

  // Snooze a nudge
  Future<void> snoozeNudge(String nudgeId, String userId, Duration duration, String contactName) async {
    try {
      final newScheduledTime = DateTime.now().add(duration);
      
      // Update the nudge
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .doc(nudgeId)
          .update({
        'scheduledTime': newScheduledTime.millisecondsSinceEpoch,
        'isSnoozed': true,
        'snoozedUntil': newScheduledTime.millisecondsSinceEpoch,
      });
      
      // Reschedule the notification
      await _notificationService.scheduleNudgeNotification(
        nudgeId.hashCode,
        'Time to connect with $contactName!',
        'Remember to reach out to $contactName. This nudge was snoozed.',
        newScheduledTime,
      );
    } catch (e) {
      print('Error snoozing nudge: $e');
      rethrow;
    }
  }

  // Cancel a nudge
  Future<void> cancelNudge(String nudgeId, String userId) async {
    try {
      // Delete the nudge
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .doc(nudgeId)
          .delete();
      
      // Cancel the notification
      await _notificationService.cancelNotification(nudgeId.hashCode);
    } catch (e) {
      print('Error canceling nudge: $e');
      rethrow;
    }
  }

  // Show the nudge scheduling dialog
  Future<void> showNudgeScheduleDialog(BuildContext context, List<Contact> contacts, List<SocialGroup> groups, String userId) async {
    showDialog(
      context: context,
      builder: (context) {
        return NudgeScheduleDialog(
          contacts: contacts,
          groups: groups,
          userId: userId,
        );
      },
    );
  }

  // Get contacts for a specific group
  Future<List<Contact>> getContactsForGroup(String userId, String groupId, List<Contact> contacts) async {
    try {
      List<Contact> filteredContacts = contacts.where((contact) => contact.connectionType == groupId).toList();
      return filteredContacts;
    } catch (e) {
      print('Error getting contacts for group: $e');
      return [];
    }
  }

  // Get all contacts for a user
  Future<List<Contact>> getAllContacts(String userId) async {
    try {
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();
      
      return contactsSnapshot.docs
          .map((doc) => Contact.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting all contacts: $e');
      return [];
    }
  }
}

// Updated NudgeScheduleDialog for group-based scheduling
class NudgeScheduleDialog extends StatefulWidget {
  final List<Contact> contacts;
  final List<SocialGroup> groups;
  final String userId;

  const NudgeScheduleDialog({
    super.key,
    required this.contacts,
    required this.groups,
    required this.userId,
  });

  @override
  State<NudgeScheduleDialog> createState() => _NudgeScheduleDialogState();
}

class _NudgeScheduleDialogState extends State<NudgeScheduleDialog> {
  final NudgeService _nudgeService = NudgeService();
  String _selectedOption = 'all'; // 'all', 'group', 'manual'
  String? _selectedGroupId;
  final Set<String> _selectedContactIds = {};

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return StreamProvider<List<Contact>>(
      create: (context) => apiService.getContactsStream(),
      initialData: [],
      child:  Consumer<List<Contact>>(
          builder: (context, contacts, child) {
            return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Schedule Nudges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Option selection
            const Text('Select contacts to nudge:'),
            const SizedBox(height: 8),
            
            RadioListTile(
              title: const Text('All Contacts'),
              value: 'all',
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() {
                  _selectedOption = value.toString();
                });
              },
            ),
            
            RadioListTile(
              title: const Text('By Group'),
              value: 'group',
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() {
                  _selectedOption = value.toString();
                });
              },
            ),
            
            if (_selectedOption == 'group') ...[
              const SizedBox(height: 8),
              const Text('Select Group:'),
              DropdownButton<String>(
                value: _selectedGroupId,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGroupId = newValue;
                  });
                },
                items: widget.groups.map<DropdownMenuItem<String>>((SocialGroup group) {
                  return DropdownMenuItem<String>(
                    value: group.id,
                    child: Text(group.name),
                  );
                }).toList(),
              ),
            ],
            
            RadioListTile(
              title: const Text('Manual Selection'),
              value: 'manual',
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() {
                  _selectedOption = value.toString();
                });
              },
            ),
            
            if (_selectedOption == 'manual') ...[
              const SizedBox(height: 8),
              const Text('Select Contacts:'),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = widget.contacts[index];
                    return CheckboxListTile(
                      title: Text(contact.name),
                      value: _selectedContactIds.contains(contact.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedContactIds.add(contact.id);
                          } else {
                            _selectedContactIds.remove(contact.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    List<Contact> selectedContacts = [];
                    
                    if (_selectedOption == 'all') {
                      selectedContacts = widget.contacts;
                    } else if (_selectedOption == 'group' && _selectedGroupId != null) {
                      selectedContacts = await _nudgeService.getContactsForGroup(
                        widget.userId, _selectedGroupId!, contacts
                      );
                    } else if (_selectedOption == 'manual') {
                      selectedContacts = widget.contacts
                          .where((contact) => _selectedContactIds.contains(contact.id))
                          .toList();
                    }
                    
                    if (selectedContacts.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one contact')),
                      );
                      return;
                    }
                    
                    Navigator.of(context).pop();
                    
                    // Show progress dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return const Dialog(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Scheduling nudges...'),
                                SizedBox(height: 20),
                                CircularProgressIndicator(),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                    
                    // Schedule nudges
                    final result = await _nudgeService.scheduleNudgesForGroup(
                      selectedContacts,
                      widget.userId,
                    );
                    
                    // Dismiss progress dialog
                    Navigator.pop(context);
                    
                    // Show result
                    _showSchedulingResult(context, result);
                  },
                  child: const Text('Schedule Nudges'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    }
    )
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
          ],
        );
      },
    );
  }
}
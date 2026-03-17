// lib/services/nudge_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/services/overdue_manager.dart';
// import 'package:nudge/services/overdue_manager.dart';
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


  // Stream<List<Nudge>>? _cachedStream;
  // String? _lastUserId;
  // StreamSubscription<QuerySnapshot>? _streamSubscription;
  // List<Nudge> _lastEmittedData = [];
  // final _controller = StreamController<List<Nudge>>.broadcast();

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
  
  // Stream<List<Nudge>> getNudgesStream(String userId) {
  //   // Return cached stream if same user and stream exists
  //   if (_cachedStream != null && _lastUserId == userId) {
  //     return _cachedStream!;
  //   }
    
  //   _lastUserId = userId;
    
  //   // Cancel previous subscription if any
  //   _streamSubscription?.cancel();
    
  //   // Reset last emitted data when creating new stream
  //   _lastEmittedData = [];
    
  //   // Create new stream with debouncing and caching
  //   _cachedStream = _firestore
  //       .collection('users')
  //       .doc(userId)
  //       .collection('nudges')
  //       .orderBy('scheduledTime', descending: false)
  //       .snapshots()
  //       .map((snapshot) {
  //         final nudges = snapshot.docs
  //             .map((doc) => Nudge.fromMap(doc.data()))
  //             .toList();
          
  //         // Always emit on first load of this stream instance
  //         if (_lastEmittedData.isEmpty) {
  //           _lastEmittedData = nudges;
  //           return nudges;
  //         }
          
  //         // Only emit if data actually changed for subsequent updates
  //         if (_hasDataChanged(nudges, _lastEmittedData)) {
  //           _lastEmittedData = nudges;
  //           return nudges;
  //         }
          
  //         // Return last emitted data if no change
  //         return _lastEmittedData;
  //       })
  //       .handleError((error) {
  //         print('Error in nudges stream: $error');
  //         return <Nudge>[];
  //       })
  //       .asBroadcastStream(); // Make it broadcast for multiple listeners
    
  //   return _cachedStream!;
  // }
  
  // Helper method to check if data actually changed
  // bool _hasDataChanged(List<Nudge> newData, List<Nudge> oldData) {
  //   if (newData.length != oldData.length) return true;
    
  //   for (int i = 0; i < newData.length; i++) {
  //     if (newData[i].id != oldData[i].id ||
  //         newData[i].isCompleted != oldData[i].isCompleted ||
  //         newData[i].scheduledTime != oldData[i].scheduledTime) {
  //       return true;
  //     }
  //   }
    
  //   return false;
  // }

  Future<List<Nudge>> getAllNudges(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('nudges')
        .get();
    
    return snapshot.docs
        .map((doc) => Nudge.fromMap(doc.data()))
        .toList();
  } catch (e) {
    print('Error getting all nudges: $e');
    return [];
  }
}

   List<DateTime> _calculateStaggeredTimes(DateTime baseTime, int count, Duration interval) {
    List<DateTime> times = [];
    for (int i = 0; i < count; i++) {
      times.add(baseTime.add(interval * i));
    }
    return times;
  }

  // Schedule a nudge for a single contact
  Future<bool> scheduleNudgeForContact(Contact contact, String userId, 
      {String? period, int? frequency, DateTime? scheduledTime}) async {
    try {
      // Use group settings if not overridden
      bool shouldSendPush = contact.isVIP;

      String effectivePeriod = period ?? contact.period;
      int effectiveFrequency = frequency ?? contact.frequency;
      
      // Calculate next nudge time if not provided
      DateTime nextNudgeTime = scheduledTime ?? _calculateNextNudgeTime(effectivePeriod, effectiveFrequency);
      
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
        isPushNotification: shouldSendPush,
        priority: contact.priority,
        isVIP: contact.isVIP,
        groupName: contact.connectionType,
        contactImageUrl: contact.imageUrl
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
      // if (shouldSendPush) {
      //   await _notificationService.scheduleNudgeNotification(
      //     nudge.id.hashCode,
      //     'Time to connect with ${contact.name}!',
      //     'Remember to reach out to ${contact.name}. You scheduled this reminder.',
      //     nextNudgeTime,
      //   );
      // }
      
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

  // Reschedule nudges after a touchpoint is logged
  Future<void> rescheduleNudgeAfterInteraction(Contact contact, String userId, [DateTime? interactionTimestamp]) async {
    try {
      // Use provided timestamp or current time if not provided (for backward compatibility)
      final interactionTime = interactionTimestamp ?? DateTime.now();
      
      // Find all active nudges for this contact
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .where('contactId', isEqualTo: contact.id)
          .where('isCompleted', isEqualTo: false)
          .get();

      // Calculate new scheduled time based on interaction time and contact's frequency
      final newScheduledTime = _calculateNextNudgeTimeFromLastContact(contact, interactionTime);

      for (final doc in snapshot.docs) {
        // Update the nudge with new scheduled time
        await doc.reference.update({
          'scheduledTime': newScheduledTime.millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Cancel and reschedule the notification if it's a push notification
        final nudge = Nudge.fromMap(doc.data());
        if (nudge.isPushNotification) {
          await _notificationService.cancelNotification(doc.id.hashCode);
          await _notificationService.scheduleNudgeNotification(
            doc.id.hashCode,
            'Time to connect with ${contact.name}!',
            'Remember to reach out to ${contact.name}.',
            newScheduledTime,
          );
        }
      }

      print('Rescheduled nudges for ${contact.name} to $newScheduledTime (based on interaction at $interactionTime)');
    } catch (e) {
      print('Error rescheduling nudges after interaction: $e');
      throw Exception('Failed to reschedule nudges: $e');
    }
  }

  // Calculate next nudge time from last contacted date
  DateTime _calculateNextNudgeTimeFromLastContact(Contact contact, DateTime interactionTime) {
    DateTime nextTime;

    // Calculate based on contact's frequency and period
    switch (contact.period) {
      case 'Daily':
        nextTime = interactionTime.add(Duration(days: contact.frequency));
        break;
      case 'Weekly':
        nextTime = interactionTime.add(Duration(days: contact.frequency * 7));
        break;
      case 'Monthly':
        nextTime = interactionTime.add(Duration(days: contact.frequency * 30));
        break;
      case 'Quarterly':
        nextTime = interactionTime.add(Duration(days: contact.frequency * 90));
        break;
      case 'Annually':
        nextTime = interactionTime.add(Duration(days: contact.frequency * 365));
        break;
      default:
        nextTime = interactionTime.add(Duration(days: 30)); // Default to 30 days
    }

    // Ensure the new time is in the future (from current time, not interaction time)
    final now = DateTime.now();
    if (nextTime.isBefore(now)) {
      nextTime = now.add(const Duration(minutes: 5));
    }

    return nextTime;
  }

// Main method to schedule nudges for imported contacts with proper spacing
Future<Map<String, dynamic>> scheduleGroupedNudgesWithSpacing(
  List<Contact> contacts, 
  String userId,
) async {
  try {
    print('Starting spaced scheduling for ${contacts.length} contacts');
    
    // Step 1: Group contacts by period and frequency
    final groupedContacts = _groupContactsByPeriodFrequency(contacts);
    
    // Step 2: Get existing scheduled nudges to avoid conflicts
    final existingNudges = await _getExistingScheduledNudges(userId);
    
    // Step 3: Process each group with proper spacing
    final results = await _processContactGroups(
      groupedContacts, 
      userId, 
      existingNudges
    );
    
    print('Successfully scheduled ${results['successCount']} out of ${contacts.length} contacts');
    
    return results;
  } catch (e) {
    print('Error in scheduleGroupedNudgesWithSpacing: $e');
    return {
      'successCount': 0,
      'failCount': contacts.length,
      'failedContacts': contacts.map((c) => c.name).toList(),
      'error': e.toString(),
    };
  }
}

// Group contacts by their period and frequency
Map<String, List<Contact>> _groupContactsByPeriodFrequency(List<Contact> contacts) {
  final groups = <String, List<Contact>>{};
  
  for (final contact in contacts) {
    final key = '${contact.period}_${contact.frequency}';
    if (!groups.containsKey(key)) {
      groups[key] = [];
    }
    groups[key]!.add(contact);
  }
  
  // Sort groups by priority (weekly first, then monthly, etc.)
  final sortedGroups = <String, List<Contact>>{};
  final periodOrder = ['weekly', 'monthly', 'quarterly', 'annually'];
  
  // Sort keys by period
  final sortedKeys = groups.keys.toList()
    ..sort((a, b) {
      final periodA = a.split('_')[0].toLowerCase();
      final periodB = b.split('_')[0].toLowerCase();
      
      final indexA = periodOrder.indexOf(periodA);
      final indexB = periodOrder.indexOf(periodB);
      
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      return a.compareTo(b);
    });
    
  for (final key in sortedKeys) {
    sortedGroups[key] = groups[key]!;
  }
  
  print('Grouped ${contacts.length} contacts into ${sortedGroups.length} groups');
  return sortedGroups;
}

// Process contact groups with proper spacing
Future<Map<String, dynamic>> _processContactGroups(
  Map<String, List<Contact>> groupedContacts,
  String userId,
  List<DateTime> existingNudges,
) async {
  int successCount = 0;
  int failCount = 0;
  final failedContacts = <String>[];
  
  // Track current time for each group
  final currentGroupTimes = <String, DateTime>{};
  
  for (final entry in groupedContacts.entries) {
    final groupKey = entry.key;
    final contacts = entry.value;
    final parts = groupKey.split('_');
    final period = parts[0];
    final frequency = int.tryParse(parts[1]) ?? 1;
    
    print('Processing group: $groupKey with ${contacts.length} contacts');
    
    // Calculate ideal spacing for this group
    final idealSpacing = _calculateIdealSpacing(period, frequency, contacts.length);
    
    // Set initial base time for this group
    DateTime groupBaseTime = currentGroupTimes[groupKey] ?? DateTime.now();
    currentGroupTimes[groupKey] = groupBaseTime;
    
    // Process each contact in the group with spacing
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      
      try {
        // Calculate nudge time with proper spacing
        final nudgeTime = await _calculateSpacedNudgeTime(
          contact,
          userId,
          i,
          contacts.length,
          groupBaseTime,
          idealSpacing,
          existingNudges,
        );
        
        if (nudgeTime != null && nudgeTime.isAfter(DateTime.now())) {
          // Schedule the nudge
          final success = await scheduleNudgeForContact(
            contact,
            userId,
            period: contact.period,
            frequency: contact.frequency,
            scheduledTime: nudgeTime,
          );
          
          if (success) {
            successCount++;
            // Add to existing nudges for future calculations
            existingNudges.add(nudgeTime);
            print('Scheduled ${contact.name} at ${nudgeTime.toLocal()}');
          } else {
            failCount++;
            failedContacts.add(contact.name);
          }
        } else {
          failCount++;
          failedContacts.add(contact.name);
        }
        
        // Update group base time for next contact
        groupBaseTime = groupBaseTime.add(idealSpacing);
        
        // Small delay to avoid overwhelming
        await Future.delayed(const Duration(milliseconds: 50));
        
      } catch (e) {
        print('Error scheduling ${contact.name}: $e');
        failCount++;
        failedContacts.add(contact.name);
      }
    }
  }
  
  return {
    'successCount': successCount,
    'failCount': failCount,
    'failedContacts': failedContacts,
  };
}

// Calculate ideal spacing between nudges for a group
Duration _calculateIdealSpacing(String period, int frequency, int groupSize) {
  final totalNudgesPerPeriod = groupSize * frequency;
  
  switch (period.toLowerCase()) {
    case 'weekly':
      // Spread across 7 days
      final days = 7 / totalNudgesPerPeriod;
      return Duration(days: days.toInt(), hours: ((days % 1) * 24).toInt());
      
    case 'monthly':
      // Spread across 30 days
      final days = 30 / totalNudgesPerPeriod;
      return Duration(days: days.toInt(), hours: ((days % 1) * 24).toInt());
      
    case 'quarterly':
      // Spread across 90 days
      final days = 90 / totalNudgesPerPeriod;
      return Duration(days: days.toInt(), hours: ((days % 1) * 24).toInt());
      
    case 'annually':
      // Spread across 365 days
      final days = 365 / totalNudgesPerPeriod;
      return Duration(days: days.toInt(), hours: ((days % 1) * 24).toInt());
      
    default:
      // Default to weekly spacing
      final days = 7 / totalNudgesPerPeriod;
      return Duration(days: days.toInt(), hours: ((days % 1) * 24).toInt());
  }
}

// Calculate nudge time with spacing and conflict avoidance
Future<DateTime?> _calculateSpacedNudgeTime(
  Contact contact,
  String userId,
  int contactIndex,
  int totalContacts,
  DateTime baseTime,
  Duration idealSpacing,
  List<DateTime> existingNudges,
) async {
  try {
    // Start with base time adjusted by contact index
    DateTime candidateTime = baseTime.add(idealSpacing * contactIndex);
    
    // Add some randomization within the day
    final randomHour = 9 + (contactIndex % 9); // Between 9 AM and 5 PM
    candidateTime = DateTime(
      candidateTime.year,
      candidateTime.month,
      candidateTime.day,
      randomHour,
      (contactIndex % 4) * 15, // 0, 15, 30, or 45 minutes
    );
    
    // Avoid conflicts with existing nudges
    candidateTime = _avoidTimeConflicts(candidateTime, existingNudges);
    
    // Ensure it's in the future
    if (candidateTime.isBefore(DateTime.now())) {
      candidateTime = DateTime.now().add(const Duration(hours: 1));
    }
    
    return candidateTime;
  } catch (e) {
    print('Error calculating nudge time for ${contact.name}: $e');
    return null;
  }
}

// Adjust time to avoid conflicts with existing nudges
DateTime _avoidTimeConflicts(DateTime candidateTime, List<DateTime> existingNudges, {int maxAttempts = 10}) {
  const conflictThreshold = Duration(hours: 2); // 2-hour buffer
  
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    bool hasConflict = false;
    
    for (final existingTime in existingNudges) {
      final timeDifference = candidateTime.difference(existingTime).abs();
      if (timeDifference < conflictThreshold) {
        hasConflict = true;
        break;
      }
    }
    
    if (!hasConflict) {
      return candidateTime;
    }
    
    // Try different offsets
    if (attempt % 2 == 0) {
      // Try positive offset
      candidateTime = candidateTime.add(Duration(hours: attempt + 1));
    } else {
      // Try negative offset
      candidateTime = candidateTime.subtract(Duration(hours: attempt));
    }
  }
  
  // If we couldn't avoid conflicts, return the original time
  return candidateTime;
}

// Get existing scheduled nudges
Future<List<DateTime>> _getExistingScheduledNudges(String userId) async {
  try {
    final now = DateTime.now();
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('nudges')
        .where('isCompleted', isEqualTo: false)
        .where('scheduledTime', isGreaterThanOrEqualTo: now.millisecondsSinceEpoch)
        .get();
    
    final existingNudges = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final time = data['scheduledTime'];
          if (time is int) {
            return DateTime.fromMillisecondsSinceEpoch(time);
          }
          return now;
        })
        .where((time) => time.isAfter(now))
        .toList();
    
    print('Found ${existingNudges.length} existing scheduled nudges');
    return existingNudges;
  } catch (e) {
    print('Error getting existing nudges: $e');
    return [];
  }
}
  
  // // Add method to process overdue nudges (call this periodically)
  Future<void> processOverdueNudges(String userId) async {
    await OverdueManager().processOverdueNudges(userId);
  }

   Stream<List<Nudge>> getUpcomingNudgesStream(String userId, {int daysAhead = 7}) {
    DateTime cutoff = DateTime.now().add(Duration(days: daysAhead));
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('nudges')
        .where('scheduledTime', isLessThanOrEqualTo: cutoff.millisecondsSinceEpoch)
        .where('isCompleted', isEqualTo: false)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Nudge.fromMap(doc.data()))
            .toList());
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
    {bool staggered = false, 
     Duration staggerInterval = const Duration(hours: 1)}
  ) async {
    int successCount = 0;
    int failCount = 0;
    List<String> failedContacts = [];
    
   contacts.sort((a, b) {
      if (a.isVIP && !b.isVIP) return -1;
      if (!a.isVIP && b.isVIP) return 1;
      return 0;
    });
    
    // Calculate base time and staggered times if needed
    DateTime baseTime = DateTime.now();
    List<DateTime> scheduledTimes = [];
    
    if (staggered) {
      scheduledTimes = _calculateStaggeredTimes(baseTime, contacts.length, staggerInterval);
    } else {
      // All at the same time
      scheduledTimes = List<DateTime>.filled(contacts.length, baseTime);
    }
    
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final scheduledTime = scheduledTimes[i];
      
      final success = await scheduleNudgeForContact(
        contact, 
        userId, 
        scheduledTime: scheduledTime
      );
      
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
      // await _notificationService.cancelNotification(nudgeId.hashCode);
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
  List<Contact> getContactsForGroup(String userId, String groupId, List<Contact> contacts) {
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
  String _selectedOption = 'all';
  String? _selectedGroupId;
  final Set<String> _selectedContactIds = {};
  bool _staggered = true;
  String _staggerInterval = '1 hour';
  List<Contact> allContacts = [];
  
  // New state to track the current view
  _DialogView _currentView = _DialogView.options;
  Map<String, dynamic>? _schedulingResult;

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return StreamProvider<List<Contact>>(
      create: (context) => apiService.getContactsStream(),
      initialData: [],
      child: Consumer<List<Contact>>(
        builder: (context, contacts, child) {
          allContacts = contacts;
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildCurrentView(context, contacts),
            ),
          );
        }
      )
    );
  }

  Widget _buildCurrentView(BuildContext context, List<Contact> contacts) {
    switch (_currentView) {
      case _DialogView.options:
        return _buildOptionsView(context, contacts);
      case _DialogView.processing:
        return _buildProcessingView();
      case _DialogView.result:
        return _buildResultView(context);
    }
  }

  Widget _buildOptionsView(BuildContext context, List<Contact> contacts) {
    return Column(
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
        const Text('Select contacts to nudge:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        
        RadioListTile(
          title: const Text('All Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
          value: 'all',
          groupValue: _selectedOption,
          onChanged: (value) {
            setState(() {
              _selectedOption = value.toString();
            });
          },
        ),
        
        RadioListTile(
          title: const Text('By Group', style: TextStyle(fontWeight: FontWeight.w600)),
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
          const Text('Select Group:', style: TextStyle(fontWeight: FontWeight.w600)),
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
          title: const Text('Manual Selection', style: TextStyle(fontWeight: FontWeight.w600)),
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
          const Text('Select Contacts:', style: TextStyle(fontWeight: FontWeight.w600)),
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
        
        // Scheduling Options
        const Text('Scheduling Options:', style: TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: [
            const Text('Staggered Reminders'),
            Switch(
              value: _staggered,
              onChanged: (value) {
                setState(() {
                  _staggered = value;
                });
              },
            ),
          ],
        ),
        
        if (_staggered) ...[
          const SizedBox(height: 8),
          const Text('Stagger Interval:', style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButton<String>(
            value: _staggerInterval,
            onChanged: (String? newValue) {
              setState(() {
                _staggerInterval = newValue!;
              });
            },
            items: <String>['30 minutes', '1 hour', '2 hours', '4 hours', '1 day']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
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
              onPressed: () => _startSchedulingProcess(context, contacts),
              child: const Text('Schedule Nudges'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Scheduling Nudges',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Please wait while we schedule your nudges...'),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context) {
    final successCount = _schedulingResult?['successCount'] as int? ?? 0;
    final failCount = _schedulingResult?['failCount'] as int? ?? 0;
    final failedContacts = _schedulingResult?['failedContacts'] as List<String>? ?? [];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scheduling Complete',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text('Successfully scheduled: $successCount nudges'),
        Text('Failed: $failCount nudges'),
        if (failedContacts.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Failed contacts:'),
          ...failedContacts.map((name) => Text('• $name')).toList(),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () {
              final apiService = Provider.of<ApiService>(context, listen: false);
              apiService.scheduleRegularNotifications(allContacts);
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }

  void _startSchedulingProcess(BuildContext context, List<Contact> contacts) async {
    // Get selected contacts
    List<Contact> selectedContacts = _getSelectedContacts(contacts);
    
    if (selectedContacts.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Please select at least one contact')),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'Please select at least one contact.',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
      return;
    }

    // Calculate stagger interval
    final interval = _calculateStaggerInterval();
    
    // Switch to processing view
    setState(() {
      _currentView = _DialogView.processing;
    });

    try {
      // Schedule nudges
      final result = await _nudgeService.scheduleNudgesForGroup(
        selectedContacts,
        widget.userId,
        staggered: _staggered,
        staggerInterval: interval,
      );

      // Switch to result view
      setState(() {
        _schedulingResult = result;
        _currentView = _DialogView.result;
      });
    } catch (e) {
      // Show error result
      setState(() {
        _schedulingResult = {
          'successCount': 0,
          'failCount': selectedContacts.length,
          'failedContacts': selectedContacts.map((c) => c.name).toList(),
          'error': e.toString(),
        };
        _currentView = _DialogView.result;
      });
    }
  }

  List<Contact> _getSelectedContacts(List<Contact> contacts) {
    if (_selectedOption == 'all') {
      return widget.contacts;
    } else if (_selectedOption == 'group' && _selectedGroupId != null) {
      return _nudgeService.getContactsForGroup(
        widget.userId, _selectedGroupId!, contacts
      );
    } else if (_selectedOption == 'manual') {
      return widget.contacts
          .where((contact) => _selectedContactIds.contains(contact.id))
          .toList();
    }
    return [];
  }

  Duration _calculateStaggerInterval() {
    switch (_staggerInterval) {
      case '30 minutes':
        return const Duration(minutes: 30);
      case '2 hours':
        return const Duration(hours: 2);
      case '4 hours':
        return const Duration(hours: 4);
      case '1 day':
        return const Duration(days: 1);
      default: // 1 hour
        return const Duration(hours: 1);
    }
  }
}

// Enum to track the current dialog view
enum _DialogView {
  options,
  processing,
  result,
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/services/notification_service.dart';
import 'package:nudge/services/nudge_service.dart';

class OverdueManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NudgeService _nudgeService = NudgeService();
  
  static const int OVERDUE_DAYS_THRESHOLD = 10;
  static const Duration RESCHEDULE_DELAY = Duration(days: 7);
  static const int MAX_NUDGES_PER_DAY = 5; // Maximum nudges to schedule per day
  
  // Check and process overdue nudges
  Future<void> processOverdueNudges(String userId) async {
    try {
      final now = DateTime.now();
      final thresholdDate = now.subtract(Duration(days: OVERDUE_DAYS_THRESHOLD));
      
      // Get all active nudges that are overdue
      final overdueNudges = await _getOverdueNudges(userId, thresholdDate);
      
      if (overdueNudges.isEmpty) return;
      
      // Group by contact to ensure only one nudge per contact
      final Map<String, Nudge> contactsWithOverdueNudges = {};
      for (final nudge in overdueNudges) {
        if (!contactsWithOverdueNudges.containsKey(nudge.contactId)) {
          contactsWithOverdueNudges[nudge.contactId] = nudge;
        }
      }
      
      // Process each contact
      for (final nudge in contactsWithOverdueNudges.values) {
        await _handleOverdueNudge(nudge, userId);
      }
      
      // Reschedule canceled nudges with proper distribution
      await _rescheduleCanceledNudges(userId);
      
    } catch (e) {
      print('Error processing overdue nudges: $e');
    }
  }
  
  // Get nudges that are overdue by more than threshold days
  Future<List<Nudge>> _getOverdueNudges(String userId, DateTime thresholdDate) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .where('isCompleted', isEqualTo: false)
          .where('isCanceled', isEqualTo: false)
          .where('scheduledTime', isLessThan: thresholdDate.millisecondsSinceEpoch)
          .get();
      
      return snapshot.docs
          .map((doc) => Nudge.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting overdue nudges: $e');
      return [];
    }
  }
  
  // Handle a single overdue nudge
  Future<void> _handleOverdueNudge(Nudge nudge, String userId) async {
    try {
      // 1. Mark the overdue nudge as canceled
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .doc(nudge.id)
          .update({
        'isCanceled': true,
        'status': 'canceled',
        'canceledAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      // 2. Cancel the notification
      final notificationService = NotificationService();
      await notificationService.cancelNotification(nudge.id.hashCode);
      
      // 3. Cancel any other active nudges for this contact
      await _cancelOtherActiveNudgesForContact(nudge.contactId, userId, nudge.id);
      
      print('Canceled overdue nudge for ${nudge.contactName}');
      
    } catch (e) {
      print('Error handling overdue nudge: $e');
    }
  }
  
  // Cancel other active nudges for the same contact
  Future<void> _cancelOtherActiveNudgesForContact(
    String contactId, 
    String userId, 
    String currentNudgeId
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .where('contactId', isEqualTo: contactId)
          .where('isCompleted', isEqualTo: false)
          .where('isCanceled', isEqualTo: false)
          .get();
      
      for (final doc in snapshot.docs) {
        if (doc.id != currentNudgeId) {
          await doc.reference.update({
            'isCanceled': true,
            'status': 'canceled',
            'canceledAt': DateTime.now().millisecondsSinceEpoch,
          });
          
          // Cancel notification
          final notificationService = NotificationService();
          await notificationService.cancelNotification(doc.id.hashCode);
        }
      }
    } catch (e) {
      print('Error canceling other nudges for contact: $e');
    }
  }
  
  // Reschedule canceled nudges with proper distribution
  Future<void> _rescheduleCanceledNudges(String userId) async {
    try {
      // Get all contacts with canceled nudges
      final contactsWithCanceledNudges = await _getContactsWithCanceledNudges(userId);
      
      if (contactsWithCanceledNudges.isEmpty) return;
      
      // Calculate distribution of nudges across days
      final distribution = _calculateDistribution(
        contactsWithCanceledNudges.length,
        startDate: DateTime.now().add(RESCHEDULE_DELAY),
      );
      
      // Reschedule each contact
      for (int i = 0; i < contactsWithCanceledNudges.length; i++) {
        final contact = contactsWithCanceledNudges[i];
        final scheduledTime = distribution[i];
        
        await _nudgeService.scheduleNudgeForContact(
          contact,
          userId,
          scheduledTime: scheduledTime,
        );
      }
      
      print('Rescheduled ${contactsWithCanceledNudges.length} canceled nudges');
      
    } catch (e) {
      print('Error rescheduling canceled nudges: $e');
    }
  }
  
  // Get contacts that have canceled nudges
  Future<List<Contact>> _getContactsWithCanceledNudges(String userId) async {
    try {
      // First get all canceled nudges
      final canceledNudgesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .where('isCanceled', isEqualTo: true)
          .where('status', isEqualTo: 'canceled')
          .get();
      
      final canceledNudges = canceledNudgesSnapshot.docs
          .map((doc) => Nudge.fromMap(doc.data()))
          .toList();
      
      // Get unique contact IDs
      final contactIds = canceledNudges
          .map((n) => n.contactId)
          .toSet()
          .toList();
      
      // Fetch contact details
      final List<Contact> contacts = [];
      for (final contactId in contactIds) {
        try {
          final contactDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('contacts')
              .doc(contactId)
              .get();
          
          if (contactDoc.exists) {
            contacts.add(Contact.fromMap(contactDoc.data() as Map<String, dynamic>));
          }
        } catch (e) {
          print('Error fetching contact $contactId: $e');
        }
      }
      
      return contacts;
    } catch (e) {
      print('Error getting contacts with canceled nudges: $e');
      return [];
    }
  }
  
  // Calculate distribution of nudges across days
  List<DateTime> _calculateDistribution(int count, {required DateTime startDate}) {
    final List<DateTime> distribution = [];
    // final int daysNeeded = (count / MAX_NUDGES_PER_DAY).ceil();
    
    for (int i = 0; i < count; i++) {
      final dayOffset = (i ~/ MAX_NUDGES_PER_DAY);
      final hourOffset = (i % MAX_NUDGES_PER_DAY) * 2; // Spread by 2-hour intervals
      
      final scheduledTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day + dayOffset,
        9 + hourOffset, // Start at 9 AM
      );
      
      distribution.add(scheduledTime);
    }
    
    return distribution;
  }
  
  // Check if a contact has any active nudges
  Future<bool> hasActiveNudgeForContact(String contactId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .where('contactId', isEqualTo: contactId)
          .where('isCompleted', isEqualTo: false)
          .where('isCanceled', isEqualTo: false)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active nudge: $e');
      return false;
    }
  }
  
  // Get the next available time slot for a contact
  Future<DateTime> getNextAvailableTimeSlot(
    String userId, {
    DateTime? preferredDate,
  }) async {
    try {
      final now = DateTime.now();
      DateTime checkDate = preferredDate ?? now.add(RESCHEDULE_DELAY);
      
      // Get nudges scheduled for the next week
      final weekLater = checkDate.add(Duration(days: 7));
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudges')
          .where('scheduledTime', 
                isGreaterThanOrEqualTo: checkDate.millisecondsSinceEpoch,
                isLessThan: weekLater.millisecondsSinceEpoch)
          .where('isCanceled', isEqualTo: false)
          .get();
      
      // Group nudges by day
      final Map<String, List<DateTime>> nudgesByDay = {};
      
      for (final doc in snapshot.docs) {
        final nudge = Nudge.fromMap(doc.data());
        final dateKey = DateFormat('yyyy-MM-dd').format(nudge.scheduledTime);
        
        if (!nudgesByDay.containsKey(dateKey)) {
          nudgesByDay[dateKey] = [];
        }
        nudgesByDay[dateKey]!.add(nudge.scheduledTime);
      }
      
      // Find the first day with available slots
      for (int day = 0; day < 30; day++) { // Look up to 30 days ahead
        final currentDate = checkDate.add(Duration(days: day));
        final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        
        final dailyNudges = nudgesByDay[dateKey] ?? [];
        
        if (dailyNudges.length < MAX_NUDGES_PER_DAY) {
          // Find an available time slot
          final availableSlot = _findAvailableTimeSlot(currentDate, dailyNudges);
          if (availableSlot != null) {
            return availableSlot;
          }
        }
      }
      
      // Fallback: return default time
      return DateTime(
        checkDate.year,
        checkDate.month,
        checkDate.day,
        10, // 10 AM
      );
      
    } catch (e) {
      print('Error getting next available time slot: $e');
      return DateTime.now().add(RESCHEDULE_DELAY);
    }
  }
  
  // Find available time slot within a day
  DateTime? _findAvailableTimeSlot(DateTime date, List<DateTime> existingNudges) {
    final startHour = 9; // 9 AM
    final endHour = 17; // 5 PM
    final intervalHours = 2;
    
    for (int hour = startHour; hour <= endHour; hour += intervalHours) {
      final potentialTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
      );
      
      // Check if this time is taken
      bool isAvailable = true;
      for (final existingTime in existingNudges) {
        final timeDiff = potentialTime.difference(existingTime).abs();
        if (timeDiff.inHours < intervalHours) {
          isAvailable = false;
          break;
        }
      }
      
      if (isAvailable) {
        return potentialTime;
      }
    }
    
    return null;
  }
}
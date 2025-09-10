// lib/services/tagging_service.dart
import '../models/contact.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

class TaggingService {
  // Analyze call logs to suggest social circles
  static Future<List<String>> suggestTagsFromCallLogs(Contact contact, List<CallLogEntry> callLogs) async {
    List<String> suggestions = [];
    
    // Filter calls for this contact
    final contactCalls = callLogs.where((call) {
      return _normalizePhoneNumber(call.number) == _normalizePhoneNumber(contact.phoneNumber);
    }).toList();
    
    if (contactCalls.isEmpty) return suggestions;
    
    // Analyze call frequency
    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));
    final lastMonth = now.subtract(const Duration(days: 30));
    
    final weeklyCalls = contactCalls.where((call) => 
      call.timestamp! > lastWeek.millisecondsSinceEpoch
    ).length;
    
    final monthlyCalls = contactCalls.where((call) => 
      call.timestamp! > lastMonth.millisecondsSinceEpoch
    ).length;
    
    // Suggest based on call frequency
    if (weeklyCalls >= 3) {
      suggestions.add('Frequent Contact');
      suggestions.add('Inner Circle');
    } else if (monthlyCalls >= 5) {
      suggestions.add('Regular Contact');
      suggestions.add('Close Circle');
    }
    
    // Analyze call duration
    final totalDuration = contactCalls.fold(0, (sum, call) => sum + (call.duration ?? 0));
    final avgDuration = totalDuration ~/ contactCalls.length;
    
    if (avgDuration > 300) { // More than 5 minutes average
      suggestions.add('Long Conversations');
    }
    
    // Analyze call timing
    final workHourCalls = contactCalls.where((call) {
      final time = DateTime.fromMillisecondsSinceEpoch(call.timestamp!);
      return time.hour >= 9 && time.hour <= 17 && time.weekday <= 5;
    }).length;
    
    final socialHourCalls = contactCalls.length - workHourCalls;
    
    if (workHourCalls > socialHourCalls * 2) {
      suggestions.add('Work Contact');
    } else if (socialHourCalls > workHourCalls * 2) {
      suggestions.add('Personal Contact');
    }
    
    // Analyze call type (incoming/outgoing)
    final outgoingCalls = contactCalls.where((call) => call.callType == CallType.outgoing).length;
    final incomingCalls = contactCalls.where((call) => call.callType == CallType.incoming).length;
    
    if (outgoingCalls > incomingCalls * 1.5) {
      suggestions.add('You Initiate');
    } else if (incomingCalls > outgoingCalls * 1.5) {
      suggestions.add('They Initiate');
    }
    
    // Remove duplicates
    return suggestions.toSet().toList();
  }
  
  // Helper method to normalize phone numbers for comparison
  static String _normalizePhoneNumber(String? number) {
    if (number == null) return '';
    // Remove all non-digit characters
    return number.replaceAll(RegExp(r'[^0-9]'), '');
  }
  
  static List<String> suggestTags(Contact contact, List<Contact> allContacts) {
    List<String> suggestions = [];
    
    // Suggest based on interaction frequency
    DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    DateTime monthAgo = DateTime.now().subtract(const Duration(days: 30));
    
    if (contact.lastContacted.isAfter(weekAgo)) {
      suggestions.add('Frequent Contact');
    } else if (contact.lastContacted.isBefore(monthAgo)) {
      suggestions.add('Needs Reconnection');
    }
    
    // Suggest based on connection type
    if (contact.connectionType == 'Family') {
      suggestions.add('Family');
    } else if (contact.connectionType == 'Client') {
      suggestions.add('Work');
    }
    
    // Suggest VIP for important contacts
    if (contact.isVIP) {
      suggestions.add('VIP');
    }
    
    // Suggest based on social groups
    if (contact.socialGroups.isNotEmpty) {
      suggestions.addAll(contact.socialGroups);
    }
    
    // Remove duplicates
    return suggestions.toSet().toList();
  }
  
  static String suggestRelationshipDepth(Contact contact, List<CallLogEntry> callLogs) {
    // Filter calls for this contact
    final contactCalls = callLogs.where((call) {
      return _normalizePhoneNumber(call.number) == _normalizePhoneNumber(contact.phoneNumber);
    }).toList();
    
    if (contactCalls.isEmpty) {
      // Fall back to basic analysis if no call logs
      if (contact.isVIP) return 'Inner Circle';
      if (contact.connectionType == 'Family') return 'Close';
      if (contact.connectionType == 'Friend') return 'Good Friend';
      return 'Acquaintance';
    }
    
    // Analyze call frequency and duration for relationship depth
    final now = DateTime.now();
    final lastMonth = now.subtract(const Duration(days: 30));
    
    final monthlyCalls = contactCalls.where((call) => 
      call.timestamp! > lastMonth.millisecondsSinceEpoch
    ).length;
    
    final totalDuration = contactCalls.fold(0, (sum, call) => sum + (call.duration ?? 0));
    final avgDuration = totalDuration ~/ contactCalls.length;
    
    // Determine relationship depth based on call patterns
    if (monthlyCalls >= 8 && avgDuration > 600) {
      return 'Inner Circle';
    } else if (monthlyCalls >= 4 && avgDuration > 300) {
      return 'Close';
    } else if (monthlyCalls >= 2) {
      return 'Good Friend';
    } else {
      return 'Acquaintance';
    }
  }
  
  // Get call logs from device with proper permission handling
  static Future<List<CallLogEntry>> getCallLogs() async {
    try {
      // Check and request call log permission
      PermissionStatus status = await Permission.phone.status;
      
      if (!status.isGranted) {
        status = await Permission.phone.request();
        
        if (!status.isGranted) {
          // Also try contacts permission as fallback
          status = await Permission.contacts.status;
          if (!status.isGranted) {
            status = await Permission.contacts.request();
          }
        }
      }
      
      // If permission still not granted, return empty list
      if (!status.isGranted) {
        return [];
      }
      
      // Define query parameters
      const int daysBack = 90; // Get calls from last 90 days
      final DateTime now = DateTime.now();
      final DateTime from = now.subtract(const Duration(days: daysBack));
      
      // Query call logs
      final Iterable<CallLogEntry> entries = await CallLog.query(
        dateFrom: from.millisecondsSinceEpoch,
        dateTo: now.millisecondsSinceEpoch,
        // orderBy: CallLo.DESCENDING,
      );
      
      return entries.toList();
    } catch (e) {
      print('Error getting call logs: $e');
      return [];
    }
  }
  
  // Get call statistics for a specific contact
  static Future<Map<String, dynamic>> getCallStatistics(Contact contact) async {
    final callLogs = await getCallLogs();
    final contactCalls = callLogs.where((call) {
      return _normalizePhoneNumber(call.number) == _normalizePhoneNumber(contact.phoneNumber);
    }).toList();
    
    if (contactCalls.isEmpty) {
      return {
        'totalCalls': 0,
        'avgDuration': 0,
        'outgoingCalls': 0,
        'incomingCalls': 0,
        'missedCalls': 0,
        'lastCall': null,
      };
    }
    
    // Calculate statistics
    final totalDuration = contactCalls.fold(0, (sum, call) => sum + (call.duration ?? 0));
    final avgDuration = totalDuration ~/ contactCalls.length;
    
    final outgoingCalls = contactCalls.where((call) => call.callType == CallType.outgoing).length;
    final incomingCalls = contactCalls.where((call) => call.callType == CallType.incoming).length;
    final missedCalls = contactCalls.where((call) => call.callType == CallType.missed).length;
    
    // Find most recent call
    contactCalls.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
    final lastCall = contactCalls.isNotEmpty 
        ? DateTime.fromMillisecondsSinceEpoch(contactCalls.first.timestamp!)
        : null;
    
    return {
      'totalCalls': contactCalls.length,
      'avgDuration': avgDuration,
      'outgoingCalls': outgoingCalls,
      'incomingCalls': incomingCalls,
      'missedCalls': missedCalls,
      'lastCall': lastCall,
    };
  }
}
// lib/services/calendar_contact_service.dart
import 'package:device_calendar/device_calendar.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class CalendarContactService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  
  // Check and request calendar permissions
  Future<bool> hasCalendarPermission() async {
    final permission = await _deviceCalendarPlugin.hasPermissions();
    return permission.data ?? false;
  }
  
  Future<bool> requestCalendarPermission() async {
    final permissionResult = await _deviceCalendarPlugin.requestPermissions();
    return permissionResult.data ?? false;
  }
  
  // Get recurring events from calendar
  Future<List<Event>> getRecurringEvents(DateTime startDate, DateTime endDate) async {
    try {
      // First, get calendars
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        return [];
      }
      
      List<Event> allEvents = [];
      
      for (final calendar in calendarsResult.data!) {
        // Retrieve events for each calendar
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(
            startDate: startDate,
            endDate: endDate,
          ),
        );
        
        if (eventsResult.isSuccess && eventsResult.data != null) {
          // Filter for recurring events or events with specific attendees
          final recurringEvents = eventsResult.data!.where((event) {
            // Check if event is recurring or has attendees
            return event.recurrenceRule != null || 
                   (event.attendees != null && event.attendees!.isNotEmpty);
          }).toList();
          
          allEvents.addAll(recurringEvents);
        }
      }
      
      return allEvents;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting calendar events: $e');
      }
      return [];
    }
  }
  
  // Analyze calendar events to find frequent contacts
  Future<Map<String, int>> analyzeContactFrequencyFromCalendar() async {
    final Map<String, int> contactFrequency = {};
    
    try {
      // Get events from the last 6 months
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
      
      final events = await getRecurringEvents(sixMonthsAgo, now);
      
      for (final event in events) {
        // Check for attendees
        if (event.attendees != null && event.attendees!.isNotEmpty) {
          for (final attendee in event.attendees!) {
            if (attendee!.emailAddress != null && attendee.emailAddress!.isNotEmpty) {
              final email = attendee.emailAddress!.toLowerCase();
              contactFrequency[email] = (contactFrequency[email] ?? 0) + 1;
            }
            
            if (attendee.name != null && attendee.name!.isNotEmpty) {
              final name = attendee.name!.toLowerCase();
              contactFrequency[name] = (contactFrequency[name] ?? 0) + 1;
            }
          }
        }
        
        // Check event title for names (for birthdays, meetings)
        if (event.title != null && event.title!.isNotEmpty) {
          final title = event.title!.toLowerCase();
          
          // Look for birthday indicators
          if (title.contains("birthday") || 
              title.contains("bday") || 
              title.contains("anniversary")) {
            
            // Extract names from birthday events
            final nameMatch = RegExp(r"([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)'s").firstMatch(title);
            if (nameMatch != null && nameMatch.group(1) != null) {
              final name = nameMatch.group(1)!.toLowerCase();
              contactFrequency[name] = (contactFrequency[name] ?? 0) + 3; // Higher weight for birthdays
            }
          }
          
          // Look for meeting/recurring event indicators
          if (event.recurrenceRule != null) {
            // Extract names from meeting titles
            final meetingPatterns = [
              "with", "meeting with", "call with", "chat with", 
              "sync with", "catch up with"
            ];
            
            for (final pattern in meetingPatterns) {
              if (title.contains(pattern)) {
                final startIndex = title.indexOf(pattern) + pattern.length;
                if (startIndex < title.length) {
                  final namePart = title.substring(startIndex).trim();
                  final name = namePart.split(' ').first;
                  if (name.isNotEmpty && name.length > 2) { // Simple validation
                    contactFrequency[name] = (contactFrequency[name] ?? 0) + 2;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing calendar frequency: $e');
      }
    }
    
    return contactFrequency;
  }
  
  // Get birthday contacts from calendar
  Future<List<String>> getBirthdayContacts() async {
    final List<String> birthdayContacts = [];
    
    try {
      final now = DateTime.now();
      final nextYear = DateTime(now.year + 1, now.month, now.day);
      
      final events = await getRecurringEvents(now, nextYear);
      
      for (final event in events) {
        if (event.title != null && event.title!.isNotEmpty) {
          final title = event.title!.toLowerCase();
          
          // Check for birthday indicators
          if (title.contains("birthday") || 
              title.contains("bday") || 
              title.contains("birth") && title.contains("day")) {
            
            // Extract name from birthday event title
            final nameMatch = RegExp(r"([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)'s").firstMatch(title);
            if (nameMatch != null && nameMatch.group(1) != null) {
              birthdayContacts.add(nameMatch.group(1)!);
            } else {
              // Try to extract name directly
              final words = title.split(' ');
              for (final word in words) {
                if (word.length > 2 && 
                    word[0].toUpperCase() == word[0] && 
                    !word.contains("birthday") && 
                    !word.contains("bday") &&
                    !word.contains("anniversary")) {
                  birthdayContacts.add(word);
                  break;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting birthday contacts: $e');
      }
    }
    
    return birthdayContacts;
  }
}
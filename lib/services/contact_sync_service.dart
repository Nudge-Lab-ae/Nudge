// lib/services/contact_sync_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import '../models/contact.dart';
import './api_service.dart';

class ContactSyncService {
  final ApiService apiService;

  ContactSyncService({required this.apiService});

  Future<Map<String, dynamic>> importDeviceContacts({
    required Function(int processed, int total) onProgress,
    int limit = 0,
    bool useSmartFilter = true,
  }) async {
    try {
      // Check and request permission using flutter_contacts
      print('stage1 - Checking contacts permission');
      
      final permissionStatus = await fContacts.FlutterContacts.requestPermission();
      print('Contacts permission status: $permissionStatus');
      
      if (!permissionStatus) {
        // If permission was denied, check if we need to guide to settings
        final status = await Permission.contacts.status;
        print('Detailed permission status: $status');
        
        if (status.isPermanentlyDenied) {
          return {
            'success': false,
            'message': 'Contacts access is disabled. Please enable it in Settings to import your contacts.',
            'importedCount': 0,
            'needsSettings': true
          };
        } else {
          return {
            'success': false,
            'message': 'Contacts permission is required to import your contacts',
            'importedCount': 0
          };
        }
      }

      print('stage2 - Permission granted, getting contacts');
      
      // Get device contacts using flutter_contacts
      final deviceContacts = await fContacts.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withThumbnail: true,
      );
      
      print('Found ${deviceContacts.length} contacts on device');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'User not logged in',
          'importedCount': 0
        };
      }

      print('stage3 - Getting existing contacts from Firestore');
      
      // Get existing contacts to avoid duplicates
      final existingContacts = await _getExistingContacts(currentUser.uid);
      final existingPhoneNumbers = existingContacts.map((c) => _normalizePhoneNumber(c.phoneNumber)).toSet();
      final existingEmails = existingContacts.map((c) => c.email.toLowerCase()).toSet();

      // Apply smart filtering if enabled
      List<fContacts.Contact> contactsToImport = deviceContacts;
      if (useSmartFilter) {
        contactsToImport = await _applySmartFiltering(contactsToImport);
      }
      
      // Filter out already imported contacts
      contactsToImport = contactsToImport.where((deviceContact) {
        // Check if any phone number matches
        final hasMatchingPhone = deviceContact.phones.any((phone) {
          return existingPhoneNumbers.contains(_normalizePhoneNumber(phone.normalizedNumber));
        });
        
        // Check if any email matches
        final hasMatchingEmail = deviceContact.emails.any((email) {
          return existingEmails.contains(email.address.toLowerCase());
        });
        
        return !hasMatchingPhone && !hasMatchingEmail;
      }).toList();
      
      // Apply limit if specified
      if (limit > 0 && contactsToImport.length > limit) {
        contactsToImport = contactsToImport.sublist(0, limit);
      }
      
      int importedCount = 0;
      int processedCount = 0;
      int totalContacts = contactsToImport.length;
      
      print('After filtering: $totalContacts contacts to import');
      
      // Get reference to user's contacts subcollection
      final contactsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts');

      // If no contacts to import after filtering
      if (totalContacts == 0) {
        return {
          'success': true,
          'message': 'No new contacts to import - all contacts already exist in Nudge',
          'importedCount': 0
        };
      }

      // Process contacts in batches
      const batchSize = 400;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var deviceContact in contactsToImport) {
        processedCount++;
        
        // Update progress
        onProgress(processedCount, totalContacts);
        
        // Skip contacts without names
        if ((deviceContact.name.first.isEmpty && deviceContact.name.last.isEmpty)) {
          continue;
        }

        // Create display name
        final displayName = _getDisplayName(deviceContact);
        
        // Create Nudge contact from device contact
        Contact nudgeContact = Contact(
          id: '', // Will be generated by Firestore
          name: displayName,
          phoneNumber: deviceContact.phones.isNotEmpty 
              ? deviceContact.phones.first.normalizedNumber 
              : '',
          email: deviceContact.emails.isNotEmpty 
              ? deviceContact.emails.first.address 
              : '',
          connectionType: 'Contact',
          frequency: 2,
          period: 'Annually',
          socialGroups: [],
          notes: '',
          imageUrl: deviceContact.photoOrThumbnail != null
              ? 'data:image/png;base64,${String.fromCharCodes(deviceContact.photoOrThumbnail!)}' 
              : '',
          lastContacted: DateTime.now(),
          isVIP: false,
          priority: 3,
          tags: [],
          interactionHistory: {},
        );

        // Add to batch
        final docRef = contactsRef.doc();
        batch.set(docRef, nudgeContact.toMap());
        importedCount++;

        // Commit batch when we reach batch size
        if (importedCount % batchSize == 0) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
        }
      }

      // Commit any remaining operations
      if (importedCount % batchSize != 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'message': 'Successfully imported $importedCount contacts',
        'importedCount': importedCount
      };
    } catch (e, stack) {
      print('Error importing contacts: $e');
      print('Stack trace: $stack');
      return {
        'success': false,
        'message': 'Failed to import contacts: $e',
        'importedCount': 0
      };
    }
  }

Future<Map<String, dynamic>> importFromContactPicker({
  required List<fContacts.Contact> pickedContacts,
  required Function(int processed, int total) onProgress,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return {
        'success': false,
        'message': 'User not logged in',
        'importedCount': 0
      };
    }

    // Get existing contacts to avoid duplicates
    final existingContacts = await _getExistingContacts(currentUser.uid);
    final existingPhoneNumbers =
        existingContacts.map((c) => _normalizePhoneNumber(c.phoneNumber)).toSet();
    final existingEmails =
        existingContacts.map((c) => c.email.toLowerCase()).toSet();

    int importedCount = 0;
    int processedCount = 0;
    int totalContacts = pickedContacts.length;

    // Filter out already imported contacts
    final contactsToImport = pickedContacts.where((deviceContact) {
      final hasMatchingPhone = deviceContact.phones.any((phone) {
        return existingPhoneNumbers.contains(_normalizePhoneNumber(phone.normalizedNumber));
      });
      final hasMatchingEmail = deviceContact.emails.any((email) {
        return existingEmails.contains(email.address.toLowerCase());
      });
      return !hasMatchingPhone && !hasMatchingEmail;
    }).toList();

    if (contactsToImport.isEmpty) {
      return {
        'success': true,
        'message': 'All selected contacts already exist in Nudge',
        'importedCount': 0
      };
    }

    // Reference to Firestore subcollection
    final contactsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts');

    for (var deviceContact in contactsToImport) {
      processedCount++;
      onProgress(processedCount, totalContacts);

      if ((deviceContact.name.first.isEmpty && deviceContact.name.last.isEmpty)) {
        continue;
      }

      final displayName = _getDisplayName(deviceContact);

      Contact nudgeContact = Contact(
        id: '',
        name: displayName,
        phoneNumber: deviceContact.phones.isNotEmpty
            ? deviceContact.phones.first.normalizedNumber
            : '',
        email: deviceContact.emails.isNotEmpty
            ? deviceContact.emails.first.address
            : '',
        connectionType: 'Contact',
        frequency: 2,
        period: 'Monthly',
        socialGroups: [],
        notes: '',
        imageUrl: deviceContact.photoOrThumbnail != null
            ? 'data:image/png;base64,${String.fromCharCodes(deviceContact.photoOrThumbnail!)}'
            : '',
        lastContacted: DateTime.now(),
        isVIP: false,
        priority: 3,
        tags: [],
        interactionHistory: {},
      );

      await contactsRef.add(nudgeContact.toMap());
      importedCount++;
    }

    return {
      'success': true,
      'message': 'Successfully imported $importedCount contacts from picker',
      'importedCount': importedCount
    };
  } catch (e, stack) {
    print('Error in contact picker: $e');
    print('Stack trace: $stack');
    return {
      'success': false,
      'message': 'Failed to import contacts from picker: $e',
      'importedCount': 0
    };
  }
}

   List<fContacts.Contact> _applyIOSSmartFiltering(List<fContacts.Contact> contacts) {
    final scoredContacts = contacts.map((contact) {
      int score = 0;
      
      // Contacts with photos get higher priority
      if (contact.photoOrThumbnail != null) {
        score += 3;
      }
      
      // Contacts with phone numbers get priority
      if (contact.phones.isNotEmpty) {
        score += 2;
      }
      
      // Contacts with both first and last names get priority
      if (contact.name.first.isNotEmpty && contact.name.last.isNotEmpty) {
        score += 2;
      }
      
      // Contacts with emails get some priority
      if (contact.emails.isNotEmpty) {
        score += 1;
      }
      
      // Calendar simulation: Contacts with anniversary dates
      if (contact.events.any((event) => event.label.name.toLowerCase().contains('anniversary'))) {
        score += 3;
      }
      
      // Calendar simulation: Work contacts (organization field)
      if (contact.organizations.isNotEmpty) {
        score += 2;
      }
      
      // Calendar simulation: Contacts with addresses (potential for local meetings)
      if (contact.addresses.isNotEmpty) {
        score += 1;
      }
      
      // Calendar simulation: Recent contacts (based on modified date)
      // if (contact.lastModified != null) {
      //   final daysSinceModified = DateTime.now().difference(contact.lastModified!).inDays;
      //   if (daysSinceModified <= 30) score += 2;
      //   else if (daysSinceModified <= 90) score += 1;
      // }

      return {'contact': contact, 'score': score};
    }).toList();
    
    scoredContacts.sort((a, b) {
      final scoreA = a['score'] as int;
      final scoreB = b['score'] as int;
      return scoreB.compareTo(scoreA);
    });
    
    return scoredContacts.map((item) => item['contact'] as fContacts.Contact).toList();
  }

  // Helper method to get display name
  String _getDisplayName(fContacts.Contact deviceContact) {
    final name = deviceContact.name;
    if (name.first.isNotEmpty && name.last.isNotEmpty) {
      return '${name.first} ${name.last}';
    } else if (name.first.isNotEmpty) {
      return name.first;
    } else if (name.last.isNotEmpty) {
      return name.last;
    } else if (deviceContact.displayName.isNotEmpty) {
      return deviceContact.displayName;
    } else {
      return 'Unknown';
    }
  }

  // Get existing contacts from Firestore
  Future<List<Contact>> _getExistingContacts(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();
      
      return querySnapshot.docs.map((doc) {
        return Contact.fromMap(doc.data() ..['id'] = doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching existing contacts: $e');
      return [];
    }
  }

  // Apply smart filtering based on call log frequency
  Future<List<fContacts.Contact>> _applySmartFiltering(List<fContacts.Contact> contacts) async {
    try {
      // For iOS, we can't access call logs due to privacy restrictions
      // So we'll use a different approach for iOS vs Android
      if (Platform.isIOS) {
        print('Using iOS-compatible smart filtering');
        return _applyIOSSmartFiltering(contacts);
      } else {
        print('Using Android call log-based smart filtering');
        return await _applyAndroidCallLogFiltering(contacts);
      }
    } catch (e) {
      print('Error applying smart filter: $e');
      return contacts;
    }
  }

  // iOS-compatible smart filtering (no call log access)
  // List<fContacts.Contact> _applyIOSSmartFiltering(List<fContacts.Contact> contacts) {
  //   final scoredContacts = contacts.map((contact) {
  //     int score = 0;
      
  //     // Contacts with photos get higher priority
  //     if (contact.photoOrThumbnail != null) {
  //       score += 3;
  //     }
      
  //     // Contacts with phone numbers get priority
  //     if (contact.phones.isNotEmpty) {
  //       score += 2;
  //     }
      
  //     // Contacts with both first and last names get priority
  //     if (contact.name.first.isNotEmpty && contact.name.last.isNotEmpty) {
  //       score += 2;
  //     }
      
  //     // Contacts with emails get some priority
  //     if (contact.emails.isNotEmpty) {
  //       score += 1;
  //     }
      
  //     return {'contact': contact, 'score': score};
  //   }).toList();
    
  //   // FIX: Add null safety check and proper casting
  //   scoredContacts.sort((a, b) {
  //     final scoreA = a['score'] as int;
  //     final scoreB = b['score'] as int;
  //     return scoreB.compareTo(scoreA); // Sort descending by score
  //   });
    
  //   return scoredContacts.map((item) => item['contact'] as fContacts.Contact).toList();
  // }

  //  Future<List<fContacts.Contact>> _applyCalendarBasedFiltering(List<fContacts.Contact> contacts) async {
  //   try {
  //     // Simulate calendar event frequency analysis
  //     final scoredContacts = contacts.map((contact) {
  //       int calendarScore = 0;
        
  //       // Birthday events (high priority recurring events)
       
  //       // Anniversary events
  //       final hasAnniversary = contact.events.any((event) => 
  //         event.label.name.toLowerCase().contains('anniversary'));
  //       if (hasAnniversary) {
  //         calendarScore += 4;
  //       }
        
  //       // Work-related contacts (potential for regular meetings)
  //       if (contact.organizations.isNotEmpty) {
  //         calendarScore += 3;
  //       }
        
  //       // Contacts with notes suggesting regular interaction
  //       if (contact.notes.isNotEmpty) {
  //         final notes = contact.notes[0].note.toLowerCase();
  //         if (notes.contains('meet') || notes.contains('lunch') || notes.contains('dinner') || 
  //             notes.contains('coffee') || notes.contains('weekly') || notes.contains('monthly')) {
  //           calendarScore += 2;
  //         }
  //       }
        
  //       // Contacts in same city/region (potential for local events)
  //       if (contact.addresses.isNotEmpty) {
  //         calendarScore += 1;
  //       }

  //       return {
  //         'contact': contact, 
  //         'calendarScore': calendarScore,
  //         'totalScore': calendarScore
  //       };
  //     }).toList();
      
  //     // Sort by calendar score
  //     scoredContacts.sort((a, b) {
  //       final scoreA = a['calendarScore'] as int;
  //       final scoreB = b['calendarScore'] as int;
  //       return scoreB.compareTo(scoreA);
  //     });
      
  //     print('Calendar-based filtering completed. Top contact calendar scores:');
  //     for (int i = 0; i < (scoredContacts.length > 5 ? 5 : scoredContacts.length); i++) {
  //       final item = scoredContacts[i];
  //       final contact = item['contact'] as fContacts.Contact;
  //       print('${contact.displayName}: Calendar Score ${item['calendarScore']}');
  //     }
      
  //     return scoredContacts.map((item) => item['contact'] as fContacts.Contact).toList();
  //   } catch (e) {
  //     print('Error in calendar-based filtering: $e');
  //     return _applyIOSSmartFiltering(contacts); // Fallback
  //   }
  // }


  // Android call log-based filtering
  Future<List<fContacts.Contact>> _applyAndroidCallLogFiltering(List<fContacts.Contact> contacts) async {
    try {
      // Request call log permission
      var callLogStatus = await Permission.phone.status;
      if (!callLogStatus.isGranted) {
        callLogStatus = await Permission.phone.request();
        if (!callLogStatus.isGranted) {
          print('Call log permission denied, falling back to iOS filtering');
          return _applyIOSSmartFiltering(contacts);
        }
      }

      // Get call log entries
      final Iterable<CallLogEntry> entries = await CallLog.get();
      
      // Create a map of phone numbers to call count and last call timestamp
      final Map<String, int> callCountMap = {};
      final Map<String, int> lastCallMap = {};
      
      for (final entry in entries) {
        if (entry.number != null) {
          final normalizedNumber = _normalizePhoneNumber(entry.number!);
          callCountMap[normalizedNumber] = (callCountMap[normalizedNumber] ?? 0) + 1;
          
          // Track the most recent call timestamp
          if (entry.timestamp != null) {
            final currentLastCall = lastCallMap[normalizedNumber] ?? 0;
            if (entry.timestamp! > currentLastCall) {
              lastCallMap[normalizedNumber] = entry.timestamp!;
            }
          }
        }
      }
      
      // Score contacts based on call frequency and recency
      final scoredContacts = contacts.map((contact) {
        int score = 0;
        int totalCallCount = 0;
        int lastCallTimestamp = 0;
        
        // Calculate call-based score for each phone number in the contact
        for (final phone in contact.phones) {
          final normalizedNumber = _normalizePhoneNumber(phone.normalizedNumber);
          final callCount = callCountMap[normalizedNumber] ?? 0;
          final lastCall = lastCallMap[normalizedNumber] ?? 0;
          
          totalCallCount += callCount;
          
          // Use the most recent call timestamp among all phone numbers
          if (lastCall > lastCallTimestamp) {
            lastCallTimestamp = lastCall;
          }
        }
        
        // Score based on call frequency (primary factor)
        if (totalCallCount > 50) score += 10;
        else if (totalCallCount > 20) score += 8;
        else if (totalCallCount > 10) score += 6;
        else if (totalCallCount > 5) score += 4;
        else if (totalCallCount > 0) score += 2;
        
        // Score based on call recency (secondary factor)
        if (lastCallTimestamp > 0) {
          final daysSinceLastCall = (DateTime.now().millisecondsSinceEpoch - lastCallTimestamp) ~/ (1000 * 60 * 60 * 24);
          if (daysSinceLastCall <= 7) score += 5;    // Called in last week
          else if (daysSinceLastCall <= 30) score += 3; // Called in last month
          else if (daysSinceLastCall <= 90) score += 1; // Called in last 3 months
        }
        
        // Bonus points for contacts with photos
        if (contact.photoOrThumbnail != null) {
          score += 2;
        }
        
        // Bonus points for contacts with complete names
        if (contact.name.first.isNotEmpty && contact.name.last.isNotEmpty) {
          score += 2;
        }
        
        return {
          'contact': contact, 
          'score': score,
          'callCount': totalCallCount,
          'lastCall': lastCallTimestamp
        };
      }).toList();
      
      // Sort by score descending (highest call frequency first)
      scoredContacts.sort((a, b) {
        final scoreA = a['score'] as int;
        final scoreB = b['score'] as int;
        
        // Primary sort by score
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        
        // Secondary sort by call count if scores are equal
        final callCountA = a['callCount'] as int;
        final callCountB = b['callCount'] as int;
        return callCountB.compareTo(callCountA);
      });
      
      print('Smart filtering completed. Top contact scores:');
      for (int i = 0; i < (scoredContacts.length > 5 ? 5 : scoredContacts.length); i++) {
        final item = scoredContacts[i];
        print('${(item['contact'] as fContacts.Contact).displayName}: Score ${item['score']}, Calls: ${item['callCount']}');
      }
      
      return scoredContacts.map((item) => item['contact'] as fContacts.Contact).toList();
    } catch (e, stack) {
      print('Error in Android call log filtering: $e');
      print('Stack trace: $stack');
      return _applyIOSSmartFiltering(contacts); // Fallback
    }
  }

  // Helper method to normalize phone numbers for comparison
  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
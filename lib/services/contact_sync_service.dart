// lib/services/contact_sync_service.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import 'package:nudge/models/social_group.dart';
import 'package:nudge/services/calendar_contact_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/contact.dart';
import './api_service.dart';

class ContactSyncService {
  final ApiService apiService;
  final FirebaseStorage storage;
  final CalendarContactService _calendarService = CalendarContactService();

  ContactSyncService({required this.apiService}) : storage = FirebaseStorage.instance;

  Future<Map<String, int>> getContactPriorityFromCalendar(
    List<fContacts.Contact> deviceContacts,
  ) async {
    final Map<String, int> contactScores = {};
    
    // Get frequency data from calendar
    final calendarFrequency = await _calendarService.analyzeContactFrequencyFromCalendar();
    final birthdayContacts = await _calendarService.getBirthdayContacts();
    
    // Score each contact based on calendar data
    for (final contact in deviceContacts) {
      int score = 0;
      
      // Check emails against calendar frequency
      for (final email in contact.emails) {
        final emailKey = email.address.toLowerCase();
        if (calendarFrequency.containsKey(emailKey)) {
          score += calendarFrequency[emailKey]! * 10; // Higher weight for exact email matches
        }
      }
      
      // Check name against calendar frequency
      final name = contact.displayName.toLowerCase();
      if (calendarFrequency.containsKey(name)) {
        score += calendarFrequency[name]! * 5;
      }
      
      // Check if contact is a birthday contact (higher priority)
      for (final birthdayName in birthdayContacts) {
        if (name.contains(birthdayName.toLowerCase()) || 
            contact.displayName.contains(birthdayName)) {
          score += 50; // High priority for birthday contacts
          break;
        }
      }
      
      // Check if contact appears in multiple email domains (professional contacts)
      final emailDomains = contact.emails.map((e) {
        final parts = e.address.split('@');
        return parts.length > 1 ? parts[1].toLowerCase() : '';
      }).where((domain) => domain.isNotEmpty).toSet();
      
      if (emailDomains.length > 1) {
        score += 20; // Professional contacts with multiple domains
      }
      
      // Check for work-related details
      if (contact.organizations.isNotEmpty) {
        score += 15; // Work contacts
      }
      
      if (score > 0) {
        contactScores[contact.id] = score;
      }
    }
    
    return contactScores;
  }
  
  Future<Map<String, dynamic>> importDeviceContacts({
    required Function(int processed, int total) onProgress,
    required SocialGroup group,
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
        print('Applying smart filtering...');
        contactsToImport = await _applySmartFiltering(contactsToImport, limit);
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
        
        // Upload contact photo if exists and get download URL
        String? imageUrl;
        if (deviceContact.photoOrThumbnail != null && deviceContact.photoOrThumbnail!.isNotEmpty) {
          try {
            imageUrl = await _uploadContactPhoto(
              photoData: deviceContact.photoOrThumbnail!,
              userId: currentUser.uid,
              contactName: displayName,
            );
            print('Uploaded photo for contact: $displayName');
          } catch (e) {
            print('Failed to upload photo for contact $displayName: $e');
            // Continue without photo if upload fails
          }
        }
        
        // Extract birthday and anniversary if available
        DateTime? birthday = _extractBirthday(deviceContact);
        DateTime? anniversary = _extractAnniversary(deviceContact);
        
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
          connectionType: group.name,
          frequency: group.frequency,
          period: group.period,
          socialGroups: [group.name], // Add to the selected group
          notes: '',
          imageUrl: imageUrl ?? '', // Store Firebase Storage URL or empty string
          lastContacted: DateTime.now(),
          isVIP: false,
          priority: 3,
          tags: [],
          interactionHistory: {},
          birthday: birthday,
          anniversary: anniversary,
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
        'message': 'Successfully imported contacts',
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

  /// Uploads contact photo to Firebase Storage and returns download URL
  Future<String?> _uploadContactPhoto({
    required Uint8List photoData,
    required String userId,
    required String contactName,
  }) async {
    try {
      // Sanitize contact name for filename
      final sanitizedName = contactName
          .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters
          .replaceAll(RegExp(r'\s+'), '_')     // Replace spaces with underscores
          .toLowerCase();
      
      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'contact_photo_${sanitizedName}_$timestamp.jpg';
      
      // Define storage path
      final storagePath = 'users/$userId/contact_photos/$filename';
      
      // Create metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // or 'image/png' if needed
        customMetadata: {
          'contactName': contactName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Upload to Firebase Storage
      final ref = storage.ref().child(storagePath);
      await ref.putData(photoData, metadata);
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading contact photo: $e');
      return null;
    }
  }

  DateTime? _extractBirthday(fContacts.Contact contact) {
    try {
      final birthdayEvent = contact.events.firstWhere(
        (e) => e.label.name.toLowerCase().contains('birthday'),
      );
      return DateTime(birthdayEvent.year!, birthdayEvent.month, birthdayEvent.day);
    } catch (e) {
      return null;
    }
  }

  DateTime? _extractAnniversary(fContacts.Contact contact) {
    try {
      final anniversaryEvent = contact.events.firstWhere(
        (e) => e.label.name.toLowerCase().contains('anniversary'),
      );
      return DateTime(anniversaryEvent.year!, anniversaryEvent.month, anniversaryEvent.day);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> importContactsWithGroup({
    required List<fContacts.Contact> pickedContacts,
    required String groupId,
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
      final existingPhoneNumbers = existingContacts.map((c) => _normalizePhoneNumber(c.phoneNumber)).toSet();
      final existingEmails = existingContacts.map((c) => c.email.toLowerCase()).toSet();

      int importedCount = 0;
      int processedCount = 0;
      int totalContacts = pickedContacts.length;

      // Filter out already imported contacts
      final contactsToImport = pickedContacts.where((deviceContact) {
        final hasMatchingPhone = deviceContact.phones.any((phone) {
          return existingPhoneNumbers.contains(_normalizePhoneNumber(phone.number));
          // return false;
        });
        final hasMatchingEmail = deviceContact.emails.any((email) {
          return existingEmails.contains(email.address.toLowerCase());
          // return false;
        });
        return !hasMatchingPhone && !hasMatchingEmail;
      }).toList();

      print('picked contacts length is'); print(pickedContacts.length);
      if (pickedContacts.isNotEmpty) {
        print(pickedContacts[0].name);
      }
      print('existing phone numbers are'); print(existingPhoneNumbers);
      print('existing emails are '); print(existingEmails);

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
        
        // Extract birthday and anniversary
        DateTime? birthday = _extractBirthday(deviceContact);
        DateTime? anniversary = _extractAnniversary(deviceContact);
        
        // Upload contact photo if exists
        String? imageUrl;
        if (deviceContact.photoOrThumbnail != null && deviceContact.photoOrThumbnail!.isNotEmpty) {
          try {
            imageUrl = await _uploadContactPhoto(
              photoData: deviceContact.photoOrThumbnail!,
              userId: currentUser.uid,
              contactName: displayName,
            );
          } catch (e) {
            print('Failed to upload photo for contact $displayName: $e');
          }
        }

        print('phone number is'); print(deviceContact.phones);
        if (deviceContact.phones.isNotEmpty){
          print(deviceContact.phones.first.number);
        }

        Contact nudgeContact = Contact(
          id: '',
          name: displayName,
          phoneNumber: deviceContact.phones.isNotEmpty
              ? deviceContact.phones.first.number
              : '',
          email: deviceContact.emails.isNotEmpty
              ? deviceContact.emails.first.address
              : '',
          connectionType: groupId,
          frequency: 2,
          period: 'Monthly',
          socialGroups: [groupId], // Assign to the selected group
          notes: '',
          imageUrl: imageUrl ?? '', // Use Firebase Storage URL
          lastContacted: DateTime.now(),
          isVIP: false,
          priority: 3,
          tags: [],
          interactionHistory: {},
          birthday: birthday,
          anniversary: anniversary,
        );

        await contactsRef.add(nudgeContact.toMap());
        importedCount++;
      }

      return {
        'success': true,
        'message': 'Successfully imported contacts to group',
        'importedCount': importedCount
      };
    } catch (e, stack) {
      print('Error in contact import with group: $e');
      print('Stack trace: $stack');
      return {
        'success': false,
        'message': 'Failed to import contacts: $e',
        'importedCount': 0
      };
    }
  }

  String generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // Updated importFromContactPicker method with better phone number handling
  Future<Map<String, dynamic>> importFromContactPicker({
    required List<fContacts.Contact> pickedContacts,
    required String groupId, 
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
      
      // Create a map of existing phone numbers for quick lookup
      final existingPhoneNumbers = existingContacts
          .map((c) => c.phoneNumber)
          .where((phone) => phone.isNotEmpty)
          .toList();
      
      final existingEmails = existingContacts
          .map((c) => c.email.toLowerCase())
          .where((email) => email.isNotEmpty)
          .toSet();

      int importedCount = 0;
      int processedCount = 0;
      int totalContacts = pickedContacts.length;

      // Filter out already imported contacts with improved matching
      final contactsToImport = pickedContacts.where((deviceContact) {
        // Check if any phone number matches using the improved _phoneNumbersMatch method
        bool hasMatchingPhone = false;
        for (final phone in deviceContact.phones) {
          // Try multiple phone number formats
          final phoneVariations = <String>[
            phone.number, // Raw number as stored
            phone.normalizedNumber, // Normalized version
            _extractPhoneNumber(phone.number), // Custom extraction
          ].where((p) => p.isNotEmpty).toSet(); // Remove duplicates
          
          for (final devicePhone in phoneVariations) {
            for (final existingPhone in existingPhoneNumbers) {
              if (_phoneNumbersMatch(devicePhone, existingPhone)) {
                hasMatchingPhone = true;
                break;
              }
            }
            if (hasMatchingPhone) break;
          }
          if (hasMatchingPhone) break;
        }
        
        // Check if any email matches
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

      List <Contact> theImportedContacts = [];

      for (var deviceContact in contactsToImport) {
        processedCount++;
        onProgress(processedCount, totalContacts);

        if ((deviceContact.name.first.isEmpty && deviceContact.name.last.isEmpty)) {
          continue;
        }

        final displayName = _getDisplayName(deviceContact);
        
        // Extract birthday and anniversary
        DateTime? birthday = _extractBirthday(deviceContact);
        DateTime? anniversary = _extractAnniversary(deviceContact);
        
        // Upload contact photo if exists
        String? imageUrl;
        if (deviceContact.photoOrThumbnail != null && deviceContact.photoOrThumbnail!.isNotEmpty) {
          try {
            imageUrl = await _uploadContactPhoto(
              photoData: deviceContact.photoOrThumbnail!,
              userId: currentUser.uid,
              contactName: displayName,
            );
          } catch (e) {
            print('Failed to upload photo for contact $displayName: $e');
          }
        }

        // IMPROVED: Get the best phone number with multiple fallback options
        String primaryPhoneNumber = await _getBestPhoneNumber(deviceContact);
        
        // Get the best email
        String primaryEmail = _getBestEmail(deviceContact);

        print('Importing contact: $displayName - Phone: $primaryPhoneNumber - Email: $primaryEmail');

        String contactId = generateRandomId(16) + displayName.substring(0, 4);


        Contact nudgeContact = Contact(
          id: contactId,
          name: displayName,
          phoneNumber: primaryPhoneNumber,
          email: primaryEmail,
          connectionType: groupId,
          frequency: 2,
          period: 'Monthly',
          socialGroups: [groupId], // Add to the selected group
          notes: '',
          imageUrl: imageUrl ?? '', // Use Firebase Storage URL
          lastContacted: DateTime.now(),
          isVIP: false,
          priority: 3,
          tags: [],
          interactionHistory: {},
          birthday: birthday,
          anniversary: anniversary,
        );

        await contactsRef.doc(contactId).set(nudgeContact.toMap());
        importedCount++;
        theImportedContacts.add(nudgeContact);
      }

      return {
        'success': true,
        'message': 'Successfully imported contacts from picker',
        'importedCount': importedCount,
        'theImportedContacts': theImportedContacts
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

  // New helper method to extract phone number from various formats
  String _extractPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If we have digits, return them
    if (digits.isNotEmpty) {
      return digits;
    }
    
    // If no digits found, try to clean the original string
    String cleaned = phoneNumber
        .replaceAll(RegExp(r'[^\d\+]'), '') // Keep digits and plus sign
        .trim();
    
    return cleaned;
  }

  // New method to get the best available phone number
  Future<String> _getBestPhoneNumber(fContacts.Contact deviceContact) async {
    if (deviceContact.phones.isEmpty) {
      return '';
    }
    
    // Priority 1: Try to find a mobile number
    for (final phone in deviceContact.phones) {
      final label = phone.label.name.toLowerCase();
      if (label.contains('mobile') || label.contains('cell') || label.contains('iphone')) {
        final extracted = _extractPhoneNumber(phone.number);
        if (extracted.isNotEmpty) return extracted;
      }
    }
    
    // Priority 2: Try to find a work number
    for (final phone in deviceContact.phones) {
      final label = phone.label.name.toLowerCase();
      if (label.contains('work') || label.contains('office') || label.contains('business')) {
        final extracted = _extractPhoneNumber(phone.number);
        if (extracted.isNotEmpty) return extracted;
      }
    }
    
    // Priority 3: Try to find a home number
    for (final phone in deviceContact.phones) {
      final label = phone.label.name.toLowerCase();
      if (label.contains('home') || label.contains('personal')) {
        final extracted = _extractPhoneNumber(phone.number);
        if (extracted.isNotEmpty) return extracted;
      }
    }
    
    // Priority 4: Try all phones in order, using multiple extraction methods
    for (final phone in deviceContact.phones) {
      // Try multiple sources in order of reliability
      final possibleNumbers = <String>[
        // First try the raw number
        phone.number,
        
        // Then try normalized number
        phone.normalizedNumber,
        
        // Then try custom extraction from raw number
        _extractPhoneNumber(phone.number),
        
        // Finally try custom extraction from normalized number
        phone.normalizedNumber.isNotEmpty ? _extractPhoneNumber(phone.normalizedNumber) : '',
      ];
      
      for (final possibleNumber in possibleNumbers) {
        if (possibleNumber.isNotEmpty) {
          final cleaned = _extractPhoneNumber(possibleNumber);
          if (cleaned.isNotEmpty && cleaned.length >= 7) { // Valid phone number should have at least 7 digits
            return cleaned;
          }
        }
      }
    }
    
    // Last resort: return whatever we can get from the first phone
    if (deviceContact.phones.isNotEmpty) {
      return _extractPhoneNumber(deviceContact.phones.first.number);
    }
    
    return '';
  }

  // New method to get the best email
  String _getBestEmail(fContacts.Contact deviceContact) {
    if (deviceContact.emails.isEmpty) {
      return '';
    }
    
    // Priority 1: Try to find a personal/home email
    for (final email in deviceContact.emails) {
      final label = email.label.name.toLowerCase();
      if (label.contains('personal') || label.contains('home')) {
        return email.address;
      }
    }
    
    // Priority 2: Try to find a work email
    for (final email in deviceContact.emails) {
      final label = email.label.name.toLowerCase();
      if (label.contains('work') || label.contains('business') || label.contains('office')) {
        return email.address;
      }
    }
    
    // Priority 3: Return the first email
    return deviceContact.emails.first.address;
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

  // Apply smart filtering based on platform
  Future<List<fContacts.Contact>> _applySmartFiltering(
    List<fContacts.Contact> contacts, 
    int limit
  ) async {
    try {
      if (Platform.isIOS) {
        print('Using iOS calendar-based smart filtering');
        return await _getSmartFilteredContactsIOS(contacts, limit);
      } else {
        print('Using Android call log-based smart filtering');
        return await _getSmartFilteredContactsAndroid(contacts, limit);
      }
    } catch (e) {
      print('Error applying smart filter: $e');
      return _getFallbackSmartContacts(contacts, limit);
    }
  }

  Future<List<fContacts.Contact>> _getSmartFilteredContactsIOS(
      List<fContacts.Contact> deviceContacts,
      int limit,
    ) async {
      try {
        // Request calendar permission
        final hasPermission = await _calendarService.hasCalendarPermission();
        if (!hasPermission) {
          final granted = await _calendarService.requestCalendarPermission();
          if (!granted) {
            // Fallback to simple filtering if no calendar permission
            print('Calendar permission not granted, using fallback');
            return _getFallbackSmartContacts(deviceContacts, limit);
          }
        }
        
        print('Getting contact priority from calendar...');
        // Get contact priority scores from calendar
        final priorityScores = await getContactPriorityFromCalendar(deviceContacts);
        print('Found priority scores for ${priorityScores.length} contacts');
        
        // Sort contacts by priority score (highest first)
        deviceContacts.sort((a, b) {
          final scoreA = priorityScores[a.id] ?? 0;
          final scoreB = priorityScores[b.id] ?? 0;
          return scoreB.compareTo(scoreA);
        });
        
        // Take top contacts with some variety
        final topContacts = deviceContacts.take(limit * 2).toList(); // Take more for variety
        
        // Ensure variety by mixing high priority with other contacts
        final selectedContacts = <fContacts.Contact>[];
        for (int i = 0; i < topContacts.length && selectedContacts.length < limit; i++) {
          // Add every other contact to ensure variety
          if (i % 2 == 0 || selectedContacts.length < limit / 2) {
            selectedContacts.add(topContacts[i]);
          }
        }
        
        // If we don't have enough contacts, add more
        if (selectedContacts.length < limit) {
          final remainingNeeded = limit - selectedContacts.length;
          final remainingContacts = deviceContacts
              .where((c) => !selectedContacts.contains(c))
              .take(remainingNeeded)
              .toList();
          selectedContacts.addAll(remainingContacts);
        }
        
        print('Calendar-based filtering selected ${selectedContacts.length} contacts');
        return selectedContacts;
        
      } catch (e) {
        print('Error in iOS smart filtering: $e');
        return _getFallbackSmartContacts(deviceContacts, limit);
      }
    }
    
  Future<List<fContacts.Contact>> _getSmartFilteredContactsAndroid(
    List<fContacts.Contact> deviceContacts,
    int limit,
  ) async {
    try {
      print('Starting Android call log-based filtering');
      
      // Request call log permission
      var callLogStatus = await Permission.phone.status;
      if (!callLogStatus.isGranted) {
        callLogStatus = await Permission.phone.request();
        if (!callLogStatus.isGranted) {
          print('Call log permission denied, falling back to calendar filtering');
          return await _getSmartFilteredContactsIOS(deviceContacts, limit);
        }
      }

      // Get call log entries
      print('Getting call log entries...');
      final Iterable<CallLogEntry> entries = await CallLog.get();
      print('Found ${entries.length} call log entries');
      
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
      
      print('Call log analysis complete. Unique numbers: ${callCountMap.length}');
      
      // Score contacts based on call frequency and recency
      final scoredContacts = deviceContacts.map((contact) {
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
        if (contact.photoOrThumbnail != null && contact.photoOrThumbnail!.isNotEmpty) {
          score += 2;
        }
        
        // Bonus points for contacts with complete names
        if (contact.name.first.isNotEmpty && contact.name.last.isNotEmpty) {
          score += 2;
        }
        
        // Bonus points for contacts with emails
        if (contact.emails.isNotEmpty) {
          score += 1;
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
      
      print('Android smart filtering completed. Top contact scores:');
      for (int i = 0; i < (scoredContacts.length > 5 ? 5 : scoredContacts.length); i++) {
        final item = scoredContacts[i];
        print('${(item['contact'] as fContacts.Contact).displayName}: Score ${item['score']}, Calls: ${item['callCount']}');
      }
      
      // Take top contacts
      final selectedContacts = scoredContacts
          .take(limit)
          .map((item) => item['contact'] as fContacts.Contact)
          .toList();
      
      print('Selected ${selectedContacts.length} contacts for import');
      return selectedContacts;
      
    } catch (e, stack) {
      print('Error in Android call log filtering: $e');
      print('Stack trace: $stack');
      return await _getSmartFilteredContactsIOS(deviceContacts, limit); // Fallback to calendar
    }
  }
    
  // Fallback method if calendar integration fails
  List<fContacts.Contact> _getFallbackSmartContacts(
    List<fContacts.Contact> deviceContacts,
    int limit,
  ) {
    print('Using fallback smart filtering');
    
    // Simple fallback: prioritize contacts with photos, emails, and organization
    final scoredContacts = deviceContacts.map((contact) {
      int score = 0;
      
      // Photo presence
      if (contact.photoOrThumbnail != null && contact.photoOrThumbnail!.isNotEmpty) score += 30;
      
      // Email count
      score += contact.emails.length * 20;
      
      // Organization/Job title
      if (contact.organizations.isNotEmpty) score += 15;
      
      // Complete name
      if (contact.name.first.isNotEmpty && contact.name.last.isNotEmpty) score += 10;
      
      // Phone numbers
      score += contact.phones.length * 5;
      
      return {'contact': contact, 'score': score};
    }).toList();
    
    scoredContacts.sort((a, b) {
      final scoreA = a['score'] as int;
      final scoreB = b['score'] as int;
      return scoreB.compareTo(scoreA);
    });
    
    return scoredContacts
        .take(limit)
        .map((item) => item['contact'] as fContacts.Contact)
        .toList();
  }

  // Helper method to normalize phone numbers for comparison
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Handle iOS-specific formatting issues
    if (Platform.isIOS) {
      // iOS often includes country code without the plus sign
      // Common country codes to handle (US/CA: 1, UK: 44, etc.)
      
      // If number starts with 1 and is exactly 11 digits (US/Canada with country code)
      if (digits.length == 11 && digits.startsWith('1')) {
        // Keep as is, but also create a version without country code for comparison
        return digits;
      }
      
      // If number is 10 digits (US/Canada without country code)
      if (digits.length == 10) {
        // Also consider the version with US country code
        return digits;
      }
      
      // For other lengths, return as is
      return digits;
    }
    
    return digits;
  }

// Enhanced phone number matching
bool _phoneNumbersMatch(String phone1, String phone2) {
  if (phone1.isEmpty || phone2.isEmpty) return false;
  
  // Extract digits from both numbers
  String normalized1 = _extractPhoneNumber(phone1);
  String normalized2 = _extractPhoneNumber(phone2);
  
  if (normalized1.isEmpty || normalized2.isEmpty) return false;
  
  // Direct match
  if (normalized1 == normalized2) return true;
  
  // Check if one contains the other (for numbers with/without country code)
  if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
    // Make sure the difference is reasonable (country code length)
    int lengthDiff = (normalized1.length - normalized2.length).abs();
    if (lengthDiff <= 3) {
      return true;
    }
  }
  
  // Check last 10 digits (for international numbers)
  if (normalized1.length >= 10 && normalized2.length >= 10) {
    String last10Digits1 = normalized1.substring(normalized1.length - 10);
    String last10Digits2 = normalized2.substring(normalized2.length - 10);
    if (last10Digits1 == last10Digits2) {
      return true;
    }
  }
  
  // Check last 9 digits (for numbers with different area codes)
  if (normalized1.length >= 9 && normalized2.length >= 9) {
    String last9Digits1 = normalized1.substring(normalized1.length - 9);
    String last9Digits2 = normalized2.substring(normalized2.length - 9);
    if (last9Digits1 == last9Digits2) {
      return true;
    }
  }
  
  return false;
}


  // Set<String> _getPhoneNumberVariations(String phoneNumber) {
  //   final variations = <String>{};
  //   final normalized = _normalizePhoneNumber(phoneNumber);
    
  //   variations.add(normalized);
    
  //   if (Platform.isIOS) {
  //     // Add US/Canada format variations
  //     if (normalized.length == 10) {
  //       variations.add('1$normalized'); // With US country code
  //     } else if (normalized.length == 11 && normalized.startsWith('1')) {
  //       variations.add(normalized.substring(1)); // Without country code
  //     }
      
  //     // Add variations with common international prefixes
  //     final commonCountryCodes = ['1', '44', '61', '49', '33']; // US, UK, Australia, Germany, France
  //     for (final code in commonCountryCodes) {
  //       if (normalized.startsWith(code) && normalized.length > code.length) {
  //         variations.add(normalized.substring(code.length));
  //       } else if (!normalized.startsWith(code)) {
  //         variations.add('$code$normalized');
  //       }
  //     }
  //   }
    
  //   return variations;
  // }



}
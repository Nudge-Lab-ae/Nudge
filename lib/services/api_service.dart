// lib/services/api_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/contact.dart';
import '../models/nudge.dart';
import '../models/social_group.dart';
import '../models/user.dart' as app_user;

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');
  
  // Get user's contacts subcollection reference
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Initialize FCM and get token
  Future<String?> initializeFCM() async {
    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        
        if (token != null) {
          // Store token in user document
          await updateUser({'fcmToken': token});
          print('FCM Token stored: $token');
          return token;
        }
      }
      
      return null;
    } catch (e) {
      print('Error initializing FCM: $e');
      return null;
    }
  }

    // Call Cloud Function to trigger scheduled notifications
  Future<Map<String, dynamic>> scheduleRegularNotifications() async {
    String contactId = _auth.currentUser!.uid;
    print('sending scheduled nudges');
    try {
      print('phase 1');
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('rescheduleUserNudges');
      print('phase 2');
      
      final result = await callable.call({
        'contactId': contactId,
      });
      print (result.data); print(' is the result');
      
      return result.data;
    } catch (e) {
      print('Error scheduling nudges: $e');
      throw Exception('Failed to trigger nudge: $e');
    }
  }

  // Call Cloud Function to trigger manual nudge
  Future<Map<String, dynamic>> triggerManualNudge(String contactId) async {
    print('sending test nudge'); print(contactId);
    try {
      print('phase 1');
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('triggerManualNudge');
      print('phase 2');
      
      final result = await callable.call({
        'contactId': contactId,
      });
      print (result.data); print(' is the result');
      
      return result.data;
    } catch (e) {
      print('Error triggering manual nudge: $e');
      throw Exception('Failed to trigger nudge: $e');
    }
  }

  // Update user's FCM token (if it changes)
  Future<void> updateFCMToken(String token) async {
    try {
      await updateUser({'fcmToken': token});
    } catch (e) {
      throw Exception('Failed to update FCM token: $e');
    }
  }

  CollectionReference _getUserContactsCollection(String userId) {
    return _usersCollection.doc(userId).collection('contacts');
  }

  // User methods
  Future<void> ensureUserDocumentCompleteness(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final defaultValues = app_user.User.defaultValues;
        
        // Check for missing fields and prepare updates
        final updates = <String, dynamic>{};
        bool needsUpdate = false;
        
        // Check each field and set default values if missing
        defaultValues.forEach((key, defaultValue) {
          if (!userData.containsKey(key) || userData[key] == null) {
            updates[key] = defaultValue;
            needsUpdate = true;
            print('Adding missing field: $key with value: $defaultValue');
          }
        });
        
        // Special handling for nested objects that might be partially missing
        if (userData['groups'] == null || 
            (userData['groups'] is List && (userData['groups'] as List).isEmpty)) {
          updates['groups'] = defaultValues['groups'];
          needsUpdate = true;
          print('Adding default groups');
        }
        
        if (userData['goals'] == null) {
          updates['goals'] = defaultValues['goals'];
          needsUpdate = true;
          print('Adding default goals');
        }
        
        if (userData['nudges'] == null) {
          updates['nudges'] = defaultValues['nudges'];
          needsUpdate = true;
          print('Adding default nudges');
        }
        
        // Update the document if any fields are missing
        if (needsUpdate) {
          await _usersCollection.doc(userId).update(updates);
          print('User document updated with missing fields for user: $userId');
        } else {
          print('User document is complete for user: $userId');
        }
      }
    } catch (e) {
      print('Error ensuring user document completeness: $e');
      // Don't throw here, as we don't want to block the app if this fails
    }
  }

  // Update the existing getUser method to ensure document completeness
  Future<app_user.User> getUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      // First, ensure the document has all required fields
      await ensureUserDocumentCompleteness(currentUser.uid);
      
      final doc = await _usersCollection.doc(currentUser.uid).get();
      
      if (doc.exists) {
        return app_user.User.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        // Create user document if it doesn't exist
        final newUser = app_user.User(
          id: currentUser.uid,
          admin: false,
          email: currentUser.email ?? '',
          username: currentUser.displayName ?? currentUser.email!.split('@')[0],
          createdAt: DateTime.now(),
          weeklyDigestEnabled: true,
          groups: [
            {"name": "Family", "id": "Family", "period": "Monthly", "frequency": 4, "colorCode": "#4FC3F7"},
            {"name": "Friend", "id": "Friend", "period": "Quarterly", "frequency": 7, "colorCode": "#FF6F61"},
            {"name": "Client", "id": "Client", "period": "Monthly", "frequency": 2, "colorCode": "#81C784"},
            {"name": "Colleague", "id": "Colleague", "period": "Annually", "frequency": 4, "colorCode": "#FFC107"},
            {"name": "Mentor", "id": "Mentor", "period": "Annually", "frequency": 2, "colorCode": "#607D8B"},
          ],
          goals: {},
          nudges: [],
          phoneNumber: '',
          photoUrl: '',
          description: '',
          bio: '',
          profileCompleted: false,
        );
        
        await _usersCollection.doc(currentUser.uid).set(newUser.toMap());
        return newUser;
      }
    } catch (e) {
      throw Exception('Failed to load user: $e');
    }
  }

  // Stream of user data
  Stream<app_user.User> get userStream {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.empty();
      return _usersCollection.doc(user.uid).snapshots().map((snapshot) {
        if (snapshot.exists) {
          return app_user.User.fromMap(snapshot.data() as Map<String, dynamic>);
        }
        return app_user.User(
          admin: false,
          id: user.uid,
          email: user.email ?? '',
          username: user.displayName ?? user.email!.split('@')[0],
          createdAt: DateTime.now(),
          groups: [],
          goals: {},
          // contacts: [],
          nudges: [],
          phoneNumber: '',
          photoUrl: '',
          description: '',
          bio: '',
          profileCompleted: false,
          weeklyDigestEnabled: true
        );
      });
    });
  }

  // Contact methods
  Stream<List<Contact>> getContactsStream() {
    String userId = _auth.currentUser!.uid;
    return _getUserContactsCollection(userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Contact.fromMap(doc.data() as Map<String, dynamic>..['id'] = doc.id))
            .toList());
  }

  Future<List<Contact>> getAllContacts() async{
    String userId = _auth.currentUser!.uid;
    QuerySnapshot snap = await _getUserContactsCollection(userId).orderBy('name').get();
    return snap.docs.map((doc) => Contact.fromMap(doc.data() as Map<String, dynamic>..['id'] = doc.id)).toList();
  }

  Future<void> addContact(Contact contact) async {
    String userId = _auth.currentUser!.uid;
    try {
      final contactData = contact.toMap();
      // Remove the id since Firestore will generate it
      contactData.remove('id');
      
      await _getUserContactsCollection(userId).add(contactData);
    } catch (e) {
      throw Exception('Failed to create contact: $e');
    }
  }

 Future<void> updateContact(Contact contact) async {
  String userId = _auth.currentUser!.uid;
    try {
      await _getUserContactsCollection(userId)
          .doc(contact.id)
          .update(contact.toMap());
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  Future<void> updateCloseCircleContacts(List<Contact> closeCircleContacts) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');
    
    // Update each contact to mark as close circle
    for (final contact in closeCircleContacts) {
      await _getUserContactsCollection(currentUser.uid)
          .doc(contact.id)
          .update({
            'isVIP': true,
            'updatedAt': DateTime.now(),
          });
    }
  } catch (e) {
    throw Exception('Failed to update close circle contacts: $e');
  }
}

  Future<void> deleteContact(String contactId) async {
    String userId = _auth.currentUser!.uid;
    try {
      await _getUserContactsCollection(userId).doc(contactId).delete();
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }

  Future<void> addUser(app_user.User user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  Future<void> updateUser(Map<String, dynamic> updates) async {
    try {
      String userId = _auth.currentUser!.uid;
      print(userId); print(' is the id');
      await _usersCollection.doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Nudge methods
  Stream<List<Nudge>> getNudgesStream() {
    return userStream.map((user) {
      return user.nudges.map((nudgeData) => Nudge.fromMap(nudgeData)).toList();
    });
  }

  Future<void> addNudge(Nudge nudge) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      final userDoc = await _usersCollection.doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final nudges = List<Map<String, dynamic>>.from(userData['nudges'] ?? []);
        
        // Generate a unique ID for the nudge
        final nudgeData = nudge.toMap();
        nudgeData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        
        nudges.add(nudgeData);
        
        await _usersCollection.doc(currentUser.uid).update({
          'nudges': nudges,
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      throw Exception('Failed to create nudge: $e');
    }
  }

  // Group methods
  // Stream<List<SocialGroup>> getGroupsStream() {
  //   return userStream.map((user) {  
  //    var list =  user.groups!.map((groupData) => SocialGroup.fromMap(groupData)).toList();
  //    print(list); print(' is the list');
  //     return list;
  //   });
  // }

  Stream<List<SocialGroup>> getGroupsStream() {
  try {
    return userStream.map((user) {
      // if (user == null) return <SocialGroup>[];
      
      // Handle cases where groups might be null or not a List
      if (user.groups == null) return <SocialGroup>[];
      
      // Ensure groups is a List
      if (user.groups is! List) return <SocialGroup>[];
      
      return user.groups!.map((groupData) {
        try {
          return SocialGroup.fromMap(groupData);
        } catch (e) {
          print('Error parsing group data: $e');
          // Return a default group or handle error as needed
          return SocialGroup(
            id: 'error',
            name: 'Error Group',
            description: 'Error loading group',
            period: 'Monthly',
            frequency: 1,
            memberIds: [],
            memberCount: 0,
            lastInteraction: DateTime.now(),
            colorCode: '#FF0000',
            birthdayNudgesEnabled: false,
            anniversaryNudgesEnabled: false
          );
        }
      }).toList();
    });
  } catch (e) {
    print('Error in getGroupsStream: $e');
    // Return an empty stream on error
    return Stream.value(<SocialGroup>[]);
  }
}

// In your ApiService class, update these methods:

Future<void> addGroup(SocialGroup group) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');
    
    final userDoc = await _usersCollection.doc(currentUser.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final groups = List<Map<String, dynamic>>.from(userData['groups'] ?? []);
      
      // Add the new group to the list
      groups.add(group.toMap());
      
      await _usersCollection.doc(currentUser.uid).update({
        'groups': groups,
        'updatedAt': DateTime.now(),
      });
    }
  } catch (e) {
    throw Exception('Failed to create group: $e');
  }
}

Future<void> updateGroup(SocialGroup group) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');
    
    final userDoc = await _usersCollection.doc(currentUser.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final groups = List<Map<String, dynamic>>.from(userData['groups'] ?? []);
      
      // Find the group index by ID
      final index = groups.indexWhere((g) => g['id'] == group.id);
      if (index != -1) {
        // Update the group
        groups[index] = group.toMap();
        
        await _usersCollection.doc(currentUser.uid).update({
          'groups': groups,
          'updatedAt': DateTime.now(),
        });
      }
    }
  } catch (e) {
    throw Exception('Failed to update group: $e');
  }
}

  Future<void> updateGroups(List<SocialGroup> groups) async {
    try {
      final currentUser = _auth.currentUser;
      print(groups); print(' is the groups');
      List<Map<String, dynamic>> groupMaps = [];
      for (int i =0; i < groups.length; i++) {
        groupMaps.add(groups[i].toMap());
      }
     await _usersCollection.doc(currentUser!.uid).update({
            'groups': groupMaps,
            'updatedAt': DateTime.now(),
          });
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
}
  // Imported contacts methods
  Future<void> updateImportedContacts(List<Map<String, dynamic>> contacts) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      await _usersCollection.doc(currentUser.uid).update({
        'importedContacts': contacts,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update imported contacts: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getImportedContacts() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      final doc = await _usersCollection.doc(currentUser.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['importedContacts'] ?? []);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get imported contacts: $e');
    }
  }

  Future<void> convertImportedToRegularContact(Map<String, dynamic> contactData) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      // Remove from imported contacts
      final importedContacts = await getImportedContacts();
      importedContacts.removeWhere((c) => c['phoneNumber'] == contactData['phoneNumber']);
      await updateImportedContacts(importedContacts);
      
      // Add to regular contacts
      final contact = Contact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: contactData['name'] ?? '',
        connectionType: contactData['connectionType'] ?? 'Friend',
        frequency: contactData['frequency'] ?? 2,
        period: contactData['period'] ?? 'Monthly',
        socialGroups: List<String>.from(contactData['socialGroups'] ?? []),
        phoneNumber: contactData['phoneNumber'] ?? '',
        email: contactData['email'] ?? '',
        notes: contactData['notes'] ?? '',
        imageUrl: contactData['imageUrl'] ?? '',
        lastContacted: DateTime.now(),
        isVIP: contactData['isVIP'] ?? false,
        priority: contactData['priority'] ?? 3,
        tags: List<String>.from(contactData['tags'] ?? []),
        interactionHistory: {},
      );
      
      await addContact(contact);
    } catch (e) {
      throw Exception('Failed to convert imported contact: $e');
    }
  }

  // Authentication methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final userDoc = await _usersCollection.doc(result.user!.uid).get();
      Map<String, dynamic> userData = {};
      
      if (userDoc.exists) {
        userData = userDoc.data() as Map<String, dynamic>;
      }
      
      return {
        'user': result.user,
        'userData': userData,
        'token': await result.user!.getIdToken(),
      };
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

Future<Map<String, dynamic>> register(String email, String password) async {
  try {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Create user document with minimal information
    final newUser = app_user.User(
      admin: false,
      id: result.user!.uid,
      email: email,
      username: '', // Will be set in CompleteProfileScreen
      phoneNumber: '',
      bio: '',
      description: '',
      photoUrl: '',
      createdAt: DateTime.now(),
      groups: [], // Will be set in SetGoalsScreen
      goals: {},
      // contacts: [],
      nudges: [],
      profileCompleted: false,
      weeklyDigestEnabled: true
    );
    
    await _usersCollection.doc(result.user!.uid).set(newUser.toMap());
    
    return {
      'user': result.user,
      'userData': newUser.toMap(),
      'token': await result.user!.getIdToken(),
    };
  } catch (e) {
    throw Exception('Failed to register: $e');
  }
}
  
  Future<Map<String, dynamic>> registerWithEmail(String email, String password, String username) async {
  try {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Create user document with additional info
    final newUser = app_user.User(
      admin: false,
      id: result.user!.uid,
      email: email,
      username: username,
      phoneNumber: '',
      bio: '',
      description: '',
      photoUrl: '',
      createdAt: DateTime.now(),
      groups: [
       {"name": "Family", "id": "Family", "period": "Monthly", "frequency": 4, "colorCode": "#4FC3F7"},
          {"name": "Friend",  "id": "Friend", "period": "Quarterly", "frequency": 7, "colorCode": "#FF6F61"},
          {"name": "Client",  "id": "Client", "period": "Monthly", "frequency": 2, "colorCode": "#81C784"},
          {"name": "Colleague",  "id": "Colleague", "period": "Annually", "frequency": 4, "colorCode": "#FFC107"},
          {"name": "Mentor",  "id": "Mentor", "period": "Annually", "frequency": 2, "colorCode": "#607D8B"},
      ],
      goals: {},
      // contacts: [],
      nudges: [],
      profileCompleted: false,
      weeklyDigestEnabled: true
    );
    
    await _usersCollection.doc(result.user!.uid).set(newUser.toMap());
    
    return {
      'user': result.user,
      'userData': newUser.toMap(),
      'token': await result.user!.getIdToken(),
    };
  } catch (e) {
    throw Exception('Failed to register: $e');
  }
}

Future<void> submitFeedback({
  required String message,
  String type = 'Feedback',
  Map<String, dynamic>? additionalData,
  required String screenName, // Add this parameter
}) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');
    
    // Get current user data
    final userDoc = await _usersCollection.doc(currentUser.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    
    // Prepare feedback data with screen info
    final feedbackData = {
      'user': {
        'userId': currentUser.uid,
        'email': currentUser.email,
        'username': userData?['username'] ?? '',
        'photoUrl': userData?['photoUrl'] ?? '',
      },
      'message': message,
      'type': type,
      'screen': screenName, // Add screen tracking
      'timestamp': FieldValue.serverTimestamp(),
      'appVersion': '1.0.0',
      'platform': _getPlatform(),
      'additionalData': additionalData ?? {},
      'status': 'new',
    };
    
    // Add to feedbacks collection
    await _firestore.collection('feedbacks').add(feedbackData);
    
    print('Feedback submitted from screen: $screenName');
  } catch (e) {
    print('Error submitting feedback: $e');
    throw Exception('Failed to submit feedback: $e');
  }
}

  String _getPlatform() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  // Add these methods to your existing ApiService class

// Feedback management methods
Stream<List<Map<String, dynamic>>> getFeedbacksStream() {
  try {
    Query query = _firestore
        .collection('feedbacks')
        .orderBy('timestamp', descending: true);
    
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          };
        })
        .toList());
  } catch (e) {
    print('Error getting feedbacks stream: $e');
    return Stream.value([]);
  }
}

  Future<void> updateFeedbackStatus(String feedbackId, String newStatus) async {
    try {
      await _firestore.collection('feedbacks').doc(feedbackId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update feedback status: $e');
    }
  }

  Future<void> addFeedbackResponse(String feedbackId, String response) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      final responseData = {
        'responderId': currentUser.uid,
        'responderEmail': currentUser.email,
        'response': response,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('feedbacks').doc(feedbackId).update({
        'adminResponse': responseData,
        'status': 'responded',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add feedback response: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getPublicFeedbacksStream({
  String? statusFilter,
  int limit = 50,
}) {
  Query query = _firestore
      .collection('feedbacks')
      .where('isPublic', isEqualTo: true)
      .orderBy('timestamp', descending: true)
      .limit(limit);

  if (statusFilter != null) {
    query = query.where('status', isEqualTo: statusFilter);
  }

  return query.snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    }).toList();
  });
}

Future<void> updateFeedbackAdminData({
  required String feedbackId,
  String? adminTitle,
  String? status,
  bool? isPublic,
}) async {
  final updateData = <String, dynamic>{};
  
  if (adminTitle != null) updateData['adminTitle'] = adminTitle;
  if (status != null) updateData['status'] = status;
  if (isPublic != null) updateData['isPublic'] = isPublic;
  
  if (updateData.isNotEmpty) {
    await _firestore.collection('feedbacks').doc(feedbackId).update(updateData);
  }
}

  Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection('feedbacks').doc(feedbackId).delete();
    } catch (e) {
      throw Exception('Failed to delete feedback: $e');
    }
  }

  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final snapshot = await _firestore.collection('feedbacks').get();
      final allFeedbacks = snapshot.docs.map((doc) => doc.data()).toList();
      
      final total = allFeedbacks.length;
      final newCount = allFeedbacks.where((f) => f['status'] == 'new').length;
      final reviewedCount = allFeedbacks.where((f) => f['status'] == 'reviewed').length;
      final respondedCount = allFeedbacks.where((f) => f['status'] == 'responded').length;
      
      // Count by type
      final typeCounts = <String, int>{};
      for (final feedback in allFeedbacks) {
        final type = feedback['type'] ?? 'Unknown';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      
      return {
        'total': total,
        'new': newCount,
        'reviewed': reviewedCount,
        'responded': respondedCount,
        'typeCounts': typeCounts,
      };
    } catch (e) {
      throw Exception('Failed to get feedback stats: $e');
    }
  }


}

class FrequencyPeriodMapper {
  static const Map<String, Map<String, dynamic>> frequencyMapping = {
    'Every few days': {'frequency': 2, 'period': 'Weekly'},
    'Weekly': {'frequency': 1, 'period': 'Weekly'},
    'Every 2 weeks': {'frequency': 2, 'period': 'Monthly'},
    'Monthly': {'frequency': 1, 'period': 'Monthly'},
    'Quarterly': {'frequency': 1, 'period': 'Quarterly'},
    'Twice a year': {'frequency': 2, 'period': 'Yearly'},
    'Once a year': {'frequency': 1, 'period': 'Yearly'},
  };

  static String getConversationalChoice(int frequency, String period) {
    for (var entry in frequencyMapping.entries) {
      if (entry.value['frequency'] == frequency && entry.value['period'] == period) {
        return entry.key;
      }
    }
    // Default fallback
    return 'Monthly';
  }

  static Map<String, dynamic> getFrequencyPeriod(String conversationalChoice) {
    return frequencyMapping[conversationalChoice] ?? {'frequency': 1, 'period': 'Monthly'};
  }
}


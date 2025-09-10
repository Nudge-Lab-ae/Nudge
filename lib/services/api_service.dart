// lib/services/api_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
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
  CollectionReference _getUserContactsCollection(String userId) {
    return _usersCollection.doc(userId).collection('contacts');
  }

  // User methods
  Future<app_user.User> getUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');
      
      final doc = await _usersCollection.doc(currentUser.uid).get();
      if (doc.exists) {
        return app_user.User.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        // Create user document if it doesn't exist
        final newUser = app_user.User(
          id: currentUser.uid,
          email: currentUser.email ?? '',
          username: currentUser.displayName ?? currentUser.email!.split('@')[0],
          createdAt: DateTime.now(),
         groups: [
          {"name": "Family", "period": "Monthly", "frequency": 4},
          {"name": "Friend", "period": "Quarterly", "frequency": 8},
          {"name": "Client", "period": "Monthly", "frequency": 2},
          {"name": "Colleague", "period": "Annually", "frequency": 4},
          {"name": "Mentor", "period": "Annually", "frequency": 2},
        ],
          goals: {},
          contacts: [],
          nudges: [],
          phoneNumber: '',
          photoURL: '',
          description: '',
          bio: ''
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
          id: user.uid,
          email: user.email ?? '',
          username: user.displayName ?? user.email!.split('@')[0],
          createdAt: DateTime.now(),
          groups: [],
          goals: {},
          contacts: [],
          nudges: [],
          phoneNumber: '',
          photoURL: '',
          description: '',
          bio: ''
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
        frequency: contactData['frequency'] ?? 'Monthly',
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
      id: result.user!.uid,
      email: email,
      username: '', // Will be set in CompleteProfileScreen
      phoneNumber: '',
      bio: '',
      description: '',
      photoURL: '',
      createdAt: DateTime.now(),
      groups: [], // Will be set in SetGoalsScreen
      goals: {},
      contacts: [],
      nudges: [],
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
      id: result.user!.uid,
      email: email,
      username: username,
      phoneNumber: '',
      bio: '',
      description: '',
      photoURL: '',
      createdAt: DateTime.now(),
      groups: [
        {"name": "Family", "period": "Monthly", "frequency": 4},
          {"name": "Friend", "period": "Quarterly", "frequency": 8},
          {"name": "Client", "period": "Monthly", "frequency": 2},
          {"name": "Colleague", "period": "Annually", "frequency": 4},
          {"name": "Mentor", "period": "Annually", "frequency": 2},
      ],
      goals: {},
      contacts: [],
      nudges: [],
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

}


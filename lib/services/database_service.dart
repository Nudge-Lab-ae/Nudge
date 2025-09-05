import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact.dart';
import '../models/nudge.dart';
import '../models/social_group.dart';
import '../models/analytics.dart';

class DatabaseService {
  final String? uid;
  
  DatabaseService({this.uid});

  // Collection references
  final CollectionReference contactsCollection = 
      FirebaseFirestore.instance.collection('contacts');
  final CollectionReference nudgesCollection = 
      FirebaseFirestore.instance.collection('nudges');
  final CollectionReference groupsCollection = 
      FirebaseFirestore.instance.collection('groups');
  final CollectionReference analyticsCollection = 
      FirebaseFirestore.instance.collection('analytics');

  // Contact methods
  // Stream<List<Contact>> get contacts {
  //   return contactsCollection
  //       .where('userId', isEqualTo: uid)
  //       .snapshots()
  //       .map(_contactListFromSnapshot);
  // }

  // List<Contact> _contactListFromSnapshot(QuerySnapshot snapshot) {
  //   return snapshot.docs.map((doc) {
  //     return Contact.fromFirestore(doc);
  //   }).toList();
  // }

  Future<void> addContact(Contact contact) async {
    final contactData = contact.toMap();
    contactData['userId'] = uid;
    await contactsCollection.add(contactData);
    return;
  }

  Future<void> updateContact(Contact contact) async {
    return await contactsCollection.doc(contact.id).update(contact.toMap());
  }

  Future<void> deleteContact(String id) async {
    return await contactsCollection.doc(id).delete();
  }

  // Nudge methods
  Stream<List<Nudge>> get nudges {
    return nudgesCollection
        .where('userId', isEqualTo: uid)
        .orderBy('scheduledTime')
        .snapshots()
        .map(_nudgeListFromSnapshot);
  }

  List<Nudge> _nudgeListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return Nudge.fromFirestore(doc);
    }).toList();
  }

 Future<void> addNudge(Nudge nudge) async {
   final nudgeData = nudge.toMap();
   nudgeData['userId'] = uid;
   await nudgesCollection.add(nudgeData);
   return;
}

  Future<void> completeNudge(String id) async {
    return await nudgesCollection.doc(id).update({
      'isCompleted': true,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> snoozeNudge(String id, Duration duration) async {
    return await nudgesCollection.doc(id).update({
      'isSnoozed': true,
      'scheduledTime': DateTime.now().add(duration).millisecondsSinceEpoch,
    });
  }

  // Group methods
  Stream<List<SocialGroup>> get groups {
    return groupsCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(_groupListFromSnapshot);
  }

  List<SocialGroup> _groupListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return SocialGroup.fromFirestore(doc);
    }).toList();
  }

  // Future<void> addGroup(SocialGroup group) async {
  //    await groupsCollection.add(group.toMap());
  //    return;
  // }

  // Analytics methods
  Stream<Analytics> get analytics {
    return analyticsCollection
        .doc(uid)
        .snapshots()
        .map(_analyticsFromSnapshot);
  }

  Analytics _analyticsFromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Analytics.fromMap(data);
  }

  Future<void> updateAnalytics(Analytics analytics) async {
    return await analyticsCollection.doc(uid).set(analytics.toMap());
  }

  // Add to DatabaseService class

// Group methods

  Future<void> addGroup(SocialGroup group) async {
    final groupData = group.toMap();
    groupData['userId'] = uid;
    await groupsCollection.add(groupData);
    return;
  }

  Future<void> updateGroup(SocialGroup group) async {
    return await groupsCollection.doc(group.id).update(group.toMap());
  }

  Future<void> deleteGroup(String id) async {
    return await groupsCollection.doc(id).delete();
  }


  Future<void> updateNudge(Nudge nudge) async {
    return await nudgesCollection.doc(nudge.id).update(nudge.toMap());
  }

  Future<void> deleteNudge(String id) async {
    return await nudgesCollection.doc(id).delete();
  }





}
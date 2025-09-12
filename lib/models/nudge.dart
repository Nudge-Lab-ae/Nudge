// lib/models/nudge.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Nudge {
  String id;
  String nudgeId;
  String contactId;
  String contactName;
  String nudgeType;
  String message;
  DateTime scheduledTime;
  bool isCompleted;
  bool isSnoozed;
  DateTime? completedAt;
  DateTime? snoozedUntil;
  String userId;
  String period;
  int frequency;

  Nudge({
    required this.id,
    required this.nudgeId,
    required this.contactId,
    required this.contactName,
    required this.nudgeType,
    required this.message,
    required this.scheduledTime,
    this.isCompleted = false,
    this.isSnoozed = false,
    this.completedAt,
    this.snoozedUntil,
    required this.userId,
    required this.period,
    required this.frequency,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nudgeId': nudgeId,
      'contactId': contactId,
      'contactName': contactName,
      'nudgeType': nudgeType,
      'message': message,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'isCompleted': isCompleted,
      'isSnoozed': isSnoozed,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'snoozedUntil': snoozedUntil?.millisecondsSinceEpoch,
      'userId': userId,
      'period': period,
      'frequency': frequency,
    };
  }

  factory Nudge.fromMap(Map<String, dynamic> data) {
    
    return Nudge(
      id: data['id'],
      nudgeId: data['nudgeId'],
      contactId: data['contactId'] ?? '',
      contactName: data['contactName'] ?? '',
      nudgeType: data['nudgeType'] ?? '',
      message: data['message'] ?? '',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(data['scheduledTime'] ?? 0),
      isCompleted: data['isCompleted'] ?? false,
      isSnoozed: data['isSnoozed'] ?? false,
      completedAt: data['completedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'])
          : null,
      snoozedUntil: data['snoozedUntil'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['snoozedUntil'])
          : null,
      userId: data['userId'] ?? '',
      period: 'Monthly',
      frequency: 2,
    );
  }

  // Create from Firestore Document
  factory Nudge.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Nudge(
      id: doc.id,
      nudgeId: data['nudgeId'] ?? doc.id,
      contactId: data['contactId'] ?? '',
      contactName: data['contactName'] ?? '',
      nudgeType: data['nudgeType'] ?? '',
      message: data['message'] ?? '',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(data['scheduledTime'] ?? 0),
      isCompleted: data['isCompleted'] ?? false,
      isSnoozed: data['isSnoozed'] ?? false,
      completedAt: data['completedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'])
          : null,
      snoozedUntil: data['snoozedUntil'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['snoozedUntil'])
          : null,
      userId: data['userId'] ?? '',
      period: 'Monthly',
      frequency: 2
    );
  }
}
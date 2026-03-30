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
  bool isPushNotification;
  int priority;
  bool isVIP;
  String contactImageUrl; 
  String groupName;

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
    required this.isPushNotification,
    required this.priority,
    required this.isVIP,
    required this.contactImageUrl,
    required this.groupName
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
      'isPushNotification': isPushNotification,
      'isVIP': isVIP,
      'priority': priority,
      'groupName': groupName,
      'contactImageUrl': contactImageUrl
    };
  }

  factory Nudge.fromMap(Map<String, dynamic> data) {
    return Nudge(
      id: data['id'] ?? '',
      nudgeId: data['nudgeId'] ?? data['id'] ?? '',
      contactId: data['contactId'] ?? '',
      contactName: data['contactName'] ?? '',
      nudgeType: data['nudgeType'] ?? '',
      message: data['message'] ?? '',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(data['scheduledTime'] ?? 0),
      isCompleted: data['isCompleted'] ?? false,
      isSnoozed: data['isSnoozed'] ?? false,
      completedAt: data['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'] is int
              ? data['completedAt']
              : (data['completedAt'] as Timestamp).millisecondsSinceEpoch)
          : null,
      snoozedUntil: data['snoozedUntil'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['snoozedUntil'])
          : null,
      userId: data['userId'] ?? '',
      period: data['period'] ?? 'Monthly',      // FIX: read from map
      frequency: data['frequency'] ?? 2,        // FIX: read from map
      priority: data['priority'] ?? 3,
      isVIP: data['isVIP'] ?? false,
      isPushNotification: data['isPushNotification'] ?? false,
      contactImageUrl: data['contactImageUrl'] ?? '',
      groupName: data['groupName'] ?? '',
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
      period: data['period'] ?? 'Monthly',
      frequency: data['frequency'] ?? 2,
      priority: data['priority'] ?? 3,
      isPushNotification: data['isPushNotification'] ?? false,
      isVIP: data['isVIP'] ?? false,
      contactImageUrl: data['contactImageUrl'] ?? '',
      groupName: data['groupName'] ?? '',
    );
  }

   Nudge copyWith({
  String? id,
  String? nudgeId,
  String? contactId,
  String? contactName,
  String? nudgeType,
  String? message,
  DateTime? scheduledTime,
  bool? isCompleted,
  bool? isSnoozed,
  DateTime? completedAt,
  DateTime? snoozedUntil,
  String? userId,
  String? period,
  int? frequency,
  bool? isPushNotification,
  int? priority,
  bool? isVIP,
  String? contactImageUrl,
  String? groupName,
  }) {
    return Nudge(
      id: id ?? this.id,
      nudgeId: nudgeId ?? this.nudgeId,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactImageUrl: contactImageUrl ?? this.contactImageUrl,
      frequency: frequency ?? this.frequency,
      period: period ?? this.period,
      nudgeType: nudgeType ?? this.nudgeType,
      message: message ?? this.message,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      completedAt: completedAt ?? this.completedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      userId: userId ?? this.userId,
      isPushNotification: isPushNotification ?? this.isPushNotification,
      priority: priority ?? this.priority,
      isVIP: isVIP ?? this.isVIP,
      groupName: groupName ?? this.groupName,
    );
  }
}
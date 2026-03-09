import 'package:cloud_firestore/cloud_firestore.dart';

class SocialGroup {
  String id;
  String name;
  String description;
  String period;
  int frequency;
  List<String> memberIds;
  int memberCount;
  DateTime lastInteraction;
  String colorCode;
  bool birthdayNudgesEnabled = true;
  bool anniversaryNudgesEnabled = true;
  int orderIndex;

  SocialGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.period,
    required this.frequency,
    required this.memberIds,
    required this.memberCount,
    required this.lastInteraction,
    required this.colorCode,
    required this.birthdayNudgesEnabled,
    required this.anniversaryNudgesEnabled,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'period': period,
      'frequency': frequency,
      'memberIds': memberIds,
      'memberCount': memberCount,
      'lastInteraction': lastInteraction.millisecondsSinceEpoch,
      'colorCode': colorCode,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'birthdayNudgesEnabled': birthdayNudgesEnabled,
      'anniversaryNudgesEnabled': anniversaryNudgesEnabled,
      'orderIndex': orderIndex,
    };
  }

  factory SocialGroup.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SocialGroup(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      period: data['period'] ?? 'Monthly',
      frequency: data['frequency'] ?? 2,
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberCount: data['memberCount'] ?? 0,
      lastInteraction: DateTime.fromMillisecondsSinceEpoch(data['lastInteraction'] ?? 0),
      colorCode: data['colorCode'] ?? '#2596BE',
      birthdayNudgesEnabled: data['birthdayNudgesEnabled'] ?? false,
      anniversaryNudgesEnabled: data['anniversaryNudgesEnabled'] ?? false,
      orderIndex: data['orderIndex'] ?? 0,
    );
  }

  factory SocialGroup.fromMap(Map<String, dynamic> data) {
    return SocialGroup(
      id: data['id'] ?? data['name'],
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      period: data['period'] ?? 'Monthly',
      frequency: data['frequency'] ?? 2,
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberCount: data['memberCount'] ?? 0,
      lastInteraction: DateTime.fromMillisecondsSinceEpoch(data['lastInteraction'] ?? 0),
      colorCode: data['colorCode'] ?? '#2596BE',
      birthdayNudgesEnabled: data['birthdayNudgesEnabled'] ?? false,
      anniversaryNudgesEnabled: data['anniversaryNudgesEnabled'] ?? false,
      orderIndex: data['orderIndex'] ?? 0,
    );
  }

  factory SocialGroup.empty() {
    return SocialGroup(
      id: '',
      name: '',
      description: '',
      period: 'Monthly',
      frequency: 2,
      memberIds: [],
      memberCount: 0,
      lastInteraction: DateTime.now(),
      colorCode: '#2596BE',
      birthdayNudgesEnabled: false,
      anniversaryNudgesEnabled: false,
      orderIndex: 0,
    );
  }

  SocialGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? period,
    int? frequency,
    List<String>? memberIds,
    int? memberCount,
    DateTime? lastInteraction,
    String? colorCode,
    bool? birthdayNudgesEnabled,
    bool? anniversaryNudgesEnabled,
    int? orderIndex,
  }) {
    return SocialGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      period: period ?? this.period,
      frequency: frequency ?? this.frequency,
      memberIds: memberIds ?? this.memberIds,
      memberCount: memberCount ?? this.memberCount,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      colorCode: colorCode ?? this.colorCode,
      birthdayNudgesEnabled: birthdayNudgesEnabled ?? this.birthdayNudgesEnabled,
      anniversaryNudgesEnabled: anniversaryNudgesEnabled?? this.anniversaryNudgesEnabled,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
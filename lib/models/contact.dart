// lib/models/contact.dart
class Contact {
  String id;
  String name;
  String connectionType;
  String frequency;
  List<String> socialGroups;
  String phoneNumber;
  String email;
  String notes;
  String imageUrl;
  DateTime lastContacted;
  bool isVIP;
  int priority;
  List<String> tags;
  Map<String, dynamic> interactionHistory;
  String? profession;
  DateTime? birthday;
  DateTime? anniversary;
  DateTime? workAnniversary;

  Contact({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.frequency,
    required this.socialGroups,
    required this.phoneNumber,
    required this.email,
    required this.notes,
    required this.imageUrl,
    required this.lastContacted,
    required this.isVIP,
    required this.priority,
    required this.tags,
    required this.interactionHistory,
    this.profession,
    this.birthday,
    this.anniversary,
    this.workAnniversary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'connectionType': connectionType,
      'frequency': frequency,
      'socialGroups': socialGroups,
      'phoneNumber': phoneNumber,
      'email': email,
      'notes': notes,
      'imageUrl': imageUrl,
      'lastContacted': lastContacted.millisecondsSinceEpoch,
      'isVIP': isVIP,
      'priority': priority,
      'tags': tags,
      'interactionHistory': interactionHistory,
      'profession': profession,
      'birthday': birthday?.millisecondsSinceEpoch,
      'anniversary': anniversary?.millisecondsSinceEpoch,
      'workAnniversary': workAnniversary?.millisecondsSinceEpoch,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] ?? '',
      name: map['name'],
      connectionType: map['connectionType'],
      frequency: map['frequency'],
      socialGroups: List<String>.from(map['socialGroups'] ?? []),
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      notes: map['notes'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      lastContacted: DateTime.fromMillisecondsSinceEpoch(map['lastContacted'] ?? 0),
      isVIP: map['isVIP'] ?? false,
      priority: map['priority'] ?? 3,
      tags: List<String>.from(map['tags'] ?? []),
      interactionHistory: Map<String, dynamic>.from(map['interactionHistory'] ?? {}),
      profession: map['profession'],
      birthday: map['birthday'] != null ? DateTime.fromMillisecondsSinceEpoch(map['birthday']) : null,
      anniversary: map['anniversary'] != null ? DateTime.fromMillisecondsSinceEpoch(map['anniversary']) : null,
      workAnniversary: map['workAnniversary'] != null ? DateTime.fromMillisecondsSinceEpoch(map['workAnniversary']) : null,
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    String? connectionType,
    String? frequency,
    List<String>? socialGroups,
    String? phoneNumber,
    String? email,
    String? notes,
    String? imageUrl,
    DateTime? lastContacted,
    bool? isVIP,
    int? priority,
    List<String>? tags,
    Map<String, dynamic>? interactionHistory,
    String? profession,
    DateTime? birthday,
    DateTime? anniversary,
    DateTime? workAnniversary,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      frequency: frequency ?? this.frequency,
      socialGroups: socialGroups ?? this.socialGroups,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      lastContacted: lastContacted ?? this.lastContacted,
      isVIP: isVIP ?? this.isVIP,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      interactionHistory: interactionHistory ?? this.interactionHistory,
      profession: profession ?? this.profession,
      birthday: birthday ?? this.birthday,
      anniversary: anniversary ?? this.anniversary,
      workAnniversary: workAnniversary ?? this.workAnniversary,
    );
  }
}
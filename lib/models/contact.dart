// lib/models/contact.dart - UPDATED VERSION
class Contact {
  String id;
  String name;
  String connectionType;
  String period;
  int frequency;
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

  // NEW FIELDS FOR SOCIAL UNIVERSE
  double cdi; // Connection Depth Index (15-100)
  String computedRing; // 'inner', 'middle', 'outer'
  String rawBand; // Current CDI band
  DateTime rawBandSince; // When CDI entered current band
  double angleDeg; // Fixed angle for layout (0-359)
  int interactionCountInWindow; // Interactions in last 90 days
  
  double css; 
  int totalNudgesSent; 
  int completedNudges; 
  bool needsAttention; // Whether this contact is flagged for follow-up
  String? attentionSource; // 'manual' (user-flagged) | 'digest' (from Reflection Digest)
  DateTime? attentionSince; // When the flag was set

  Contact({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.frequency,
    required this.period,
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
    // New fields with defaults
    this.cdi = 50.0, // Default middle
    this.computedRing = 'middle',
    this.rawBand = 'middle',
    DateTime? rawBandSince,
    this.angleDeg = 0.0,
    this.interactionCountInWindow = 0,

    this.css = 50.0, // New field
    this.totalNudgesSent = 0, // New field
    this.completedNudges = 0, // New field

    this.needsAttention = false,
    this.attentionSource,
    this.attentionSince,
  }) : rawBandSince = rawBandSince ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'connectionType': connectionType,
      'frequency': frequency,
      'period': period,
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
      // New fields
      'cdi': cdi,
      'computedRing': computedRing,
      'rawBand': rawBand,
      'rawBandSince': rawBandSince.millisecondsSinceEpoch,
      'angleDeg': angleDeg,
      'interactionCountInWindow': interactionCountInWindow,
      'css': css, 
      'totalNudgesSent': totalNudgesSent, 
      'completedNudges': completedNudges, 
      'needsAttention': needsAttention,
      'attentionSource': attentionSource,
      'attentionSince': attentionSince?.millisecondsSinceEpoch,
      };
  }

  factory Contact.empty() {
    return Contact(
      id: '',
      name: '',
      connectionType: '',
      frequency: 0,
      period: '',
      socialGroups: [],
      phoneNumber: '',
      email: '',
      notes: '',
      imageUrl: '',
      lastContacted: DateTime.now(),
      isVIP: false,
      priority: 3,
      tags:[],
      interactionHistory: {},
      profession: '',
      birthday: null,
      anniversary: null,
      workAnniversary: null,
      // New fields
      cdi: 0,
      computedRing: 'middle',
      rawBand: 'middle',
      rawBandSince: DateTime.now(),
      angleDeg: 0,
      interactionCountInWindow: 0,
      css: 50,
      totalNudgesSent: 0, 
      completedNudges: 0,
      needsAttention: false,
      attentionSource: null,
      attentionSince: null,
    );
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] ?? '',
      name: map['name'],
      connectionType: map['connectionType'],
      frequency: map['frequency'],
      period: map['period'],
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
      // New fields
      cdi: (map['cdi'] ?? 50.0).toDouble(),
      computedRing: map['computedRing'] ?? 'middle',
      rawBand: map['rawBand'] ?? 'middle',
      rawBandSince: map['rawBandSince'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['rawBandSince'])
          : DateTime.now(),
      angleDeg: (map['angleDeg'] ?? 0.0).toDouble(),
      interactionCountInWindow: map['interactionCountInWindow'] ?? 0,

      css: (map['css'] ?? 50.0).toDouble(), 
      totalNudgesSent: map['totalNudgesSent'] ?? 0, 
      completedNudges: map['completedNudges'] ?? 0, 
      needsAttention: map['needsAttention'] ?? false,
      attentionSource: map['attentionSource'],
      attentionSince: map['attentionSince'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['attentionSince'])
          : null,
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    String? connectionType,
    int? frequency,
    String? period,
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
    // New fields
    double? cdi,
    String? computedRing,
    String? rawBand,
    DateTime? rawBandSince,
    double? angleDeg,
    int? interactionCountInWindow,
    double? css, 
    int? totalNudgesSent, 
    int? completedNudges, 
    bool? needsAttention,
    // Use Object? sentinel so callers can explicitly pass null to clear these
    Object? attentionSource = _sentinel,
    Object? attentionSince = _sentinel,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      frequency: frequency ?? this.frequency,
      period: period ?? this.period,
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
      cdi: cdi ?? this.cdi,
      computedRing: computedRing ?? this.computedRing,
      rawBand: rawBand ?? this.rawBand,
      rawBandSince: rawBandSince ?? this.rawBandSince,
      angleDeg: angleDeg ?? this.angleDeg,
      interactionCountInWindow: interactionCountInWindow ?? this.interactionCountInWindow,
      css: css ?? this.css, 
      totalNudgesSent: totalNudgesSent ?? this.totalNudgesSent, 
      completedNudges: completedNudges ?? this.completedNudges,
       needsAttention: needsAttention ?? this.needsAttention,
      // Sentinel pattern lets callers pass null explicitly to clear the field
      attentionSource: identical(attentionSource, _sentinel)
          ? this.attentionSource
          : attentionSource as String?,
      attentionSince: identical(attentionSince, _sentinel)
          ? this.attentionSince
          : attentionSince as DateTime?,
    );
  }

  // Helper method to get target interval days for CDI calculation
  double get targetIntervalDays {
    switch (period) {
      case 'Daily':
        return 1.0;
      case 'Weekly':
        return 7.0;
      case 'Monthly':
        return 30.0;
      case 'Quarterly':
        return 90.0;
      case 'Annually':
        return 365.0;
      default:
        return 30.0; // Default to monthly
    }
  }
}
const Object _sentinel = Object();
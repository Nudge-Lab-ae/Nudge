// analytics.dart
class Analytics {
  int totalContacts;
  int vipContacts;
  int completedNudges;
  int contactsNeedingAttention;
  Map<String, int> contactsByType;
  double relationshipHealth;
  int weeklyConnections;
  int monthlyCatchups;
  int vipInteractions;
  int newConnections;
  DateTime lastUpdated;

  Analytics({
    required this.totalContacts,
    required this.vipContacts,
    required this.completedNudges,
    required this.contactsNeedingAttention,
    required this.contactsByType,
    required this.relationshipHealth,
    required this.weeklyConnections,
    required this.monthlyCatchups,
    required this.vipInteractions,
    required this.newConnections,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalContacts': totalContacts,
      'vipContacts': vipContacts,
      'completedNudges': completedNudges,
      'contactsNeedingAttention': contactsNeedingAttention,
      'contactsByType': contactsByType,
      'relationshipHealth': relationshipHealth,
      'weeklyConnections': weeklyConnections,
      'monthlyCatchups': monthlyCatchups,
      'vipInteractions': vipInteractions,
      'newConnections': newConnections,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory Analytics.fromMap(Map<String, dynamic> map) {
    return Analytics(
      totalContacts: map['totalContacts'] ?? 0,
      vipContacts: map['vipContacts'] ?? 0,
      completedNudges: map['completedNudges'] ?? 0,
      contactsNeedingAttention: map['contactsNeedingAttention'] ?? 0,
      contactsByType: Map<String, int>.from(map['contactsByType'] ?? {}),
      relationshipHealth: (map['relationshipHealth'] ?? 0).toDouble(),
      weeklyConnections: map['weeklyConnections'] ?? 0,
      monthlyCatchups: map['monthlyCatchups'] ?? 0,
      vipInteractions: map['vipInteractions'] ?? 0,
      newConnections: map['newConnections'] ?? 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] ?? 0),
    );
  }

  Analytics copyWith({
    int? totalContacts,
    int? vipContacts,
    int? completedNudges,
    int? contactsNeedingAttention,
    Map<String, int>? contactsByType,
    double? relationshipHealth,
    int? weeklyConnections,
    int? monthlyCatchups,
    int? vipInteractions,
    int? newConnections,
    DateTime? lastUpdated,
  }) {
    return Analytics(
      totalContacts: totalContacts ?? this.totalContacts,
      vipContacts: vipContacts ?? this.vipContacts,
      completedNudges: completedNudges ?? this.completedNudges,
      contactsNeedingAttention: contactsNeedingAttention ?? this.contactsNeedingAttention,
      contactsByType: contactsByType ?? this.contactsByType,
      relationshipHealth: relationshipHealth ?? this.relationshipHealth,
      weeklyConnections: weeklyConnections ?? this.weeklyConnections,
      monthlyCatchups: monthlyCatchups ?? this.monthlyCatchups,
      vipInteractions: vipInteractions ?? this.vipInteractions,
      newConnections: newConnections ?? this.newConnections,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
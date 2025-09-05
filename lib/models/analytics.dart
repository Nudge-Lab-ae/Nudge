class Analytics {
  int totalContacts;
  int vipContacts;
  int completedNudges;
  int pendingNudges;
  Map<String, int> contactsByType;
  Map<String, int> nudgesByFrequency;
  double successRate;
  DateTime lastUpdated;

  Analytics({
    required this.totalContacts,
    required this.vipContacts,
    required this.completedNudges,
    required this.pendingNudges,
    required this.contactsByType,
    required this.nudgesByFrequency,
    required this.successRate,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalContacts': totalContacts,
      'vipContacts': vipContacts,
      'completedNudges': completedNudges,
      'pendingNudges': pendingNudges,
      'contactsByType': contactsByType,
      'nudgesByFrequency': nudgesByFrequency,
      'successRate': successRate,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory Analytics.fromMap(Map<String, dynamic> map) {
    return Analytics(
      totalContacts: map['totalContacts'] ?? 0,
      vipContacts: map['vipContacts'] ?? 0,
      completedNudges: map['completedNudges'] ?? 0,
      pendingNudges: map['pendingNudges'] ?? 0,
      contactsByType: Map<String, int>.from(map['contactsByType'] ?? {}),
      nudgesByFrequency: Map<String, int>.from(map['nudgesByFrequency'] ?? {}),
      successRate: (map['successRate'] ?? 0).toDouble(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] ?? 0),
    );
  }

  Analytics copyWith({
    int? totalContacts,
    int? vipContacts,
    int? completedNudges,
    int? pendingNudges,
    Map<String, int>? contactsByType,
    Map<String, int>? nudgesByFrequency,
    double? successRate,
    DateTime? lastUpdated,
  }) {
    return Analytics(
      totalContacts: totalContacts ?? this.totalContacts,
      vipContacts: vipContacts ?? this.vipContacts,
      completedNudges: completedNudges ?? this.completedNudges,
      pendingNudges: pendingNudges ?? this.pendingNudges,
      contactsByType: contactsByType ?? this.contactsByType,
      nudgesByFrequency: nudgesByFrequency ?? this.nudgesByFrequency,
      successRate: successRate ?? this.successRate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
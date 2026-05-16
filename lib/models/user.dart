// lib/models/user.dart
class User {
  String id;
  String email;
  String username;
  String phoneNumber;
  String photoUrl;
  String bio;
  bool admin;
  String description;
  DateTime createdAt;
  double immersionLevel;
  final Map<String, dynamic>? goals;
  final List<Map<String, dynamic>>? groups;
  final List<Map<String, dynamic>> nudges;
  final bool profileCompleted;
  final bool weeklyDigestEnabled;
  final int? trialStartedAt;
  final String? subscriptionTier;
  final String? subscriptionStatus;
  final int? subscriptionExpiresAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.createdAt,
    required this.nudges,
    required this.goals,
    required this.groups,
    required this.bio,
    required this.description,
    required this.phoneNumber,
    required this.photoUrl,
    required this.profileCompleted,
    required this.admin,
    required this.immersionLevel,
    required this.weeklyDigestEnabled,
    this.trialStartedAt,
    this.subscriptionTier,
    this.subscriptionStatus,
    this.subscriptionExpiresAt,
  });

  // Method to get default values for all fields
  static Map<String, dynamic> get defaultValues {
    return {
      'id': '',
      'email': '',
      'username': '',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'nudges': [],
      'goals': {},
      'immersionLevel': 0.5,
      'groups': [
        {"name": "Family", "id": "Family", "period": "Monthly", "frequency": 4, "colorCode": "#4FC3F7"},
        {"name": "Friend", "id": "Friend", "period": "Quarterly", "frequency": 7, "colorCode": "#FF6F61"},
        {"name": "Client", "id": "Client", "period": "Monthly", "frequency": 2, "colorCode": "#81C784"},
        {"name": "Colleague", "id": "Colleague", "period": "Annually", "frequency": 4, "colorCode": "#FFC107"},
        {"name": "Mentor", "id": "Mentor", "period": "Annually", "frequency": 2, "colorCode": "#607D8B"},
      ],
      'bio': '',
      'description': '',
      'phoneNumber': '',
      'photoUrl': '',
      'profileCompleted': false,
      'admin': false,
      'weeklyDigestEnabled': true,
      'trialStartedAt': null,
      'subscriptionTier': 'free',
      'subscriptionStatus': 'inactive',
      'subscriptionExpiresAt': null,
    };
  }

  // Method to check if user data is complete
  bool get hasCompleteData {
    return id.isNotEmpty &&
        email.isNotEmpty &&
        username.isNotEmpty &&
        goals != null &&
        groups != null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'immersionLevel': immersionLevel,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'nudges': nudges,
      'goals': goals ?? {},
      'groups': groups ?? User.defaultValues['groups'],
      'bio': bio,
      'description': description,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'profileCompleted': profileCompleted,
      'admin': admin,
      'weeklyDigestEnabled': weeklyDigestEnabled,
      if (trialStartedAt != null) 'trialStartedAt': trialStartedAt,
      if (subscriptionTier != null) 'subscriptionTier': subscriptionTier,
      if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus,
      if (subscriptionExpiresAt != null) 'subscriptionExpiresAt': subscriptionExpiresAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Use default values for any missing fields
    final defaultValues = User.defaultValues;
    
    return User(
      id: map['id'] ?? defaultValues['id']!,
      email: map['email'] ?? defaultValues['email']!,
      username: map['username'] ?? defaultValues['username']!,
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : defaultValues['createdAt']!,
      nudges: List<Map<String, dynamic>>.from(map['nudges'] ?? defaultValues['nudges']!),
      goals: Map<String, dynamic>.from(map['goals'] ?? defaultValues['goals']!),
      groups: List<Map<String, dynamic>>.from(map['groups'] ?? defaultValues['groups']!),
      bio: map['bio'] ?? defaultValues['bio']!,
      immersionLevel: map['immersionLevel'] ?? defaultValues['immersionLevel'],
      description: map['description'] ?? defaultValues['description']!,
      phoneNumber: map['phoneNumber'] ?? defaultValues['phoneNumber']!,
      photoUrl: map['photoUrl'] ?? defaultValues['photoUrl']!,
      profileCompleted: map['profileCompleted'] ?? defaultValues['profileCompleted']!,
      admin: map['admin'] ?? defaultValues['admin']!,
      weeklyDigestEnabled: map['weeklyDigestEnabled'] ?? defaultValues['weeklyDigestEnabled']!,
      trialStartedAt: map['trialStartedAt'] as int?,
      subscriptionTier: map['subscriptionTier'] as String?,
      subscriptionStatus: map['subscriptionStatus'] as String?,
      subscriptionExpiresAt: map['subscriptionExpiresAt'] as int?,
    );
  }
}
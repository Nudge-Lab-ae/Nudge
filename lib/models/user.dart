// lib/models/user.dart
class User {
  String id;
  String email;
  String username;
  String phoneNumber;
  String photoURL;
  String bio;
  String description;
  DateTime createdAt;
  // Map<String, dynamic> defaultFrequencies;
  final Map<String, dynamic>? goals;
  final List<Map<String, dynamic>>? groups;
  final List<Map<String, dynamic>> nudges;
  final List<Map<String, dynamic>> contacts; //

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.createdAt,
    // required this.defaultFrequencies,
    required this.nudges,
    required this.goals,
    required this.groups,
    required this.contacts,
    required this.bio,
    required this.description,
    required this.phoneNumber,
    required this.photoURL,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'createdAt': createdAt.millisecondsSinceEpoch,
      // 'defaultFrequencies': defaultFrequencies,
      'nudges': nudges,
      'goals': goals ?? {},
      'groups': groups,
      'contacts': contacts,
      'bio': bio,
      'description': description,
      'phoneNumber': phoneNumber,
      'photoUrl': photoURL,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      username: map['username'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      // defaultFrequencies: Map<String, String>.from(map['defaultFrequencies']),
      nudges: List<Map<String, String>>.from(map['nudges'] ?? {}),
      goals: Map<String, String>.from(map['goals'] ?? {}),
      groups:  List<Map<String, String>>.from(map['groups'] ?? {}),
      contacts: List<Map<String, dynamic>>.from(map['contacts'] ?? []),
      bio: map['bio'],
      description: map['description'],
      phoneNumber: map['phoneNumber'],
      photoURL: map['photoUrl']
    );
  }
}
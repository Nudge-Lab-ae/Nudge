// lib/test/mock_contacts_generator.dart
import 'dart:math';
import '../models/contact.dart';

class MockContactsGenerator {
  static final Random _random = Random();
  static final List<String> _names = [
    'John Smith', 'Emma Johnson', 'Michael Brown', 'Sarah Davis', 'David Wilson',
    'Lisa Anderson', 'James Miller', 'Jennifer Taylor', 'Robert Moore', 'Maria Garcia',
    'William Martin', 'Susan Jackson', 'Richard Lee', 'Karen White', 'Charles Harris',
    'Nancy Clark', 'Thomas Lewis', 'Betty Walker', 'Daniel Hall', 'Margaret Young',
    'Paul Allen', 'Dorothy King', 'Mark Scott', 'Sandra Adams', 'Steven Wright',
    'Carol Baker', 'George Nelson', 'Ruth Carter', 'Edward Mitchell', 'Sharon Perez',
    'Brian Roberts', 'Deborah Turner', 'Kevin Phillips', 'Jessica Campbell',
    'Jason Parker', 'Cynthia Evans', 'Jeffrey Edwards', 'Angela Collins',
    'Ryan Stewart', 'Brenda Sanchez', 'Gary Morris', 'Pamela Rogers', 'Timothy Reed',
    'Amy Cook', 'Joshua Bailey', 'Martha Murphy', 'Eric Rivera', 'Janet Cooper',
    'Scott Richardson', 'Diane Cox'
  ];

  static final List<String> _connectionTypes = [
    'Friend', 'Family', 'Colleague', 'Mentor', 'Acquaintance',
    'Client', 'Business Partner', 'Classmate', 'Neighbor', 'Relative'
  ];

  static final List<String> _tags = [
    'Gym Buddy', 'Book Club', 'Music', 'Travel', 'Foodie',
    'Tech', 'Art', 'Sports', 'Volunteer', 'Parenting'
  ];

  static List<Contact> generateMockContacts({int count = 50}) {
    final contacts = <Contact>[];
    final now = DateTime.now();
    
    for (int i = 0; i < count; i++) {
      // Generate CDI with distribution:
      // - 20% in inner circle (80-100)
      // - 50% in middle circle (50-79)
      // - 30% in outer circle (15-49)
      double cdi;
      String computedRing;
      
      
      // Last contacted between 1 and 180 days ago
      final lastContacted = now.subtract(Duration(days: _random.nextInt(180) + 1));
      
      // Generate stable angle based on index
      final angleDeg = (i * 360.0 / count) % 360;
      
      // Generate VIP status (20% chance)
      final isVIP = _random.nextDouble() < 0.2;

      final rand = _random.nextDouble();
      if (rand < 0.2) {
        cdi = 80 + _random.nextDouble() * 20; // 80-100
        computedRing = 'inner';
        if (isVIP)  computedRing = 'inner_vip';
      } else if (rand < 0.7) {
        cdi = 50 + _random.nextDouble() * 29; // 50-79
        computedRing = 'middle';
        if (isVIP)  computedRing = 'middle_vip';
      } else {
        cdi = 15 + _random.nextDouble() * 34; // 15-49
        computedRing = 'outer';
        if (isVIP)  computedRing = 'outer_vip';
      }
      
      // Generate interaction count (0-20)
      final interactionCount = _random.nextInt(20);
      
      contacts.add(Contact(
        id: 'mock_${i + 1000}',
        name: _names[i % _names.length],
        connectionType: _connectionTypes[i % _connectionTypes.length],
        period: ['Weekly', 'Monthly', 'Quarterly'][i % 3],
        frequency: _random.nextInt(10) + 1,
        socialGroups: i % 3 == 0 ? ['Social Club'] : [],
        phoneNumber: '+1${_random.nextInt(900000000) + 100000000}',
        email: 'contact${i}@example.com',
        notes: 'Mock contact for testing',
        imageUrl: '',
        lastContacted: lastContacted,
        isVIP: isVIP,
        priority: _random.nextInt(5) + 1,
        tags: [_tags[i % _tags.length]],
        interactionHistory: {},
        profession: ['Developer', 'Designer', 'Manager', 'Teacher', 'Doctor'][i % 5],
        birthday: i % 4 == 0 ? DateTime(1980 + i % 20, (i % 12) + 1, (i % 28) + 1) : null,
        cdi: cdi,
        computedRing: computedRing,
        rawBand: computedRing,
        rawBandSince: now.subtract(Duration(days: _random.nextInt(60) + 7)),
        angleDeg: angleDeg,
        interactionCountInWindow: interactionCount,
      ));
    }
    
    return contacts;
  }
  
}
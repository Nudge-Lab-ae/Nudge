// lib/services/tagging_service.dart
import '../models/contact.dart';

class TaggingService {
  static List<String> suggestTags(Contact contact, List<Contact> allContacts) {
    List<String> suggestions = [];
    
    // Suggest based on interaction frequency
    DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    DateTime monthAgo = DateTime.now().subtract(const Duration(days: 30));
    
    if (contact.lastContacted.isAfter(weekAgo)) {
      suggestions.add('Frequent Contact');
    } else if (contact.lastContacted.isBefore(monthAgo)) {
      suggestions.add('Needs Reconnection');
    }
    
    // Suggest based on connection type
    if (contact.connectionType == 'Family') {
      suggestions.add('Family');
    } else if (contact.connectionType == 'Client') {
      suggestions.add('Work');
    }
    
    // Suggest VIP for important contacts
    if (contact.isVIP) {
      suggestions.add('VIP');
    }
    
    // Remove duplicates
    return suggestions.toSet().toList();
  }
  
  static String suggestRelationshipDepth(Contact contact) {
    // Simple algorithm to suggest relationship depth
    // Based on interaction frequency and contact details
    if (contact.isVIP) return 'Inner Circle';
    if (contact.connectionType == 'Family') return 'Close';
    if (contact.connectionType == 'Friend') return 'Good Friend';
    return 'Acquaintance';
  }
}
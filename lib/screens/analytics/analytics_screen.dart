// lib/screens/analytics/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/analytics.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/analytics_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view analytics')),
      );
    }
    
    final apiService = ApiService();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
      ),
      body: StreamProvider<List<Contact>>.value(
        value: apiService.getContactsStream(),
        initialData: const [],
        child: Consumer<List<Contact>>(
          builder: (context, contacts, child) {
            // Calculate analytics data
            final analytics = _calculateAnalytics(contacts);
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  AnalyticsChart(analytics: analytics),
                  // Add more analytics widgets here
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Analytics _calculateAnalytics(List<Contact> contacts) {
    // Calculate various analytics metrics
    final vipCount = contacts.where((c) => c.isVIP).length;
    final needsAttention = contacts.where((c) => 
      c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
    ).length;
    
    // Count contacts by type
    final contactsByType = <String, int>{};
    for (var contact in contacts) {
      contactsByType[contact.connectionType] = 
          (contactsByType[contact.connectionType] ?? 0) + 1;
    }
    
    // Calculate success rate (placeholder)
    final successRate = contacts.isEmpty ? 0.0 : 
        (contacts.length - needsAttention) / contacts.length * 100;
    
    return Analytics(
      totalContacts: contacts.length,
      vipContacts: vipCount,
      completedNudges: 0, // You'll need to track this
      pendingNudges: needsAttention,
      contactsByType: contactsByType,
      nudgesByFrequency: {}, // You'll need to track this
      successRate: successRate,
      lastUpdated: DateTime.now(),
    );
  }
}
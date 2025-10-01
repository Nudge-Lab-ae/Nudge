// lib/screens/analytics/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/analytics.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../services/auth_service.dart';
import '../../services/nudge_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view analytics')),
      );
    }
    
    final apiService = Provider.of<ApiService>(context);
    final nudgeService = NudgeService();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics', style: AppTextStyles.title3.copyWith(color: Colors.black)),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Colors.white
      ),
      body: StreamBuilder<List<Contact>>(
        stream: apiService.getContactsStream(),
        builder: (context, contactsSnapshot) {
          if (contactsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (contactsSnapshot.hasError) {
            return Center(child: Text('Error loading contacts: ${contactsSnapshot.error}'));
          }
          
          final contacts = contactsSnapshot.data ?? [];
          
          return StreamBuilder<List<Nudge>>(
            stream: nudgeService.getNudgesStream(user.uid),
            builder: (context, nudgesSnapshot) {
              if (nudgesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (nudgesSnapshot.hasError) {
                return Center(child: Text('Error loading nudges: ${nudgesSnapshot.error}'));
              }
              
              final nudges = nudgesSnapshot.data ?? [];
              
              // Calculate analytics data
              final analytics = _calculateAnalytics(contacts, nudges);
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummarySection(analytics, contacts.length),
                    const SizedBox(height: 24),
                    _buildNudgePerformanceSection(analytics, nudges),
                    const SizedBox(height: 24),
                    // _buildRelationshipHealthSection(analytics, contacts),
                    // const SizedBox(height: 24),
                    _buildVIPContactsSection(analytics, contacts),
                    const SizedBox(height: 24),
                    _buildInteractionPatternsSection(analytics, nudges),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummarySection(Analytics analytics, int totalContacts) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relationship Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Contacts', totalContacts.toString(), Icons.people),
                _buildStatCard('VIP Contacts', analytics.vipContacts.toString(), Icons.star),
                _buildStatCard('Needs Attention', analytics.contactsNeedingAttention.toString(), Icons.notifications_active),
              ],
            ),
            const SizedBox(height: 16),
            // LinearPercentIndicator(
            //   animation: true,
            //   lineHeight: 20.0,
            //   animationDuration: 1000,
            //   percent: analytics.nudgeCompletionRate / 100,
            //   center: Text("${analytics.nudgeCompletionRate.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white)),
            //   barRadius: const Radius.circular(10),
            //   progressColor: _getProgressColor(analytics.nudgeCompletionRate),
            //   backgroundColor: Colors.grey[300],
            // ),
            // const SizedBox(height: 8),
            // const Text(
            //   'Nudge Completion Rate',
            //   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color.fromRGBO(45, 161, 175, 1)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // Widget _buildRelationshipHealthSection(Analytics analytics, List<Contact> contacts) {
  //   final healthData = _calculateRelationshipHealth(contacts);
    
  //   return Card(
  //     elevation: 4,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'Relationship Health by Type',
  //             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //           ),
  //           const SizedBox(height: 16),
  //           SizedBox(
  //             height: 200,
  //             child: healthData.isEmpty
  //                 ? const Center(child: Text('No data available'))
  //                 : SfCartesianChart(
  //                     primaryXAxis: CategoryAxis(),
  //                     series: <ChartSeries>[
  //                       ColumnSeries<Map<String, dynamic>, String>(
  //                         dataSource: healthData,
  //                         xValueMapper: (Map<String, dynamic> data, _) => data['type'],
  //                         yValueMapper: (Map<String, dynamic> data, _) => data['health'],
  //                         dataLabelSettings: const DataLabelSettings(isVisible: true),
  //                         color: const Color.fromRGBO(45, 161, 175, 1),
  //                       )
  //                     ],
  //                   ),
  //           ),
  //           const SizedBox(height: 16),
  //           const Text(
  //             'Health score based on timely communication',
  //             style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildInteractionPatternsSection(Analytics analytics, List<Nudge> nudges) {
    final interactionData = _calculateInteractionPatterns(nudges);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Nudge Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: interactionData.isEmpty
                  ? const Center(child: Text('No data available'))
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(),
                      primaryYAxis: NumericAxis(minimum: 0),
                      series: <ChartSeries>[
                        LineSeries<Map<String, dynamic>, String>(
                          dataSource: interactionData,
                          xValueMapper: (Map<String, dynamic> data, _) => data['period'],
                          yValueMapper: (Map<String, dynamic> data, _) => data['interactions'],
                          markerSettings: const MarkerSettings(isVisible: true),
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                          color: const Color.fromRGBO(45, 161, 175, 1),
                        )
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Completed nudges by week',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVIPContactsSection(Analytics analytics, List<Contact> contacts) {
    final vipContacts = contacts.where((contact) => contact.isVIP).toList();
    final vipInteractionData = _calculateVIPInteractions(vipContacts);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Close Circle Engagement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: vipInteractionData.isEmpty
                  ? const Center(child: Text('No Close circle contacts'))
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(),
                      series: <ChartSeries>[
                        BarSeries<Map<String, dynamic>, String>(
                          dataSource: vipInteractionData,
                          xValueMapper: (Map<String, dynamic> data, _) => data['name'],
                          yValueMapper: (Map<String, dynamic> data, _) => data['interactions'],
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                          color: const Color.fromRGBO(45, 161, 175, 1),
                        )
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Close Contact Engagement', style: TextStyle(fontWeight: FontWeight.w700),),
                Chip(
                  label: Text('${vipContacts.length} Contacts', style: const TextStyle(color: Colors.white)),
                  backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgePerformanceSection(Analytics analytics, List<Nudge> nudges) {
    final nudgePerformance = _calculateNudgePerformance(nudges);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nudge Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNudgeStat('Scheduled', nudgePerformance['scheduled'] ?? 0, Icons.schedule),
                _buildNudgeStat('Completed', nudgePerformance['completed'] ?? 0, Icons.check_circle),
                _buildNudgeStat('Missed', nudgePerformance['missed'] ?? 0, Icons.not_interested),
              ],
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              animation: true,
              lineHeight: 20.0,
              animationDuration: 1000,
              percent: (nudgePerformance['completionRate'] ?? 0) / 100,
              center: Text("${(nudgePerformance['completionRate'] ?? 0).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white)),
              barRadius: const Radius.circular(10),
              progressColor: _getProgressColor(nudgePerformance['completionRate']?.toDouble() ?? 0),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            const Text(
              'Nudge Completion Rate',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgeStat(String title, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color.fromRGBO(45, 161, 175, 1)),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return const Color.fromRGBO(45, 161, 175, 1);
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  Analytics _calculateAnalytics(List<Contact> contacts, List<Nudge> nudges) {
    final vipCount = contacts.where((c) => c.isVIP).length;
    
    // Calculate contacts needing attention (not contacted in the last 30 days)
    final needsAttention = contacts.where((c) => 
      c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
    ).length;
    
    // Count contacts by type
    final contactsByType = <String, int>{};
    for (var contact in contacts) {
      contactsByType[contact.connectionType] = 
          (contactsByType[contact.connectionType] ?? 0) + 1;
    }
    
    // Calculate nudge completion rate
    final completedNudges = nudges.where((nudge) => nudge.isCompleted).length;
    final totalNudges = nudges.length;
    final nudgeCompletionRate = totalNudges == 0 ? 100.0 : (completedNudges / totalNudges * 100);
    
    // Calculate relationship health based on contact engagement
    final relationshipHealth = _calculateOverallRelationshipHealth(contacts);
    
    // Calculate interaction metrics
    final weeklyConnections = _calculateWeeklyConnections(nudges);
    final monthlyCatchups = _calculateMonthlyCatchups(nudges);
    final vipInteractions = _calculateVIPInteractionsCount(contacts);
    final newConnections = _calculateNewConnections(contacts);
    
    return Analytics(
      totalContacts: contacts.length,
      vipContacts: vipCount,
      completedNudges: completedNudges,
      contactsNeedingAttention: needsAttention,
      contactsByType: contactsByType,
      relationshipHealth: relationshipHealth,
      nudgeCompletionRate: nudgeCompletionRate,
      weeklyConnections: weeklyConnections,
      monthlyCatchups: monthlyCatchups,
      vipInteractions: vipInteractions,
      newConnections: newConnections,
      lastUpdated: DateTime.now(),
    );
  }

  double _calculateOverallRelationshipHealth(List<Contact> contacts) {
    if (contacts.isEmpty) return 100.0;
    
    double totalHealth = 0;
    int contactCount = 0;
    
    for (var contact in contacts) {
      final daysSinceLastContact = DateTime.now().difference(contact.lastContacted).inDays;
      final daysPerFrequency = contact.frequency * _getDaysInPeriod(contact.period);
      
      // Health score: 100% if contacted recently, decreasing based on how overdue
      double healthScore = 100.0;
      if (daysSinceLastContact > daysPerFrequency) {
        healthScore = 100 - ((daysSinceLastContact - daysPerFrequency) / daysPerFrequency * 50).clamp(0, 100).toDouble();
      }
      
      totalHealth += healthScore;
      contactCount++;
    }
    
    return contactCount == 0 ? 100.0 : totalHealth / contactCount;
  }

  // List<Map<String, dynamic>> _calculateRelationshipHealth(List<Contact> contacts) {
  //   final healthData = <Map<String, dynamic>>[];
  //   final types = <String, List<double>>{};
    
  //   // Group contacts by type and calculate average health
  //   for (var contact in contacts) {
  //     if (!types.containsKey(contact.connectionType)) {
  //       types[contact.connectionType] = [];
  //     }
      
  //     final daysSinceLastContact = DateTime.now().difference(contact.lastContacted).inDays;
  //     final daysPerFrequency = contact.frequency * _getDaysInPeriod(contact.period);
      
  //     double healthScore = 100.0;
  //     if (daysSinceLastContact > daysPerFrequency) {
  //       healthScore = 100 - ((daysSinceLastContact - daysPerFrequency) / daysPerFrequency * 50).clamp(0, 100).toDouble();
  //     }
      
  //     types[contact.connectionType]!.add(healthScore);
  //   }
    
  //   // Calculate average health for each type
  //   types.forEach((type, scores) {
  //     final averageHealth = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
  //     healthData.add({'type': type, 'health': averageHealth.roundToDouble()});
  //   });
    
  //   return healthData;
  // }

  int _getDaysInPeriod(String period) {
    switch (period.toLowerCase()) {
      case 'daily': return 1;
      case 'weekly': return 7;
      case 'monthly': return 30;
      case 'quarterly': return 90;
      case 'annually': return 365;
      default: return 30;
    }
  }

  List<Map<String, dynamic>> _calculateInteractionPatterns(List<Nudge> nudges) {
    final interactionData = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    // Group interactions by week for the last 4 weeks
    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i + 1) * 7));
      final weekEnd = now.subtract(Duration(days: i * 7));
      
      final weekInteractions = nudges.where((nudge) => 
        nudge.isCompleted && 
        nudge.scheduledTime.isAfter(weekStart) && 
        nudge.scheduledTime.isBefore(weekEnd)
      ).length;
      
      interactionData.add({
        'period': 'Week ${4 - i}',
        'interactions': weekInteractions,
      });
    }
    
    return interactionData;
  }

  List<Map<String, dynamic>> _calculateVIPInteractions(List<Contact> vipContacts) {
    final interactionData = <Map<String, dynamic>>[];
    
    // Get top 5 VIP contacts by last contacted date (most recent first)
    final sortedContacts = vipContacts.toList()
      ..sort((a, b) => b.lastContacted.compareTo(a.lastContacted));
    
    for (int i = 0; i < sortedContacts.length && i < 5; i++) {
      final contact = sortedContacts[i];
      final daysSinceContact = DateTime.now().difference(contact.lastContacted).inDays;
      
      interactionData.add({
        'name': contact.name.split(' ')[0],
        'interactions': daysSinceContact,
      });
    }
    
    return interactionData;
  }

  Map<String, int> _calculateNudgePerformance(List<Nudge> nudges) {
    final scheduled = nudges.length;
    final completed = nudges.where((nudge) => nudge.isCompleted).length;
    final missed = nudges.where((nudge) => !nudge.isCompleted && nudge.scheduledTime.isBefore(DateTime.now())).length;
    final completionRate = scheduled == 0 ? 0 : (completed / scheduled * 100).round();
    
    return {
      'scheduled': scheduled,
      'completed': completed,
      'missed': missed,
      'completionRate': completionRate,
    };
  }

  int _calculateWeeklyConnections(List<Nudge> nudges) {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    
    return nudges.where((nudge) => 
      nudge.isCompleted && nudge.scheduledTime.isAfter(weekStart)
    ).length;
  }

  int _calculateMonthlyCatchups(List<Nudge> nudges) {
    final now = DateTime.now();
    final monthStart = now.subtract(const Duration(days: 30));
    
    return nudges.where((nudge) => 
      nudge.isCompleted && nudge.scheduledTime.isAfter(monthStart)
    ).length;
  }

  int _calculateVIPInteractionsCount(List<Contact> contacts) {
    return contacts.where((contact) => 
      contact.isVIP && contact.lastContacted.isAfter(DateTime.now().subtract(const Duration(days: 30)))
    ).length;
  }

  int _calculateNewConnections(List<Contact> contacts) {
    return contacts.where((contact) => 
      contact.lastContacted.isAfter(DateTime.now().subtract(const Duration(days: 30))) &&
      contact.interactionHistory.length <= 1
    ).length;
  }
}
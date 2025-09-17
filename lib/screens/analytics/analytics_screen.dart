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
// import 'package:intl/intl.dart';
import '../../services/auth_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final List<String> _timeFilters = ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'All Time'];
  String _selectedFilter = 'Last 30 Days';
  DateTime? _startDate;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Last 7 Days':
        _startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Last 90 Days':
        _startDate = now.subtract(const Duration(days: 90));
        break;
      case 'All Time':
        _startDate = null; // No filter
        break;
      case 'Last 30 Days':
      default:
        _startDate = now.subtract(const Duration(days: 30));
        break;
    }
  }

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
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics', style: AppTextStyles.title3.copyWith(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                _updateDateRange();
              });
            },
            itemBuilder: (BuildContext context) {
              return _timeFilters.map((String filter) {
                return PopupMenuItem<String>(
                  value: filter,
                  child: Text(filter),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: StreamProvider<List<Contact>>.value(
        value: apiService.getContactsStream(),
        initialData: const [],
        child: StreamProvider<List<Nudge>>.value(
          value: apiService.getNudgesStream(),
          initialData: const [],
          child: Consumer2<List<Contact>, List<Nudge>>(
            builder: (context, contacts, nudges, child) {
              // Calculate analytics data based on selected time filter
              final analytics = _calculateAnalytics(contacts, nudges);
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeFilterChip(),
                    const SizedBox(height: 16),
                    _buildSummarySection(analytics),
                    const SizedBox(height: 24),
                    _buildRelationshipHealthSection(analytics, contacts),
                    const SizedBox(height: 24),
                    _buildContactDistributionSection(analytics),
                    const SizedBox(height: 24),
                    _buildInteractionPatternsSection(analytics, nudges),
                    const SizedBox(height: 24),
                    _buildVIPContactsSection(analytics, contacts),
                    const SizedBox(height: 24),
                    _buildNudgePerformanceSection(analytics, nudges),
                    const SizedBox(height: 24),
                    _buildGoalsProgressSection(analytics),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 16),
        const SizedBox(width: 8),
        Chip(
          label: Text(_selectedFilter),
          backgroundColor: const Color.fromRGBO(37, 150, 190, 0.2),
        ),
      ],
    );
  }

  Widget _buildSummarySection(Analytics analytics) {
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
                _buildStatCard('Total Contacts', analytics.totalContacts.toString(), Icons.people),
                _buildStatCard('VIP Contacts', analytics.vipContacts.toString(), Icons.star),
                _buildStatCard('Needs Attention', analytics.contactsNeedingAttention.toString(), Icons.notifications_active),
              ],
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              animation: true,
              lineHeight: 20.0,
              animationDuration: 1000,
              percent: analytics.relationshipHealth / 100,
              center: Text("${analytics.relationshipHealth.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white)),
              barRadius: const Radius.circular(10),
              progressColor: _getProgressColor(analytics.relationshipHealth),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            const Text(
              'Relationship Health Score',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
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
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRelationshipHealthSection(Analytics analytics, List<Contact> contacts) {
    // Calculate health by relationship type
    final healthData = _calculateRelationshipHealth(contacts);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relationship Health by Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <ChartSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: healthData,
                    xValueMapper: (Map<String, dynamic> data, _) => data['type'],
                    yValueMapper: (Map<String, dynamic> data, _) => data['health'],
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    color: const Color.fromRGBO(45, 161, 175, 1),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Health score by relationship category',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactDistributionSection(Analytics analytics) {
    final data = analytics.contactsByType.entries.map((entry) {
      return {'type': entry.key, 'count': entry.value};
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                series: <CircularSeries>[
                  PieSeries<Map<String, dynamic>, String>(
                    dataSource: data,
                    xValueMapper: (Map<String, dynamic> data, _) => data['type'],
                    yValueMapper: (Map<String, dynamic> data, _) => data['count'],
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    enableTooltip: true,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              'Interaction Patterns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
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
            Text(
              'Interaction trends for $_selectedFilter',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              'VIP Contacts Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
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
                const Text('VIP Contact Engagement'),
                Chip(
                  label: Text('${vipContacts.length} VIPs', style: const TextStyle(color: Colors.white)),
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
              percent: (nudgePerformance['completionRate'] ?? 0 / 100).toDouble(),
              center: Text("${(nudgePerformance['completionRate'] ?? 0).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white)),
              barRadius: const Radius.circular(10),
              progressColor: _getProgressColor(nudgePerformance['completionRate']?.toDouble() ?? 0),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            const Text(
              'Nudge Completion Rate',
              style: TextStyle(fontSize: 12),
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

  Widget _buildGoalsProgressSection(Analytics analytics) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Goals Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildGoalProgressItem('Weekly Connections', analytics.weeklyConnections, 20),
            _buildGoalProgressItem('Monthly Catch-ups', analytics.monthlyCatchups, 40),
            _buildGoalProgressItem('VIP Interactions', analytics.vipInteractions, 15),
            _buildGoalProgressItem('New Connections', analytics.newConnections, 10),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressItem(String title, int current, int target) {
    final percentage = (current / target * 100).clamp(0, 100);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text('$current/$target'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(percentage.toDouble())),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}% complete',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return const Color.fromRGBO(45, 161, 175, 1);
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

   Analytics _calculateAnalytics(List<Contact> contacts, List<Nudge> nudges) {
    // Filter contacts and nudges based on selected time range
    final filteredContacts = _startDate != null
        ? contacts.where((contact) => contact.lastContacted.isAfter(_startDate!)).toList()
        : contacts;
    
    final filteredNudges = _startDate != null
        ? nudges.where((nudge) => nudge.scheduledTime.isAfter(_startDate!)).toList()
        : nudges;

    // Calculate various analytics metrics
    final vipCount = contacts.where((c) => c.isVIP).length;
    final needsAttention = contacts.where((c) => 
      c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
    ).length;
    
    // Count contacts by type
    final contactsByType = <String, int>{};
    for (var contact in filteredContacts) {
      contactsByType[contact.connectionType] = 
          (contactsByType[contact.connectionType] ?? 0) + 1;
    }
    
    // Calculate relationship health score
    final relationshipHealth = contacts.isEmpty ? 0.0 : 
        (contacts.length - needsAttention) / contacts.length * 100;
    
    // Calculate interaction metrics
    final completedNudges = filteredNudges.where((nudge) => nudge.isCompleted).length;
    // final pendingNudges = filteredNudges.where((nudge) => !nudge.isCompleted).length;
    
    // Calculate goal progress
    final weeklyConnections = _calculateWeeklyConnections(filteredNudges);
    final monthlyCatchups = _calculateMonthlyCatchups(filteredNudges);
    final vipInteractions = _calculateVIPInteractionsCount(filteredContacts);
    final newConnections = _calculateNewConnections(filteredContacts);
    
    return Analytics(
      totalContacts: contacts.length,
      vipContacts: vipCount,
      completedNudges: completedNudges,
      // pendingNudges: pendingNudges,
      contactsNeedingAttention: needsAttention,
      contactsByType: contactsByType,
      relationshipHealth: relationshipHealth,
      weeklyConnections: weeklyConnections,
      monthlyCatchups: monthlyCatchups,
      vipInteractions: vipInteractions,
      newConnections: newConnections,
      lastUpdated: DateTime.now(),
    );
  }

  List<Map<String, dynamic>> _calculateRelationshipHealth(List<Contact> contacts) {
    final healthData = <Map<String, dynamic>>[];
    final types = <String, List<int>>{};
    
    // Group contacts by type and calculate average health
    for (var contact in contacts) {
      if (!types.containsKey(contact.connectionType)) {
        types[contact.connectionType] = [];
      }
      
      // Calculate health score for this contact (simplified)
      final daysSinceLastContact = DateTime.now().difference(contact.lastContacted).inDays;
      final healthScore = 100 - (daysSinceLastContact / 30 * 100).clamp(0, 100).toInt();
      
      types[contact.connectionType]!.add(healthScore);
    }
    
    // Calculate average health for each type
    types.forEach((type, scores) {
      final averageHealth = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) ~/ scores.length;
      healthData.add({'type': type, 'health': averageHealth});
    });
    
    return healthData;
  }

  List<Map<String, dynamic>> _calculateInteractionPatterns(List<Nudge> nudges) {
    final interactionData = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    // Group interactions by week
    for (int i = 0; i < 4; i++) {
      final weekStart = now.subtract(Duration(days: (3 - i) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      final weekInteractions = nudges.where((nudge) => 
        nudge.isCompleted && 
        nudge.scheduledTime.isAfter(weekStart) && 
        nudge.scheduledTime.isBefore(weekEnd)
      ).length;
      
      interactionData.add({
        'period': 'Week ${i + 1}',
        'interactions': weekInteractions,
      });
    }
    
    return interactionData;
  }

  List<Map<String, dynamic>> _calculateVIPInteractions(List<Contact> vipContacts) {
    final interactionData = <Map<String, dynamic>>[];
    
    // Get top 5 VIP contacts by interaction frequency
    final sortedContacts = vipContacts.toList()
      ..sort((a, b) => b.interactionHistory.length.compareTo(a.interactionHistory.length));
    
    for (int i = 0; i < sortedContacts.length && i < 5; i++) {
      final contact = sortedContacts[i];
      interactionData.add({
        'name': contact.name.split(' ')[0],
        'interactions': contact.interactionHistory.length,
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
// Updated analytics_screen.dart
// lib/screens/analytics/analytics_screen.dart
import 'package:flutter/material.dart';
// import 'package:nudge/models/analytics.dart';
import 'package:nudge/models/contact.dart';
// import 'package:nudge/models/nudge.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:percent_indicator/percent_indicator.dart';
import '../../services/auth_service.dart';
// import '../../services/nudge_service.dart';

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
    
    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono')),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
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
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Text('Analytics', style: AppTextStyles.title3.copyWith(color: Colors.black, fontWeight: FontWeight.w700, fontFamily: 'Quicksand')),
                ),
                const SizedBox(height: 24),
                
                // Contact Distribution Pie Chart
                _buildContactDistributionSection(contacts),
                const SizedBox(height: 24),
                
                // Additional insights can be added here in the future
                _buildAdditionalInsightsSection(contacts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactDistributionSection(List<Contact> contacts) {
    final distributionData = _calculateContactDistribution(contacts);
    
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
            
            if (distributionData.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No contacts yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 300,
                child: SfCircularChart(
                  title: ChartTitle(text: 'Contacts by Category'),
                  legend: Legend(
                    isVisible: true,
                    overflowMode: LegendItemOverflowMode.wrap,
                    position: LegendPosition.bottom,
                  ),
                  series: <CircularSeries>[
                    PieSeries<Map<String, dynamic>, String>(
                      dataSource: distributionData,
                      xValueMapper: (Map<String, dynamic> data, _) => data['category'],
                      yValueMapper: (Map<String, dynamic> data, _) => data['count'],
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      pointColorMapper: (Map<String, dynamic> data, _) => _getCategoryColor(data['category']),
                      explode: true,
                      explodeIndex: 0,
                    )
                  ],
                  tooltipBehavior: TooltipBehavior(enable: true),
                ),
              ),
            
            const SizedBox(height: 16),
            if (distributionData.isNotEmpty)
              _buildDistributionLegend(distributionData),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionLegend(List<Map<String, dynamic>> distributionData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribution Summary',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Column(
          children: distributionData.map((data) {
            final percentage = (data['count'] / distributionData.fold(0, (sum, item) => (sum + item['count']).toInt())) * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(data['category']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['category'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${data['count']} (${percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdditionalInsightsSection(List<Contact> contacts) {
    final totalContacts = contacts.length;
    final vipContacts = contacts.where((c) => c.isVIP).length;
    final needsAttention = contacts.where((c) => 
      c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
    ).length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInsightItem('Total Contacts', totalContacts.toString(), Icons.people),
                _buildInsightItem('Close Circle', vipContacts.toString(), Icons.star),
                _buildInsightItem('Needs Care', needsAttention.toString(), Icons.warning),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'More detailed analytics coming soon as your network grows!',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color.fromRGBO(45, 161, 175, 1)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _calculateContactDistribution(List<Contact> contacts) {
    final categoryCounts = <String, int>{};
    
    for (var contact in contacts) {
      final category = contact.connectionType.isEmpty ? 'Uncategorized' : contact.connectionType;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }
    
    // Convert to list and sort by count (descending)
    final distributionList = categoryCounts.entries.map((entry) {
      return {
        'category': entry.key,
        'count': entry.value,
      };
    }).toList();
    
    distributionList.sort((a, b) {
      int bcount = b['count'] as int;
      int acount = a['count'] as int;
      return (bcount.compareTo(acount));
    });
    
    return distributionList;
  }

  Color _getCategoryColor(String category) {
    // Generate consistent colors based on category
    final colors = [
      const Color.fromRGBO(45, 161, 175, 1), // Primary teal
      Colors.green[600]!,
      Colors.purple[600]!,
      Colors.amber[700]!,
      Colors.pink[600]!,
      Colors.brown[600]!,
      Colors.indigo[600]!,
      Colors.orange[600]!,
      Colors.blue[600]!,
    ];
    
    final index = category.hashCode % colors.length;
    return colors[index];
  }
}
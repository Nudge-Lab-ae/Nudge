import 'package:flutter/material.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class SetGoalsScreen extends StatefulWidget {
  const SetGoalsScreen({super.key});

  @override
  State<SetGoalsScreen> createState() => _SetGoalsScreenState();
}

class _SetGoalsScreenState extends State<SetGoalsScreen> {
  final Map<String, Map<String, dynamic>> _groupSettings = {
    'Family': {'period': 'Monthly', 'frequency': 4.0},
    'Friends': {'period': 'Quarterly', 'frequency': 8.0},
    'Clients': {'period': 'Annually', 'frequency': 2.0},
  };

  final Map<String, Map<String, dynamic>> _periodRanges = {
    'Monthly': {'min': 1, 'max': 31, 'divisions': 30},
    'Quarterly': {'min': 1, 'max': 13, 'divisions': 12},
    'Annually': {'min': 1, 'max': 53, 'divisions': 52},
  };

  String _getFrequencyLabel(String period, double frequency) {
    switch (period) {
      case 'Monthly':
        return '${frequency.toInt()} times per month';
      case 'Quarterly':
        return '${frequency.toInt()} times per quarter';
      case 'Annually':
        return '${frequency.toInt()} times per year';
      default:
        return '${frequency.toInt()} times';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NUDGE'),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Goals',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Adjust how often you want to engage with each group of contacts.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            
            // Family Settings
            _buildGroupSettings('Family'),
            const SizedBox(height: 30),
            
            // Friends Settings
            _buildGroupSettings('Friends'),
            const SizedBox(height: 30),
            
            // Clients Settings
            _buildGroupSettings('Clients'),
            const SizedBox(height: 50),
            
            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  
                  // Convert settings to the format expected by the backend
                  final groups = _groupSettings.entries.map((entry) {
                    return {
                      'name': entry.key,
                      'period': entry.value['period'],
                      'frequency': entry.value['frequency'].toInt().toString(),
                    };
                  }).toList();
                  
                  // Save settings to backend
                  await apiService.updateUser({
                    'groups': groups,
                  });
                  
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSettings(String groupName) {
    final settings = _groupSettings[groupName]!;
    final period = settings['period'] as String;
    final frequency = settings['frequency'] as double;
    final range = _periodRanges[period]!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          groupName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        
        // Period Selection
        Text(
          'Contact Period:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPeriodButton('Monthly', period == 'Monthly', groupName),
            _buildPeriodButton('Quarterly', period == 'Quarterly', groupName),
            _buildPeriodButton('Annually', period == 'Annually', groupName),
          ],
        ),
        const SizedBox(height: 20),
        
        // Frequency Selection with Slider
        Text(
          _getFrequencyLabel(period, frequency),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        Slider(
          value: frequency,
          min: range['min']!.toDouble(),
          max: range['max']!.toDouble(),
          divisions: range['divisions'],
          label: frequency.toInt().toString(),
          onChanged: (value) {
            setState(() {
              _groupSettings[groupName]!['frequency'] = value;
            });
          },
        ),
        
        // Min and Max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              range['min'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              range['max'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodButton(String period, bool isSelected, String groupName) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _groupSettings[groupName]!['period'] = period;
              // Reset frequency to middle value when period changes
              final range = _periodRanges[period]!;
              _groupSettings[groupName]!['frequency'] = 
                  (range['min']! + range['max']!) / 2.0;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? const Color.fromRGBO(37, 150, 190, 1)
                : Colors.grey[200],
            foregroundColor: isSelected ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(period),
        ),
      ),
    );
  }
}
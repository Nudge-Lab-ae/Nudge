import 'package:flutter/material.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class SetGoalsScreen extends StatefulWidget {
  final bool isFromSettings;
  
  const SetGoalsScreen({super.key, this.isFromSettings = false});

  @override
  State<SetGoalsScreen> createState() => _SetGoalsScreenState();
}

class _SetGoalsScreenState extends State<SetGoalsScreen> {
  late Map<String, Map<String, dynamic>> _groupSettings;
  bool _isLoading = true;

  final Map<String, Map<String, dynamic>> _periodRanges = {
    'Monthly': {'min': 1, 'max': 31, 'divisions': 30},
    'Quarterly': {'min': 1, 'max': 13, 'divisions': 12},
    'Annually': {'min': 1, 'max': 53, 'divisions': 52},
  };

  @override
  void initState() {
    super.initState();
    _loadUserGoals();
  }

  Future<void> _loadUserGoals() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final user = await apiService.getUser();
      
      // Initialize with default settings if user has no groups
      if (user.groups == null || user.groups!.isEmpty) {
        _groupSettings = {
          'Family': {'period': 'Monthly', 'frequency': 4.0},
          'Friend': {'period': 'Quarterly', 'frequency': 8.0},
          'Client': {'period': 'Monthly', 'frequency': 2.0},
          'Colleague': {'period': 'Annually', 'frequency': 4.0},
          'Mentor': {'period': 'Annually', 'frequency': 2.0},
        };
      } else {
        // Convert user's groups to our settings format
        _groupSettings = {};
        for (var group in user.groups!) {
          _groupSettings[group['name']] = {
            'period': group['period'],
            'frequency': double.parse(group['frequency']),
          };
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user goals: $e');
      // Fallback to default settings
      _groupSettings = {
        'Family': {'period': 'Monthly', 'frequency': 4.0},
        'Friend': {'period': 'Quarterly', 'frequency': 8.0},
        'Client': {'period': 'Monthly', 'frequency': 2.0},
        'Colleague': {'period': 'Annually', 'frequency': 4.0},
        'Mentor': {'period': 'Annually', 'frequency': 2.0},
      };
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  Future<void> _saveGoals() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Convert settings to the format expected by the backend
      final groups = _groupSettings.entries.map((entry) {
        return {
          'name': entry.key,
          'period': entry.value['period'],
          'frequency': entry.value['frequency'].toInt(),
        };
      }).toList();
      
      // Save settings to backend
      await apiService.updateUser({
        'groups': groups,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goals updated successfully!'),
        ),
      );
      
      // Navigate based on where we came from
      if (widget.isFromSettings) {
        Navigator.pop(context); // Go back to settings
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving goals: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NUDGE'),
          backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Goals', style: AppTextStyles.title2.copyWith(color: Colors.white),),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        leading: widget.isFromSettings
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   widget.isFromSettings ? 'Edit Goals' : 'Set Goals',
            //   style: const TextStyle(
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
            // const SizedBox(height: 10),
            Text(
              widget.isFromSettings 
                ? 'Adjust how often you want to engage with each group of contacts.'
                : 'Adjust the default level of how often you want to engage with each group of contacts. This can be edited later by group or person.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            
            // Family Settings
            _buildGroupSettings('Family'),
            const SizedBox(height: 30),
            
            // Friends Settings
            _buildGroupSettings('Friend'),
            const SizedBox(height: 30),
            
            // Clients Settings
            _buildGroupSettings('Client'),
            const SizedBox(height: 50),

            _buildGroupSettings('Colleague'),
            const SizedBox(height: 50),

            _buildGroupSettings('Mentor'),
            const SizedBox(height: 50),
            
            // Continue/Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveGoals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.isFromSettings ? 'Save Changes' : 'Continue',
                  style: const TextStyle(
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
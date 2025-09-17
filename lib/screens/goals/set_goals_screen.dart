// lib/screens/set_goals_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/social_group.dart';

class SetGoalsScreen extends StatefulWidget {
  final bool isFromSettings;
  
  const SetGoalsScreen({super.key, this.isFromSettings = false});

  @override
  State<SetGoalsScreen> createState() => _SetGoalsScreenState();
}

class _SetGoalsScreenState extends State<SetGoalsScreen> {
  late List<SocialGroup> _userGroups;
  bool _isLoading = true;
  bool _isManagingGroups = false;
  final Map<String, SocialGroup> _groupsBeingEdited = {};

  final Map<String, Map<String, dynamic>> _periodRanges = {
    'Weekly': {'min': 1, 'max': 7, 'divisions': 6},
    'Monthly': {'min': 1, 'max': 7, 'divisions': 6},
    'Quarterly': {'min': 1, 'max': 7, 'divisions': 6},
    'Annually': {'min': 1, 'max': 7, 'divisions': 6},
  };

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final groups = await apiService.getGroupsStream().first;
      
      setState(() {
        _userGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user groups: $e');
      // Fallback to default groups
      _userGroups = [
        SocialGroup(
          id: '1',
          name: 'Family',
          description: 'Family members',
          period: 'Monthly',
          frequency: 4,
          memberIds: [],
          memberCount: 0,
          lastInteraction: DateTime.now(),
          colorCode: '#2596BE',
        ),
        SocialGroup(
          id: '2',
          name: 'Friend',
          description: 'Friends',
          period: 'Quarterly',
          frequency: 8,
          memberIds: [],
          memberCount: 0,
          lastInteraction: DateTime.now(),
          colorCode: '#FF6F61',
        ),
        SocialGroup(
          id: '3',
          name: 'Client',
          description: 'Clients',
          period: 'Monthly',
          frequency: 2,
          memberIds: [],
          memberCount: 0,
          lastInteraction: DateTime.now(),
          colorCode: '#81C784',
        ),
        SocialGroup(
          id: '4',
          name: 'Colleague',
          description: 'Colleagues',
          period: 'Annually',
          frequency: 4,
          memberIds: [],
          memberCount: 0,
          lastInteraction: DateTime.now(),
          colorCode: '#FFC107',
        ),
        SocialGroup(
          id: '5',
          name: 'Mentor',
          description: 'Mentors',
          period: 'Annually',
          frequency: 2,
          memberIds: [],
          memberCount: 0,
          lastInteraction: DateTime.now(),
          colorCode: '#607D8B',
        ),
      ];
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFrequencyLabel(String period, double frequency) {
    switch (period) {
      case 'Weekly':
        return '${frequency.toInt()} times per week';
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
      
      // Update each group with new settings
      await apiService.updateGroups(_userGroups);
      
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

  void _toggleGroupManagement() {
    setState(() {
      _isManagingGroups = !_isManagingGroups;
      _groupsBeingEdited.clear();
    });
  }

  void _addNewGroup() {
    final newGroup = SocialGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New Group',
      description: '',
      period: 'Monthly',
      frequency: 2,
      memberIds: [],
      memberCount: 0,
      lastInteraction: DateTime.now(),
      colorCode: '#2596BE',
    );
    
    setState(() {
      _userGroups.add(newGroup);
      _groupsBeingEdited[newGroup.id] = newGroup;
    });
  }

  void _editGroup(SocialGroup group) {
    setState(() {
      _groupsBeingEdited[group.id] = SocialGroup(
        id: group.id,
        name: group.name,
        description: group.description,
        period: group.period,
        frequency: group.frequency,
        memberIds: List.from(group.memberIds),
        memberCount: group.memberCount,
        lastInteraction: group.lastInteraction,
        colorCode: group.colorCode,
      );
    });
  }

  void _saveGroupEdit(String groupId) {
    final editedGroup = _groupsBeingEdited[groupId];
    if (editedGroup != null) {
      final index = _userGroups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        setState(() {
          _userGroups[index] = editedGroup;
          _groupsBeingEdited.remove(groupId);
        });
      }
    }
  }

  void _cancelGroupEdit(String groupId) {
    setState(() {
      _groupsBeingEdited.remove(groupId);
    });
  }

  void _deleteGroup(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Are you sure you want to delete this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userGroups.removeWhere((group) => group.id == groupId);
                _groupsBeingEdited.remove(groupId);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NUDGE'),
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isManagingGroups ? 'Manage Groups' : 'Edit Goals', 
          style: AppTextStyles.title2.copyWith(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        leading: widget.isFromSettings
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              _isManagingGroups ? Icons.checklist : Icons.group,
              color: Colors.white,
            ),
            onPressed: _toggleGroupManagement,
            tooltip: _isManagingGroups ? 'Set Goals' : 'Manage Groups',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isManagingGroups) ...[
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
              
              // Build settings for each group
              ..._userGroups.map((group) => Column(
                children: [
                  _buildGroupSettings(group),
                  const SizedBox(height: 30),
                ],
              )).toList(),
            ] else ...[
              const Text(
                'Manage your contact groups. Add, edit, or remove groups to organize your contacts.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              
              // Add new group button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addNewGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // List of groups for management
              ..._userGroups.map((group) => 
                _buildGroupManagementItem(group)
              ).toList(),
            ],
            
            // Continue/Save Button
            if (!_isManagingGroups) SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveGoals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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

  Widget _buildGroupSettings(SocialGroup group) {
    final range = _periodRanges[group.period]!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name,
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
            _buildPeriodButton('Weekly', group.period == 'Weekly', group),
            _buildPeriodButton('Monthly', group.period == 'Monthly', group),
            _buildPeriodButton('Quarterly', group.period == 'Quarterly', group),
            _buildPeriodButton('Annually', group.period == 'Annually', group),
          ],
        ),
        const SizedBox(height: 20),
        
        // Frequency Selection with Slider
        Text(
          _getFrequencyLabel(group.period, group.frequency.toDouble()),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        Slider(
          value: group.frequency.toDouble(),
          min: range['min']!.toDouble(),
          max: range['max']!.toDouble(),
          divisions: range['divisions'],
          label: group.frequency.toString(),
          onChanged: (value) {
            setState(() {
              group.frequency = value.toInt();
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

  Widget _buildGroupManagementItem(SocialGroup group) {
    final isEditing = _groupsBeingEdited.containsKey(group.id);
    final editedGroup = isEditing ? _groupsBeingEdited[group.id]! : group;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEditing) ...[
              TextFormField(
                initialValue: editedGroup.name,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _groupsBeingEdited[group.id] = editedGroup.copyWith(name: value);
                  });
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                initialValue: editedGroup.description,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) {
                  setState(() {
                    _groupsBeingEdited[group.id] = editedGroup.copyWith(description: value);
                  });
                },
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _saveGroupEdit(group.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                  ElevatedButton(
                    onPressed: () => _cancelGroupEdit(group.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (group.description.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            group.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editGroup(group),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteGroup(group.id),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period, bool isSelected, SocialGroup group) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              group.period = period;
              // Reset frequency to middle value when period changes
              final range = _periodRanges[period]!;
              group.frequency = ((range['min']! + range['max']!) / 2).toInt();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? const Color.fromRGBO(45, 161, 175, 1)
                : Colors.grey[200],
            foregroundColor: isSelected ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(period, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
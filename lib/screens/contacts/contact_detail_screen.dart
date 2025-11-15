// contact_detail_screen.dart - Updated with Close Circle toggle, Social Tags, and Scheduled Nudges
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/smart_tagging_suggestions.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;
  
  const ContactDetailScreen({super.key, required this.contact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late Contact _currentContact;
  bool _isUpdatingVIP = false;

  @override
  void initState() {
    super.initState();
    _currentContact = widget.contact;
  }

  Future<void> _toggleVIPStatus(bool isVIP) async {
    if (_isUpdatingVIP) return;
    
    setState(() {
      _isUpdatingVIP = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final updatedContact = _currentContact.copyWith(isVIP: isVIP);
        await apiService.updateContact(updatedContact);
        
        setState(() {
          _currentContact = updatedContact;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVIP ? 'Added to Close Circle' : 'Removed from Close Circle')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating Close Circle status: $e')),
      );
    } finally {
      setState(() {
        _isUpdatingVIP = false;
      });
    }
  }

  Future<void> _editNextNudge() async {
    // Show dialog to edit next nudge schedule
    showDialog(
      context: context,
      builder: (context) {
        return _NextNudgeDialog(contact: _currentContact);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // final authService = Provider.of<AuthService>(context);
    final apiService = Provider.of<ApiService>(context);
    // final user = authService.currentUser;
    // var size = MediaQuery.of(context).size;
    
    bool isLocalImage = _currentContact.imageUrl.isNotEmpty && 
        (_currentContact.imageUrl.startsWith('/') || 
         _currentContact.imageUrl.startsWith('file://'));
    
    bool hasNoInfo = _currentContact.phoneNumber.isEmpty &&
        _currentContact.email.isEmpty &&
        _currentContact.notes.isEmpty &&
        _currentContact.birthday == null &&
        _currentContact.anniversary == null &&
        _currentContact.workAnniversary == null;

    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditContactScreen(contactId: _currentContact.id),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              apiService.triggerManualNudge(_currentContact.id);
            },
            tooltip: 'Send test nudge',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Color.fromRGBO(45, 161, 175, 1),
                    backgroundImage: _currentContact.imageUrl.isNotEmpty
                        ? isLocalImage
                            ? FileImage(File(_currentContact.imageUrl.replaceFirst('file://', '')))
                            : NetworkImage(_currentContact.imageUrl) as ImageProvider
                        : null,
                    child: _currentContact.imageUrl.isEmpty 
                        ? const Icon(Icons.person, size: 40) 
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _currentContact.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (_currentContact.profession != null && _currentContact.profession!.isNotEmpty)
                    Text(
                      _currentContact.profession!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            // Close Circle Toggle
            Card(
              child: ListTile(
                leading: Icon(Icons.star, color: _currentContact.isVIP ? Colors.amber : Colors.grey),
                title: Text('Close Circle', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_currentContact.isVIP 
                    ? 'This contact is in your Close Circle' 
                    : 'Add to your Close Circle for special attention'),
                trailing: _isUpdatingVIP
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(
                        value: _currentContact.isVIP,
                        onChanged: _toggleVIPStatus,
                        activeColor: Color.fromRGBO(45, 161, 175, 1),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Contact Information Section
            if (_currentContact.phoneNumber.isNotEmpty || _currentContact.email.isNotEmpty) ...[
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              
              if (_currentContact.phoneNumber.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone', style: TextStyle(fontWeight: FontWeight.w600),),
                  subtitle: Text(_currentContact.phoneNumber),
                ),
              
              if (_currentContact.email.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email', style: TextStyle(fontWeight: FontWeight.w600),),
                  subtitle: Text(_currentContact.email),
                ),
              const SizedBox(height: 20),
            ],
            
            // Connection Details Section
            const Text(
              'Connection Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Connection Type', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Text(_currentContact.connectionType),
            ),

            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Contact Period', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Text(_currentContact.period.toString()),
            ),
            
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Contact Frequency', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Text('${_currentContact.frequency} times per ${_currentContact.period.toLowerCase()}'),
            ),
            
            if (_currentContact.socialGroups.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Social Groups', style: TextStyle(fontWeight: FontWeight.w600),),
                subtitle: Text(_currentContact.socialGroups.join(', ')),
              ),
            
            // Social Tags Section (Renamed from Tag Suggestions)
            const SizedBox(height: 24),
            const Text(
              'Social Tags',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SmartTaggingSuggestions(contact: _currentContact),
            
            // Important Dates Section
            if (_currentContact.birthday != null || _currentContact.anniversary != null || _currentContact.workAnniversary != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Important Dates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              
              if (_currentContact.birthday != null)
                ListTile(
                  leading: const Icon(Icons.cake),
                  title: const Text('Birthday'),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.birthday!)),
                ),
              
              if (_currentContact.anniversary != null)
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('Anniversary'),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.anniversary!)),
                ),
              
              if (_currentContact.workAnniversary != null)
                ListTile(
                  leading: const Icon(Icons.work),
                  title: const Text('Work Anniversary'),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.workAnniversary!)),
                ),
            ],
            
            // Notes Section
            if (_currentContact.notes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(_currentContact.notes),
            ],
            
            // Contextual message when no info
            if (hasNoInfo) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    Text(
                      'Add your first Close Circle contact for better insights.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
            // Scheduled Nudges Section (Replaces Snooze/Done buttons)
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scheduled Nudges',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Next nudge scheduled based on your ${_currentContact.period.toLowerCase()} frequency',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Frequency: ${_currentContact.frequency}x/${_currentContact.period.toLowerCase()}',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Connection Type: ${_currentContact.connectionType}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: Color.fromRGBO(45, 161, 175, 1)),
                          onPressed: _editNextNudge,
                          tooltip: 'Edit Nudge Schedule',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Dialog for editing next nudge schedule
class _NextNudgeDialog extends StatefulWidget {
  final Contact contact;
  
  const _NextNudgeDialog({required this.contact});

  @override
  State<_NextNudgeDialog> createState() => __NextNudgeDialogState();
}

class __NextNudgeDialogState extends State<_NextNudgeDialog> {
  late String _selectedPeriod;
  late int _selectedFrequency;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.contact.period;
    _selectedFrequency = widget.contact.frequency;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Nudge Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Adjust how often you want to be reminded to contact ${widget.contact.name}'),
          const SizedBox(height: 20),
          
          // Period Selection
          const Text('Contact Period:', style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButton<String>(
            value: _selectedPeriod,
            onChanged: (String? newValue) {
              setState(() {
                _selectedPeriod = newValue!;
              });
            },
            items: <String>['Daily', 'Weekly', 'Monthly', 'Quarterly', 'Annually']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),
          
          // Frequency Selection
          const Text('Times per period:', style: TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _selectedFrequency.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: _selectedFrequency.toString(),
            onChanged: (double value) {
              setState(() {
                _selectedFrequency = value.toInt();
              });
            },
          ),
          Text('$_selectedFrequency times', textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final apiService = Provider.of<ApiService>(context, listen: false);
              final updatedContact = widget.contact.copyWith(
                period: _selectedPeriod,
                frequency: _selectedFrequency,
              );
              
              await apiService.updateContact(updatedContact);
              Navigator.of(context).pop();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated nudge schedule for ${widget.contact.name}')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating schedule: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
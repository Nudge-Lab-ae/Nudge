// contact_detail_screen.dart - Updated with Close Circle toggle, Social Tags, and Scheduled Nudges
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
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

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    
    // Trim and split the name by spaces
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      // Has at least first and last name - get first letter of first and last name
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      // Only first name available
      return parts.first[0].toUpperCase();
    }
    
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    // final authService = Provider.of<AuthService>(context);
    final apiService = Provider.of<ApiService>(context);
    // final user = authService.currentUser;
    var size = MediaQuery.of(context).size;
    final initials = _getContactInitials(_currentContact.name);
    
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
        title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
              gradient: const LinearGradient(
          colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        ),
        // Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Color(0xff3CB3E9), fontFamily: 'RobotoMono'),),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xff3CB3E9)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: size.height*0.4),
        child: FeedbackFloatingButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                 Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 80,
          backgroundColor: Colors.transparent, // Removed blue background
          backgroundImage: _currentContact.imageUrl.isNotEmpty
              ? isLocalImage
                  ? FileImage(File(_currentContact.imageUrl.replaceFirst('file://', '')))
                  : NetworkImage(_currentContact.imageUrl) as ImageProvider
              : AssetImage('assets/contact-icons/${getRandomIndex(_currentContact.id)}.png') as ImageProvider,
          child: _currentContact.imageUrl.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/contact-icons/${getRandomIndex(_currentContact.id)}.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _currentContact.name.isNotEmpty ?initials.toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
                  const SizedBox(height: 15),
                  Text(
                    (_currentContact.name).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff555555)
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
                title: Text('Close Circle', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
                subtitle: Text(_currentContact.isVIP 
                    ? 'This contact is in your Close Circle' 
                    : 'Add to your Close Circle for special attention'),
                trailing: _isUpdatingVIP
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(
                        value: _currentContact.isVIP,
                        onChanged: _toggleVIPStatus,
                        activeColor: Color(0xff3CB3E9),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Contact Information Section
            if (_currentContact.phoneNumber.isNotEmpty || _currentContact.email.isNotEmpty) ...[
              const Text(
                'CONTACT INFORMATION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff6e6e6e),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              
              if (_currentContact.phoneNumber.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone, color: Color(0xff555555),),
                  title: const Text('Phone', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555)),),
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
              'CONNECTION DETAILS',
              style: TextStyle(
                fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff6e6e6e),
              letterSpacing: 1.0,

              ),
            ),
            const SizedBox(height: 10),
            
            ListTile(
              leading: const Icon(Icons.category, color: Color(0xff555555)),
              title: const Text('Connection Type', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555)),),
              subtitle: Text(_currentContact.connectionType),
            ),

            // ListTile(
            //   leading: const Icon(Icons.schedule),
            //   title: const Text('Contact Period', style: TextStyle(fontWeight: FontWeight.w600),),
            //   subtitle: Text(_currentContact.period.toString()),
            // ),
            
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Contact Frequency', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555)),),
            subtitle: Text(FrequencyPeriodMapper.getConversationalChoice(_currentContact.frequency, _currentContact.period)),
          ),
            
            if (_currentContact.socialGroups.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Social Groups', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555)),),
                subtitle: Text(_currentContact.socialGroups.join(', ')),
              ),
            
            // Social Tags Section (Renamed from Tag Suggestions)
            const SizedBox(height: 24),
            const Text(
              'SOCIAL TAGS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xff6e6e6e),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            SmartTaggingSuggestions(contact: _currentContact),
            
            // Important Dates Section
            if (_currentContact.birthday != null || _currentContact.anniversary != null || _currentContact.workAnniversary != null) ...[
              const SizedBox(height: 20),
              const Text(
                'IMPORTANT DATES',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              
              if (_currentContact.birthday != null)
                ListTile(
                  leading: const Icon(Icons.cake),
                  title: const Text('Birthday', style: TextStyle(color: Color(0xff555555)),),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.birthday!)),
                ),
              
              if (_currentContact.anniversary != null)
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('Anniversary', style: TextStyle(color: Color(0xff555555)),),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.anniversary!)),
                ),
              
              if (_currentContact.workAnniversary != null)
                ListTile(
                  leading: const Icon(Icons.work),
                  title: const Text('Work Anniversary', style: TextStyle(color: Color(0xff555555)),),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.workAnniversary!)),
                ),
            ],
            
            // Notes Section
            if (_currentContact.notes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Notes',
                style: TextStyle(
                  color: Color(0xff555555),
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
                      'SCHEDULED NUDGES',
                      style: TextStyle(
                        color: Color(0xff6e6e6e),
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
                                'Frequency: ${FrequencyPeriodMapper.getConversationalChoice(_currentContact.frequency, _currentContact.period)}',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555)),
                              ),
                              Text(
                                'Connection Type: ${_currentContact.connectionType}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14,),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: Color(0xff3CB3E9)),
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

  int getRandomIndex(String seed) {
  if (seed.isEmpty) return 1;
  var hash = 0;
  for (var i = 0; i < seed.length; i++) {
    hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return (hash.abs() % 6) + 1;
}

}

// Replace the entire _NextNudgeDialog class with this updated version:

class _NextNudgeDialog extends StatefulWidget {
  final Contact contact;
  
  const _NextNudgeDialog({required this.contact});

  @override
  State<_NextNudgeDialog> createState() => __NextNudgeDialogState();
}

class __NextNudgeDialogState extends State<_NextNudgeDialog> {
  late String _selectedFrequencyChoice;

  @override
  void initState() {
    super.initState();
    _selectedFrequencyChoice = FrequencyPeriodMapper.getConversationalChoice(
      widget.contact.frequency, 
      widget.contact.period
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Nudge Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Adjust how often you want to be reminded to contact ${widget.contact.name}'),
          const SizedBox(height: 20),
          
          // Frequency Selection with Conversational Options
          const Text('Contact Frequency:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedFrequencyChoice,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: FrequencyPeriodMapper.frequencyMapping.keys.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFrequencyChoice = newValue;
                });
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // Show what the selection means
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Color(0xff3CB3E9), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getFrequencyDescription(_selectedFrequencyChoice),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              final frequencyData = FrequencyPeriodMapper.getFrequencyPeriod(_selectedFrequencyChoice);
              
              final updatedContact = widget.contact.copyWith(
                period: frequencyData['period'] as String,
                frequency: frequencyData['frequency'] as int,
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
            backgroundColor: const Color(0xff3CB3E9),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  String _getFrequencyDescription(String frequencyChoice) {
    final data = FrequencyPeriodMapper.getFrequencyPeriod(frequencyChoice);
    final frequency = data['frequency'];
    final period = data['period'];
    
    switch (frequencyChoice) {
      case 'Every few days':
        return 'You\'ll be reminded to contact ${widget.contact.name} multiple times per week';
      case 'Weekly':
        return 'You\'ll be reminded to contact ${widget.contact.name} once per week';
      case 'Every 2 weeks':
        return 'You\'ll be reminded to contact ${widget.contact.name} twice per month';
      case 'Monthly':
        return 'You\'ll be reminded to contact ${widget.contact.name} once per month';
      case 'Quarterly':
        return 'You\'ll be reminded to contact ${widget.contact.name} once every 3 months';
      case 'Twice a year':
        return 'You\'ll be reminded to contact ${widget.contact.name} twice per year';
      case 'Once a year':
        return 'You\'ll be reminded to contact ${widget.contact.name} once per year';
      default:
        return 'You\'ll be reminded to contact ${widget.contact.name} $frequency times per $period';
    }
  }
}
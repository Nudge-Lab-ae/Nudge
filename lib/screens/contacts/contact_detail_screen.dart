// contact_detail_screen.dart - Updated with Close Circle toggle, Social Tags, and Scheduled Nudges
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/theme/text_styles.dart';
// import 'package:nudge/widgets/add_touchpoint_modal.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';

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
        title: Text('Contact Details', style: AppTextStyles.title2.copyWith(color: Color(0xff555555))),
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
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 50, right: 6),
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
                    (_currentContact.name),
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
                        inactiveThumbColor: Color(0xff555555),
                        inactiveTrackColor: Color(0xffaaaaaa),
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
            
            const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showLogInteractionModal(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3CB3E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 20, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'LOG INTERACTION',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogInteractionModal(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _LogInteractionModal(
            apiService: apiService,
            contact: _currentContact,
          ),
        );
      },
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

// Custom modal that shows only the log interaction part (without contact selection)
class _LogInteractionModal extends StatefulWidget {
  final ApiService apiService;
  final Contact contact;
  
  const _LogInteractionModal({
    required this.apiService,
    required this.contact,
  });

  @override
  State<_LogInteractionModal> createState() => __LogInteractionModalState();
}

class __LogInteractionModalState extends State<_LogInteractionModal> {
  TextEditingController _notesController = TextEditingController();
  String? _selectedInteractionType;
  bool _isLoading = false;

  final List<String> _interactionTypes = [
    'call',
    'message',
    'meet',
    'other'
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _logTouchpoint() async {
    if (_selectedInteractionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an interaction type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Log the interaction
      await widget.apiService.logInteraction(
        contactId: widget.contact.id,
        interactionType: _selectedInteractionType!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Touchpoint logged for ${widget.contact.name}! Next nudge has been rescheduled.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Close the modal after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pop(context);
      });

    } catch (e) {
      print('Error logging touchpoint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log touchpoint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOG TOUCHPOINT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff555555),
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xff555555)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Selected Contact Display (already selected from contact detail)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3CB3E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3CB3E9).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3CB3E9),
                  ),
                  child: Center(
                    child: Text(
                      widget.contact.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff333333),
                        ),
                      ),
                      Text(
                        widget.contact.connectionType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff888888),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Interaction Type Selection
          Text(
            'INTERACTION TYPE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xff888888),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interactionTypes.map((type) {
              final isSelected = _selectedInteractionType == type;
              return ChoiceChip(
                label: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Color(0xff333333),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF3CB3E9),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? const Color(0xFF3CB3E9) : const Color(0xFFEEEEEE),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedInteractionType = selected ? type : null;
                  });
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Notes Field
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Log Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _logTouchpoint,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CB3E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: Colors.white,),
                        SizedBox(width: 8),
                        Text(
                          'LOG TOUCHPOINT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
// contact_detail_screen.dart - Updated with Close Circle toggle, Social Tags, and Scheduled Nudges
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/theme/text_styles.dart';
// import 'package:nudge/widgets/add_touchpoint_modal.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          SnackBar(content: Text(isVIP ? 'Added to Favourites' : 'Removed from Favourites')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating Favourites status: $e')),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
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
        title: Text('Contact Details', style: AppTextStyles.title2.copyWith(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
        backgroundColor: themeProvider.getSurfaceColor(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: themeProvider.getTextPrimaryColor(context)),
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
                          color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.01),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.transparent,
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
                                  _currentContact.name.isNotEmpty ? initials.toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontFamily: 'OpenSans',
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
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'OpenSans',
                      fontWeight: FontWeight.bold,
                      color: themeProvider.getTextPrimaryColor(context)
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (_currentContact.profession != null && _currentContact.profession!.isNotEmpty)
                    Text(
                      _currentContact.profession!,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'OpenSans',
                        color: themeProvider.getTextSecondaryColor(context),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            // Close Circle Toggle
            Card(
              color: themeProvider.getCardColor(context),
              child: ListTile(
                leading: Icon(Icons.star, color: _currentContact.isVIP ? Colors.amber : themeProvider.getTextSecondaryColor(context)),
                title: Text('Favourites', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                subtitle: Text(_currentContact.isVIP 
                    ? 'This contact is in your Favourites' 
                    : 'Add to your Favourites for special attention',
                    style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                trailing: _isUpdatingVIP
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                    : Switch(
                        value: _currentContact.isVIP,
                        onChanged: _toggleVIPStatus,
                        activeColor: AppTheme.primaryColor,
                        inactiveThumbColor: themeProvider.getTextSecondaryColor(context),
                        inactiveTrackColor: themeProvider.getTextHintColor(context),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Contact Information Section
            if (_currentContact.phoneNumber.isNotEmpty || _currentContact.email.isNotEmpty) ...[
              Text(
                'CONTACT INFORMATION',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.bold,
                  color: themeProvider.getTextSecondaryColor(context),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              
              if (_currentContact.phoneNumber.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.phone, color: themeProvider.getTextPrimaryColor(context)),
                  title: Text('Phone', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  subtitle: Text(_currentContact.phoneNumber, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                ),
              
              if (_currentContact.email.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.email, color: themeProvider.getTextPrimaryColor(context)),
                  title: Text('Email', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  subtitle: Text(_currentContact.email, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                ),
              const SizedBox(height: 20),
            ],
            
            // Connection Details Section
            Text(
              'CONNECTION DETAILS',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.bold,
                color: themeProvider.getTextSecondaryColor(context),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            
            ListTile(
              leading: 
              // Icon(Icons.category, color: themeProvider.getTextPrimaryColor(context)),
              SvgPicture.asset(
              'assets/contact-icons/connection-type.svg',
              width: 22,
              height: 22,
              color: themeProvider.getTextPrimaryColor(context)
            ),
              title: Text('Connection Type', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
              subtitle: Text(_currentContact.connectionType, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
            ),

            ListTile(
              leading: Icon(Icons.schedule, color: themeProvider.getTextPrimaryColor(context)),
              title: Text('Contact Frequency', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
              subtitle: Text(FrequencyPeriodMapper.getConversationalChoice(_currentContact.frequency, _currentContact.period),
                style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
            ),
            
            if (_currentContact.socialGroups.isNotEmpty)
              ListTile(
                leading: Icon(Icons.group, color: themeProvider.getTextPrimaryColor(context)),
                title: Text('Social Groups', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                subtitle: Text(_currentContact.socialGroups.join(', '), style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
              ),
            
            // Important Dates Section
            if (_currentContact.birthday != null || _currentContact.anniversary != null || _currentContact.workAnniversary != null) ...[
              const SizedBox(height: 20),
              Text(
                'IMPORTANT DATES',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.bold,
                  color: themeProvider.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 10),
              
              if (_currentContact.birthday != null)
                ListTile(
                  leading: Icon(Icons.cake, color: themeProvider.getTextPrimaryColor(context)),
                  title: Text('Birthday', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.birthday!), 
                    style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                ),
              
              if (_currentContact.anniversary != null)
                ListTile(
                  leading: Icon(Icons.favorite, color: themeProvider.getTextPrimaryColor(context)),
                  title: Text('Anniversary', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.anniversary!), 
                    style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                ),
              
              if (_currentContact.workAnniversary != null)
                ListTile(
                  leading: Icon(Icons.work, color: themeProvider.getTextPrimaryColor(context)),
                  title: Text('Work Anniversary', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  subtitle: Text(DateFormat('MMMM d, y').format(_currentContact.workAnniversary!), 
                    style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                ),
            ],
            
            // Notes Section
            if (_currentContact.notes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Notes',
                style: TextStyle(
                  color: themeProvider.getTextPrimaryColor(context),
                  fontSize: 18,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(_currentContact.notes, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
            ],
            
            // Contextual message when no info
            if (hasNoInfo) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.getCardColor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: themeProvider.getTextHintColor(context)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info, size: 40, color: themeProvider.getTextSecondaryColor(context)),
                    const SizedBox(height: 10),
                    Text(
                      'Add your first Favourites contact for better insights.',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'OpenSans',
                        color: themeProvider.getTextSecondaryColor(context),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 30),

            // Simpler version - add this as a Chip or Badge
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _getRingColor(_currentContact.computedRing).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getRingColor(_currentContact.computedRing).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRingIcon(_currentContact.computedRing),
                    size: 16,
                    color: _getRingColor(_currentContact.computedRing),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getFormattedRingName(_currentContact.computedRing),
                    style: TextStyle(
                      color: _getRingColor(_currentContact.computedRing),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'OpenSans',
                    ),
                  ),
                  if (_currentContact.cdi > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      'CDI: ${_currentContact.cdi.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: themeProvider.getTextSecondaryColor(context),
                        fontSize: 12,
                        fontFamily: 'OpenSans',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showLogInteractionModal(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
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
                        fontFamily: 'OpenSans',
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

    // Add this method to get ring color
  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.yellow;
      case 'middle':
        return const Color(0xff3CB3E9);
      case 'outer':
        return const Color(0xff897ED6);
      default:
        return Colors.grey;
    }
  }

  // Add this method to get ring icon
  IconData _getRingIcon(String ring) {
    switch (ring) {
      case 'inner':
        return Icons.star;
      case 'middle':
        return Icons.circle;
      case 'outer':
        return Icons.circle_outlined;
      default:
        return Icons.circle;
    }
  }

  // Add this method to get formatted ring name
  String _getFormattedRingName(String ring) {
    switch (ring) {
      case 'inner':
        return 'Inner Circle';
      case 'middle':
        return 'Middle Circle';
      case 'outer':
        return 'Outer Circle';
      default:
        return 'Unknown';
    }
  }

  Future<void> _showLogInteractionModal(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: themeProvider.getSurfaceColor(context),
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
  final List<String> _interactionTypes = ['call', 'message', 'meet', 'other'];

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    
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
              Text(
                'LOG TOUCHPOINT',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.w700,
                  color: themeProvider.getTextPrimaryColor(context),
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: themeProvider.getTextPrimaryColor(context)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Selected Contact Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor,
                  ),
                  child: Center(
                    child: Text(
                      widget.contact.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'OpenSans',
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
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'OpenSans',
                          fontWeight: FontWeight.w600,
                          color: themeProvider.getTextPrimaryColor(context),
                        ),
                      ),
                      Text(
                        widget.contact.connectionType,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'OpenSans',
                          color: themeProvider.getTextSecondaryColor(context),
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
              fontFamily: 'OpenSans',
              fontWeight: FontWeight.w600,
              color: themeProvider.getTextSecondaryColor(context),
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
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : themeProvider.getTextPrimaryColor(context),
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: themeProvider.getCardColor(context),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : themeProvider.getTextHintColor(context),
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
            style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeProvider.getTextHintColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeProvider.getTextHintColor(context)),
              ),
              filled: true,
              fillColor: themeProvider.getCardColor(context),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Log Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _logTouchpoint,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
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
                        Icon(Icons.add, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'LOG TOUCHPOINT',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'OpenSans',
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
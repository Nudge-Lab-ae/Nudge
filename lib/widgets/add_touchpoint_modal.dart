// lib/widgets/add_touchpoint_modal.dart
import 'dart:math';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';
import '../models/contact.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AddTouchpointModal extends StatefulWidget {
  final ApiService apiService;
  
  const AddTouchpointModal({
    Key? key,
    required this.apiService,
  }) : super(key: key);

  @override
  State<AddTouchpointModal> createState() => _AddTouchpointModalState();
}

class _AddTouchpointModalState extends State<AddTouchpointModal> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  TextEditingController _searchController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  Contact? _selectedContact;
  String? _selectedInteractionType;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _showConfetti = false;
  late ConfettiController _confettiController;

  final List<String> _interactionTypes = [
    'call',
    'message',
    'meet',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final contacts = await widget.apiService.getAllContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load contacts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = _contacts;
      });
      return;
    }

    setState(() {
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
               contact.email.toLowerCase().contains(query) ||
               contact.phoneNumber.contains(query);
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _logTouchpoint() async {
    if (_selectedContact == null || _selectedInteractionType == null) {
      Flushbar(
      padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
      backgroundGradient: LinearGradient(
        colors: [ Color.fromARGB(255, 215, 73, 63), Color.fromARGB(255, 215, 73, 63)],
        stops: [0.6, 1],
      ), duration: Duration(seconds: 2),
      dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      flushbarPosition: FlushbarPosition.TOP,
      messageText: Center(
          child: Text( 'Please select a contact and interaction type', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
            color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final interactionDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Log the interaction
      await widget.apiService.logInteraction(
        contactId: _selectedContact!.id,
        interactionType: _selectedInteractionType!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        interactionDate: interactionDateTime.toIso8601String(),
      );

      // Show confetti animation
      setState(() {
        _showConfetti = true;
        _isLoading = false;
      });
      
      _confettiController.play();

      // Show success message
      Flushbar(
      padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
      backgroundGradient: LinearGradient(
        colors: [ Color.fromARGB(255, 11, 155, 47), Color.fromARGB(255, 26, 154, 56)],
        stops: [0.6, 1],
      ), duration: Duration(seconds: 2),
      dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      flushbarPosition: FlushbarPosition.TOP,
      messageText: Center(
          child: Text( 'Touchpoint logged for ${_selectedContact!.name}! Next nudge has been rescheduled.', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
            color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);

      // Close after animation
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
      print('Error logging touchpoint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log touchpoint: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Path _drawStar(Size size) {
    // Method to draw a 5-point star
    double degToRad(double deg) => deg * (3.14159 / 180.0);
    
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = 360 / (numberOfPoints * 2);
    final path = Path();
    
    for (int i = 0; i < numberOfPoints * 2; i++) {
      final radius = i.isEven ? externalRadius : internalRadius;
      final angle = degToRad(i * degreesPerStep - 90);
      final x = halfWidth + radius * cos(angle);
      final y = halfWidth + radius * sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = themeProvider.getSurfaceColor(context);
    final textColor = themeProvider.isDarkMode ? Colors.white : const Color(0xff333333);
    final secondaryTextColor = themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff888888);
    final borderColor = themeProvider.isDarkMode ? Colors.grey.shade600 : const Color(0xFFEEEEEE);
    final iconColor = themeProvider.isDarkMode ? Colors.white : const Color(0xff555555);

    // Format date and time for display
    final formattedDate = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final formattedTime = _selectedTime.format(context);

    return Stack(
      children: [
        GestureDetector(
          onTap: _dismissKeyboard,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
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
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: iconColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Contact Search
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Search Contacts',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Selected Contact Display
                if (_selectedContact != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                          ),
                          child: Center(
                            child: Text(
                              _selectedContact!.name.substring(0, 1).toUpperCase(),
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
                                _selectedContact!.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                _selectedContact!.connectionType,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.clear, size: 20, color: secondaryTextColor),
                          onPressed: () {
                            setState(() {
                              _selectedContact = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Contact List
                if (_selectedContact == null) ...[
                  Text(
                    'SELECT CONTACT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          )
                        : _filteredContacts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 48, color: secondaryTextColor),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No contacts found',
                                      style: TextStyle(color: secondaryTextColor),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                        child: Text(
                                          'Clear search',
                                          style: TextStyle(color: primaryColor),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredContacts.length,
                                itemBuilder: (context, index) {
                                  final contact = _filteredContacts[index];
                                  return ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryColor.withOpacity(0.2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          contact.name.substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      contact.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                    subtitle: Text(
                                      contact.connectionType,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                    trailing: Icon(Icons.chevron_right, color: secondaryTextColor),
                                    onTap: () {
                                      setState(() {
                                        _selectedContact = contact;
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Interaction Type Selection
                if (_selectedContact != null) ...[
                  Text(
                    'INTERACTION TYPE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
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
                            color: isSelected ? Colors.white : textColor,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                        side: BorderSide(
                          color: isSelected ? primaryColor : borderColor,
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
                  
                  // Date and Time Selection
                  Text(
                    'WHEN DID THIS INTERACTION HAPPEN?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.calendar_today, size: 20, color: primaryColor),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.access_time, size: 20, color: primaryColor),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes Field
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      labelStyle: TextStyle(color: secondaryTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Log Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _logTouchpoint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themeProvider.isDarkMode ? Colors.black : Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 20, color: themeProvider.isDarkMode ? Colors.black : Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'LOG TOUCHPOINT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        
        // Confetti animation overlay
        if (_showConfetti)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Color(0xFF3CB3E9),
                  ],
                  createParticlePath: _drawStar,
                  numberOfParticles: 30,
                  gravity: 0.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
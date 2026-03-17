// lib/widgets/add_touchpoint_modal.dart
// import 'dart:math';

// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:nudge/services/message_service.dart';
// import 'package:top_snackbar_flutter/custom_snack_bar.dart';
// import 'package:top_snackbar_flutter/top_snack_bar.dart';
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
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to load contacts: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      TopMessageService().showMessage(
          context: context,
          message: 'Failed to load contacts: $e',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
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

  // Future<void> _logTouchpoint() async {
  //   if (_selectedContact == null || _selectedInteractionType == null) {
  //     Flushbar(
  //     padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
  //     backgroundGradient: LinearGradient(
  //       colors: [ Color.fromARGB(255, 215, 73, 63), Color.fromARGB(255, 215, 73, 63)],
  //       stops: [0.6, 1],
  //     ), duration: Duration(seconds: 2),
  //     dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
  //     flushbarPosition: FlushbarPosition.TOP,
  //     messageText: Center(
  //         child: Text( 'Please select a contact and interaction type', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
  //           color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);
  //     return;
  //   }

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     // Combine date and time
  //     final interactionDateTime = DateTime(
  //       _selectedDate.year,
  //       _selectedDate.month,
  //       _selectedDate.day,
  //       _selectedTime.hour,
  //       _selectedTime.minute,
  //     );

  //     // Log the interaction
  //     await widget.apiService.logInteraction(
  //       contactId: _selectedContact!.id,
  //       interactionType: _selectedInteractionType!,
  //       notes: _notesController.text.isNotEmpty ? _notesController.text : null,
  //       interactionDate: interactionDateTime.toIso8601String(),
  //     );

  //     // Show confetti animation
  //     setState(() {
  //       _showConfetti = true;
  //       _isLoading = false;
  //     });
      
  //     _confettiController.play();

  //     // Show success message
  //     Flushbar(
  //     padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
  //     backgroundGradient: LinearGradient(
  //       colors: [ Color.fromARGB(255, 11, 155, 47), Color.fromARGB(255, 26, 154, 56)],
  //       stops: [0.6, 1],
  //     ), duration: Duration(seconds: 2),
  //     flushbarStyle: FlushbarStyle.GROUNDED,
  //     flushbarPosition: FlushbarPosition.TOP, // or FlushbarPosition.BOTTOM
  //     margin: EdgeInsets.zero,
  //     // dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
  //     messageText: Center(
  //         child: Text( 'Touchpointz logged for ${_selectedContact!.name}! Next nudge has been rescheduled.', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
  //           color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);


  //     // Close after animation
  //     Future.delayed(const Duration(seconds: 3), () {
  //       if (mounted) {
  //         Navigator.pop(context);
  //       }
  //     });

  //   } catch (e) {
  //     print('Error logging touchpoint: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to log touchpoint: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }


  Future<void> _logTouchpoint() async {
    if (_selectedContact == null || _selectedInteractionType == null) {
      // Replace the Flushbar error message
      // showTopSnackBar(
      //   Overlay.of(context),
      //   CustomSnackBar.info(
      //     message: 'Please select a contact and interaction type',
      //     textStyle: TextStyle(
      //       fontFamily: 'Inter',
      //       fontSize: 14,
      //       color: Colors.white,
      //       fontWeight: FontWeight.w600,
      //     ),
      //   ),
      //   displayDuration: const Duration(seconds: 2),
      //   padding: EdgeInsets.zero,
      //   // showOutAnimationDuration: const Duration(milliseconds: 500),
      //   reverseAnimationDuration: const Duration(milliseconds: 500),
      //   snackBarPosition: SnackBarPosition.top, // This ensures it's at the top
      // );

       TopMessageService().showMessage(
          context: context,
          message: 'Please select a contact and interaction type.',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
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

      // Replace the Flushbar success message
      // showTopSnackBar(
      //   Overlay.of(context),
      //   CustomSnackBar.success(
      //     message: 'Touchpointz logged for ${_selectedContact!.name}! Next nudge has been rescheduled.',
      //     textStyle: TextStyle(
      //       fontFamily: 'Inter',
      //       fontSize: 14,
      //       color: Colors.white,
      //       fontWeight: FontWeight.w600,
      //     ),
      //   ),
      //   displayDuration: const Duration(seconds: 2),
      //   padding: EdgeInsets.zero,
      //   // showOutAnimationDuration: const Duration(milliseconds: 500),
      //   reverseAnimationDuration: const Duration(milliseconds: 500),
      //   snackBarPosition: SnackBarPosition.top, // This ensures it's at the top
      // );

       TopMessageService().showMessage(
          context: context,
          message: 'Touchpoint logged for ${_selectedContact!.name}! Next nudge has been rescheduled.',
          backgroundColor: Colors.green,
          // icon: Icons.check,
        );

      // Close after animation
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
      print('Error logging touchpoint: $e');
      // Keep the ScaffoldMessenger for errors as it's fine for bottom messages
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to log touchpoint: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'Failed to log touchpoint: $e',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // Path _drawStar(Size size) {
  //   // Method to draw a 5-point star
  //   double degToRad(double deg) => deg * (3.14159 / 180.0);
    
  //   const numberOfPoints = 5;
  //   final halfWidth = size.width / 2;
  //   final externalRadius = halfWidth;
  //   final internalRadius = halfWidth / 2.5;
  //   final degreesPerStep = 360 / (numberOfPoints * 2);
  //   final path = Path();
    
  //   for (int i = 0; i < numberOfPoints * 2; i++) {
  //     final radius = i.isEven ? externalRadius : internalRadius;
  //     final angle = degToRad(i * degreesPerStep - 90);
  //     final x = halfWidth + radius * cos(angle);
  //     final y = halfWidth + radius * sin(angle);
      
  //     if (i == 0) {
  //       path.moveTo(x, y);
  //     } else {
  //       path.lineTo(x, y);
  //     }
  //   }
  //   path.close();
  //   return path;
  // }

      String _getRelativeDateDescription(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final difference = selectedDate.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 0) {
      // Past dates
      final absDays = difference.abs();
      if (absDays <= 7) {
        return '$absDays day${absDays > 1 ? 's' : ''} ago';
      } else if (absDays <= 30) {
        final weeks = (absDays / 7).floor();
        return '$weeks week${weeks > 1 ? 's' : ''} ago';
      } else if (absDays <= 365) {
        final months = (absDays / 30).floor();
        return '$months month${months > 1 ? 's' : ''} ago';
      } else {
        final years = (absDays / 365).floor();
        return '$years year${years > 1 ? 's' : ''} ago';
      }
    } else {
      // Future dates
      if (difference <= 7) {
        return 'in $difference day${difference > 1 ? 's' : ''}';
      } else if (difference <= 30) {
        final weeks = (difference / 7).ceil();
        return 'in $weeks week${weeks > 1 ? 's' : ''}';
      } else if (difference <= 365) {
        final months = (difference / 30).ceil();
        return 'in $months month${months > 1 ? 's' : ''}';
      } else {
        final years = (difference / 365).ceil();
        return 'in $years year${years > 1 ? 's' : ''}';
      }
    }
  }

  String _getRelativeTimeDescription(DateTime date, TimeOfDay time) {
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      date.year, date.month, date.day,
      time.hour, time.minute,
    );
    
    final difference = now.difference(selectedDateTime);
    
    if (selectedDateTime.year == now.year &&
        selectedDateTime.month == now.month &&
        selectedDateTime.day == now.day) {
      // Same day
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        final hours = difference.inHours;
        return '$hours hour${hours > 1 ? 's' : ''} ago';
      }
    }
    
    return ''; // Return empty for non-today dates
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3CB3E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3CB3E9).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: const Color(0xFF3CB3E9),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getRelativeDateDescription(_selectedDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3CB3E9),
                            ),
                          ),
                        ),
                        if (_getRelativeTimeDescription(_selectedDate, _selectedTime).isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getRelativeTimeDescription(_selectedDate, _selectedTime),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              numberOfParticles: 20,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
      ],
    );
  }
}
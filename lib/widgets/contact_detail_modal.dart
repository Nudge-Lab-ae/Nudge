// lib/widgets/contact_details_modal.dart
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/contact.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart'; // Add this import
import 'package:provider/provider.dart'; // Add this import
import 'package:confetti/confetti.dart';


class ContactDetailsModal extends StatefulWidget {
  final Contact contact;
  final ApiService apiService;
  final String? displayRing;
  
  const ContactDetailsModal({
    super.key,
    required this.contact,
    required this.apiService,
    this.displayRing,
  });

  @override
  State<ContactDetailsModal> createState() => _ContactDetailsModalState();
}

class _ContactDetailsModalState extends State<ContactDetailsModal> {

  // bool _showConfetti = false;
 
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    final contact = widget.contact;
    final daysSinceLastContact = DateTime.now().difference(contact.lastContacted).inDays;
    final displayRing = widget.displayRing ?? contact.computedRing;
    final ringColor = _getRingColor(displayRing);
    
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? const Color(0xFF1E1E1E) 
          : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONTACT DETAILS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode 
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xff555555),
                  // letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close, 
                  color: isDarkMode 
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xff555555)
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Contact header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD600),
                      const Color(0xFFFFAB00).withOpacity(0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD600).withOpacity(isDarkMode ? 0.4 : 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    contact.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: TextStyle(
                        fontSize: contact.name.length >15 ?22 : 27,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode 
                          ? Colors.white
                          : const Color(0xff333333),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // VIP badge
                    if (contact.isVIP)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(isDarkMode ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD700)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'FAVOURITE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode 
                                  ? const Color(0xFFEEEEEE)
                                  : const Color(0xff555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Contact stats in cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: null,
                  title: 'Connection Type',
                  value: contact.connectionType.isNotEmpty 
                      ? contact.connectionType 
                      : 'Not specified',
                  color: const Color(0xFF3CB3E9),
                  isDarkMode: isDarkMode,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  icon: Icons.circle,
                  title: 'Social Ring',
                  value: contact.computedRing.toUpperCase(),
                  color: ringColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.access_time,
                  title: 'Last Contacted',
                  value: daysSinceLastContact == 0 
                      ? 'Today' 
                      : daysSinceLastContact == 1 
                          ? 'Yesterday' 
                          : '$daysSinceLastContact days ago',
                  color: daysSinceLastContact > 30 
                      ? Colors.redAccent 
                      : daysSinceLastContact > 7 
                          ? const Color(0xFFFFC107) 
                          : Colors.green,
                  isDarkMode: isDarkMode,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Expanded(
              //   child: _buildStatCard(
              //     icon: Icons.phone,
              //     title: 'CDI Score',
              //     value: contact.cdi.toStringAsFixed(2),
              //     color: const Color(0xFF9C27B0),
              //     isDarkMode: isDarkMode,
              //   ),
              // ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logTouchpoint(context, contact);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CB3E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
           
          const SizedBox(height: 24),
           
          // Contact information section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode 
                  ? const Color(0xFF444444)
                  : const Color(0xFFEEEEEE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTACT INFORMATION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode 
                      ? const Color(0xFFCCCCCC)
                      : const Color(0xff555555),
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Phone number
                if (contact.phoneNumber.isNotEmpty)
                  _buildContactInfoRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: contact.phoneNumber,
                    isDarkMode: isDarkMode,
                  ),
                
                if (contact.phoneNumber.isNotEmpty) const SizedBox(height: 12),
                
                // Email
                if (contact.email.isNotEmpty)
                  _buildContactInfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: contact.email,
                    isDarkMode: isDarkMode,
                  ),
                
                if (contact.email.isNotEmpty) const SizedBox(height: 12),
                
                // Notes
                if (contact.notes.isNotEmpty)
                  _buildContactInfoRow(
                    icon: Icons.note,
                    label: 'Notes',
                    value: contact.notes,
                    maxLines: 3,
                    isDarkMode: isDarkMode,
                  ),
              ],
            ),
          ),
                  
        ],
      ),
    );
  }

  void _logTouchpoint(BuildContext context, Contact contact) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          color: Colors.transparent,
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDarkMode 
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: _LogTouchpointModal(
                  apiService: widget.apiService,
                  contact: contact,
                  isDarkMode: isDarkMode,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData? icon,
    required String title,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? const Color(0xFF2A2A2A)
          : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
            ? const Color(0xFF444444)
            : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: icon == null
              ? SvgPicture.asset(
              'assets/contact-icons/connection-type.svg',
              width: 22,
              height: 22,
              color: color
            ) : Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode 
                      ? const Color(0xFFAAAAAA)
                      : const Color(0xff888888),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode 
                      ? Colors.white
                      : const Color(0xff333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDarkMode,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF3CB3E9).withOpacity(isDarkMode ? 0.2 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFF3CB3E9),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode 
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xff888888),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode 
                    ? Colors.white
                    : const Color(0xff333333),
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.yellow;
      case 'middle':
        return const Color(0xff3CB3E9);
      case 'outer':
        return const Color(0xff897ED6);
      default:
        return Colors.yellow;
    }
  }
}

// ... (previous imports and code remain the same until _LogTouchpointModal class)

class _LogTouchpointModal extends StatefulWidget {
  final ApiService apiService;
  final Contact contact;
  final bool isDarkMode;
  
  const _LogTouchpointModal({
    required this.apiService,
    required this.contact,
    required this.isDarkMode,
  });

  @override
  State<_LogTouchpointModal> createState() => __LogTouchpointModalState();
}

class __LogTouchpointModalState extends State<_LogTouchpointModal> {
  TextEditingController _notesController = TextEditingController();
  String? _selectedInteractionType;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _showConfetti = false;
  late ConfettiController _confettiController;

  @override 
  void initState(){
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  final List<String> _interactionTypes = [
    'call',
    'message',
    'meet',
    'other'
  ];

 
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

  Future<void> _logInteraction() async {
    if (_selectedInteractionType == null) {
      Flushbar(
        padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
        backgroundGradient: LinearGradient(
          colors: [Color.fromARGB(255, 207, 82, 73), Color.fromARGB(255, 207, 82, 73)],
          stops: [0.6, 1],
        ), duration: Duration(seconds: 2),
        dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
        flushbarPosition: FlushbarPosition.TOP,
        messageText: Center(
            child: Text( 'Please select an interaction type', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
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
        contactId: widget.contact.id,
        interactionType: _selectedInteractionType!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        interactionDate: interactionDateTime.toIso8601String(), // Add this parameter
      );
      
      setState(() {
         _showConfetti = true;
      });

       _confettiController.play();

      Flushbar(
        padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
        backgroundGradient: LinearGradient(
          colors: [Colors.green, Colors.green],
          stops: [0.6, 1],
        ), duration: Duration(seconds: 2),
        dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
        flushbarPosition: FlushbarPosition.TOP,
        messageText: Center(
            child: Text( 'Touchpoint logged for ${widget.contact.name}! Next nudge has been rescheduled.', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
              color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);

      // Close both modals after a brief delay
      Future.delayed(const Duration(milliseconds: 2500), () {
        Navigator.pop(context); // Close the log touchpoint modal
        Navigator.pop(context); // Close the contact detail modal
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Format date and time for display
    final formattedDate = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final formattedTime = _selectedTime.format(context);
    
    return GestureDetector(
              onTap: _dismissKeyboard,
              child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Column(
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
                  color: widget.isDarkMode 
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xff555555),
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close, 
                  color: widget.isDarkMode 
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xff555555)
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Selected Contact Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3CB3E9).withOpacity(widget.isDarkMode ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3CB3E9).withOpacity(widget.isDarkMode ? 0.4 : 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF3CB3E9),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode 
                            ? Colors.white
                            : const Color(0xff333333),
                        ),
                      ),
                      Text(
                        widget.contact.connectionType,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDarkMode 
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xff888888),
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
              color: widget.isDarkMode 
                ? const Color(0xFFAAAAAA)
                : const Color(0xff888888),
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
                    color: isSelected 
                      ? Colors.white
                      : widget.isDarkMode 
                          ? Colors.white
                          : const Color(0xff333333),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF3CB3E9),
                backgroundColor: widget.isDarkMode 
                  ? const Color(0xFF2A2A2A)
                  : Colors.white,
                side: BorderSide(
                  color: isSelected 
                    ? const Color(0xFF3CB3E9)
                    : widget.isDarkMode 
                        ? const Color(0xFF444444)
                        : const Color(0xFFEEEEEE),
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
              color: widget.isDarkMode 
                ? const Color(0xFFAAAAAA)
                : const Color(0xff888888),
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
                      color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDarkMode 
                          ? const Color(0xFF444444)
                          : const Color(0xFFEEEEEE),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: const Color(0xFF3CB3E9)),
                            const SizedBox(width: 12),
                            ],
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white : const Color(0xff333333),
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
                      color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDarkMode 
                          ? const Color(0xFF444444)
                          : const Color(0xFFEEEEEE),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 20, color: const Color(0xFF3CB3E9)),
                            const SizedBox(width: 12),
                            ],
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white : const Color(0xff333333),
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
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : const Color(0xff333333),
            ),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: TextStyle(
                color: widget.isDarkMode 
                  ? const Color(0xFFAAAAAA)
                  : const Color(0xff888888),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode 
                    ? const Color(0xFF444444)
                    : const Color(0xFFEEEEEE),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode 
                    ? const Color(0xFF444444)
                    : const Color(0xFFEEEEEE),
                ),
              ),
              filled: true,
              fillColor: widget.isDarkMode 
                ? const Color(0xFF2A2A2A)
                : Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Log Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _logInteraction,
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
                        Icon(Icons.add, size: 20, color: Colors.white),
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
      if (_showConfetti)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                // color: Colors.black.withOpacity(0.5),
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
                  // createParticlePath: _drawStar,
                  numberOfParticles: 30,
                  gravity: 0.1,
                ),
              ),
            ),
          ),
      ])
    ));
  }
}



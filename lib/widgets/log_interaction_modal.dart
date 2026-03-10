import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:confetti/confetti.dart';
// import 'package:nudge/widgets/hi_five_animation.dart';
import '../../models/contact.dart';

// Custom modal for logging interactions
class LogInteractionModal extends StatefulWidget {
  final ApiService apiService;
  final Contact contact;
  final bool isDarkMode;
  
  const LogInteractionModal({
    required this.apiService,
    required this.contact,
    required this.isDarkMode,
  });

  @override
  State<LogInteractionModal> createState() => LogInteractionModalState();
}

class LogInteractionModalState extends State<LogInteractionModal> {
  TextEditingController _notesController = TextEditingController();
  String? _selectedInteractionType;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _showConfetti = false;
  late ConfettiController _confettiController;
  // bool _showCelebration = false;

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
  }

  @override
  void dispose() {
    _notesController.dispose();
    _confettiController.dispose();
    super.dispose();
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

  void showSelectFlushbar(BuildContext context) {
    Flushbar(
      padding: EdgeInsets.all(10),
      borderRadius: BorderRadius.zero,
      backgroundGradient: LinearGradient(
        colors: [Color.fromRGBO(243, 87, 87, 1), Color.fromRGBO(243, 87, 87, 1)],
        stops: [0.6, 1],
      ),
      duration: Duration(seconds: 2),
      flushbarPosition: FlushbarPosition.TOP,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      messageText: Center(
          child: Text(
        'Please select an interaction type',
        style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w400),
      )),
    ).show(context);
  }

  Future<void> _logInteraction() async {
    if (_selectedInteractionType == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Please select an interaction type'),
      //     backgroundColor: Colors.orange,
      //   ),
      // );
      showSelectFlushbar(context);
      return;
    }

    setState(() {
        _showConfetti = true;
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
        interactionDate: interactionDateTime.toIso8601String(),
      );
      _confettiController.play();

     
       Flushbar(
      padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
      backgroundGradient: LinearGradient(
        colors: [Color.fromRGBO(38, 184, 19, 1), Color.fromRGBO(38, 184, 19, 1)],
        stops: [0.6, 1],
      ), duration: Duration(seconds: 2),
      dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      flushbarPosition: FlushbarPosition.TOP,
      messageText: Center(
          child: Text( 'Touchpoint logged for ${widget.contact.name}! Next nudge has been rescheduled.', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
            color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);

      // Show hi-five animation
      setState(() {
        // _showCelebration = true;
        _isLoading = false;
      });

      // Close after animation
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            // _showCelebration = false;
          });
          Navigator.pop(context, {
            'success': true,
            'interactionDateTime': interactionDateTime,
          });
        }
      });

    } catch (e) {
      print('Error logging touchpoint: $e');
      
      Flushbar(
      padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero,
      backgroundGradient: LinearGradient(
        colors: [Colors.red, Colors.red],
        stops: [0.6, 1],
      ), duration: Duration(seconds: 2),
      dismissDirection: FlushbarDismissDirection.HORIZONTAL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      flushbarPosition: FlushbarPosition.TOP,
      messageText: Center(
          child: Text( 'Failed to log touchpoint: $e', style: TextStyle(fontFamily: 'Inter',fontSize: 14,
            color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,)),).show(context);
      setState(() {
        _isLoading = false;
      });
      // Don't close the modal on error - let the user try again
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Format date and time for display
    final formattedDate = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final formattedTime = _selectedTime.format(context);
    
    return Stack(
    children: [
      Container(
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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
    ),
    if (_showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
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
    // if (_showCelebration)
    //     Container(
    //       color: Colors.black.withOpacity(0.7),
    //       width: MediaQuery.of(context).size.width,
    //       height: MediaQuery.of(context).size.height,
    //       child: HiFiveAnimation(
    //         onComplete: (){}, // This will be overridden in state
    //       ),
    //     ),
    ])
    ;
  }
}

// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/widgets/feedback_forum_preview.dart';
import 'package:nudge/widgets/screen_tracker.dart';
import 'package:nudge/widgets/scrollable_roadmap.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class FeedbackBottomSheet extends StatefulWidget {
  final String currentSection;
  final String? initialType;

  const FeedbackBottomSheet({
    super.key,
    required this.currentSection,
    this.initialType,
  });

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedType = 'Feedback / Inquiry';
  bool _isSubmitting = false;

  final List<String> _feedbackTypes = [
    'Feedback / Inquiry',
    'Bug Report',
    'Feature Request',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedType = widget.initialType ?? 'Feedback / Inquiry';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    // Validate title for feature requests
    if (_selectedType == 'Feature Request' && _titleController.text.trim().isEmpty) {
      // Flushbar(
      //   padding: const EdgeInsets.all(10), 
      //   borderRadius: BorderRadius.zero, 
      //   duration: const Duration(seconds: 2),
      //   flushbarPosition: FlushbarPosition.TOP, 
      //   backgroundColor: Colors.orange,
      //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
      //   messageText: Center(
      //     child: Text('Please enter a title for your feature request', style: const TextStyle(fontFamily: 'OpenSans', fontSize: 14,
      //         color: Colors.white, fontWeight: FontWeight.w400)),
      //   ),
      // ).show(context);

       TopMessageService().showMessage(
            context: context,
            message: 'Please enter a title for your feature request.',
            backgroundColor: Colors.deepOrange,
            icon: Icons.error,
          );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      // Flushbar(
      //   padding: const EdgeInsets.all(10), 
      //   borderRadius: BorderRadius.zero, 
      //   duration: const Duration(seconds: 2),
      //   flushbarPosition: FlushbarPosition.TOP, 
      //   backgroundColor: Colors.orange,
      //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
      //   messageText: Center(
      //     child: Text('Please enter your feedback', style: const TextStyle(fontFamily: 'OpenSans', fontSize: 14,
      //         color: Colors.white, fontWeight: FontWeight.w400)),
      //   ),
      // ).show(context);
      // return;
       TopMessageService().showMessage(
            context: context,
            message: 'Please enter your feedback.',
            backgroundColor: Colors.deepOrange,
            icon: Icons.error,
          );
    }

    setState(() => _isSubmitting = true);

    try {
      final screenName = ScreenTracker.getCurrentScreen(context);
    
      await _apiService.submitFeedback(
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
        message: _messageController.text,
        type: _selectedType,
        additionalData: {
          'currentSection': widget.currentSection,
        },
        screenName: screenName,
      );

      // Flushbar(
      //   padding: const EdgeInsets.all(10), 
      //   borderRadius: BorderRadius.zero, 
      //   duration: const Duration(seconds: 2),
      //   flushbarPosition: FlushbarPosition.TOP, 
      //   backgroundColor: Colors.green,
      //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
      //   messageText: Center(
      //     child: Text(_selectedType == 'Feature Request' 
      //         ? 'Thank you for your feature request!' 
      //         : 'Thank you for your feedback!', style: const TextStyle(fontFamily: 'OpenSans', fontSize: 14,
      //         color: Colors.white, fontWeight: FontWeight.w400)),
      //   ),
      // ).show(context);

       TopMessageService().showMessage(
            context: context,
            message: _selectedType == 'Feature Request' 
              ? 'Thank you for your feature request!' 
              : 'Thank you for your feedback!',
            backgroundColor: Colors.green,
            icon: Icons.check,
          );

      _titleController.clear();
      _messageController.clear();
      // Switch to forum tab after submission
      _tabController.animateTo(1);
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error submitting feedback: $e'),
      //     backgroundColor: Colors.red.withOpacity(0.9),
      //   ),
      // );
      TopMessageService().showMessage(
            context: context,
            message: 'Error submitting feedback: $e',
            backgroundColor: Colors.deepOrange,
            icon: Icons.error,
          );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showFeedbackTypeDialog(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Feedback Type',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xff333333),
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _feedbackTypes.length,
            itemBuilder: (context, index) {
              final type = _feedbackTypes[index];
              return ListTile(
                title: Text(
                  type,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xff333333),
                  ),
                ),
                onTap: () {
                  setState(() => _selectedType = type);
                  Navigator.of(context).pop();
                },
                tileColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8, // Increased height for more content
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar for better UX
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xff3CB3E9),
              unselectedLabelColor: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
              indicatorColor: const Color(0xff3CB3E9),
              tabs: const [
                Tab(text: 'Submit Feedback'),
                Tab(text: 'Feedback Forum'),
                Tab(text: 'Roadmap'),
              ],
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Submit Feedback Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback from: ${_getSectionName(widget.currentSection)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          'Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : const Color(0xff333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showFeedbackTypeDialog(context, isDarkMode),
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(text: _selectedType),
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : const Color(0xff333333),
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: isDarkMode ? const Color(0xFF444444) : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xff3CB3E9), width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Title field - NEW
                        Text(
                          'Title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : const Color(0xff333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xff333333),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: _selectedType == 'Feature Request' 
                              ? 'Enter a title for your feature request' 
                              : 'Enter a title (optional)',
                            hintStyle: TextStyle(
                              color: isDarkMode ? const Color(0xFF888888) : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: isDarkMode ? const Color(0xFF444444) : Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xff3CB3E9), width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          'Your Feedback',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : const Color(0xff333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _messageController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xff333333),
                            fontSize: 14,
                          ),
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Share your thoughts, suggestions, or issues...',
                            hintStyle: TextStyle(
                              color: isDarkMode ? const Color(0xFF888888) : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: isDarkMode ? const Color(0xFF444444) : Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xff3CB3E9), width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Helper text for feature requests
                        if (_selectedType == 'Feature Request')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: isDarkMode ? const Color(0xFF888888) : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Feature requests with clear titles get voted on in the forum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? const Color(0xFF888888) : Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isSubmitting
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: isDarkMode ? Colors.white : const Color(0xff3CB3E9),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _submitFeedback,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xff3CB3E9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Submit Feedback',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        // const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  
                  // Feedback Forum Tab
                  const FeedbackForumPreview(),
                  
                  // Roadmap Tab
                  const ScrollableRoadmapWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  String _getSectionName(String route) {
    final sectionMap = {
      '/dashboard': 'Dashboard',
      '/contacts': 'Contacts',
      '/groups': 'Groups',
      '/analytics': 'Analytics',
      '/notifications': 'Notifications',
      '/settings': 'Settings',
      '/welcome': 'Welcome Screen',
      '/login': 'Login Screen',
      '/register': 'Register Screen',
      'unknown': 'Unknown Section',
    };
    
    return sectionMap[route] ?? route;
  }
}
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
// import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
import 'package:nudge/widgets/feedback_forum_preview.dart';
import 'package:nudge/widgets/screen_tracker.dart';

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
  final TextEditingController _messageController = TextEditingController();
  String _selectedType = 'Feedback';
  bool _isSubmitting = false;

  final List<String> _feedbackTypes = [
    'Feedback',
    'Bug Report',
    'Feature Request',
    'General Inquiry',
    'Complaint'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedType = widget.initialType ?? 'Feedback';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final screenName = ScreenTracker.getCurrentScreen(context);
    
      await _apiService.submitFeedback(
        message: _messageController.text,
        type: _selectedType,
        additionalData: {
          'currentSection': widget.currentSection,
          // 'userFlow': _userFlow,
        },
        screenName: screenName, // Add screen tracking
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );

      _messageController.clear();
      // Switch to forum tab after submission
      _tabController.animateTo(1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting feedback: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showFeedbackTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Feedback Type', style: TextStyle(fontWeight: FontWeight.w700),),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _feedbackTypes.length,
            itemBuilder: (context, index) {
              final type = _feedbackTypes[index];
              return ListTile(
                title: Text(type, style: TextStyle(fontWeight: FontWeight.w500),),
                onTap: () {
                  setState(() => _selectedType = type);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xff3CB3E9),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Submit Feedback'),
              Tab(text: 'Feedback Forum'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Submit Feedback Tab
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feedback from: ${_getSectionName(widget.currentSection)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showFeedbackTypeDialog,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(text: _selectedType),
                            decoration: InputDecoration(
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          // Optional: to show border even when there's an error
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 1),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                            borderRadius: BorderRadius.circular(10)
                          ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Your Feedback',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts, suggestions, or issues...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          // Optional: to show border even when there's an error
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 1),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                            borderRadius: BorderRadius.circular(10)
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: _isSubmitting
                            ? const Center(child: CircularProgressIndicator())
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Feedback Forum Tab
                const FeedbackForumPreview(),
              ],
            ),
          ),
        ],
      ),
    );
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
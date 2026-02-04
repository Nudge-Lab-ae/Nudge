import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class FeedbackForumScreen extends StatefulWidget {
  const FeedbackForumScreen({super.key});

  @override
  State<FeedbackForumScreen> createState() => _FeedbackForumScreenState();
}

class _FeedbackForumScreenState extends State<FeedbackForumScreen> {
  final ApiService _apiService = ApiService();
  String _filterStatus = 'all';
  final List<String> _statusOptions = ['all', 'received', 'planned', 'in_progress', 'completed'];
  
  // Track upvoted feedbacks by user
  Map<String, bool> _upvotedFeedbacks = {};
  
  List<Map<String, dynamic>> _filterFeedbacks(List<Map<String, dynamic>> feedbacks) {
    List<Map<String, dynamic>> filtered = feedbacks;
    
    // Filter to only show Feature Requests
    filtered = filtered.where((f) => f['type'] == 'Feature Request').toList();

    if (_filterStatus != 'all') {
      filtered = filtered.where((f) => f['status'] == _filterStatus).toList();
    }

    return filtered;
  }
  
  // Method to handle upvoting
  Future<void> _toggleUpvote(String feedbackId, bool currentlyUpvoted) async {
    try {
      final newUpvotedState = !currentlyUpvoted;
      
      // Update locally first for immediate UI feedback
      setState(() {
        _upvotedFeedbacks[feedbackId] = newUpvotedState;
      });
      
      // Call API to update upvote count
      await _apiService.upvoteFeedback(
        feedbackId: feedbackId,
        upvote: newUpvotedState,
      );
      
    } catch (e) {
      // Revert on error
      setState(() {
        _upvotedFeedbacks[feedbackId] = currentlyUpvoted;
      });
      print('Error upvoting: $e');
    }
  }
  
  // Initialize upvote states
  void _initializeUpvoteStates(List<Map<String, dynamic>> feedbacks) async{
    for (var feedback in feedbacks) {
      final feedbackId = feedback['id'] as String?;
      if (feedbackId != null) {
        final upvotes = feedback['upvotes'] as List<dynamic>? ?? [];
        final currentUser =  await _apiService.getUser();
        // Check if current user has already upvoted this feedback
        final isUpvoted = upvotes.any((upvote) => 
          upvote is Map && upvote['userId'] == currentUser.id
        );
        
        _upvotedFeedbacks[feedbackId] = isUpvoted;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Feature Requests Forum',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xff555555),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? const Color(0xFFCCCCCC) : const Color(0xff3CB3E9),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse and upvote feature requests. Track their progress and share your support!',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? const Color(0xFF444444) : Colors.grey.shade300,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Filter by status:',
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFCCCCCC) : const Color(0xff333333),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode ? const Color(0xFF555555) : Colors.grey.shade400,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                    underline: const SizedBox(),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(
                          status == 'all' ? 'All Statuses' : _getStatusDisplayName(status),
                          style: TextStyle(
                            color: status == 'all' 
                              ? (isDarkMode ? const Color(0xFFCCCCCC) : const Color(0xff333333))
                              : _getStatusColor(status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Feedback List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _apiService.getFeedbacksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? const Color(0xFF3CB3E9) : const Color(0xff3CB3E9),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading feature requests: ${snapshot.error}',
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final allFeedbacks = snapshot.data ?? [];
                
                // Initialize upvote states
                if (_upvotedFeedbacks.isEmpty && allFeedbacks.isNotEmpty) {
                  _initializeUpvoteStates(allFeedbacks);
                }
                
                final filteredFeedbacks = _filterFeedbacks(allFeedbacks);
                
                if (filteredFeedbacks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 64,
                          color: isDarkMode ? const Color(0xFF555555) : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No feature requests yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDarkMode ? const Color(0xFFCCCCCC) : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterStatus != 'all' 
                              ? 'No feature requests with status "${_getStatusDisplayName(_filterStatus)}"'
                              : 'Be the first to suggest a new feature!',
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredFeedbacks.length,
                  itemBuilder: (context, index) {
                    return _buildFeedbackItem(filteredFeedbacks[index], isDarkMode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback, bool isDarkMode) {
    final feedbackId = feedback['id'] as String? ?? '';
    final title = feedback['adminTitle'] ?? 'No Title';
    final message = feedback['message'] ?? '';
    final status = feedback['status'] ?? 'received';
    // final type = feedback['type'] ?? 'Feature Request';
    final section = feedback['section'] ?? 'General';
    // final user = feedback['user'] ?? {};
    final adminResponse = feedback['adminResponse'];
    final upvotes = feedback['upvotes'] as List<dynamic>? ?? [];
    final upvoteCount = upvotes.length;
    
    final isUpvoted = _upvotedFeedbacks[feedbackId] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF444444) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(isDarkMode ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    _getStatusDisplayName(status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Upvote count
                GestureDetector(
                  onTap: feedbackId.isNotEmpty ? () {
                    _toggleUpvote(feedbackId, isUpvoted);
                  } : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpvoted 
                        ? Colors.orange.withOpacity(isDarkMode ? 0.3 : 0.2)
                        : Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isUpvoted ? Colors.orange : Colors.grey,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUpvoted ? Icons.thumb_up : Icons.thumb_up,
                          size: 15,
                          color: isUpvoted ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          upvoteCount.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUpvoted ? Colors.orange : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xff333333),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Message preview
            Text(
              message.length > 150 ? '${message.substring(0, 150)}...' : message,
              style: TextStyle(
                color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Meta information
            Row(
              children: [
                // Icon(
                //   Icons.person_outline,
                //   size: 14,
                //   color: isDarkMode ? const Color(0xFF888888) : Colors.grey.shade600,
                // ),
                // const SizedBox(width: 4),
                // Text(
                //   user['username'] ?? user['email'] ?? 'Anonymous',
                //   style: TextStyle(
                //     fontSize: 12,
                //     color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey.shade600,
                //   ),
                // ),
                // const SizedBox(width: 12),
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: isDarkMode ? const Color(0xFF888888) : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _getSectionDisplayName(section),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            // Admin Response
            if (adminResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.green.shade800 : Colors.green.shade100,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Response:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.green.shade300 : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminResponse['response'] ?? '',
                      style: TextStyle(
                        color: isDarkMode ? const Color(0xFFCCCCCC) : const Color(0xff333333),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'received': return 'Received';
      case 'planned': return 'Planned';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'received': return Colors.orange;
      case 'planned': return Colors.blue;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getSectionDisplayName(String section) {
    final sectionMap = {
      '/dashboard': 'Dashboard',
      '/contacts': 'Contacts',
      '/groups': 'Groups',
      '/analytics': 'Analytics',
      '/notifications': 'Notifications',
      '/settings': 'Settings',
      'unknown': 'General',
    };
    
    return sectionMap[section] ?? section;
  }
}
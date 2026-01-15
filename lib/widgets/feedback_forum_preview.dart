import 'package:flutter/material.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class FeedbackForumPreview extends StatelessWidget {
  const FeedbackForumPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ApiService().getFeedbacksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: isDarkMode ? const Color(0xFF3CB3E9) : const Color(0xff3CB3E9),
            ),
          );
        }
        
        if (snapshot.hasError || snapshot.data == null) {
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
                  'Unable to load feedback forum',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        final feedbacks = snapshot.data!;
        
        if (feedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: isDarkMode ? const Color(0xFF555555) : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No feedback yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? const Color(0xFFCCCCCC) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to share your thoughts!',
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Recent Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xff333333),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeedbackForumScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: const Color(0xff3CB3E9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Feedback items
            Expanded(
              child: ListView.builder(
                itemCount: feedbacks.length,
                itemBuilder: (context, index) {
                  return _buildPreviewItem(feedbacks[index], isDarkMode);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewItem(Map<String, dynamic> feedback, bool isDarkMode) {
    final title = feedback['adminTitle'] ?? 'No Title';
    final message = feedback['message'] ?? '';
    final status = feedback['status'] ?? 'received';
    final screen = feedback['screen'] ?? 'Unknown Screen';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(isDarkMode ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusDisplayName(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Screen
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(isDarkMode ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    screen,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : const Color(0xff333333),
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.length > 100 
                  ? '${message.substring(0, 100)}...' 
                  : message,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? const Color(0xFFAAAAAA) : Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
}
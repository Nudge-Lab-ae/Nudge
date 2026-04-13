import 'package:flutter/material.dart';
import 'package:nudge/main.dart';
import 'package:nudge/theme/app_theme.dart';
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
              color: isDarkMode ? AppColors.lightPrimary : AppColors.lightPrimary,
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
                  color: isDarkMode ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load feedback forum',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        
        final allFeedbacks = snapshot.data!;
        final filteredFeedbacks = _filterFeedbacks(allFeedbacks);
        
        if (filteredFeedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: isDarkMode ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                ),
                const SizedBox(height: 16),
                Text(
                  'No feature requests yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to share your thoughts!',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Recent Feature Requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.darkSurfaceContainerHighest,
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
                        color: AppColors.lightPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Feedback items
            Expanded(
              child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: ListView.builder(
                itemCount: filteredFeedbacks.length,
                itemBuilder: (context, index) {
                  return _buildPreviewItem(filteredFeedbacks[index], isDarkMode);
                },
              ),
            )),
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
      color: Theme.of(navigatorKey.currentContext!).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? Color(0xFF444444) : AppColors.lightSurfaceContainerHigh,
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
                    borderRadius: BorderRadius.circular(8),
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
                    color: Theme.of(navigatorKey.currentContext!).colorScheme.secondary.withOpacity(isDarkMode ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    screen,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(navigatorKey.currentContext!).colorScheme.secondary,
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
                color: isDarkMode ? Colors.white : AppColors.darkSurfaceContainerHighest,
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
                  color: isDarkMode ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
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

   List<Map<String, dynamic>> _filterFeedbacks(List<Map<String, dynamic>> feedbacks) {
    // Filter to only show Feature Requests
    return feedbacks.where((f) => f['type'] == 'Feature Request').toList();
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
      case 'received': return AppColors.warning;
      case 'planned': return Theme.of(navigatorKey.currentContext!).colorScheme.secondary;
      case 'in_progress': return Theme.of(navigatorKey.currentContext!).colorScheme.primary;
      case 'completed': return AppColors.success;
      default: return AppColors.lightOnSurfaceVariant;
    }
  }
}
import 'package:flutter/material.dart';
import 'package:nudge/screens/feedback/feedback_bottom_sheet.dart';
// import 'package:nudge/services/api_service.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';

class FeedbackFloatingButton extends StatefulWidget {
  const FeedbackFloatingButton({super.key});

  @override
  State<FeedbackFloatingButton> createState() => _FeedbackFloatingButtonState();
}

class _FeedbackFloatingButtonState extends State<FeedbackFloatingButton> {
  bool _isExpanded = false;
  // final ApiService _apiService = ApiService();

  void _showFeedbackDialog(BuildContext context, String section) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedbackBottomSheet(currentSection: section),
    );
  }

  void _openFeedbackForum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackForumScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Expanded menu
        if (_isExpanded)
          Positioned(
            right: 16,
            bottom: 80,
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMenuOption(
                    icon: Icons.feedback,
                    text: 'Give Feedback',
                    onTap: () {
                      final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
                      _showFeedbackDialog(context, currentRoute);
                      setState(() => _isExpanded = false);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuOption(
                    icon: Icons.forum,
                    text: 'View Forum',
                    onTap: () {
                      _openFeedbackForum(context);
                      setState(() => _isExpanded = false);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuOption(
                    icon: Icons.bug_report,
                    text: 'Report Bug',
                    onTap: () {
                      final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
                      _showFeedbackDialog(context, currentRoute, /* initialType: 'Bug Report' */);
                      setState(() => _isExpanded = false);
                    },
                  ),
                ],
              ),
            ),
          ),
        
        // Main floating button
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isExpanded)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton(
                    onPressed: () => setState(() => _isExpanded = false),
                    mini: true,
                    backgroundColor: Colors.grey.shade600,
                    child: const Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              FloatingActionButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                backgroundColor: const Color(0xff3CB3E9),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isExpanded
                      ? const Icon(Icons.chat, color: Colors.white)
                      : const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xff3CB3E9)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
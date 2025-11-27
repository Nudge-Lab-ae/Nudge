import 'package:flutter/material.dart';
// import 'package:nudge/services/api_service.dart';
import 'package:nudge/screens/feedback/feedback_bottom_sheet.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';

class FeedbackFloatingButton extends StatefulWidget {
   final String? currentSection;
  
  const FeedbackFloatingButton({super.key, this.currentSection});

  @override
  State<FeedbackFloatingButton> createState() => _FeedbackFloatingButtonState();
}

class _FeedbackFloatingButtonState extends State<FeedbackFloatingButton> {
  bool _isExpanded = false;
  // final ApiService _apiService = ApiService();

  void _showFeedbackDialog(BuildContext context, String section, {String? initialType}) {
    final currentSection = widget.currentSection ?? section;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedbackBottomSheet(
        currentSection: currentSection, // Pass the specific section
        initialType: initialType,
      ),
    ).whenComplete(() {
      setState(() => _isExpanded = false);
    });
  }

  void _openFeedbackForum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackForumScreen(),
      ),
    ).whenComplete(() {
      setState(() => _isExpanded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _isExpanded ? 140 : 40, // Smaller size
      height: _isExpanded ? 150 : 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Expanded menu
          if (_isExpanded)
            Positioned(
              right: 45, // Position to the left of the main button
              bottom: 0,
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(10),
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
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildMenuOption(
                      icon: Icons.forum,
                      text: 'View Forum',
                      onTap: () {
                        _openFeedbackForum(context);
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildMenuOption(
                      icon: Icons.bug_report,
                      text: 'Report Bug',
                      onTap: () {
                        final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
                        _showFeedbackDialog(context, currentRoute, initialType: 'Bug Report');
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Main floating button - positioned center-right
          Positioned(
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // if (_isExpanded)
                //   Container(
                //     margin: const EdgeInsets.only(bottom: 8),
                //     child: FloatingActionButton(
                //       onPressed: () => setState(() => _isExpanded = false),
                //       mini: true,
                //       backgroundColor: Colors.grey.shade600,
                //       child: const Icon(Icons.close, size: 16, color: Colors.white),
                //     ),
                //   ),
                FloatingActionButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  mini: true, // Smaller button
                  backgroundColor: const Color(0xff3CB3E9),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isExpanded
                        ? const Icon(Icons.close, color: Colors.white, size: 18)
                        : const Icon(Icons.feedback, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xff3CB3E9)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
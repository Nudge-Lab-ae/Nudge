// lib/screens/feedback/feedback_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();

  // Type selection matching Image 1 grid
  String _selectedType = 'Suggestion';
  String _selectedCategory = 'User Experience';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _typeCards = [
    {'label': 'Suggestion', 'icon': Icons.lightbulb_outline_rounded,  'apiType': 'Feature Request'},
    {'label': 'Issue',      'icon': Icons.bug_report_outlined,         'apiType': 'Bug Report'},
    {'label': 'Praise',     'icon': Icons.favorite_outline_rounded,    'apiType': 'Feedback / Inquiry'},
    {'label': 'Other',      'icon': Icons.more_horiz_rounded,          'apiType': 'Feedback / Inquiry'},
  ];

  final List<String> _categories = [
    'User Experience',
    'Performance',
    'Onboarding',
    'Contact Management',
    'Notifications',
    'Groups',
    'Universe',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _apiType =>
      _typeCards.firstWhere((t) => t['label'] == _selectedType)['apiType'] as String;

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      TopMessageService().showMessage(
        context: context,
        message: 'Please enter your message.',
        backgroundColor: AppColors.warning,
        icon: Icons.info_outline,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final screenName = ScreenTracker.getCurrentScreen(context);
      await _apiService.submitFeedback(
        message: _messageController.text.trim(),
        type: _apiType,
        additionalData: {
          'currentSection': widget.currentSection,
          'category': _selectedCategory,
        },
        screenName: screenName,
      );
      TopMessageService().showMessage(
        context: context,
        message: _selectedType == 'Suggestion'
            ? 'Thanks for your suggestion!'
            : 'Thank you for your feedback!',
        backgroundColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );
      _messageController.clear();
      _tabController.animateTo(1);
    } catch (e) {
      TopMessageService().showMessage(
        context: context,
        message: 'Error submitting: $e',
        backgroundColor: AppColors.lightError,
        icon: Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final scheme = Theme.of(context).colorScheme;

    final bg    = isDark ? AppColors.darkSurfaceContainerLow  : Colors.white;
    final textP = isDark ? AppColors.darkOnSurface            : AppColors.lightOnSurface;
    final textS = isDark ? AppColors.darkOnSurfaceVariant     : AppColors.lightOnSurfaceVariant;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          const SizedBox(height: 4),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: themeProvider.isDarkMode?const Color.fromARGB(255, 153, 101, 221):AppColors.lightPrimary,
            unselectedLabelColor: textS,
            indicatorColor:themeProvider.isDarkMode?const Color.fromARGB(255, 153, 101, 221):AppColors.lightPrimary,
            indicatorWeight: 2,
            labelPadding: EdgeInsets.zero,
            labelStyle: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 12),
            tabs: const [
              Tab(text: 'Submit Feedback'),
              Tab(text: 'Forum'),
              Tab(text: 'Roadmap'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubmitTab(isDark, textP, textS, scheme),
                const FeedbackForumPreview(),
                const ScrollableRoadmapWidget(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSubmitTab(bool isDark, Color textP, Color textS, ColorScheme scheme) {
    final fieldBg = isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFF0EDE9);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Hero header ──────────────────────────────────────────────
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28, fontWeight: FontWeight.w800, color: textP, height: 1.15),
              children: [
                const TextSpan(text: 'Share your '),
                TextSpan(
                  text: 'thoughts',
                  style: TextStyle(color: isDark?Color.fromARGB(255, 161, 124, 209):AppColors.lightPrimary),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us shape the future of intelligent empathy. '
            'Whether it\'s a bug, a brilliant idea, or just some love, we\'re listening.',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: textS, height: 1.55),
          ),
          const SizedBox(height: 24),

          // ── White / dark card ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                  blurRadius: 20, offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // TYPE OF FEEDBACK
              Text('TYPE OF FEEDBACK',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: textS, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: _typeCards.map((card) {
                  final label = card['label'] as String;
                  final icon  = card['icon']  as IconData;
                  final isSelected = _selectedType == label;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ?  AppColors.lightPrimary .withOpacity(0.28)
                            : fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.lightPrimary 
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                            size: 18,
                            color: isSelected ? Color.fromARGB(255, 170, 51, 210) : textS),
                          const SizedBox(width: 8),
                          Text(label,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: isSelected ? Color.fromARGB(255, 186, 123, 206): textP)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // REFINE CATEGORY
              Text('REFINE CATEGORY',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: textS, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: textS, size: 20),
                    dropdownColor: isDark
                        ? AppColors.darkSurfaceContainerHigh
                        : Colors.white,
                    style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: GoogleFonts.beVietnamPro(color: textP)),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // YOUR MESSAGE
              Text('YOUR MESSAGE',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: textS, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 5,
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
                decoration: InputDecoration(
                  hintText: 'Tell us more about your experience...',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: textS),
                  filled: true,
                  fillColor: fieldBg,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.lightPrimary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity, height: 50,
                child: _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : GestureDetector(
                        onTap: _submitFeedback,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
                            ),
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lightPrimary.withOpacity(0.35),
                                blurRadius: 14, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Submit Feedback',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Response time card ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: 12, offset: const Offset(0, 2),
              )],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Our Response Time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: textP)),
                  const SizedBox(height: 4),
                  Text(
                    'We typically review all community feedback within 24–48 hours.',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: textS, height: 1.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: AppColors.lightPrimary),
                    const SizedBox(width: 4),
                    Text('HIGH PRIORITY',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.lightPrimary, letterSpacing: 0.5)),
                  ]),
                ],
              )),
              Icon(Icons.support_agent_rounded,
                  size: 40, color: textS.withOpacity(0.3)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Banner ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0533), Color(0xFF2D0B5A)],
                  ),
                ),
              ),
              // Star dots
              Positioned.fill(child: CustomPaint(painter: _StarDotsPainter())),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Every piece of feedback makes\nNudge smarter.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.white, height: 1.3),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // // ── Global input stat ────────────────────────────────────────
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          //   decoration: BoxDecoration(
          //     color: isDark ? AppColors.darkSurfaceContainerHigh : Colors.white,
          //     borderRadius: BorderRadius.circular(16),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [
          //       Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //         Text('GLOBAL INPUT',
          //           style: GoogleFonts.beVietnamPro(
          //             fontSize: 10, fontWeight: FontWeight.w700,
          //             color: textS, letterSpacing: 0.8)),
          //         const SizedBox(height: 4),
          //         Text('12.4k',
          //           style: GoogleFonts.plusJakartaSans(
          //             fontSize: 26, fontWeight: FontWeight.w800, color: textP)),
          //       ]),
          //       Container(
          //         width: 40, height: 40,
          //         decoration: BoxDecoration(
          //           color: AppColors.lightPrimary.withOpacity(0.1),
          //           borderRadius: BorderRadius.circular(12),
          //         ),
          //         child: const Icon(Icons.trending_up_rounded,
          //             color: AppColors.lightPrimary, size: 22),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

// Simple star dots for the banner background
class _StarDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.25);
    final positions = [
      Offset(size.width * 0.72, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.55),
      Offset(size.width * 0.60, size.height * 0.75),
      Offset(size.width * 0.92, size.height * 0.25),
      Offset(size.width * 0.78, size.height * 0.88),
    ];
    for (final pos in positions) {
      canvas.drawCircle(pos, 1.5, p);
    }
    final pBig = Paint()..color = Colors.white.withOpacity(0.12);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.5), 28, pBig);
  }

  @override
  bool shouldRepaint(_) => false;
}

// lib/screens/feedback/feedback_forum_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/scrollable_roadmap.dart';
import '../../widgets/stitch_top_bar.dart';

class FeedbackForumScreen extends StatefulWidget {
  const FeedbackForumScreen({super.key});

  @override
  State<FeedbackForumScreen> createState() => _FeedbackForumScreenState();
}

class _FeedbackForumScreenState extends State<FeedbackForumScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  String _filterStatus = 'all';
  String _sortBy = 'top'; // 'top' | 'new'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Map<String, bool> _upvotedFeedbacks = {};

  final List<String> _statusOptions = [
    'all', 'received', 'planned', 'in_progress', 'completed'];

  // ── Category color palette (maps section/tag to colour) ──────────────────
  static const Map<String, Color> _categoryColors = {
    'workspace':  Color(0xFF0D9488),
    'data':       Color(0xFFE07830),
    'design':     Color(0xFF751FE7),
    'accessibility': Color(0xFF2563EB),
    'utility':    Color(0xFF059669),
    'general':    Color(0xFF6B7280),
  };

  Color _categoryColor(String tag) {
    final key = tag.toLowerCase();
    for (final entry in _categoryColors.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return const Color(0xFF6B7280);
  }

  // ── Filtering / sorting ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _processedList(List<Map<String, dynamic>> raw) {
    var list = raw.where((f) => f['type'] == 'Feature Request').toList();

    if (_filterStatus != 'all') {
      list = list.where((f) => f['status'] == _filterStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) {
        final title = (f['adminTitle'] ?? '').toLowerCase();
        final msg   = (f['message']    ?? '').toLowerCase();
        return title.contains(q) || msg.contains(q);
      }).toList();
    }

    if (_sortBy == 'top') {
      list.sort((a, b) {
        final av = (a['upvotes'] as List?)?.length ?? 0;
        final bv = (b['upvotes'] as List?)?.length ?? 0;
        return bv.compareTo(av);
      });
    } else {
      list.sort((a, b) {
        final at = a['createdAt'] as int? ?? 0;
        final bt = b['createdAt'] as int? ?? 0;
        return bt.compareTo(at);
      });
    }
    return list;
  }

  Future<void> _toggleUpvote(String id, bool currently) async {
    setState(() => _upvotedFeedbacks[id] = !currently);
    try {
      await _apiService.upvoteFeedback(feedbackId: id, upvote: !currently);
    } catch (_) {
      setState(() => _upvotedFeedbacks[id] = currently);
    }
  }

  void _initUpvotes(List<Map<String, dynamic>> feedbacks) async {
    for (final f in feedbacks) {
      final id = f['id'] as String?;
      if (id == null) continue;
      final upvotes = f['upvotes'] as List<dynamic>? ?? [];
      final user = await _apiService.getUser();
      _upvotedFeedbacks[id] =
          upvotes.any((u) => u is Map && u['userId'] == user.id);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  String _statusLabel(String s) {
    switch (s) {
      case 'received':    return 'Under Review';
      case 'planned':     return 'Planned';
      case 'in_progress': return 'In Progress';
      case 'completed':   return 'Completed';
      default:            return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'received':    return const Color(0xFF6B7280);
      case 'planned':     return const Color(0xFFE07830);
      case 'in_progress': return const Color(0xFF059669);
      case 'completed':   return const Color(0xFF2563EB);
      default:            return const Color(0xFF6B7280);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final scaffoldBg = isDark ? AppColors.darkBackground : const Color(0xFFF5F3F0);
    final textP = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final textS = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    return Scaffold(
      backgroundColor: scaffoldBg,
      // Use a plain AppBar so the system back gesture still works,
      // but render our own content inside the title area.
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        toolbarHeight: 0, // hide default toolbar — we draw our own header below
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Fixed header: stitch top bar + hero + subtitle + tabs ────
            const StitchTopBar(showBack: true, trailingIcon: Icons.person_outline_rounded),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Hero title
                  /* if (isDark) ...[
                    Text('Shape the',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30, fontWeight: FontWeight.w800,
                        color: textP, height: 1.1)),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFD4BBFF), Color(0xFF9C6FE4)],
                      ).createShader(bounds),
                      child: Text('Future.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30, fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic, color: Colors.white)),
                    ),
                  ] else ...[
                     */RichText(text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30, fontWeight: FontWeight.w800,
                        color: textP, height: 1.2),
                      children: [
                        const TextSpan(text: 'Shape our '),
                        TextSpan(
                          text: 'Future',
                          style: const TextStyle(color: AppColors.lightPrimary)),
                      ],
                    )),
                  /* ], */
                  const SizedBox(height: 6),
                  Text(
                    'We\'re building Nudge with you. Suggest new features, '
                    'vote for your favorites, and track our roadmap.',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13, color: textS, height: 1.5)),
                  const SizedBox(height: 16),

                  // ── Pill tab toggle ──────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHigh
                          : Colors.white,
                      borderRadius: BorderRadius.circular(9999),
                      border: isDark ? null : Border.all(
                        color: Colors.black.withOpacity(0.08)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainerHighest
                            : const Color(0xFFF0EDE9),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.08)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: textP,
                      unselectedLabelColor: textS,
                      labelStyle: GoogleFonts.beVietnamPro(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle:
                          GoogleFonts.beVietnamPro(fontSize: 13),
                      tabs: const [
                        Tab(text: 'Feature Requests'),
                        Tab(text: 'Roadmap'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── TabBarView fills ALL remaining space ──────────────────
            // Each tab owns its own scroll — no outer SingleChildScrollView.
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Feature Requests scrolls internally via ListView
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildRequestsTab(isDark, textP, textS),
                  ),
                  // Roadmap gets full height — its own ScrollController works
                  const ScrollableRoadmapWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(bool isDark, Color textP, Color textS) {
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final fieldBg = isDark
        ? AppColors.darkSurfaceContainerHighest
        : const Color(0xFFF0EDE9);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Filter / sort row ──────────────────────────────────────────
      Row(children: [
        // Status filter pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fieldBg, borderRadius: BorderRadius.circular(9999)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: textS, size: 16),
              dropdownColor: isDark
                  ? AppColors.darkSurfaceContainerHigh
                  : Colors.white,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: textP),
              onChanged: (v) => setState(() => _filterStatus = v!),
              items: _statusOptions.map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s == 'all' ? 'Status: All' : 'Status: ${_statusLabel(s)}',
                  style: GoogleFonts.beVietnamPro(color: textP)),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Sort pill
        GestureDetector(
          onTap: () => setState(() =>
              _sortBy = _sortBy == 'top' ? 'new' : 'top'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(9999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Sort: ${_sortBy == 'top' ? 'Top' : 'New'}',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: textP)),
              const SizedBox(width: 4),
              Icon(Icons.swap_vert_rounded, color: textS, size: 16),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      // ── Search ─────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: fieldBg, borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search requests...',
            hintStyle: GoogleFonts.beVietnamPro(fontSize: 14, color: textS),
            prefixIcon: Icon(Icons.search_rounded, color: textS, size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // ── List ───────────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _apiService.getFeedbacksStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: AppColors.lightPrimary));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}',
                  style: GoogleFonts.beVietnamPro(color: textS)));
            }
            final all = snapshot.data ?? [];
            if (_upvotedFeedbacks.isEmpty && all.isNotEmpty) {
              _initUpvotes(all);
            }
            final list = _processedList(all);
            if (list.isEmpty) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 56, color: textS.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text('No feature requests yet',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: textP)),
                  const SizedBox(height: 6),
                  Text('Be the first to suggest a feature!',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: textS)),
                ],
              ));
            }
            return ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (ctx, i) =>
                  _buildCard(list[i], i, list.length, isDark, textP, textS, cardBg),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildCard(
    Map<String, dynamic> feedback,
    int index,
    int total,
    bool isDark,
    Color textP,
    Color textS,
    Color cardBg,
  ) {
    final id          = feedback['id'] as String? ?? '';
    final title       = feedback['adminTitle'] ?? 'No Title';
    final message     = feedback['message']    ?? '';
    final status      = feedback['status']     ?? 'received';
    final section     = feedback['section']    ?? 'General';
    final upvotes     = (feedback['upvotes'] as List<dynamic>? ?? []).length;
    final isUpvoted   = _upvotedFeedbacks[id] ?? false;
    final createdAt   = feedback['createdAt'] as int?;
    final comments    = (feedback['comments'] as List<dynamic>? ?? []).length;
    final adminResponse = feedback['adminResponse'];

    // Top item (most votes) gets a purple featured card
    final isTop = index == 0 && upvotes > 10;

    final timeAgo = _timeAgo(createdAt);

    if (isTop) return _buildTopCard(feedback, id, title, message, status,
        upvotes, isUpvoted, isDark, textP, textS);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
          blurRadius: 10, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: category + status + upvote counter
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _categoryPill(section, isDark),
            const SizedBox(width: 8),
            _statusPill(status, isDark),
            const Spacer(),
            GestureDetector(
              onTap: id.isNotEmpty
                  ? () => _toggleUpvote(id, isUpvoted)
                  : null,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUpvoted
                        ? AppColors.lightPrimary
                        : (isDark
                            ? AppColors.darkSurfaceContainerHighest
                            : const Color(0xFFF0EDE9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Icon(Icons.keyboard_arrow_up_rounded,
                      color: isUpvoted ? Colors.white : textS, size: 16),
                    Text(upvotes.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isUpvoted ? Colors.white : textP)),
                  ]),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),

          // Title
          Text(title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w700, color: textP)),
          const SizedBox(height: 6),

          // Message
          Text(
            message.length > 120 ? '${message.substring(0, 120)}...' : message,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13, color: textS, height: 1.5)),
          const SizedBox(height: 12),

          // Meta row: avatars / comments + date
          Row(children: [
            if (comments > 0) ...[
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 14, color: AppColors.lightPrimary),
              const SizedBox(width: 4),
              Text('$comments Comments',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: AppColors.lightPrimary,
                  fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            const Spacer(),
            Text(timeAgo.toUpperCase(),
              style: GoogleFonts.beVietnamPro(
                fontSize: 11, color: textS, letterSpacing: 0.3)),
          ]),

          // Admin response
          if (adminResponse != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Team Response',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.success)),
                  const SizedBox(height: 4),
                  Text(adminResponse['response'] ?? '',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13, color: textP, height: 1.4)),
                ],
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildTopCard(
    Map<String, dynamic> feedback,
    String id, String title, String message, String status,
    int upvotes, bool isUpvoted,
    bool isDark, Color textP, Color textS,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
        ),
        boxShadow: [BoxShadow(
          color: AppColors.lightPrimary.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 6),
        )],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // TOP REQUEST pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text('TOP REQUEST',
            style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 0.8)),
        ),
        const SizedBox(height: 12),

        Text(title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: Colors.white, height: 1.2)),
        const SizedBox(height: 8),

        Text(
          message.length > 140 ? '${message.substring(0, 140)}...' : message,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13, color: Colors.white70, height: 1.55)),
        const SizedBox(height: 14),

        // Milestone card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.rocket_launch_outlined,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NEXT MILESTONE',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: Colors.white60, letterSpacing: 0.6)),
              Text(_statusLabel(status),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // Upvote button
        GestureDetector(
          onTap: id.isNotEmpty ? () => _toggleUpvote(id, isUpvoted) : null,
          child: Container(
            width: double.infinity, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.thumb_up_outlined,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('${isUpvoted ? 'Voted' : 'Upvote'} Feature ($upvotes)',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _categoryPill(String section, bool isDark) {
    final label = _sectionLabel(section).toUpperCase();
    final color = _categoryColor(section);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6)),
      child: Text(label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _statusPill(String status, bool isDark) {
    final color = _statusColor(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(_statusLabel(status),
        style: GoogleFonts.beVietnamPro(
          fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  String _sectionLabel(String s) {
    const map = {
      '/dashboard':     'General',
      '/contacts':      'Contacts',
      '/groups':        'Groups',
      '/analytics':     'Data',
      '/notifications': 'Utility',
      '/settings':      'Design',
      'unknown':        'General',
    };
    return map[s] ?? s;
  }

  String _timeAgo(int? ms) {
    if (ms == null) return '';
    final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inDays > 7)  return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays > 0)  return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}

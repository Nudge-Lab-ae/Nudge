import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nudge/providers/theme_provider.dart';

class FeedbackManagementScreen extends StatefulWidget {
  const FeedbackManagementScreen({super.key});

  @override
  State<FeedbackManagementScreen> createState() => _FeedbackManagementScreenState();
}

class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
  final ApiService _apiService = ApiService();
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  final List<String> _statusOptions = [
    'all', 'new', 'reviewed', 'responded', 'received', 'planned', 'in_progress', 'completed'
  ];
  final List<String> _typeOptions = [
    'all', 'Feedback', 'Bug Report', 'Feature Request', 'General Inquiry', 'Complaint'
  ];

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final isDark = themeProvider.isDarkMode;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: GradientText(
            text: 'NUDGE',
            style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 25),
            // Near-black wordmark per Stitch mockups (no purple/blue gradient).
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
                  ? const [Color(0xFFE7E1DE), Color(0xFF968DA1)]
                  : const [Color(0xFF1A1A1A), Color(0xFF666666)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: scheme.primary),
          surfaceTintColor: Colors.transparent,
          backgroundColor: scheme.surfaceContainerLow,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: scheme.onSurface),
              onPressed: () => setState(() {}),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStatsOverview(),
            _buildFilterSection(),
            Expanded(child: _buildFeedbackList()),
          ],
        ),
      ),
    );
  }

  // ── Stats overview ────────────────────────────────────────────────────────

  Widget _buildStatsOverview() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final scheme = Theme.of(context).colorScheme;
    // Use a proper surface colour — never colorScheme.outline as a background
    final headerBg = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;

    return FutureBuilder<Map<String, dynamic>>(
      future: _apiService.getFeedbackStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: headerBg,
            child: Center(
              child: CircularProgressIndicator(color: scheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: headerBg,
            child: Text(
              'Error loading stats: ${snapshot.error}',
              style: TextStyle(color: scheme.onSurface),
            ),
          );
        }

        final stats = snapshot.data ?? {};
        final total         = stats['total']     ?? 0;
        final newCount      = stats['new']       ?? 0;
        final reviewedCount = stats['reviewed']  ?? 0;
        final respondedCount= stats['responded'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          color: headerBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('Total',     total.toString(),          scheme.secondary),
                  _buildStatCard('New',       newCount.toString(),       AppColors.warning),
                  _buildStatCard('Reviewed',  reviewedCount.toString(),  AppColors.success),
                  _buildStatCard('Responded', respondedCount.toString(), scheme.primary),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            // onSurfaceVariant — a legible secondary text token in both modes
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ── Filter section ────────────────────────────────────────────────────────

  Widget _buildFilterSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: isDark ? scheme.surfaceContainerHigh : scheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    // onSurfaceVariant always readable in both modes
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                DropdownButton<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? scheme.surfaceContainerHigh
                      : Colors.white,
                  style: TextStyle(color: scheme.onSurface),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == 'all' ? 'All Statuses' : status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'all'
                              ? scheme.onSurface
                              : _getStatusColor(status),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TYPE',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                DropdownButton<String>(
                  value: _typeFilter,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? scheme.surfaceContainerHigh
                      : Colors.white,
                  style: TextStyle(color: scheme.onSurface),
                  items: _typeOptions.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type == 'all' ? 'All Types' : type,
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _typeFilter = v!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Feedback list ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterFeedbacks(List<Map<String, dynamic>> feedbacks) {
    var filtered = feedbacks;
    if (_statusFilter != 'all') filtered = filtered.where((f) => f['status'] == _statusFilter).toList();
    if (_typeFilter   != 'all') filtered = filtered.where((f) => f['type']   == _typeFilter  ).toList();
    return filtered;
  }

  Widget _buildFeedbackList() {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _apiService.getFeedbacksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: scheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading feedbacks: ${snapshot.error}',
              style: TextStyle(color: scheme.onSurface),
            ),
          );
        }

        final filtered = _filterFeedbacks(snapshot.data ?? []);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feedback_outlined, size: 64, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'No feedback found',
                  style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                ),
                if (_statusFilter != 'all' || _typeFilter != 'all')
                  TextButton(
                    onPressed: () => setState(() {
                      _statusFilter = 'all';
                      _typeFilter   = 'all';
                    }),
                    child: Text('Clear Filters',
                        style: TextStyle(color: scheme.primary)),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) => _buildFeedbackItem(filtered[i]),
        );
      },
    );
  }

  // ── Feedback item card ────────────────────────────────────────────────────

  Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark  = themeProvider.isDarkMode;
    final scheme  = Theme.of(context).colorScheme;

    final user          = feedback['user'] ?? {};
    final timestamp     = feedback['timestamp'] ?? DateTime.now();
    final status        = feedback['status'] ?? 'new';
    final type          = feedback['type'] ?? 'Feedback';
    final message       = feedback['message'] ?? '';
    final adminResponse = feedback['adminResponse'];
    final section       = feedback['section'] ?? 'unknown';
    final String? adminTitle = feedback['adminTitle'];
    final isPublic      = feedback['isPublic'] ?? false;

    final titleController    = TextEditingController(text: adminTitle ?? '');
    final responseController = TextEditingController();

    final cardBg   = isDark ? scheme.surfaceContainerHigh : Colors.white;
    final msgBg    = isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh;
    final subText  = scheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: cardBg,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_getTypeIcon(type), color: _getStatusColor(status), size: 20),
        ),
        title: Text(
          adminTitle != null ? adminTitle.toUpperCase() : 'NO TITLE SET',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${user['username'] ?? user['email'] ?? 'Unknown User'}',
              style: TextStyle(color: scheme.onSurface, fontSize: 13),
            ),
            Text(
              'Section: ${_getSectionName(section)}',
              style: TextStyle(fontSize: 12, color: subText),
            ),
            Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
              style: TextStyle(fontSize: 12, color: subText),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _getStatusColor(status),
              padding: EdgeInsets.zero,
            ),
            if (isPublic)
              Chip(
                label: const Text(
                  'PUBLIC',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppColors.success,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('User',        '${user['username'] ?? 'N/A'} (${user['email']})'),
                _buildInfoRow('Platform',    feedback['platform']   ?? 'Unknown'),
                _buildInfoRow('App Version', feedback['appVersion'] ?? '1.0.0'),
                _buildInfoRow('Section',     _getSectionName(section)),

                const SizedBox(height: 12),

                // Admin title input
                Text('Admin Title (for forum):',
                    style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                const SizedBox(height: 4),
                TextField(
                  controller: titleController,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter a descriptive title for the feedback forum...',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outline)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outline)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.primary, width: 2)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.save, color: scheme.primary),
                      onPressed: () async {
                        if (titleController.text.trim().isNotEmpty) {
                          await _apiService.updateFeedbackAdminData(
                            feedbackId: feedback['id'],
                            adminTitle: titleController.text.trim(),
                          );
                          TopMessageService().showMessage(
                            context: context,
                            message: 'Title updated',
                            backgroundColor: AppColors.success,
                            icon: Icons.check,
                          );
                        }
                      },
                    ),
                    fillColor: isDark
                        ? scheme.surfaceContainerHighest
                        : scheme.surfaceContainerLow,
                    filled: true,
                  ),
                ),

                const SizedBox(height: 12),

                // User message
                Text('User Message:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // Proper surface container — never colorScheme.outline as a bg
                    color: msgBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? scheme.outlineVariant : Colors.transparent,
                    ),
                  ),
                  child: Text(message, style: TextStyle(color: scheme.onSurface)),
                ),

                const SizedBox(height: 12),

                // Admin response
                Text('Admin Response:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.green.shade300 : AppColors.success,
                    )),
                const SizedBox(height: 4),
                TextField(
                  controller: responseController,
                  maxLines: 3,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: adminResponse != null
                        ? 'Update existing response...'
                        : 'Enter your response...',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outline)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outline)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.primary, width: 2)),
                    fillColor: isDark
                        ? scheme.surfaceContainerHighest
                        : scheme.surfaceContainerLow,
                    filled: true,
                  ),
                ),

                const SizedBox(height: 16),
                _buildEnhancedActionButtons(feedback, responseController, titleController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildEnhancedActionButtons(
    Map<String, dynamic> feedback,
    TextEditingController responseController,
    TextEditingController titleController,
  ) {
    final isDark  = Provider.of<ThemeProvider>(context).isDarkMode;
    final scheme  = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: feedback['status'] ?? 'new',
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
                  style: TextStyle(color: scheme.onSurface),
                  items: ['new', 'reviewed', 'responded', 'received', 'planned', 'in_progress', 'completed']
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase(),
                                style: TextStyle(
                                    color: _getStatusColor(s),
                                    fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _updateFeedbackStatus(feedback['id'], v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(flex: 1, child: SizedBox()),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            if (feedback['status'] != 'responded')
              Expanded(
                child: MaterialButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (responseController.text.trim().isNotEmpty) {
                      _addFeedbackResponse(feedback['id'], responseController.text.trim());
                      responseController.clear();
                    }
                  },
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'Send Response',
                        // Always white on the green background
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),

            if (feedback['status'] != 'responded') const SizedBox(width: 8),

            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    await _apiService.updateFeedbackAdminData(
                      feedbackId: feedback['id'],
                      adminTitle: titleController.text.trim(),
                    );
                    TopMessageService().showMessage(
                      context: context,
                      message: 'Title saved.',
                      backgroundColor: AppColors.success,
                      icon: Icons.check,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Save Title', style: TextStyle(fontSize: 13)),
              ),
            ),

            const SizedBox(width: 8),

            IconButton(
              onPressed: () => _deleteFeedback(feedback),
              icon: Icon(
                Icons.delete,
                color: isDark ? Colors.red.shade300 : scheme.error,
              ),
              tooltip: 'Delete',
            ),
          ],
        ),
      ],
    );
  }

  // ── Firestore actions ─────────────────────────────────────────────────────

  Future<void> _addFeedbackResponse(String feedbackId, String response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await FirebaseFirestore.instance.collection('feedbacks').doc(feedbackId).update({
        'adminResponse': {
          'response': response,
          'responderEmail': user.email,
          'timestamp': DateTime.now(),
        },
        'status': 'responded',
        'updatedAt': DateTime.now(),
      });
      TopMessageService().showMessage(
        context: context,
        message: 'Response sent successfully.',
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
    } catch (e) {
      TopMessageService().showMessage(
        context: context,
        message: 'Error sending response: $e',
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
    }
  }

  void _updateFeedbackStatus(String feedbackId, String newStatus) async {
    try {
      await _apiService.updateFeedbackStatus(feedbackId, newStatus);
      TopMessageService().showMessage(
        context: context,
        message: 'Status updated successfully.',
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
    } catch (e) {
      TopMessageService().showMessage(
        context: context,
        message: 'Error updating status: $e',
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
    }
  }

  void _deleteFeedback(Map<String, dynamic> feedback) async {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text('Delete Feedback',
            style: TextStyle(color: scheme.onSurface)),
        content: Text(
          'Are you sure you want to delete this feedback? This action cannot be undone.',
          // onSurfaceVariant — legible in both modes
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: scheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                  color: isDark ? Colors.red.shade300 : scheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteFeedback(feedback['id']);
        TopMessageService().showMessage(
          context: context,
          message: 'Feedback deleted successfully.',
          backgroundColor: AppColors.success,
          icon: Icons.check,
        );
      } catch (e) {
        TopMessageService().showMessage(
          context: context,
          message: 'Error deleting feedback: $e',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
      }
    }
  }

  // ── Helper methods ────────────────────────────────────────────────────────

  Widget _buildInfoRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: scheme.onSurface)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  String _getSectionName(String section) {
    const map = {
      '/dashboard':    'Dashboard',
      '/contacts':     'Contacts',
      '/groups':       'Groups',
      '/analytics':    'Analytics',
      '/notifications':'Notifications',
      '/settings':     'Settings',
      '/welcome':      'Welcome Screen',
      '/login':        'Login Screen',
      '/register':     'Register Screen',
      'unknown':       'Unknown Section',
    };
    return map[section] ?? section;
  }

  Color _getStatusColor(String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'new':         return AppColors.warning;
      case 'reviewed':    return scheme.secondary;
      case 'responded':   return AppColors.success;
      case 'received':    return AppColors.warning;
      case 'planned':     return scheme.secondary;
      case 'in_progress': return scheme.primary;
      case 'completed':   return AppColors.success;
      default:            return scheme.outline;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Bug Report':      return Icons.bug_report;
      case 'Feature Request': return Icons.lightbulb_outline;
      case 'Complaint':       return Icons.warning;
      case 'General Inquiry': return Icons.help_outline;
      default:                return Icons.feedback;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/gradient_text.dart';
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: themeProvider.getBackgroundColor(context),
        appBar: AppBar(
          title: GradientText(
            text: 'NUDGE',
            style: const TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
            gradient: const LinearGradient(
              colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: theme.colorScheme.primary),
          surfaceTintColor: Colors.transparent,
          backgroundColor: themeProvider.getSurfaceColor(context),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: themeProvider.isDarkMode ? Colors.white : null),
              onPressed: () {
                setState(() {});
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            // Stats Overview
            _buildStatsOverview(),
            
            // Filters
            _buildFilterSection(),
            
            // Feedback List
            Expanded(
              child: _buildFeedbackList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _apiService.getFeedbackStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Text(
              'Error loading stats: ${snapshot.error}',
              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
            ),
          );
        }
        
        final stats = snapshot.data ?? {};
        final total = stats['total'] ?? 0;
        final newCount = stats['new'] ?? 0;
        final reviewedCount = stats['reviewed'] ?? 0;
        final respondedCount = stats['responded'] ?? 0;
        
        return Container(
          padding: const EdgeInsets.all(16),
          color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode ? Colors.white : const Color(0xff3CB3E9),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('Total', total.toString(), Colors.blue),
                  _buildStatCard('New', newCount.toString(), Colors.orange),
                  _buildStatCard('Reviewed', reviewedCount.toString(), Colors.green),
                  _buildStatCard('Responded', respondedCount.toString(), Colors.purple),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
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
            color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.getSurfaceColor(context),
        border: Border(
          bottom: BorderSide(
            color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _statusFilter,
                      isExpanded: true,
                      dropdownColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(
                            status == 'all' ? 'All Statuses' : status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'all' 
                                  ? (themeProvider.isDarkMode ? Colors.white : Colors.black)
                                  : _getStatusColor(status),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _statusFilter = value!;
                        });
                      },
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
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _typeFilter,
                      isExpanded: true,
                      dropdownColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555),
                      ),
                      items: _typeOptions.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type == 'all' ? 'All Types' : type,
                            style: TextStyle(
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _typeFilter = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterFeedbacks(List<Map<String, dynamic>> feedbacks) {
    List<Map<String, dynamic>> filtered = feedbacks;

    if (_statusFilter != 'all') {
      filtered = filtered.where((f) => f['status'] == _statusFilter).toList();
    }

    if (_typeFilter != 'all') {
      filtered = filtered.where((f) => f['type'] == _typeFilter).toList();
    }

    return filtered;
  }

  Widget _buildFeedbackList() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _apiService.getFeedbacksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading feedbacks: ${snapshot.error}',
              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
            ),
          );
        }
        
        final allFeedbacks = snapshot.data ?? [];
        final filteredFeedbacks = _filterFeedbacks(allFeedbacks);
        
        if (filteredFeedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.feedback_outlined,
                  size: 64,
                  color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No feedback found',
                  style: TextStyle(
                    fontSize: 18,
                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
                if (_statusFilter != 'all' || _typeFilter != 'all')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _statusFilter = 'all';
                        _typeFilter = 'all';
                      });
                    },
                    child: Text(
                      'Clear Filters',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: filteredFeedbacks.length,
          itemBuilder: (context, index) {
            final feedback = filteredFeedbacks[index];
            return _buildFeedbackItem(feedback);
          },
        );
      },
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    final user = feedback['user'] ?? {};
    final timestamp = feedback['timestamp'] ?? DateTime.now();
    final status = feedback['status'] ?? 'new';
    final type = feedback['type'] ?? 'Feedback';
    final message = feedback['message'] ?? '';
    final adminResponse = feedback['adminResponse'];
    final section = feedback['section'] ?? 'unknown';
    String? adminTitle = (feedback['adminTitle']);
    final isPublic = feedback['isPublic'] ?? false;
    
    final TextEditingController _titleController = TextEditingController(text: adminTitle ?? '');
    final TextEditingController _responseController = TextEditingController();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getTypeIcon(type),
            color: _getStatusColor(status),
            size: 20,
          ),
        ),
        title: Text(
          adminTitle != null ? adminTitle.toUpperCase() : 'NO TITLE SET',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${user['username'] ?? user['email'] ?? 'Unknown User'}',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.grey.shade300 : Colors.black,
              ),
            ),
            Text(
              'Section: ${_getSectionName(section)}',
              style: TextStyle(
                fontSize: 12,
                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
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
                backgroundColor: Colors.green,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info
                _buildInfoRow('User', '${user['username'] ?? 'N/A'} (${user['email']})'),
                _buildInfoRow('Platform', feedback['platform'] ?? 'Unknown'),
                _buildInfoRow('App Version', feedback['appVersion'] ?? '1.0.0'),
                _buildInfoRow('Section', _getSectionName(section)),
                
                const SizedBox(height: 12),
                
                // Admin Title Input
                Text(
                  'Admin Title (for forum):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Enter a descriptive title for the feedback forum...',
                    hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.save,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () async {
                        if (_titleController.text.trim().isNotEmpty) {
                          await _apiService.updateFeedbackAdminData(
                            feedbackId: feedback['id'],
                            adminTitle: _titleController.text.trim(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Title updated'),
                              backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
                            ),
                          );
                        }
                      },
                    ),
                    fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                    filled: true,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'User Message:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                
                // Admin Response
                const SizedBox(height: 12),
                Text(
                  'Admin Response:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.green.shade300 : Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _responseController,
                  maxLines: 3,
                  style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: adminResponse != null 
                        ? 'Update existing response...' 
                        : 'Enter your response...',
                    hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                    filled: true,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Enhanced Action Buttons
                _buildEnhancedActionButtons(feedback, _responseController, _titleController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButtons(
    Map<String, dynamic> feedback, 
    TextEditingController responseController,
    TextEditingController titleController,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    
    return Column(
      children: [
        Row(
          children: [
            // Status Update
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: feedback['status'] ?? 'new',
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
                  items: ['new', 'reviewed', 'responded', 'received', 'planned', 'in_progress', 'completed'].map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newStatus) {
                    if (newStatus != null) {
                      _updateFeedbackStatus(feedback['id'], newStatus);
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Public/Private Toggle Placeholder
            const Expanded(
              flex: 1,
              child: SizedBox(), // Keeping the placeholder as in original
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            // Respond Button
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
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: const Center(
                      child: Text(
                        'Send Response',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            
            if (feedback['status'] != 'responded') const SizedBox(width: 8),
            
            // Save Title Button
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    await _apiService.updateFeedbackAdminData(
                      feedbackId: feedback['id'],
                      adminTitle: titleController.text.trim(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Title saved'),
                        backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Save Title',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Delete Button
            IconButton(
              onPressed: () => _deleteFeedback(feedback),
              icon: Icon(
                Icons.delete,
                color: themeProvider.isDarkMode ? Colors.red.shade300 : Colors.red,
              ),
              tooltip: 'Delete',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addFeedbackResponse(String feedbackId, String response) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    FirebaseFirestore _firestore = FirebaseFirestore.instance;
    FirebaseAuth _auth = FirebaseAuth.instance;
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final responseData = {
      'response': response,
      'responderEmail': user.email,
      'timestamp': DateTime.now(),
    };

    try {
      await _firestore.collection('feedbacks').doc(feedbackId).update({
        'adminResponse': responseData,
        'status': 'responded',
        'updatedAt': DateTime.now(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Response sent successfully'),
          backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending response: $e'),
          backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
        ),
      );
    }
  }

  String _getSectionName(String section) {
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
    
    return sectionMap[section] ?? section;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new': return Colors.orange;
      case 'reviewed': return Colors.blue;
      case 'responded': return Colors.green;
      case 'received': return Colors.orange;
      case 'planned': return Colors.blue;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Bug Report': return Icons.bug_report;
      case 'Feature Request': return Icons.lightbulb_outline;
      case 'Complaint': return Icons.warning;
      case 'General Inquiry': return Icons.help_outline;
      default: return Icons.feedback;
    }
  }

  void _updateFeedbackStatus(String feedbackId, String newStatus) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    try {
      await _apiService.updateFeedbackStatus(feedbackId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Status updated successfully'),
          backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
        ),
      );
    }
  }

  void _deleteFeedback(Map<String, dynamic> feedback) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // final theme = Theme.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Delete Feedback',
          style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete this feedback? This action cannot be undone.',
          style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.red.shade300 : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _apiService.deleteFeedback(feedback['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Feedback deleted successfully'),
            backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting feedback: $e'),
            backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : null,
          ),
        );
      }
    }
  }
}
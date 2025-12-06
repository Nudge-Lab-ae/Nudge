import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/gradient_text.dart';

class FeedbackForumScreen extends StatefulWidget {
  const FeedbackForumScreen({super.key});

  @override
  State<FeedbackForumScreen> createState() => _FeedbackForumScreenState();
}

class _FeedbackForumScreenState extends State<FeedbackForumScreen> {
  final ApiService _apiService = ApiService();
  String _filterStatus = 'all';
  final List<String> _statusOptions = ['all', 'received', 'planned', 'in_progress', 'completed'];

  // Client-side filtering function
  List<Map<String, dynamic>> _filterFeedbacks(List<Map<String, dynamic>> feedbacks) {
    List<Map<String, dynamic>> filtered = feedbacks;

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((f) => f['status'] == _filterStatus).toList();
    }

    // Only show public feedbacks in the forum
    filtered = filtered;

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          text: 'NUDGE',
          style: const TextStyle(
            fontSize: 25,
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.bold,
          ),
          gradient: const LinearGradient(
            colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feedback Forum',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff3CB3E9),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'See what others are suggesting and track feature updates',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Text('Filter by status:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == 'all' ? 'All Statuses' : _getStatusDisplayName(status),
                        style: TextStyle(
                          color: _getStatusColor(status),
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
              ],
            ),
          ),
          
          // Feedback List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Now using getFeedbacksStream without filters
              stream: _apiService.getFeedbacksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('Error loading feedback: ${snapshot.error}'),
                      ],
                    ),
                  );
                }
                
                final allFeedbacks = snapshot.data ?? [];
                
                // Apply client-side filtering
                final filteredFeedbacks = _filterFeedbacks(allFeedbacks);
                
                if (filteredFeedbacks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No feedback items yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterStatus != 'all' 
                              ? 'No items with status "${_getStatusDisplayName(_filterStatus)}"'
                              : 'Be the first to share your feedback!',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredFeedbacks.length,
                  itemBuilder: (context, index) {
                    return _buildFeedbackItem(filteredFeedbacks[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
    final title = feedback['adminTitle'] ?? 'No Title';
    final message = feedback['message'] ?? '';
    final status = feedback['status'] ?? 'received';
    final type = feedback['type'] ?? 'Feedback';
    final section = feedback['section'] ?? 'General';
    final user = feedback['user'] ?? {};
    final adminResponse = feedback['adminResponse'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: _getStatusColor(status).withOpacity(0.1),
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
                // Type indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Message preview
            Text(
              message.length > 150 ? '${message.substring(0, 150)}...' : message,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Meta information
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  user['username'] ?? user['email'] ?? 'Anonymous',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _getSectionDisplayName(section),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            
            // Admin Response
            if (adminResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Response:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(adminResponse['response'] ?? ''),
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
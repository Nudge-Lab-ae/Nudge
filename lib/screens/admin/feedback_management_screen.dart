import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
// import 'package:provider/provider.dart';

class FeedbackManagementScreen extends StatefulWidget {
  const FeedbackManagementScreen({super.key});

  @override
  State<FeedbackManagementScreen> createState() => _FeedbackManagementScreenState();
}

class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
  final ApiService _apiService = ApiService();
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  final List<String> _statusOptions = ['all', 'new', 'reviewed', 'responded'];
  final List<String> _typeOptions = [
    'all', 'Feedback', 'Bug Report', 'Feature Request', 'General Inquiry', 'Complaint'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title3.copyWith(
          color: Color.fromRGBO(45, 161, 175, 1), 
          fontFamily: 'RobotoMono'
        )),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
    );
  }

  Widget _buildStatsOverview() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _apiService.getFeedbackStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Text('Error loading stats: ${snapshot.error}'),
          );
        }
        
        final stats = snapshot.data ?? {};
        final total = stats['total'] ?? 0;
        final newCount = stats['new'] ?? 0;
        final reviewedCount = stats['reviewed'] ?? 0;
        final respondedCount = stats['responded'] ?? 0;
        
        return Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(45, 161, 175, 1),
                ),
              ),
              SizedBox(height: 12),
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
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
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
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _statusFilter,
                      isExpanded: true,
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(
                            status == 'all' ? 'All Statuses' : status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
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
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _typeFilter,
                      isExpanded: true,
                      items: _typeOptions.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type == 'all' ? 'All Types' : type),
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

  Widget _buildFeedbackList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _apiService.getFeedbacksStream(statusFilter: _statusFilter == 'all' ? null : _statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading feedbacks: ${snapshot.error}'));
        }
        
        final feedbacks = snapshot.data ?? [];
        
        // Apply type filter
        final filteredFeedbacks = _typeFilter == 'all' 
            ? feedbacks 
            : feedbacks.where((f) => f['type'] == _typeFilter).toList();
        
        if (filteredFeedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feedback_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No feedback found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                if (_statusFilter != 'all' || _typeFilter != 'all')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _statusFilter = 'all';
                        _typeFilter = 'all';
                      });
                    },
                    child: Text('Clear Filters'),
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
    final user = feedback['user'] ?? {};
    final timestamp = feedback['timestamp'] ?? DateTime.now();
    final status = feedback['status'] ?? 'new';
    final type = feedback['type'] ?? 'Feedback';
    final message = feedback['message'] ?? '';
    final adminResponse = feedback['adminResponse'];
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
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
          user['username'] ?? user['email'] ?? 'Unknown User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: _getStatusColor(status),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info
                _buildInfoRow('User', '${user['username'] ?? 'N/A'} (${user['email']})'),
                _buildInfoRow('Platform', feedback['platform'] ?? 'Unknown'),
                _buildInfoRow('App Version', feedback['appVersion'] ?? '1.0.0'),
                
                SizedBox(height: 12),
                
                // Message
                Text(
                  'Message:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(message),
                ),
                
                // Admin Response
                if (adminResponse != null) ...[
                  SizedBox(height: 12),
                  Text(
                    'Admin Response:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminResponse['response'],
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'By ${adminResponse['responderEmail']} on ${DateFormat('MMM dd, yyyy - HH:mm').format(adminResponse['timestamp']?.toDate() ?? DateTime.now())}',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 16),
                
                // Action Buttons
                _buildActionButtons(feedback),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> feedback) {
    return Row(
      children: [
        // Status Update
        Expanded(
          child: DropdownButton<String>(
            value: feedback['status'] ?? 'new',
            isExpanded: true,
            items: ['new', 'reviewed', 'responded'].map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: _getStatusColor(status)),
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
        
        SizedBox(width: 8),
        
        // Respond Button
        if (feedback['status'] != 'responded')
          ElevatedButton.icon(
            onPressed: () => _showResponseDialog(feedback),
            icon: Icon(Icons.reply, size: 16, color: Colors.white,),
            label: Text('Respond'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        
        SizedBox(width: 8),
        
        // Delete Button
        IconButton(
          onPressed: () => _deleteFeedback(feedback),
          icon: Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new': return Colors.orange;
      case 'reviewed': return Colors.blue;
      case 'responded': return Colors.green;
      default: return Colors.grey;
    }
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
    try {
      await _apiService.updateFeedbackStatus(feedbackId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  void _showResponseDialog(Map<String, dynamic> feedback) {
    final TextEditingController responseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${feedback['user']['email']}'),
            SizedBox(height: 8),
            Text('Type: ${feedback['type']}'),
            SizedBox(height: 16),
            Text('Response:'),
            TextField(
              controller: responseController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter your response...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (responseController.text.trim().isNotEmpty) {
                try {
                  await _apiService.addFeedbackResponse(
                    feedback['id'], 
                    responseController.text.trim()
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Response sent successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending response: $e')),
                  );
                }
              }
            },
            child: Text('Send Response'),
          ),
        ],
      ),
    );
  }

  void _deleteFeedback(Map<String, dynamic> feedback) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Feedback'),
        content: Text('Are you sure you want to delete this feedback? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _apiService.deleteFeedback(feedback['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feedback deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting feedback: $e')),
        );
      }
    }
  }
}
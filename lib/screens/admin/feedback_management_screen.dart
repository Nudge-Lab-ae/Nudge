import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/services/api_service.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
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
  final List<String> _statusOptions = [
  'all', 'new', 'reviewed', 'responded', 'received', 'planned', 'in_progress', 'completed'
];
  final List<String> _typeOptions = [
    'all', 'Feedback', 'Bug Report', 'Feature Request', 'General Inquiry', 'Complaint'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5CDEE5), // #5CDEE5
                  Color(0xFF2D85F6), // #2D85F6
                  Color(0xFF7A4BFF), // #7A4BFF
                ], stops: [0.0, 0.6, 1.0], begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xff3CB3E9)),
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
                  color: Color(0xff3CB3E9),
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
// Add these new status options at the top of _FeedbackManagementScreenState

// Update the _buildFeedbackItem method to include admin title and public status
Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
  final user = feedback['user'] ?? {};
  final timestamp = feedback['timestamp'] ?? DateTime.now();
  final status = feedback['status'] ?? 'new';
  final type = feedback['type'] ?? 'Feedback';
  final message = feedback['message'] ?? '';
  final adminResponse = feedback['adminResponse'];
  final section = feedback['section'] ?? 'unknown';
  final adminTitle = feedback['adminTitle'];
  final isPublic = feedback['isPublic'] ?? false;
  // final votes = feedback['votes'] ?? 0;
  
  final TextEditingController _titleController = TextEditingController(text: adminTitle ?? '');
  final TextEditingController _responseController = TextEditingController();

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
        adminTitle ?? 'No Title Set',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From: ${user['username'] ?? user['email'] ?? 'Unknown User'}'),
          Text(
            'Section: ${_getSectionName(section)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
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
          if (isPublic) 
            Chip(
              label: Text(
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
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info
              _buildInfoRow('User', '${user['username'] ?? 'N/A'} (${user['email']})'),
              _buildInfoRow('Platform', feedback['platform'] ?? 'Unknown'),
              _buildInfoRow('App Version', feedback['appVersion'] ?? '1.0.0'),
              _buildInfoRow('Section', _getSectionName(section)),
              
              SizedBox(height: 12),
              
              // Admin Title Input
              Text(
                'Admin Title (for forum):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter a descriptive title for the feedback forum...',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.save),
                    onPressed: () async {
                      if (_titleController.text.trim().isNotEmpty) {
                        await _apiService.updateFeedbackAdminData(
                          feedbackId: feedback['id'],
                          adminTitle: _titleController.text.trim(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Title updated')),
                        );
                      }
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              // Message
              Text(
                'User Message:',
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
              SizedBox(height: 12),
              Text(
                'Admin Response:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              SizedBox(height: 4),
              TextField(
                controller: _responseController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: adminResponse != null 
                      ? 'Update existing response...' 
                      : 'Enter your response...',
                  border: OutlineInputBorder(),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Enhanced Action Buttons
              _buildEnhancedActionButtons(feedback, _responseController, _titleController),
            ],
          ),
        ),
      ],
    ),
  );
}

// Add this new method for enhanced action buttons
Widget _buildEnhancedActionButtons(
  Map<String, dynamic> feedback, 
  TextEditingController responseController,
  TextEditingController titleController,
) {
  // final isPublic = feedback['isPublic'] ?? false;
  
  return Column(
    children: [
      Row(
        children: [
          // Status Update
          Expanded(
            flex: 2,
            child: DropdownButton<String>(
              value: feedback['status'] ?? 'new',
              isExpanded: true,
              items: ['new', 'reviewed', 'responded', 'received', 'planned', 'in_progress', 'completed'].map((status) {
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
          
          // Public/Private Toggle
          Expanded(
            flex: 1,
            child: Center()/* OutlinedButton.icon(
              onPressed: () => _toggleFeedbackVisibility(feedback),
              icon: Icon(
                isPublic ? Icons.visibility : Icons.visibility_off,
                size: 16,
              ),
              label: Text(isPublic ? 'Public' : 'Private'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isPublic ? Colors.green : Colors.grey,
                side: BorderSide(color: isPublic ? Colors.green : Colors.grey),
              ),
            ) */,
          ),
        ],
      ),
      
      SizedBox(height: 8),
      
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
                  child: Center(
                    child: Text('Send Response', style: TextStyle(fontSize: 14, color: Colors.white),),
                  ),
                ),
                // icon: Icon(Icons.reply, size: 16, color: Colors.white),
              ),
            ),
          
          if (feedback['status'] != 'responded') SizedBox(width: 8),
          
          // Save Title Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await _apiService.updateFeedbackAdminData(
                    feedbackId: feedback['id'],
                    adminTitle: titleController.text.trim(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Title saved')),
                  );
                }
              },
              // icon: Icon(Icons.title, size: 16),
              label: Text('Save Title', style: TextStyle(fontSize: 13),),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  ),
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
      ),
    ],
  );
}

Future<void> _addFeedbackResponse(String feedbackId, String response) async {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  final user = _auth.currentUser;
  if (user == null) throw Exception('User not logged in');

  final responseData = {
    'response': response,
    'responderEmail': user.email,
    'timestamp': DateTime.now(),
  };

  await _firestore.collection('feedbacks').doc(feedbackId).update({
    'adminResponse': responseData,
    'status': 'responded',
    'updatedAt': DateTime.now(),
  });
}

// Add this helper method
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

// Add this method to toggle visibility
// void _toggleFeedbackVisibility(Map<String, dynamic> feedback) async {
//   try {
//     final currentVisibility = feedback['isPublic'] ?? false;
//     await _apiService.updateFeedbackAdminData(
//       feedbackId: feedback['id'],
//       isPublic: !currentVisibility,
//     );
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Feedback marked as ${!currentVisibility ? 'public' : 'private'}')),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Error updating visibility: $e')),
//     );
//   }
// }

// Update the status color method to include new statuses
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

  // Widget _buildActionButtons(Map<String, dynamic> feedback) {
  //   return Row(
  //     children: [
  //       // Status Update
  //       Expanded(
  //         child: DropdownButton<String>(
  //           value: feedback['status'] ?? 'new',
  //           isExpanded: true,
  //           items: ['new', 'reviewed', 'responded'].map((status) {
  //             return DropdownMenuItem(
  //               value: status,
  //               child: Text(
  //                 status.toUpperCase(),
  //                 style: TextStyle(color: _getStatusColor(status)),
  //               ),
  //             );
  //           }).toList(),
  //           onChanged: (newStatus) {
  //             if (newStatus != null) {
  //               _updateFeedbackStatus(feedback['id'], newStatus);
  //             }
  //           },
  //         ),
  //       ),
        
  //       SizedBox(width: 8),
        
  //       // Respond Button
  //       if (feedback['status'] != 'responded')
  //         ElevatedButton.icon(
  //           onPressed: () => _showResponseDialog(feedback),
  //           icon: Icon(Icons.reply, size: 16, color: Colors.white,),
  //           label: Text('Respond'),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.green,
  //             foregroundColor: Colors.white,
  //           ),
  //         ),
        
  //       SizedBox(width: 8),
        
  //       // Delete Button
  //       IconButton(
  //         onPressed: () => _deleteFeedback(feedback),
  //         icon: Icon(Icons.delete, color: Colors.red),
  //         tooltip: 'Delete',
  //       ),
  //     ],
  //   );
  // }

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

  // void _showResponseDialog(Map<String, dynamic> feedback) {
  //   final TextEditingController responseController = TextEditingController();
    
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Respond to Feedback'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('User: ${feedback['user']['email']}'),
  //           SizedBox(height: 8),
  //           Text('Type: ${feedback['type']}'),
  //           SizedBox(height: 16),
  //           Text('Response:'),
  //           TextField(
  //             controller: responseController,
  //             maxLines: 4,
  //             decoration: InputDecoration(
  //               hintText: 'Enter your response...',
  //               border: OutlineInputBorder(),
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () async {
  //             if (responseController.text.trim().isNotEmpty) {
  //               try {
  //                 await _apiService.addFeedbackResponse(
  //                   feedback['id'], 
  //                   responseController.text.trim()
  //                 );
  //                 Navigator.pop(context);
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   SnackBar(content: Text('Response sent successfully')),
  //                 );
  //               } catch (e) {
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   SnackBar(content: Text('Error sending response: $e')),
  //                 );
  //               }
  //             }
  //           },
  //           child: Text('Send Response'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
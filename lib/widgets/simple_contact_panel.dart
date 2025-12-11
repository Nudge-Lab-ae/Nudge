// lib/widgets/simple_contact_panel.dart - CLEAN VERSION
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/api_service.dart';

class SimpleContactPanel extends StatefulWidget {
  final Contact contact;
  final ApiService apiService;

  const SimpleContactPanel({
    Key? key,
    required this.contact,
    required this.apiService,
  }) : super(key: key);

  @override
  State<SimpleContactPanel> createState() => _SimpleContactPanelState();
}

class _SimpleContactPanelState extends State<SimpleContactPanel> {
  String _selectedType = 'message';
  bool _isLogging = false;

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    final ringColor = _getRingColor(contact.computedRing);
    var contactFirst = contact.name.split(' ').first;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ringColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ringColor,
                    child: Text(
                      contact.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff333333),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ringColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRingLabel(contact.computedRing),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ringColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Info grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildInfoItem(Icons.category, 'Category', contact.connectionType),
                      const SizedBox(width: 16),
                      _buildInfoItem(Icons.access_time, 'Last Connected', _getTimeAgo(daysAgo)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoItem(Icons.star, 'VIP', contact.isVIP ? 'Yes' : 'No'),
                      const SizedBox(width: 16),
                      _buildInfoItem(Icons.timeline, 'CDI', '${contact.cdi.toInt()}%'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            
            // Interaction logging
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log Interaction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How did you connect with $contactFirst ?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quick interaction buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickButton('message', 'Text', Icons.message),
                      _buildQuickButton('call', 'Call', Icons.call),
                      _buildQuickButton('meet', 'Meet', Icons.people),
                      _buildQuickButton('email', 'Email', Icons.email),
                      _buildQuickButton('social', 'Social', Icons.thumb_up),
                      _buildQuickButton('other', 'Other', Icons.more_horiz),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Log button
                  SizedBox(
                    width: double.infinity,
                    child: _isLogging
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3CB3E9),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _logInteraction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3CB3E9),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'LOG INTERACTION',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xff333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3CB3E9) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3CB3E9) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.green;
      case 'middle':
        return Color(0xFFFFC107); // Amber/Yellow
      case 'outer':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getRingLabel(String ring) {
    switch (ring) {
      case 'inner':
        return 'Inner Circle';
      case 'middle':
        return 'Middle Circle';
      case 'outer':
        return 'Outer Circle';
      default:
        return 'Unknown';
    }
  }

  String _getTimeAgo(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return '${(days / 7).floor()} weeks ago';
    if (days < 365) return '${(days / 30).floor()} months ago';
    return '${(days / 365).floor()} years ago';
  }

  Future<void> _logInteraction() async {
    if (_isLogging) return;
    
    setState(() {
      _isLogging = true;
    });
    
    try {
      await widget.apiService.logInteraction(
        contactId: widget.contact.id,
        interactionType: _selectedType,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Logged ${_selectedType} with ${widget.contact.name}'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }
}
// lib/widgets/contact_quick_panel.dart - SIMPLIFIED VERSION
import 'package:flutter/material.dart';
import 'package:nudge/services/message_service.dart';
// import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../services/api_service.dart';

class ContactQuickPanel extends StatefulWidget {
  final Contact contact;
  final ApiService apiService;

  const ContactQuickPanel({
    Key? key,
    required this.contact,
    required this.apiService,
  }) : super(key: key);

  @override
  State<ContactQuickPanel> createState() => _ContactQuickPanelState();
}

class _ContactQuickPanelState extends State<ContactQuickPanel> {
  String _selectedInteractionType = 'message';
  TextEditingController _notesController = TextEditingController();
  bool _isLogging = false;

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final daysSince = DateTime.now().difference(contact.lastContacted).inDays;
    final lastContactText = _getLastContactText(daysSince);
    
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            
            // Contact header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: contact.imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(contact.imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: contact.imageUrl.isEmpty ? const Color(0xFF3CB3E9) : null,
                    ),
                    child: contact.imageUrl.isEmpty
                        ? Center(
                            child: Text(
                              contact.name.isNotEmpty 
                                ? contact.name.substring(0, 1).toUpperCase()
                                : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff555555),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildRingBadge(contact.computedRing),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            
            // Contact info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  _buildInfoRow(
                    icon: Icons.category,
                    label: 'Category',
                    value: contact.connectionType.isNotEmpty 
                      ? contact.connectionType 
                      : 'Not categorized',
                  ),
                  const SizedBox(height: 12),
                  
                  // Last interaction
                  _buildInfoRow(
                    icon: Icons.access_time,
                    label: 'Last connected',
                    value: lastContactText,
                  ),
                  const SizedBox(height: 12),
                  
                  // Ring status
                  _buildInfoRow(
                    icon: _getRingIcon(contact.computedRing),
                    label: 'Relationship Status',
                    value: _getRingDescription(contact.computedRing),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            
            // Add a Touchpoint section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ADD A TOUCHPOINT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff555555),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Log an interaction to maintain this connection',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Interaction type selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildInteractionTypeButton('message', 'Message', Icons.message),
                        const SizedBox(width: 8),
                        _buildInteractionTypeButton('call', 'Call', Icons.call),
                        const SizedBox(width: 8),
                        _buildInteractionTypeButton('meet', 'Meet', Icons.people),
                        const SizedBox(width: 8),
                        _buildInteractionTypeButton('other', 'Other', Icons.more_horiz),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Notes field (optional)
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3CB3E9)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                  const SizedBox(height: 20),
                  
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
                  
                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildRingBadge(String ring) {
    Color color;
    String label;
    
    switch (ring) {
      case 'inner':
        color = Colors.green;
        label = 'Inner Circle';
        break;
      case 'middle':
        color = Colors.orange;
        label = 'Middle Circle';
        break;
      case 'outer':
        color = Colors.redAccent;
        label = 'Outer Circle';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xff555555),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionTypeButton(String type, String label, IconData icon) {
    final isSelected = _selectedInteractionType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInteractionType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3CB3E9)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3CB3E9)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRingIcon(String ring) {
    switch (ring) {
      case 'inner': return Icons.favorite;
      case 'middle': return Icons.favorite_border;
      case 'outer': return Icons.person_outline;
      default: return Icons.help;
    }
  }

  String _getRingDescription(String ring) {
    switch (ring) {
      case 'inner': return 'Strong, active connection';
      case 'middle': return 'Moderate connection';
      case 'outer': return 'Less active connection';
      default: return 'Unknown status';
    }
  }

  String _getLastContactText(int days) {
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
        interactionType: _selectedInteractionType,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      
      // Show success
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('✓ Interaction logged for ${widget.contact.name}'),
      //     backgroundColor: Colors.green,
      //     duration: const Duration(seconds: 2),
      //   ),
      // );

       TopMessageService().showMessage(
          context: context,
          message: 'Interaction logged for ${widget.contact.name}',
          backgroundColor: Colors.green,
          icon: Icons.check,
        );
      
      // Close after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
      
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to log interaction: $e'),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 3),
      //   ),
      // );
      TopMessageService().showMessage(
          context: context,
          message: 'Failed to log interaction: $e',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
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
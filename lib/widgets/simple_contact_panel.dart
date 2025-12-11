// lib/widgets/simple_contact_panel.dart - IMPROVED
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
  Color? _ringColor;

  @override
  void initState() {
    super.initState();
    _ringColor = _getRingColor(widget.contact.computedRing);
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final daysAgo = DateTime.now().difference(contact.lastContacted).inDays;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
          
          // Contact info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _ringColor,
                  child: Text(
                    contact.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff333333),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _ringColor!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _ringColor!.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getRingLabel(contact.computedRing),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ringColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Last connected: ${_getTimeAgo(daysAgo)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${contact.connectionType}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
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
                  'How did you connect?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff333333),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Quick interaction buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInteractionButton('message', 'Message', Icons.message),
                    _buildInteractionButton('call', 'Call', Icons.call),
                    _buildInteractionButton('meet', 'Meet', Icons.people),
                    _buildInteractionButton('email', 'Email', Icons.email),
                    _buildInteractionButton('social', 'Social', Icons.thumb_up),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isLogging
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF3CB3E9).withOpacity(0.7),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _logInteraction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3CB3E9),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'LOG CONNECTION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 
              ? MediaQuery.of(context).viewInsets.bottom 
              : 20),
        ],
      ),
    );
  }

  Widget _buildInteractionButton(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3CB3E9) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3CB3E9) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF3CB3E9).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.white : Colors.grey[700]),
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
        return const Color(0xFF3CB3E9);
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
      
      // Show success and close
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${_selectedType} logged with ${widget.contact.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
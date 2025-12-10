// lib/widgets/contact_quick_panel.dart
import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final lastContacted = contact.lastContacted;
    final daysAgo = DateTime.now().difference(lastContacted).inDays;
    var customHeight = MediaQuery.of(context).padding.bottom;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Contact header
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: contact.imageUrl.isNotEmpty
                    ? NetworkImage(contact.imageUrl)
                    : AssetImage('assets/contact-icons/1.png') as ImageProvider,
                child: contact.imageUrl.isEmpty
                    ? Text(
                        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
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
                    const SizedBox(height: 4),
                    _buildRingBadge(contact.computedRing),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Contact info
          _buildInfoRow('Category', contact.connectionType),
          _buildInfoRow('Last contacted', '$daysAgo days ago'),
          _buildInfoRow('Interactions (90d)', '${contact.interactionCountInWindow} times'),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          
          // Log interaction section
          const Text(
            'Log Interaction',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff555555),
            ),
          ),
          const SizedBox(height: 12),
          
          // Interaction type selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildInteractionTypeButton('message', 'Message'),
                const SizedBox(width: 8),
                _buildInteractionTypeButton('call', 'Call'),
                const SizedBox(width: 8),
                _buildInteractionTypeButton('meet', 'Meet'),
                const SizedBox(width: 8),
                _buildInteractionTypeButton('other', 'Other'),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Log button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _logInteraction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3CB3E9),
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
          
          const SizedBox(height: 20),
          
          // View full profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContactDetailScreen(contact: contact),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff3CB3E9),
                side: const BorderSide(color: Color(0xff3CB3E9)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('VIEW FULL PROFILE'),
            ),
          ),
          
          SizedBox(height: customHeight),
        ],
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
        color = Colors.red;
        label = 'Outer Circle';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xff555555),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionTypeButton(String type, String label) {
    final isSelected = _selectedInteractionType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInteractionType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xff3CB3E9)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _logInteraction() async {
    try {
      await widget.apiService.logInteraction(
        contactId: widget.contact.id,
        interactionType: _selectedInteractionType,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Interaction logged for ${widget.contact.name}'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log interaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
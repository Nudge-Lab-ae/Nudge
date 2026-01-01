// lib/widgets/contact_details_modal.dart
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/api_service.dart';

class ContactDetailsModal extends StatefulWidget {
  final Contact contact;
  final ApiService apiService;
  
  const ContactDetailsModal({
    super.key,
    required this.contact,
    required this.apiService,
  });

  @override
  State<ContactDetailsModal> createState() => _ContactDetailsModalState();
}

class _ContactDetailsModalState extends State<ContactDetailsModal> {
  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final daysSinceLastContact = DateTime.now().difference(contact.lastContacted).inDays;
    final ringColor = _getRingColor(contact.computedRing);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONTACT DETAILS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff555555),
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xff555555)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Contact header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ringColor,
                      ringColor.withOpacity(0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    contact.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff333333),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // VIP badge
                    if (contact.isVIP)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD700)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VIP CONTACT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Contact stats in cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.category,
                  title: 'Connection Type',
                  value: contact.connectionType.isNotEmpty 
                      ? contact.connectionType 
                      : 'Not specified',
                  color: const Color(0xFF3CB3E9),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  icon: Icons.circle,
                  title: 'Social Ring',
                  value: contact.computedRing.toUpperCase(),
                  color: ringColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.access_time,
                  title: 'Last Contacted',
                  value: daysSinceLastContact == 0 
                      ? 'Today' 
                      : daysSinceLastContact == 1 
                          ? 'Yesterday' 
                          : '$daysSinceLastContact days ago',
                  color: daysSinceLastContact > 30 
                      ? Colors.redAccent 
                      : daysSinceLastContact > 7 
                          ? Color(0xFFFFC107) 
                          : Colors.green,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  icon: Icons.phone,
                  title: 'Contact Priority',
                  value: contact.priority.toString(),
                  color: Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logTouchpoint(context, contact);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CB3E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20, color: Colors.white,),
                  SizedBox(width: 12),
                  Text(
                    'ADD TOUCHPOINT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
           const SizedBox(height: 24),
           // Contact information section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFEEEEEE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTACT INFORMATION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff555555),
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Phone number
                if (contact.phoneNumber.isNotEmpty)
                  _buildContactInfoRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: contact.phoneNumber,
                  ),
                
                if (contact.phoneNumber.isNotEmpty) const SizedBox(height: 12),
                
                // Email
                if (contact.email.isNotEmpty)
                  _buildContactInfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: contact.email,
                  ),
                
                if (contact.email.isNotEmpty) const SizedBox(height: 12),
                
                // Notes
                if (contact.notes.isNotEmpty)
                  _buildContactInfoRow(
                    icon: Icons.note,
                    label: 'Notes',
                    value: contact.notes,
                    maxLines: 3,
                  ),
              ],
            ),
          ),
                  
        ],
      ),
    );
  }

    void _logTouchpoint(BuildContext context, Contact contact) async {
    // Show interaction type selection
    final interactionType = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT INTERACTION TYPE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff555555),
                ),
              ),
              const SizedBox(height: 20),
              
              // Interaction type options
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.call, color: Color(0xFF3CB3E9)),
                    title: const Text('Phone Call'),
                    onTap: () => Navigator.pop(context, 'call'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.message, color: Color(0xFF3CB3E9)),
                    title: const Text('Message'),
                    onTap: () => Navigator.pop(context, 'message'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people, color: Color(0xFF3CB3E9)),
                    title: const Text('In Person Meeting'),
                    onTap: () => Navigator.pop(context, 'meet'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.more_horiz, color: Color(0xFF3CB3E9)),
                    title: const Text('Other'),
                    onTap: () => Navigator.pop(context, 'other'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (interactionType == null) return;

    // Optional notes input
    final notes = await showDialog<String>(
      context: context,
      builder: (context) {
        String notesText = '';
        return AlertDialog(
          title: const Text('Add Notes (Optional)'),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            onChanged: (value) => notesText = value,
            decoration: const InputDecoration(
              hintText: 'Add any notes about this interaction...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, notesText),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CB3E9),
              ),
              child: const Text('Add Notes', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );

    try {
      // Log the interaction
      await widget.apiService.logInteraction(
        contactId: contact.id,
        interactionType: interactionType,
        notes: notes,
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Touchpoint logged for ${contact.name}! Next nudge has been rescheduled.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Close the modal
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error logging touchpoint: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log touchpoint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff888888),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ));
  }

  Widget _buildContactInfoRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(0xFF3CB3E9).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: Color(0xFF3CB3E9),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff888888),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xff333333),
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.green;
      case 'middle':
        return Color(0xFFFFC107);
      case 'outer':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
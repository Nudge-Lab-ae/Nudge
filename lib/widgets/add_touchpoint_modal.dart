// lib/widgets/add_touchpoint_modal.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/contact.dart';

class AddTouchpointModal extends StatefulWidget {
  final ApiService apiService;
  
  const AddTouchpointModal({
    Key? key,
    required this.apiService,
  }) : super(key: key);

  @override
  State<AddTouchpointModal> createState() => _AddTouchpointModalState();
}

class _AddTouchpointModalState extends State<AddTouchpointModal> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  TextEditingController _searchController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  Contact? _selectedContact;
  String? _selectedInteractionType;
  bool _isLoading = false;

  final List<String> _interactionTypes = [
    'call',
    'message',
    'meet',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final contacts = await widget.apiService.getAllContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load contacts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = _contacts;
      });
      return;
    }

    setState(() {
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
               contact.email.toLowerCase().contains(query) ||
               contact.phoneNumber.contains(query);
      }).toList();
    });
  }

  Future<void> _logTouchpoint() async {
    if (_selectedContact == null || _selectedInteractionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a contact and interaction type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Log the interaction
      await widget.apiService.logInteraction(
        contactId: _selectedContact!.id,
        interactionType: _selectedInteractionType!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Touchpoint logged for ${_selectedContact!.name}! Next nudge has been rescheduled.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Close the modal after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pop(context);
      });

    } catch (e) {
      print('Error logging touchpoint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log touchpoint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOG TOUCHPOINT',
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
          
          // Contact Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Contacts',
              prefixIcon: const Icon(Icons.search, color: Color(0xff3CB3E9)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Selected Contact Display
          if (_selectedContact != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3CB3E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3CB3E9).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3CB3E9),
                    ),
                    child: Center(
                      child: Text(
                        _selectedContact!.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedContact!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff333333),
                          ),
                        ),
                        Text(
                          _selectedContact!.connectionType,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Color(0xff888888)),
                    onPressed: () {
                      setState(() {
                        _selectedContact = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Contact List
          if (_selectedContact == null) ...[
            Text(
              'SELECT CONTACT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xff888888),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: Color(0xff888888)),
                              const SizedBox(height: 16),
                              const Text(
                                'No contacts found',
                                style: TextStyle(color: Color(0xff888888)),
                              ),
                              if (_searchController.text.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                  child: const Text('Clear search'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF3CB3E9).withOpacity(0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    contact.name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF3CB3E9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                contact.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xff333333),
                                ),
                              ),
                              subtitle: Text(
                                contact.connectionType,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff888888),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xff888888)),
                              onTap: () {
                                setState(() {
                                  _selectedContact = contact;
                                });
                              },
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Interaction Type Selection
          if (_selectedContact != null) ...[
            Text(
              'INTERACTION TYPE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xff888888),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interactionTypes.map((type) {
                final isSelected = _selectedInteractionType == type;
                return ChoiceChip(
                  label: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Color(0xff333333),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF3CB3E9),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF3CB3E9) : const Color(0xFFEEEEEE),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedInteractionType = selected ? type : null;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Notes Field
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Log Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _logTouchpoint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CB3E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 20, color: Colors.white,),
                          SizedBox(width: 8),
                          Text(
                            'LOG TOUCHPOINT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
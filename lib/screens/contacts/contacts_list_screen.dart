// lib/screens/contacts/contacts_list_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../notifications/notifications_screen.dart';
import 'contact_detail_screen.dart';
import 'add_contact_screen.dart';
import '../../models/contact.dart';
import '../../services/auth_service.dart';

class ContactsListScreen extends StatefulWidget {
  final String? filter;
  final String? mode;
  final bool showAppBar;
  
  const ContactsListScreen({super.key, this.filter, this.mode, required this.showAppBar});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedContacts = Set<String>();
  bool _isSelecting = false;
  List<Contact> totalContacts = [];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);

    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isAddToGroupMode = routeArgs?['action'] == 'add_to_group';
    final groupName = routeArgs?['groupName'];
    final groupPeriod = routeArgs?['groupPeriod'];
    final groupFrequency = routeArgs?['groupFrequency'];
    
    // If user is not logged in, show empty state
    if (user == null) {
      return _buildEmptyState();
    }
    
    return Scaffold(
      appBar: !widget.showAppBar
      ? null
      :_isSelecting
          ? _buildSelectionAppBar(context, groupName)
          : _buildNormalAppBar(context, isAddToGroupMode, groupName),
      body: StreamProvider<List<Contact>>(
        create: (context) => apiService.getContactsStream(),
        initialData: const [],
        child: Consumer<List<Contact>>(
          builder: (context, contacts, child) {
            // Apply filter if provided
            totalContacts = contacts;
            final filteredContacts = _applyFilter(contacts, widget.filter);

            
            // Show empty state if no contacts
            if (filteredContacts.isEmpty) {
              return _buildEmptyState(filter: widget.filter);
            }
            
            // Filter contacts based on search query
            final searchedContacts = filteredContacts.where((contact) {
              return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
            }).toList();
            
            // Show empty state if no contacts match search
            if (searchedContacts.isEmpty) {
              return Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No contacts found for "$_searchQuery"',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            }
            
            return Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchedContacts.length,
                    itemBuilder: (context, index) {
                      final contact = searchedContacts[index];
                      final isSelected = _selectedContacts.contains(contact.id);
                      
                      return _isSelecting
                          ? _buildSelectableContactTile(contact, isSelected)
                          : _buildNormalContactTile(
                              contact, 
                              isAddToGroupMode, 
                              groupName, 
                              groupPeriod, 
                              groupFrequency
                            );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(
        isAddToGroupMode, 
        groupName, 
        groupPeriod, 
        groupFrequency,
        totalContacts
      ),
    );
  }

  AppBar _buildNormalAppBar(BuildContext context, bool isAddToGroupMode, String? groupName) {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      title: isAddToGroupMode 
          ? Text('Add to $groupName', style: AppTextStyles.button.copyWith(color: Colors.white))
          : Text(_getTitle(widget.filter), style: AppTextStyles.button.copyWith(color: Colors.white)),
      backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      actions: [
        if (!isAddToGroupMode) // Only show notifications in normal mode
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(BuildContext context, String? groupName) {
    return AppBar(
      backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        '${_selectedContacts.length} selected${groupName != null ? ' for $groupName' : ''}',
        style: AppTextStyles.button.copyWith(color: Colors.white),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSelecting = false;
            _selectedContacts.clear();
          });
        },
      ),
      actions: [
        if (_selectedContacts.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () {
              // Get the current contacts from the Consumer
              final contacts = Provider.of<List<Contact>>(context, listen: false);
              final filteredContacts = _applyFilter(contacts, widget.filter);
              final searchedContacts = filteredContacts.where((contact) {
                return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
              }).toList();
              
              setState(() {
                if (_selectedContacts.length == searchedContacts.length) {
                  // If all are selected, clear selection
                  _selectedContacts.clear();
                } else {
                  // Select all visible contacts
                  _selectedContacts = Set<String>.from(searchedContacts.map((c) => c.id));
                }
              });
            },
            tooltip: 'Select All',
          ),
      ],
    );
  }

  Widget _buildSelectableContactTile(Contact contact, bool isSelected) {
    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedContacts.add(contact.id);
            } else {
              _selectedContacts.remove(contact.id);
            }
          });
        },
      ),
      title: Text(contact.name, style: AppTextStyles.primaryBold,),
      subtitle: Text(contact.connectionType),
      trailing: Text(
        'Last: ${contact.lastContacted.difference(DateTime.now()).inDays.abs()}d ago',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        setState(() {
          if (_selectedContacts.contains(contact.id)) {
            _selectedContacts.remove(contact.id);
          } else {
            _selectedContacts.add(contact.id);
          }
        });
      },
    );
  }

  Widget _buildNormalContactTile(Contact contact, bool isAddToGroupMode, String? groupName, String? groupPeriod, int? groupFrequency) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color.fromRGBO(45, 161, 175, 1),
        backgroundImage: contact.imageUrl.isNotEmpty
            ? NetworkImage(contact.imageUrl)
            : null,
        child: contact.imageUrl.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(contact.name, style: AppTextStyles.primarySemiBold,),
      subtitle: Text(contact.connectionType),
      trailing: Text(
        'Last: ${contact.lastContacted.difference(DateTime.now()).inDays.abs()}d ago',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        if (isAddToGroupMode && groupName != null && groupPeriod != null && groupFrequency != null) {
          _addContactToGroup(context, contact, groupName, groupPeriod, groupFrequency);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactDetailScreen(contact: contact),
            ),
          );
        }
      },
      onLongPress: () {
        if (widget.mode == 'add_to_group') {
           setState(() {
          _isSelecting = true;
          _selectedContacts.add(contact.id);
        });
        }
       
      },
    );
  }

  Widget _buildFloatingActionButton(bool isAddToGroupMode, String? groupName, String? groupPeriod, int? groupFrequency, List<Contact> contacts) {
    if (_isSelecting) {
      return FloatingActionButton.extended(
        onPressed: () async{
          if (_selectedContacts.isNotEmpty) {
            await _addMultipleContactsToGroup(context, groupName!, groupPeriod!, groupFrequency!, contacts );
          }
        },
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        icon: const Icon(Icons.group_add, color: Colors.white),
        label: Text('Add ${_selectedContacts.length} Contacts', style: const TextStyle(color: Colors.white)),
      );
    } else if (isAddToGroupMode) {
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactScreen(
                groupName: groupName,
                groupPeriod: groupPeriod,
                groupFrequency: groupFrequency,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Contact', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      );
    } else {
      return FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
  }

  Future<void> _addMultipleContactsToGroup(BuildContext context, String groupName, String groupPeriod, int groupFrequency, List<Contact> contacts) async {
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    int successCount = 0;
    int errorCount = 0;
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adding Contacts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Processing $successCount of ${_selectedContacts.length} contacts...'),
            ],
          ),
        );
      },
    );
    
    // Process each selected contact
    for (String contactId in _selectedContacts) {
      try {
        final contact = contacts.firstWhere((c) => c.id == contactId);
        
        // Update contact with new group assignment
        final updatedContact = contact.copyWith(
          connectionType: groupName,
          period: groupPeriod,
          frequency: groupFrequency,
        );
        
        await apiService.updateContact(updatedContact);
        successCount++;
      } catch (e) {
        errorCount++;
        print('Error adding contact $contactId to group: $e');
      }
    }
    
    // Close progress dialog
    Navigator.of(context).pop();
    
    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $successCount contacts to $groupName${errorCount > 0 ? '. $errorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Reset selection
    setState(() {
      _isSelecting = false;
      _selectedContacts.clear();
    });
  }

  void _addContactToGroup(BuildContext context, Contact contact, String groupName, String groupPeriod, int groupFrequency) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    // Check if contact is already in a different group
    if (contact.connectionType.isNotEmpty && contact.connectionType != groupName) {
      // Show confirmation dialog
      bool confirmOverride = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Override Group Assignment'),
            content: Text(
              '${contact.name} is already in the "${contact.connectionType}" group. '
              'Do you want to override this and assign them to "$groupName" instead?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Override'),
              ),
            ],
          );
        },
      );
      
      if (!confirmOverride) {
        return; // User cancelled the operation
      }
    }
    
    try {
      // Update contact with new group assignment
      final updatedContact = contact.copyWith(
        connectionType: groupName,
        period: groupPeriod,
        frequency: groupFrequency,
      );
      
      await apiService.updateContact(updatedContact);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${contact.name} to $groupName')),
      );
      
      Navigator.pop(context); // Return to group screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add contact: $e')),
      );
    }
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState({String? filter}) {
    String title;
    String description;
    
    switch (filter) {
      case 'vip':
        title = 'No VIP contacts yet';
        description = 'Mark contacts as VIP to see them here';
        break;
      case 'needs_attention':
        title = 'No contacts need attention';
        description = 'All your contacts have been contacted recently';
        break;
      default:
        title = 'No contacts yet';
        description = 'Add your first contact to get started';
    }
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ), textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddContactScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
              ),
              child: Text('Add Contact', style: AppTextStyles.button.copyWith(color: Colors.white),),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _getTitle(String? filter) {
    switch (filter) {
      case 'vip':
        return 'VIP Contacts';
      case 'needs_attention':
        return 'Contacts Needing Attention';
      default:
        return 'All Contacts';
    }
  }

  List<Contact> _applyFilter(List<Contact> contacts, String? filter) {
    switch (filter) {
      case 'vip':
        return contacts.where((c) => c.isVIP).toList();
      case 'needs_attention':
        return contacts.where((c) => 
          c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
        ).toList();
      default:
        return contacts;
    }
  }
}
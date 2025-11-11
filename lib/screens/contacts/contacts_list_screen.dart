// lib/screens/contacts/contacts_list_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
// import '../notifications/notifications_screen.dart';
import 'contact_detail_screen.dart';
import 'add_contact_screen.dart';
import '../../models/contact.dart';
import '../../services/auth_service.dart';

class ContactsListScreen extends StatefulWidget {
  final String? filter;
  final String? mode;
  final bool showAppBar;
  final Function hideButton;
  
  const ContactsListScreen({super.key, this.filter, this.mode, required this.showAppBar, required this.hideButton});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedContacts = Set<String>();
  bool _isSelecting = false;
  String? _selectionMode; // 'add_to_group' or 'delete'
  List<Contact> totalContacts = [];
  String _currentFilter = 'all'; // 'all', 'vip', 'needs_attention'

  @override
  void initState() {
    super.initState();
    // Set initial filter from widget.filter if provided
    _currentFilter = widget.filter ?? 'all';
  }

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
      body: GestureDetector(
    onTap: _isSelecting ? _exitSelectionMode : null,
    behavior: HitTestBehavior.opaque,
    child: Column(
        children: [
          // Add selection controls here
          _buildSelectionControls(),
          Expanded(
            child: StreamProvider<List<Contact>>(
        create: (context) => apiService.getContactsStream(),
        initialData: const [],
        child: Consumer<List<Contact>>(
          builder: (context, contacts, child) {
            // Apply filter if provided
            totalContacts = contacts;
            final filteredContacts = _applyFilter(contacts, _currentFilter);

            
            // Show empty state if no contacts
            if (filteredContacts.isEmpty) {
              return _buildEmptyState(filter: _currentFilter);
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
                  _buildSearchAndFilterBar(),
                  if (_currentFilter != 'all' && _currentFilter!='') _buildFilterTitleRow(),
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
                _buildSearchAndFilterBar(),
                if (_currentFilter != 'all' && _currentFilter!='') _buildFilterTitleRow(),
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
      ))])),
      floatingActionButton: _selectedContacts.isNotEmpty
      ?_buildFloatingActionButton(
        isAddToGroupMode, 
        groupName, 
        groupPeriod, 
        groupFrequency,
        totalContacts
      ):Center(),
    );
  }

    Widget _buildSelectionControls() {
      if (!_isSelecting) return const SizedBox.shrink();
      
      return Container(
        padding: const EdgeInsets.all(16.0),
        color: const Color.fromRGBO(45, 161, 175, 0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Select All / Deselect All
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleSelectAll,
                icon: Icon(
                  _selectedContacts.length == _getVisibleContactsCount() 
                    ? Icons.deselect 
                    : Icons.select_all,
                  color: const Color.fromRGBO(45, 161, 175, 1),
                ),
                label: Text(
                  _selectedContacts.length == _getVisibleContactsCount() 
                    ? 'Deselect All' 
                    : 'Select All',
                  style: const TextStyle(color: Color.fromRGBO(45, 161, 175, 1)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Cancel Selection
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      );
    }

  AppBar _buildNormalAppBar(BuildContext context, bool isAddToGroupMode, String? groupName) {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      title: isAddToGroupMode 
          ? Text('Add to $groupName', style: AppTextStyles.button.copyWith(color: Colors.white))
          : Text(_getTitle(_currentFilter), style: AppTextStyles.button.copyWith(color: Colors.white)),
      backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      actions: [
        if (!isAddToGroupMode) // Only show bulk actions in normal mode
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'select_delete') {
                setState(() {
                  _isSelecting = true;
                  _selectionMode = 'delete';
                });
              } else if (value == 'delete_all') {
                _deleteAllContacts(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'select_delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Select Contacts to Delete'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete All Contacts'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context, String? groupName) {
    String title;
    if (_selectionMode == 'add_to_group') {
      title = '${_selectedContacts.length} selected${groupName != null ? ' for $groupName' : ''}';
    } else {
      title = '${_selectedContacts.length} selected for deletion';
    }

    return AppBar(
      backgroundColor: _selectionMode == 'delete' ? Colors.red : const Color.fromRGBO(45, 161, 175, 1),
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        title,
        style: AppTextStyles.button.copyWith(color: Colors.white),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _exitSelectionMode,
      ),
      actions: [
        // Select All / Deselect All button
        IconButton(
          icon: Icon(_selectedContacts.length == _getVisibleContactsCount() ? Icons.deselect : Icons.select_all),
          onPressed: _toggleSelectAll,
          tooltip: _selectedContacts.length == _getVisibleContactsCount() ? 'Deselect All' : 'Select All',
        ),
        
        // Cancel selection button
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
          tooltip: 'Cancel Selection',
        ),
        
        if (_selectionMode == 'delete' && _selectedContacts.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteSelectedContacts(context),
            tooltip: 'Delete Selected',
          ),
      ],
    );
  }

      void _exitSelectionMode() {
      setState(() {
        _isSelecting = false;
        _selectedContacts.clear();
        _selectionMode = null;
      });
      widget.hideButton();
    }

    void _toggleSelectAll() {
      final visibleContacts = _getVisibleContacts();
      
      setState(() {
        if (_selectedContacts.length == visibleContacts.length) {
          // Deselect all
          _selectedContacts.clear();
        } else {
          // Select all visible contacts
          _selectedContacts = Set<String>.from(visibleContacts.map((c) => c.id));
        }
      });
    }

    List<Contact> _getVisibleContacts() {
      final contacts = Provider.of<List<Contact>>(context, listen: false);
      final filteredContacts = _applyFilter(contacts, _currentFilter);
      
      return filteredContacts.where((contact) {
        return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    int _getVisibleContactsCount() {
      return _getVisibleContacts().length;
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
            _selectionMode = 'add_to_group';
            _selectedContacts.add(contact.id);
          });
        } else {
          setState(() {
            _isSelecting = true;
            _selectionMode = 'delete';
            _selectedContacts.add(contact.id);
          });
          widget.hideButton();
        }
      },
    );
  }

  Widget _buildFloatingActionButton(bool isAddToGroupMode, String? groupName, String? groupPeriod, int? groupFrequency, List<Contact> contacts) {
    if (_isSelecting) {
      if (_selectionMode == 'add_to_group') {
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
      } else if (_selectionMode == 'delete') {
        return FloatingActionButton.extended(
          onPressed: () => _deleteSelectedContacts(context),
          backgroundColor: Colors.red,
          icon: const Icon(Icons.delete, color: Colors.white),
          label: Text('Delete ${_selectedContacts.length} contacts', style: const TextStyle(color: Colors.white)),
        );
      }
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
    
    return Container(); // Fallback
  }

  Widget _buildSearchAndFilterBar() {
    return Material(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list, color: Color.fromRGBO(45, 161, 175, 1)),
                      onSelected: (String newValue) {
                        setState(() {
                          _currentFilter = newValue;
                        });
                      },
                      itemBuilder: (BuildContext context) {
                        return <String>['all', 'vip', 'needs_attention'].map((String value) {
                          return PopupMenuItem<String>(
                            value: value,
                            child: Text(
                              _getFilterLabel(value),
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                )

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTitleRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getFilterTitle(_currentFilter),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(45, 161, 175, 1),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentFilter = 'all';
              });
            },
            child: const Text(
              'Clear Filter',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // String _getFilterEquivalent(String filter) {
  //    switch (filter) {
  //     case 'vip':
  //       return 'vip';
  //     case 'needs_attention':
  //       return 'needs_attention';
  //     default:
  //       return 'all';
  //   }
  // }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'vip':
        return 'Close Circle';
      case 'needs_attention':
        return 'Needs Care';
      default:
        return 'All Contacts';
    }
  }

  String _getFilterTitle(String filter) {
    switch (filter) {
      case 'vip':
        return 'Close Circle Contacts';
      case 'needs_attention':
        return 'Contacts Needing Care';
      default:
        return 'All Contacts';
    }
  }

  Future<void> _deleteSelectedContacts(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contacts', style: TextStyle(fontWeight: FontWeight.w700),),
        content: Text('Are you sure you want to delete ${_selectedContacts.length} contacts? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      int successCount = 0;
      int errorCount = 0;
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Deleting Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Deleting $successCount of ${_selectedContacts.length} contacts...'),
              ],
            ),
          );
        },
      );
      
      // Process each selected contact
      for (String contactId in _selectedContacts) {
        try {
          await apiService.deleteContact(contactId);
          successCount++;
        } catch (e) {
          errorCount++;
          print('Error deleting contact $contactId: $e');
        }
      }
      
      // Close progress dialog
      Navigator.of(context).pop();
      
      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $successCount contacts${errorCount > 0 ? '. $errorCount failed' : ''}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Reset selection
      setState(() {
        _isSelecting = false;
        _selectedContacts.clear();
        _selectionMode = null;
      });
    }
  }

  Future<void> _deleteAllContacts(BuildContext context) async {
    final contacts = Provider.of<List<Contact>>(context, listen: false);
    
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts to delete')),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Contacts'),
        content: Text('Are you sure you want to delete all ${contacts.length} contacts? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      int successCount = 0;
      int errorCount = 0;
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Deleting All Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Deleting $successCount of ${contacts.length} contacts...'),
              ],
            ),
          );
        },
      );
      
      // Process all contacts
      for (Contact contact in contacts) {
        try {
          await apiService.deleteContact(contact.id);
          successCount++;
        } catch (e) {
          errorCount++;
          print('Error deleting contact ${contact.id}: $e');
        }
      }
      
      // Close progress dialog
      Navigator.of(context).pop();
      
      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $successCount contacts${errorCount > 0 ? '. $errorCount failed' : ''}',
          ),
          duration: const Duration(seconds: 3),
        ),
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
      _selectionMode = null;
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

    Widget _buildEmptyState({String? filter}) {
      String title;
      String description;
      
      switch (filter) {
        case 'vip':
          title = 'No Close Circle Contacts yet';
          description = 'Mark contacts as Close Circle to see them here';
          break;
        case 'needs_attention':
          title = 'No contacts need care';
          description = 'All your contacts have been contacted recently';
          break;
        default:
          title = 'No contacts yet';
          description = 'Add your first contact to get started';
      }
      
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.contacts,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ), 
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // Multiple Add Options
                Column(
                  children: [
                    // Manual Add
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text('Add Contact Manually', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Smart Import (Android only)
                    if (Theme.of(context).platform == TargetPlatform.android)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ImportContactsScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
                            side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.smart_button),
                          label: const Text('Smart Import (Android)'),
                        ),
                      ),
                    
                    if (Theme.of(context).platform == TargetPlatform.android) const SizedBox(height: 12),
                    
                    // Contact Picker
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _importFromContactPicker,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
                          side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.import_contacts),
                        label: const Text('Import from Contacts'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                if (filter != null && filter != 'all')
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentFilter = 'all';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 145, 209, 216),
                    ),
                    child: Text('Clear Filter', style: AppTextStyles.button.copyWith(color: Colors.black)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Add contact picker method
    Future<void> _importFromContactPicker() async {
      // This would integrate with the device's contact picker
      // For now, we'll show a placeholder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact picker integration coming soon')),
      );
    }
  String _getTitle(String? filter) {
    switch (filter) {
      case 'vip':
        return 'Close Circle';
      case 'needs_attention':
        return 'Contacts Needing Care';
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
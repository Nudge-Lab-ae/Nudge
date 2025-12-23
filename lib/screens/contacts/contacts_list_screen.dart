// lib/screens/contacts/contacts_list_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
// import 'package:nudge/widgets/gradient_text.dart';
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
  bool _isDeletingInProgress = false;
  int _deletionSuccessCount = 0;
  int _deletionTotalCount = 0;
  int _deletionErrorCount = 0;
  bool _isAddingToGroupInProgress = false;
  int _addingSuccessCount = 0;
  int _addingTotalCount = 0;
  int _addingErrorCount = 0;
  String? _currentGroupName;

  @override
  void initState() {
  super.initState();
  // Set initial filter from widget.filter if provided
  _currentFilter = widget.filter ?? 'all';
  
  // Check if we're in add-to-group mode and set selecting mode accordingly
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isAddToGroupMode = routeArgs?['action'] == 'add_to_group';
    
    if (isAddToGroupMode) {
      setState(() {
        _isSelecting = true;
        _selectionMode = 'add_to_group';
      });
    }
  });
}

// Update the build method to properly integrate with parent Scaffold
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
  
  // When used from dashboard (showAppBar: false), we use CustomScrollView
  if (!widget.showAppBar) {
    return StreamProvider<List<Contact>>(
      create: (context) => apiService.getContactsStream(),
      initialData: const [],
      child: Consumer<List<Contact>>(
        builder: (context, contacts, child) {
          totalContacts = contacts;
          final filteredContacts = _applyFilter(contacts, _currentFilter);
          final searchedContacts = filteredContacts.where((contact) {
            return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();
          
          return Scaffold(
          floatingActionButton: Padding(
            padding: EdgeInsets.only(right: 6, bottom: 30,),
            child: _selectedContacts.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _selectionMode == 'add_to_group'
                    ? _addMultipleContactsToGroup(context, groupName!, groupPeriod!, groupFrequency!, totalContacts)
                    : _deleteSelectedContacts(context),
                backgroundColor: _selectionMode == 'add_to_group' ? const Color(0xff3CB3E9) : Colors.red,
                icon: Icon(
                  _selectionMode == 'add_to_group' ? Icons.group_add : Icons.delete,
                  color: Colors.white,
                ),
                label: Text(
                  _selectionMode == 'add_to_group'
                      ? 'ADD ${_selectedContacts.length} CONTACTS'
                      : 'DELETE ${_selectedContacts.length} CONTACTS',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : FeedbackFloatingButton(
                currentSection: 'contacts',
                extraActions: !isAddToGroupMode
                    ? [
                        FeedbackAction(
                          label: 'Add Contact',
                          icon: Icons.add,
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
                          // color: const Color(0xff3CB3E9),
                        ),
                      ]
                    : [],
              ),
            ),
            body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Sliver App Bar
                  SliverAppBar(
                    title: isAddToGroupMode 
                        ? Text('Add to $groupName', style: AppTextStyles.title3.copyWith(color: Color(0xff555555)))
                        : Padding(
                          padding: EdgeInsets.only(left: 30),
                          child: Text('Contacts', style: AppTextStyles.title2.copyWith(color: Color(0xff555555), fontSize: 22)),
                          ),
                    backgroundColor: Colors.white,
                    leading: Center(),
                    centerTitle: isAddToGroupMode,
                    surfaceTintColor: Colors.transparent,
                    floating: true,
                    snap: true,
                    pinned: false,
                    actions: [
                      if (!isAddToGroupMode)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'select_delete') {
                              setState(() {
                                _isSelecting = true;
                                _selectionMode = 'delete';
                              });
                              widget.hideButton();
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
                                  Text('DELETE ALL CONTACTS'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  
                  // Selection Controls (only when selecting)
                  if (_isSelecting)
                    SliverToBoxAdapter(
                      child: _buildSelectionControls(),
                    ),
                  
                  // Add-to-group header (only when in add-to-group mode)
                  if (isAddToGroupMode && !_isSelecting)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, top: 20, right: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text('Add to $groupName', style: AppTextStyles.title3.copyWith(color: Color(0xff555555))),
                            // const SizedBox(height: 4),
                            Text(
                              'Long press on contacts to select multiple',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  
                  // Search and Filter Bar
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildSearchAndFilterBar(),
                          if (_currentFilter != 'all' && _currentFilter != '') 
                            _buildFilterTitleRow(),
                        ],
                      ),
                    ),
                  ),
                  
                  // Contacts List
                  if (searchedContacts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          filteredContacts.isEmpty 
                              ? 'No contacts found'
                              : 'No contacts found for "$_searchQuery"',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
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
                          childCount: searchedContacts.length,
                        ),
                      ),
                    ),
                  
                  // Bottom padding for FAB
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
              
              // Progress overlays
              _buildDeletionProgressOverlay(),
              _buildAddingToGroupProgressOverlay(),
            ],
          ));
        },
      ),
    );
  }
  
  // Original implementation for standalone use
  return Scaffold(
    appBar: /* _isSelecting
        ? _buildSelectionAppBar(context, groupName)
        : */ _buildNormalAppBar(context, isAddToGroupMode, groupName),
    body: Stack(
      children: [
        GestureDetector(
          onTap: _isSelecting ? _exitSelectionMode : null,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              // Original implementation remains for standalone use
              if (isAddToGroupMode)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text('Add to $groupName', style: AppTextStyles.title3.copyWith(color: Color(0xff555555))),
                        // SizedBox(height: 4),
                        Text(
                          'Long press on contacts to select multiple',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isAddToGroupMode)
                SizedBox(height: 10),
              _buildSelectionControls(),
              Expanded(
                child: StreamProvider<List<Contact>>(
                  create: (context) => apiService.getContactsStream(),
                  initialData: const [],
                  child: Consumer<List<Contact>>(
                    builder: (context, contacts, child) {
                      totalContacts = contacts;
                      final filteredContacts = _applyFilter(contacts, _currentFilter);
                      
                      if (filteredContacts.isEmpty) {
                        return _buildEmptyState(filter: _currentFilter);
                      }
                      
                      final searchedContacts = filteredContacts.where((contact) {
                        return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
                      }).toList();
                      
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
                ),
              ),
            ],
          ),
        ),
        _buildDeletionProgressOverlay(),
        _buildAddingToGroupProgressOverlay(),
      ],
    ),
    floatingActionButton: Padding(
        padding: EdgeInsets.only(right: 16,bottom: 30,),
        child: _selectedContacts.isNotEmpty
      ? FloatingActionButton.extended(
          onPressed: () => _selectionMode == 'add_to_group'
              ? _addMultipleContactsToGroup(context, groupName!, groupPeriod!, groupFrequency!, totalContacts)
              : _deleteSelectedContacts(context),
          backgroundColor: _selectionMode == 'add_to_group' ? const Color(0xff3CB3E9) : Colors.red,
          icon: Icon(
            _selectionMode == 'add_to_group' ? Icons.group_add : Icons.delete,
            color: Colors.white,
          ),
          label: Text(
            _selectionMode == 'add_to_group'
                ? 'ADD ${_selectedContacts.length} CONTACTS'
                : 'DELETE ${_selectedContacts.length} CONTACTS',
            style: const TextStyle(color: Colors.white),
          ),
        )
      : FeedbackFloatingButton(
          currentSection: 'contacts',
          extraActions: !isAddToGroupMode
              ? [
                  FeedbackAction(
                    label: 'Add Contact',
                    icon: Icons.add,
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
                  ),
                ]
              : [],
        )),
  );
}

  Widget _buildSelectionControls() {
    if (!_isSelecting) return const SizedBox.shrink();
    print('deselect mode'); print(_selectedContacts.length); print(_getVisibleContactsCount());
    
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
                color: const Color(0xff3CB3E9),
              ),
              label: Text(
                _selectedContacts.length == _getVisibleContactsCount() && _selectedContacts.isNotEmpty
                  ? 'DESELECT ALL' 
                  : 'SELECT ALL',
                style: const TextStyle(color: Color(0xff3CB3E9), fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xff3CB3E9)),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Cancel Selection
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exitSelectionMode,
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('CANCEL', style: TextStyle(color: Colors.red, fontSize: 15)),
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
      iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
      title: isAddToGroupMode 
          ? Text('Add to $groupName', style: AppTextStyles.title3.copyWith(color: Color(0xff555555)))
          // Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Color(0xff3CB3E9), fontFamily: 'RobotoMono'))
          : Padding(
            padding: EdgeInsets.only(left: 30),
            child: Text('Contacts', style: AppTextStyles.title2.copyWith(color: Color(0xff555555), fontSize: 22))
            ),
      backgroundColor: Colors.white,
      centerTitle: isAddToGroupMode,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (!isAddToGroupMode) // Only show bulk actions in normal mode
          PopupMenuButton<String>(
            onSelected: (value) {
             if (value == 'select_delete') {
                setState(() {
                  _isSelecting = true;
                  _selectionMode = 'delete';
                });
                widget.hideButton(); // Add this line
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
                    Text('DELETE ALL CONTACTS'),
                  ],
                ),
              ),
            ],
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
    List<Contact> contacts = [];
    if (widget.mode == 'add_to_group') {
      contacts = totalContacts;
    } else {
      contacts = Provider.of<List<Contact>>(context, listen: false);
    }
     
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
      title: Text((contact.name), style: AppTextStyles.primaryBold.copyWith(color: Color(0xff555555)),),
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

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    
    // Trim and split the name by spaces
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      // Has at least first and last name - get first letter of first and last name
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      // Only first name available
      return parts.first[0].toUpperCase();
    }
    
    return '?';
  }

  Widget _buildNormalContactTile(Contact contact, bool isAddToGroupMode, String? groupName, String? groupPeriod, int? groupFrequency) {
    final initials = _getContactInitials(contact.name);
    return ListTile(
      leading: CircleAvatar(
        radius: 24, // Increased from default
        backgroundColor: Colors.transparent,
        backgroundImage: contact.imageUrl.isNotEmpty
            ? NetworkImage(contact.imageUrl)
            : AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png') as ImageProvider,
        child: contact.imageUrl.isEmpty
            ? Text(
                contact.name.isNotEmpty ? initials.toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Adjust font size accordingly
                ),
              )
            : null,
      ),
      title: Text((contact.name), style: AppTextStyles.primarySemiBold.copyWith(color: Color(0xff555555), fontSize: 15)),
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
          widget.hideButton(); // Add this line
        } else {
          setState(() {
            _isSelecting = true;
            _selectionMode = 'delete';
            _selectedContacts.add(contact.id);
          });
          widget.hideButton(); // Add this line
        }
      },
    );
  }

  // Widget _buildFloatingActionButton(bool isAddToGroupMode, String? groupName, String? groupPeriod, int? groupFrequency, List<Contact> contacts) {
    
  //   if (_isDeletingInProgress) {
  //     return Center();
  //   } else if (_isSelecting) {
  //     if (_selectionMode == 'add_to_group') {
  //       return FloatingActionButton.extended(
  //         onPressed: () async{
  //           if (_selectedContacts.isNotEmpty) {
  //             await _addMultipleContactsToGroup(context, groupName!, groupPeriod!, groupFrequency!, contacts );
  //           }
  //         },
  //         backgroundColor: const Color(0xff3CB3E9),
  //         icon: const Icon(Icons.group_add, color: Colors.white),
  //         label: Text('ADD ${_selectedContacts.length} CONTACTS', style: const TextStyle(color: Colors.white)),
  //       );
  //     } else if (_selectionMode == 'delete') {
  //       return FloatingActionButton.extended(
  //         onPressed: () => _deleteSelectedContacts(context),
  //         backgroundColor: Colors.red,
  //         icon: const Icon(Icons.delete, color: Colors.white),
  //         label: Text('DELETE ${_selectedContacts.length} CONTACTS', style: const TextStyle(color: Colors.white)),
  //       );
  //     }
  //   } else if (isAddToGroupMode) {
  //     return FloatingActionButton.extended(
  //       onPressed: () {
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => AddContactScreen(
  //               groupName: groupName,
  //               groupPeriod: groupPeriod,
  //               groupFrequency: groupFrequency,
  //             ),
  //           ),
  //         );
  //       },
  //       icon: const Icon(Icons.add, color: Colors.white),
  //       label: const Text('New Contact', style: TextStyle(color: Colors.white)),
  //       backgroundColor: const Color(0xff3CB3E9),
  //     );
  //   } else {
  //     return FloatingActionButton(
  //       onPressed: () {
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => const AddContactScreen(),
  //           ),
  //         );
  //       },
  //       backgroundColor: const Color(0xff3CB3E9),
  //       child: const Icon(Icons.add, color: Colors.white),
  //     );
  //   }
    
  //   return Container(); // Fallback
  // }

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
                      hintStyle: TextStyle(color: Color(0xff555555)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xff555555),),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.grey, width: 1),
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
                      icon: const Icon(Icons.filter_list, color: Color(0xff3CB3E9)),
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
              color: Color(0xff3CB3E9),
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

  Widget _buildDeletionProgressOverlay() {
    if (!_isDeletingInProgress) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 50,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Deleting Contacts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _deletionTotalCount > 0 
                    ? _deletionSuccessCount / _deletionTotalCount 
                    : 0,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$_deletionSuccessCount of $_deletionTotalCount contacts deleted'
                '${_deletionErrorCount > 0 ? ' ($_deletionErrorCount errors)' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddingToGroupProgressOverlay() {
    if (!_isAddingToGroupInProgress) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 50,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adding to $_currentGroupName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff3CB3E9),
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _addingTotalCount > 0 
                    ? _addingSuccessCount / _addingTotalCount 
                    : 0,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff3CB3E9)),
              ),
              const SizedBox(height: 8),
              Text(
                '$_addingSuccessCount of $_addingTotalCount contacts added'
                '${_addingErrorCount > 0 ? ' ($_addingErrorCount errors)' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedContacts(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE CONTACTS', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff555555)),),
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
      _startDeletionProcess();
      // sendTestNudges();
    }
  }

  void sendTestNudges() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    apiService.scheduleTestNudges(_selectedContacts.toList());
  }

  void _startDeletionProcess() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    setState(() {
      _isDeletingInProgress = true;
      _deletionSuccessCount = 0;
      _deletionErrorCount = 0;
      _deletionTotalCount = _selectedContacts.length;
    });
    
    // Process each selected contact
    for (String contactId in _selectedContacts) {
      try {
        // First, cancel any nudges for this contact
        
        // Then delete the contact
        await apiService.deleteContact(contactId);
        setState(() {
          _deletionSuccessCount++;
        });
      } catch (e) {
        setState(() {
          _deletionErrorCount++;
        });
        print('Error deleting contact $contactId: $e');
      }
    }

    apiService.cancelNudgesForContacts(_selectedContacts.toList());
    
    // Show result and clean up
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $_deletionSuccessCount contacts${_deletionErrorCount > 0 ? '. $_deletionErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Reset everything
    setState(() {
      _isDeletingInProgress = false;
      _isSelecting = false;
      _selectedContacts.clear();
      _selectionMode = null;
    });
    widget.hideButton();
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
        title: const Text('Delete All Contacts', style: TextStyle(color: Color(0xff555555), fontWeight: FontWeight.w600),),
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
      _startBulkDeletionProcess(contacts);
    }
  }

  void _startBulkDeletionProcess(List<Contact> contacts) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    setState(() {
      _isDeletingInProgress = true;
      _deletionSuccessCount = 0;
      _deletionErrorCount = 0;
      _deletionTotalCount = contacts.length;
    });
    
    // Process all contacts
    for (Contact contact in contacts) {
      try {
        await apiService.deleteContact(contact.id);
        setState(() {
          _deletionSuccessCount++;
        });
      } catch (e) {
        setState(() {
          _deletionErrorCount++;
        });
        print('Error deleting contact ${contact.id}: $e');
    }
    }
    
    // Show result and clean up
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $_deletionSuccessCount contacts${_deletionErrorCount > 0 ? '. $_deletionErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Reset
    setState(() {
      _isDeletingInProgress = false;
    });
  }

  Future<void> _addMultipleContactsToGroup(BuildContext context, String groupName, String groupPeriod, int groupFrequency, List<Contact> contacts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ADD TO GROUP', style: TextStyle(color: Color(0xff555555), fontWeight: FontWeight.w600),),
        content: Text('Are you sure you want to add ${_selectedContacts.length} contacts to "$groupName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add to Group'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) {
      return;
    }
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    // final nudgeService = NudgeService();
    final user = authService.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }
    
    setState(() {
      _isAddingToGroupInProgress = true;
      _addingSuccessCount = 0;
      _addingErrorCount = 0;
      _addingTotalCount = _selectedContacts.length;
      _currentGroupName = groupName;
    });
    
    final List<Contact> successfullyAddedContacts = [];
    
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
        
        // Add to successfully added list for nudge scheduling
        successfullyAddedContacts.add(updatedContact);
        
        setState(() {
          _addingSuccessCount++;
        });
      } catch (e) {
        setState(() {
          _addingErrorCount++;
        });
        print('Error adding contact $contactId to group: $e');
      }
    }
    
    // Schedule nudges for successfully added contacts (in background)
    if (successfullyAddedContacts.isNotEmpty) {
      _scheduleNudgesForGroupContacts(successfullyAddedContacts, groupName, groupPeriod, groupFrequency, user.uid);
    }
    
    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $_addingSuccessCount contacts to $groupName${_addingErrorCount > 0 ? '. $_addingErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    widget.hideButton();
    
    // Reset selection and progress
    setState(() {
      _isAddingToGroupInProgress = false;
      _isSelecting = false;
      _selectedContacts.clear();
      _selectionMode = null;
      _currentGroupName = null;
    });
  }

  Future<void> _scheduleNudgesForGroupContacts(List<Contact> contacts, String groupName, String period, int frequency, String userId) async {
    final nudgeService = NudgeService();
    
    try {
      int scheduledCount = 0;
      
      for (final contact in contacts) {
        // Schedule nudge for this contact with group parameters
        final success = await nudgeService.scheduleNudgeForContact(
          contact,
          userId,
          period: period,
          frequency: frequency,
        );
        
        if (success) scheduledCount++;
        
        // Small delay to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      print('Successfully scheduled nudges for $scheduledCount contacts in $groupName group');
      
    } catch (e) {
      print('Error scheduling nudges for group contacts: $e');
      // Don't show error to user as this is background process
    }
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
            title: Text('OVERRIDE GROUP ASSIGNMENT', style: AppTextStyles.title3.copyWith(color: Color(0xff555555))),
            content: Text(
              '${contact.name} is already in the "${contact.connectionType}" group. '
              'Do you want to override this and assign them to "$groupName" instead?', style: TextStyle(color: Color(0xff555555)),
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(right: 6,bottom: 30,),
        child: FeedbackFloatingButton(
          currentSection: 'contacts',
          extraActions: [
                  FeedbackAction(
                    label: 'Add Contacts',
                    icon: Icons.person_add,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddContactScreen(),
                        ),
                      );
                    },
                    // color: const Color(0xff3CB3E9),
                  ),
                ],
        ),
      ),
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
                        backgroundColor: const Color(0xff3CB3E9),
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
                          foregroundColor: const Color(0xff3CB3E9),
                          side: const BorderSide(color: Color(0xff3CB3E9)),
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
                        foregroundColor: const Color(0xff3CB3E9),
                        side: const BorderSide(color: Color(0xff3CB3E9)),
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

  int getRandomIndex(String seed) {
  if (seed.isEmpty) return 1;
  var hash = 0;
  for (var i = 0; i < seed.length; i++) {
    hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return (hash.abs() % 6) + 1;
}


  // Add contact picker method
  Future<void> _importFromContactPicker() async {
    // This would integrate with the device's contact picker
    // For now, we'll show a placeholder
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Contact picker integration coming soon')),
    // );
    Navigator.pushNamed(context, '/import_contacts');
  }

  // String _getTitle(String? filter) {
  //   switch (filter) {
  //     case 'vip':
  //       return 'Close Circle';
  //     case 'needs_attention':
  //       return 'Contacts Needing Care';
  //     default:
  //       return 'All Contacts';
  //   }
  // }

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
// lib/screens/contacts/contacts_list_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/api_service.dart';
// import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/theme/text_styles.dart';
// import 'package:nudge/widgets/feedback_floating_button.dart';
// import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
// import '../notifications/notifications_screen.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
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
  bool emptyContacts = false;
  List<SocialGroup> allGroups = [];

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

  fetchGroups() async{
    final apiService = Provider.of<ApiService>(context, listen: false);
    final groups = await apiService.getGroupsStream().first;
    setState(() {
      allGroups = groups;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isAddToGroupMode = routeArgs?['action'] == 'add_to_group';
    final groupName = routeArgs?['groupName'];
    final groupPeriod = routeArgs?['groupPeriod'];
    final groupFrequency = routeArgs?['groupFrequency'];
    
    // If user is not logged in, show empty state
    if (user == null || emptyContacts) {
      return _buildEmptyState(themeProvider: themeProvider);
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
            if (totalContacts.isEmpty) {
              return _buildEmptyState(themeProvider: themeProvider);
            }
            final searchedContacts = filteredContacts.where((contact) {
              return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
            }).toList();
            
            return GestureDetector(
              onTap: _dismissKeyboard,
              child: Scaffold(
              floatingActionButton: Padding(
                padding: EdgeInsets.only(right: 10, bottom: 55,),
                child: _selectedContacts.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => _selectionMode == 'add_to_group'
                        ? _addMultipleContactsToGroup(context, groupName!, groupPeriod!, groupFrequency!, totalContacts, themeProvider)
                        : _deleteSelectedContacts(context),
                    backgroundColor: _selectionMode == 'add_to_group' ? theme.colorScheme.primary : Colors.red,
                    icon: Icon(
                      _selectionMode == 'add_to_group' ? Icons.group_add : Icons.delete,
                      color: Colors.white,
                    ),
                    label: Text(
                      _selectionMode == 'add_to_group'
                          ? 'ADD ${_selectedContacts.length} CONTACTS'
                          : 'DELETE ${_selectedContacts.length} CONTACTS',
                      style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
                    ),
                  )
                : Center()/* FeedbackFloatingButton(
                    currentSection: 'contacts',
                    extraActions: !isAddToGroupMode
                        ? [
                            FeedbackAction(
                              label: 'Add Contact',
                              icon: Icons.add,
                              onPressed: () {
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) => AddContactScreen(
                                //       groupName: groupName,
                                //       groupPeriod: groupPeriod,
                                //       groupFrequency: groupFrequency,
                                //     ),
                                //   ),
                                // );
                                _showAddContactOptions(context, themeProvider);
                              },
                            ),
                          ]
                        : [],
                  ) */,
              ),
              body: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Sliver App Bar
                      SliverAppBar(
                        title: isAddToGroupMode 
                            ? Text('Add to $groupName', style: AppTextStyles.title3.copyWith(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'))
                            : Padding(
                              padding: EdgeInsets.only(left: 0),
                              child: Text('Contacts', style: AppTextStyles.title2.copyWith(color: themeProvider.getTextPrimaryColor(context), fontWeight: FontWeight.w800, fontSize: 22, fontFamily: 'Inter')),
                            ),
                        backgroundColor: themeProvider.getBackgroundColor(context),
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
                                PopupMenuItem<String>(
                                  value: 'select_delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Select Contacts to Delete', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete_all',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_forever, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete All Contacts', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
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
                          child: _buildSelectionControls(themeProvider: themeProvider),
                        ),
                      
                      // Add-to-group header (only when in add-to-group mode)
                      if (isAddToGroupMode && !_isSelecting)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20, top: 20, right: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Long press on contacts to select multiple',
                                  style: TextStyle(
                                    fontFamily: 'OpenSans',
                                    fontSize: 12,
                                    color: themeProvider.getTextSecondaryColor(context),
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
                              _buildSearchAndFilterBar(themeProvider: themeProvider),
                              if (_currentFilter != 'all' && _currentFilter != '') 
                                _buildFilterTitleRow(themeProvider: themeProvider),
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
                              style: TextStyle(fontSize: 16, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
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
                                    ? _buildSelectableContactTile(contact, isSelected, themeProvider: themeProvider)
                                    : _buildNormalContactTile(
                                        contact, 
                                        isAddToGroupMode, 
                                        groupName, 
                                        groupPeriod, 
                                        groupFrequency,
                                        themeProvider: themeProvider
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
                  _buildDeletionProgressOverlay(themeProvider: themeProvider),
                  _buildAddingToGroupProgressOverlay(themeProvider: themeProvider),
                ],
              ),
            ));
          },
        ),
      );
    }
    
    // Original implementation for standalone use
    return GestureDetector(
              onTap: _dismissKeyboard,
              child: Scaffold(
      appBar: _buildNormalAppBar(context, isAddToGroupMode, groupName, themeProvider: themeProvider),
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
                          Text(
                            'Long press on contacts to select multiple',
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 12,
                              color: themeProvider.getTextSecondaryColor(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isAddToGroupMode)
                  SizedBox(height: 10),
                _buildSelectionControls(themeProvider: themeProvider),
                Expanded(
                  child: StreamProvider<List<Contact>>(
                    create: (context) => apiService.getContactsStream(),
                    initialData: const [],
                    child: Consumer<List<Contact>>(
                      builder: (context, contacts, child) {
                        totalContacts = contacts;
                        final filteredContacts = _applyFilter(contacts, _currentFilter);
                        
                        if (filteredContacts.isEmpty) {
                          return _buildEmptyState(filter: _currentFilter, themeProvider: themeProvider);
                        }
                        
                        final searchedContacts = filteredContacts.where((contact) {
                          return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
                        }).toList();
                        
                        if (searchedContacts.isEmpty) {
                          return Column(
                            children: [
                              _buildSearchAndFilterBar(themeProvider: themeProvider),
                              if (_currentFilter != 'all' && _currentFilter!='') _buildFilterTitleRow(themeProvider: themeProvider),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'No contacts found for "$_searchQuery"',
                                    style: TextStyle(fontSize: 16, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        
                        return Column(
                          children: [
                            _buildSearchAndFilterBar(themeProvider: themeProvider),
                            if (_currentFilter != 'all' && _currentFilter!='') _buildFilterTitleRow(themeProvider: themeProvider),
                            Expanded(
                              child: ListView.builder(
                                itemCount: searchedContacts.length,
                                itemBuilder: (context, index) {
                                  final contact = searchedContacts[index];
                                  final isSelected = _selectedContacts.contains(contact.id);
                                  
                                  return _isSelecting
                                      ? _buildSelectableContactTile(contact, isSelected, themeProvider: themeProvider)
                                      : _buildNormalContactTile(
                                          contact, 
                                          isAddToGroupMode, 
                                          groupName, 
                                          groupPeriod, 
                                          groupFrequency,
                                          themeProvider: themeProvider
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
          _buildDeletionProgressOverlay(themeProvider: themeProvider),
          _buildAddingToGroupProgressOverlay(themeProvider: themeProvider),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(right: 16,bottom: 55,),
        child: _selectedContacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _selectionMode == 'add_to_group'
                  ? _addMultipleContactsToGroup(context, groupName!, groupPeriod!, groupFrequency!, totalContacts, themeProvider)
                  : _deleteSelectedContacts(context),
              backgroundColor: _selectionMode == 'add_to_group' ? theme.colorScheme.primary : Colors.red,
              icon: Icon(
                _selectionMode == 'add_to_group' ? Icons.group_add : Icons.delete,
                color: Colors.white,
              ),
              label: Text(
                _selectionMode == 'add_to_group'
                    ? 'ADD ${_selectedContacts.length} CONTACTS'
                    : 'DELETE ${_selectedContacts.length} CONTACTS',
                style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
              ),
            )
          : /* FeedbackFloatingButton(
              currentSection: 'contacts',
              extraActions: !isAddToGroupMode
                  ? [
                      FeedbackAction(
                        label: 'Add Contact',
                        icon: Icons.add,
                        onPressed: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => AddContactScreen(
                          //       groupName: groupName,
                          //       groupPeriod: groupPeriod,
                          //       groupFrequency: groupFrequency,
                          //     ),
                          //   ),
                          // );
                          _showAddContactOptions(context, themeProvider);
                        },
                      ),
                    ]
                  : [],
            ) */Center()),
    ));
  }

  Widget _buildSelectionControls({required ThemeProvider themeProvider}) {
    if (!_isSelecting) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: themeProvider.isDarkMode 
          ? theme.colorScheme.primary.withOpacity(0.1)
          : const Color.fromRGBO(45, 161, 175, 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Select All / Deselect All
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _toggleSelectAll,
              onLongPress: () {
                apiService.scheduleTestNudges(_selectedContacts.toList());
                // apiService.cleanupTestNudges();
              },
              icon: Icon(
                _selectedContacts.length == _getVisibleContactsCount() 
                  ? Icons.deselect 
                  : Icons.select_all,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                _selectedContacts.length == _getVisibleContactsCount() && _selectedContacts.isNotEmpty
                  ? 'DESELECT ALL' 
                  : 'SELECT ALL',
                style: TextStyle(color: theme.colorScheme.primary, fontSize: 15, fontFamily: 'OpenSans'),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Cancel Selection
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exitSelectionMode,
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('CANCEL', style: TextStyle(color: Colors.red, fontSize: 15, fontFamily: 'OpenSans')),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  AppBar _buildNormalAppBar(BuildContext context, bool isAddToGroupMode, String? groupName, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    return AppBar(
      iconTheme: IconThemeData(color: theme.colorScheme.primary),
      title: isAddToGroupMode 
          ? Text('Add to $groupName', style: AppTextStyles.title3.copyWith(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'))
          : Padding(
            padding: EdgeInsets.only(left: 0),
            child: Text('Contacts', style: AppTextStyles.title2.copyWith(color: themeProvider.getTextPrimaryColor(context), fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'OpenSans'))
          ),
      backgroundColor: themeProvider.getBackgroundColor(context),
      centerTitle: isAddToGroupMode,
      surfaceTintColor: Colors.transparent,
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
              PopupMenuItem<String>(
                value: 'select_delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Select Contacts to Delete', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete All Contacts', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
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

  Widget _buildSelectableContactTile(Contact contact, bool isSelected, {required ThemeProvider themeProvider}) {
    final daysSinceLastContact = contact.lastContacted.difference(DateTime.now()).inDays.abs();
    
    return ListTile(
      tileColor: themeProvider.getSurfaceColor(context),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact name - now uses full width
          const SizedBox(height: 6),
          Text(
            contact.name,
            style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Connection type and last contacted in a row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Connection type
              Flexible(
                child: Text(
                  contact.connectionType,
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context),
                    fontFamily: 'OpenSans',
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Last contacted
              Text(
                'Last: ${daysSinceLastContact}d ago',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'OpenSans',
                  color: themeProvider.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
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
    
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    
    return '?';
  }

  Widget _buildNormalContactTile(Contact contact, bool isAddToGroupMode, String? groupName, String? groupPeriod, int? groupFrequency, {required ThemeProvider themeProvider}) {
    // final theme = Theme.of(context);
    final initials = _getContactInitials(contact.name);
    final daysSinceLastContact = contact.lastContacted.difference(DateTime.now()).inDays.abs();
    
    return ListTile(
      tileColor: themeProvider.getSurfaceColor(context),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: themeProvider.isDarkMode ? AppTheme.darkSurfaceVariant : Colors.transparent,
        backgroundImage: contact.imageUrl.isNotEmpty
            ? NetworkImage(contact.imageUrl)
            : AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png') as ImageProvider,
        child: contact.imageUrl.isEmpty
            ? Text(
                contact.name.isNotEmpty ? initials.toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenSans',
                  fontSize: 16,
                ),
              )
            : null,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact name - now uses full width
          const SizedBox(height: 6),
          Text(
            contact.name,
            style: AppTextStyles.primarySemiBold.copyWith(
              color: themeProvider.getTextPrimaryColor(context),
              fontFamily: 'OpenSans',
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Connection type and last contacted in a row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Connection type
              Flexible(
                child: Text(
                  contact.connectionType,
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context),
                    fontFamily: 'OpenSans',
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Last contacted
              Text(
                'Last: ${daysSinceLastContact}d ago',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'OpenSans',
                  color: themeProvider.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
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
          widget.hideButton();
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

  Widget _buildSearchAndFilterBar({required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    return Material(
      elevation: 2.0,
      child: Container(
        color: themeProvider.getSurfaceColor(context),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      hintStyle: TextStyle(color: themeProvider.getTextHintColor(context), fontFamily: 'OpenSans'),
                      prefixIcon: Icon(Icons.search, color: themeProvider.getTextHintColor(context)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: themeProvider.getSurfaceColor(context),
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
                    color: themeProvider.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.filter_list, color: theme.colorScheme.primary),
                      onSelected: (String newValue) {
                        setState(() {
                          _currentFilter = newValue;
                        });
                      },
                      itemBuilder: (BuildContext context) {
                        return <String>['all', 'vip'/* , 'needs_attention' */].map((String value) {
                          return PopupMenuItem<String>(
                            value: value,
                            child: Text(
                              _getFilterLabel(value),
                              style: TextStyle(fontSize: 14, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
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

  Widget _buildFilterTitleRow({required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: themeProvider.isDarkMode ? AppTheme.darkSurfaceVariant : Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getFilterTitle(_currentFilter),
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'OpenSans',
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentFilter = 'all';
              });
            },
            child: Text(
              'Clear Filter',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14, 
                fontFamily: 'OpenSans'
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
        return 'Favourites';
      case 'needs_attention':
        return 'Needs Care';
      default:
        return 'All Contacts';
    }
  }

  String _getFilterTitle(String filter) {
    switch (filter) {
      case 'vip':
        return 'Favourite Contacts';
      case 'needs_attention':
        return 'Contacts Needing Care';
      default:
        return 'All Contacts';
    }
  }

  Widget _buildDeletionProgressOverlay({required ThemeProvider themeProvider}) {
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
            color: themeProvider.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Deleting Contacts',
                style: TextStyle(
                  fontFamily: 'OpenSans',
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
                backgroundColor: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$_deletionSuccessCount of $_deletionTotalCount contacts deleted'
                '${_deletionErrorCount > 0 ? ' ($_deletionErrorCount errors)' : ''}',
                style: TextStyle(fontSize: 14, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddingToGroupProgressOverlay({required ThemeProvider themeProvider}) {
    if (!_isAddingToGroupInProgress) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
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
            color: themeProvider.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adding to $_currentGroupName',
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _addingTotalCount > 0 
                    ? _addingSuccessCount / _addingTotalCount 
                    : 0,
                backgroundColor: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                '$_addingSuccessCount of $_addingTotalCount contacts added'
                '${_addingErrorCount > 0 ? ' ($_addingErrorCount errors)' : ''}',
                style: TextStyle(fontSize: 14, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedContacts(BuildContext context) async {
    final theme = Theme.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Provider.of<ThemeProvider>(context).getSurfaceColor(context),
        title: Text('DELETE CONTACTS', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
        content: Text('Are you sure you want to delete ${_selectedContacts.length} contacts? This action cannot be undone.', style: TextStyle(color: Provider.of<ThemeProvider>(context).getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _startDeletionProcess();
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
    
    for (String contactId in _selectedContacts) {
      try {
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $_deletionSuccessCount contacts${_deletionErrorCount > 0 ? '. $_deletionErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
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
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts to delete')),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text('Delete All Contacts', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontFamily: 'OpenSans')),
        content: Text('Are you sure you want to delete all ${contacts.length} contacts? This action cannot be undone.', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $_deletionSuccessCount contacts${_deletionErrorCount > 0 ? '. $_deletionErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    setState(() {
      _isDeletingInProgress = false;
    });
  }

  Future<void> _addMultipleContactsToGroup(BuildContext context, String groupName, String groupPeriod, int groupFrequency, List<Contact> contacts, ThemeProvider themeProvider) async {
    final theme = Theme.of(context);
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text('ADD TO GROUP', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontFamily: 'OpenSans')),
        content: Text('Are you sure you want to add ${_selectedContacts.length} contacts to "$groupName"?', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Add to Group', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
    
    if (confirmed != true) {
      return;
    }
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
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
    
    for (String contactId in _selectedContacts) {
      try {
        final contact = contacts.firstWhere((c) => c.id == contactId);
        
        final updatedContact = contact.copyWith(
          connectionType: groupName,
          period: groupPeriod,
          frequency: groupFrequency,
        );
        
        await apiService.updateContact(updatedContact);
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
    
    List<String> contactIds = [];
    contacts.map((contact){
      contactIds.add(contact.id);
    });
    
    if (successfullyAddedContacts.isNotEmpty) {
      apiService.cancelNudgesForContacts(contactIds);
      apiService.scheduleNudgesForContacts(contactIds: contactIds);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $_addingSuccessCount contacts to $groupName${_addingErrorCount > 0 ? '. $_addingErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    widget.hideButton();
    
    setState(() {
      _isAddingToGroupInProgress = false;
      _isSelecting = false;
      _selectedContacts.clear();
      _selectionMode = null;
      _currentGroupName = null;
    });
    Navigator.pop(context);
  }

  void _addContactToGroup(BuildContext context, Contact contact, String groupName, String groupPeriod, int groupFrequency) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (contact.connectionType.isNotEmpty && contact.connectionType != groupName) {
      bool confirmOverride = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: themeProvider.getSurfaceColor(context),
            title: Text('OVERRIDE GROUP ASSIGNMENT', style: AppTextStyles.title3.copyWith(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
            content: Text(
              '${contact.name} is already in the "${contact.connectionType}" group. '
              'Do you want to override this and assign them to "$groupName" instead?',
              style: TextStyle(color: themeProvider.getTextPrimaryColor(context)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Override', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
              ),
            ],
          );
        },
      );
      
      if (!confirmOverride) {
        return;
      }
    }
    
    try {
      final updatedContact = contact.copyWith(
        connectionType: groupName,
        period: groupPeriod,
        frequency: groupFrequency,
      );
      
      await apiService.updateContact(updatedContact);
      await apiService.cancelNudgesForContacts([contact.id]);
      await apiService.scheduleNudgesForContacts(contactIds: [contact.id]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${contact.name} to $groupName')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add contact: $e')),
      );
    }
  }

  Widget _buildEmptyState({String? filter, required ThemeProvider themeProvider}) {
    String title;
    String description;
    
    switch (filter) {
      case 'vip':
        title = 'No Favourite Contacts yet';
        description = 'Mark contacts as Favourite to see them here';
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
        padding: EdgeInsets.only(right: 10,bottom: 55,),
        child: Center()/* FeedbackFloatingButton(
          currentSection: 'contacts',
          extraActions: [
            FeedbackAction(
              label: 'Add Contacts',
              icon: Icons.person_add,
              onPressed: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => AddContactScreen(),
                //   ),
                // );
                _showAddContactOptions(context, themeProvider);
              },
            ),
          ],
        ) */,
      ),
      body: Container(
        color: themeProvider.getBackgroundColor(context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.contacts,
                  size: 64,
                  color: themeProvider.getTextSecondaryColor(context),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 16,
                    color: themeProvider.getTextSecondaryColor(context),
                  ), 
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddContactScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text('Add Contact Manually', style: TextStyle(color: Colors.white, fontFamily: 'OpenSans')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (Theme.of(context).platform == TargetPlatform.android)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImportContactsScreen(
                                  groups: allGroups,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.smart_button),
                          label: const Text('Smart Import (Android)'),
                        ),
                      ),
                    
                    if (Theme.of(context).platform == TargetPlatform.android) const SizedBox(height: 12),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _importFromContactPicker,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                      backgroundColor: themeProvider.isDarkMode 
                          ? AppTheme.darkSurfaceVariant 
                          : const Color.fromARGB(255, 145, 209, 216),
                    ),
                    child: Text('Clear Filter', style: AppTextStyles.button.copyWith(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  ),
              ],
            ),
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

  Future<void> _importFromContactPicker() async {
    Navigator.pushNamed(context, '/import_contacts');
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
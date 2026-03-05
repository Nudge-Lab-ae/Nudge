import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:nudge/main.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:shimmer/shimmer.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/social_group.dart';
import '../../models/contact.dart';
import '../../models/nudge.dart';
// import '../../widgets/feedback_floating_button.dart';

enum SortOption { orderIndex, name, memberCount, frequency }

class GroupsListScreen extends StatefulWidget {
  final bool showAppBar;
  const GroupsListScreen({super.key, required this.showAppBar});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  String _searchQuery = '';
  Stream<List<SocialGroup>>? _groupsStream;
  Stream<List<Nudge>>? _nudgesStream;
  List allContacts = [];
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  SortOption _currentSortOption = SortOption.orderIndex;
  bool _sortAscending = true;
  final ScrollController _scrollController = ScrollController();
  List<SocialGroup> allGroups = [];
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    _groupsStream = apiService.getGroupsStream().handleError((error) {
      print('Error in groups stream: $error');
      return <SocialGroup>[];
    });
    
    _nudgesStream = apiService.getNudgesStream().handleError((error) {
      print('Error in nudges stream: $error');
      return <Nudge>[];
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeStreams();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  double _calculateGroupProgress(List<Contact> groupMembers, List<Nudge> allNudges) {
    if (groupMembers.isEmpty) return 0.0;

    double totalProgress = 0.0;
    int membersWithNudges = 0;

    for (final member in groupMembers) {
      final memberNudges = allNudges.where((nudge) => nudge.contactId == member.id).toList();
      
      if (memberNudges.isNotEmpty) {
        final totalNudges = memberNudges.length;
        final completedNudges = memberNudges.where((nudge) => nudge.isCompleted).length;
        final memberProgress = totalNudges > 0 ? completedNudges / totalNudges : 0.0;
        totalProgress += memberProgress;
        membersWithNudges++;
      }
    }

    if (membersWithNudges == 0) return 0.0;
    return totalProgress / membersWithNudges;
  }

  List<SocialGroup> _sortGroups(List<SocialGroup> groups) {
    List<SocialGroup> sortedGroups = List.from(groups);
    
    switch (_currentSortOption) {
      case SortOption.orderIndex:
        sortedGroups.sort((a, b) => _sortAscending 
            ? a.orderIndex.compareTo(b.orderIndex) 
            : b.orderIndex.compareTo(a.orderIndex));
        break;
      case SortOption.name:
        sortedGroups.sort((a, b) => _sortAscending 
            ? a.name.compareTo(b.name) 
            : b.name.compareTo(a.name));
        break;
      case SortOption.memberCount:
        sortedGroups.sort((a, b) => _sortAscending 
            ? a.memberCount.compareTo(b.memberCount) 
            : b.memberCount.compareTo(a.memberCount));
        break;
      case SortOption.frequency:
        sortedGroups.sort((a, b) => _sortAscending 
            ? a.frequency.compareTo(b.frequency) 
            : b.frequency.compareTo(a.frequency));
        break;
    }
    
    return sortedGroups;
  }

  void _showDeleteConfirmation(BuildContext context, SocialGroup group, ApiService apiService, ThemeProvider themeProvider, bool doubleTap) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text('Delete Group', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans', fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete the "${group.name}" group?', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Close the confirmation dialog first
                Navigator.pop(dialogContext);
                
                // Small delay to ensure dialog is closed
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Get all contacts
                final contacts = await apiService.getContactsStream().first;
                
                // Find contacts that belong to this group
                final groupContacts = contacts.where((c) => 
                  c.connectionType == group.name || c.connectionType == group.id
                ).toList();
                
                if (groupContacts.isNotEmpty && context.mounted) {
                  // Get available groups (excluding the one being deleted)
                  final currentGroups = await apiService.getGroupsStream().first;
                  final availableGroups = currentGroups.where((g) => g.id != group.id).toList();
                  
                  // Show reassignment modal
                  final result = await showModalBottomSheet<Map<String, String?>>(
                    context: navigatorKey.currentContext!,
                    // context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (modalContext) => _buildReassignmentModal(
                      context: modalContext,
                      deletedGroup: group,
                      affectedContacts: groupContacts,
                      availableGroups: availableGroups,
                      themeProvider: themeProvider,
                    ),
                  );
                  
                  // Process the selections
                  if (result != null && context.mounted) {
                      try {
                        await _processContactReassignments(
                          result,
                          groupContacts,
                          availableGroups,
                          apiService,
                          // Remove the onSuccess callback that shows message here
                        );
                        
                        // Show success message after all navigation is complete
                        if (context.mounted) {
                          // Use a microtask to ensure navigation is complete
                          Future.microtask(() {
                            if (context.mounted) {
                              _showSuccessMessage('Contacts reassigned successfully');
                            }
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Future.microtask(() {
                            if (context.mounted) {
                              _showFailureMessage(e.toString());
                            }
                          });
                        }
                        // Re-throw to prevent group deletion if reassignment failed
                        rethrow;
                      }
                    } else if (result == null){
                    return;
                  }
                }
                
                // Delete the group and reorder remaining groups
                if (context.mounted) {
                  // Get current groups
                  final updatedGroups = await apiService.getGroupsStream().first;
                  
                  // Remove the deleted group
                  updatedGroups.removeWhere((g) => g.id == group.id);
                  
                  // Reorder the remaining groups to have sequential orderIndex starting from 0
                  final reorderedGroups = updatedGroups.asMap().entries.map((entry) {
                    return entry.value.copyWith(orderIndex: entry.key);
                  }).toList();
                  
                  // Save the reordered groups
                  await apiService.updateGroups(reorderedGroups);
                  
                  _showSuccessMessage('Deleted "${group.name}" group');
                  
                  // Refresh the UI
                  setState(() {
                    _initializeStreams();
                  });
                  
                  // if (!doubleTap) {
                  //   Navigator.pop(context);
                  // }
                }
                
              } catch (e) {
                if (context.mounted) {
                  _showFailureMessage('Error deleting group: $e');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
  }

  // Add these helper methods to your _GroupsListScreenState class

  Widget _buildReassignmentModal({
    required BuildContext context,
    required SocialGroup deletedGroup,
    required List<Contact> affectedContacts,
    required List<SocialGroup> availableGroups,
    required ThemeProvider themeProvider,
  }) {
    final theme = Theme.of(context);
    
    // Create a map to store selected group for each contact
    Map<String, String?> contactSelections = {};
    Map<String, String> contactOriginalGroups = {};
    
    // Initialize selections with empty (unassigned) for all contacts
    for (var contact in affectedContacts) {
      contactSelections[contact.id] = null;
      contactOriginalGroups[contact.id] = contact.connectionType;
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: themeProvider.getSurfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: themeProvider.getTextSecondaryColor(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reassign Contacts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.getTextPrimaryColor(context),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The "${deletedGroup.name}" group is being deleted. Please assign each contact to a new group.',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.getTextSecondaryColor(context),
                        fontFamily: 'OpenSans',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: contactSelections.values.where((s) => s != null).length / affectedContacts.length,
                        backgroundColor: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${contactSelections.values.where((s) => s != null).length}/${affectedContacts.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: themeProvider.getTextPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Contacts list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: affectedContacts.length,
                  itemBuilder: (context, index) {
                    final contact = affectedContacts[index];
                    final isSelected = contactSelections[contact.id] != null;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : themeProvider.isDarkMode 
                                ? AppTheme.darkSurfaceVariant 
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.5)
                              : themeProvider.isDarkMode 
                                  ? AppTheme.darkCardBorder 
                                  : Colors.grey.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Contact info
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: themeProvider.isDarkMode ? AppTheme.darkSurfaceVariant : Colors.transparent,
                                  backgroundImage: contact.imageUrl.isNotEmpty
                                      ? NetworkImage(contact.imageUrl)
                                      : AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png') as ImageProvider,
                                  child: contact.imageUrl.isEmpty
                                      ? Text(
                                          contact.name.isNotEmpty ? _getContactInitials(contact.name).toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: themeProvider.getTextPrimaryColor(context),
                                          fontFamily: 'OpenSans',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      /* Text(
                                        'Previously: ${contactOriginalGroups[contact.id] ?? 'No group'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: themeProvider.getTextSecondaryColor(context),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ), */
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Group selection
                            Container(
                              decoration: BoxDecoration(
                                color: themeProvider.isDarkMode 
                                    ? Colors.grey[900] 
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: themeProvider.isDarkMode 
                                      ? AppTheme.darkCardBorder 
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: contactSelections[contact.id],
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Select a group (optional)',
                                      style: TextStyle(
                                        color: themeProvider.getTextSecondaryColor(context),
                                      ),
                                    ),
                                  ),
                                  isExpanded: true,
                                  icon: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.arrow_drop_down,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  items: [
                                    // Option for unassigned
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.person_outline,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'No group (unassigned)',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontFamily: 'OpenSans',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Divider
                                    const DropdownMenuItem<String>(
                                      value: 'divider',
                                      enabled: false,
                                      child: Divider(height: 1),
                                    ),
                                    // Available groups
                                    ...availableGroups.map((group) {
                                      return DropdownMenuItem<String>(
                                        value: group.id,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  group.name,
                                                  style: TextStyle(
                                                    color: themeProvider.getTextPrimaryColor(context),
                                                    fontFamily: 'OpenSans',
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (String? newValue) {
                                    if (newValue != 'divider') {
                                      setState(() {
                                        contactSelections[contact.id] = newValue;
                                      });
                                    }
                                  },
                                  style: TextStyle(
                                    color: themeProvider.getTextPrimaryColor(context),
                                    fontSize: 14,
                                  ),
                                  dropdownColor: themeProvider.getSurfaceColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'OpenSans',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Check if any contact is unassigned
                          final unassignedContacts = contactSelections.entries
                              .where((entry) => entry.value == null)
                              .map((entry) => affectedContacts.firstWhere(
                                (contact) => contact.id == entry.key,
                                orElse: () => Contact.empty(),
                              ))
                              .where((contact) => contact.name.isNotEmpty)
                              .toList();
                          
                          if (unassignedContacts.isNotEmpty) {
                            // Show a snackbar instead of a dialog to avoid navigation conflicts
                            Flushbar(
                              padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                              backgroundColor: Colors.deepOrange,
                              flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                              forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                              messageText: Center(
                                  child: Text( 'Please assign all ${unassignedContacts.length} contact${unassignedContacts.length > 1 ? 's' : ''} to a group', style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
                                      color: Colors.white, fontWeight: FontWeight.w400),)),
                            ).show(context);

                          } else {
                            // All contacts are assigned, proceed
                            Navigator.pop(navigatorKey.currentContext!, contactSelections);
                            // Navigator.pop(context, contactSelections);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Changes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'OpenSans',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processContactReassignments(
    Map<String, String?> selections,
    List<Contact> affectedContacts,
    List<SocialGroup> availableGroups,
    ApiService apiService,
    {Function(String)? onSuccess,
    Function(String)? onError}
  ) async {
    try {
      // Update each contact with their new group
      for (var contact in affectedContacts) {
        final selectedGroupId = selections[contact.id];
        
        if (selectedGroupId != null) {
          // Find the selected group
          final selectedGroup = availableGroups.firstWhere(
            (g) => g.id == selectedGroupId,
          );
          
          // Update contact with new group
          final updatedContact = contact.copyWith(
            connectionType: selectedGroup.name,
            period: selectedGroup.period,
            frequency: selectedGroup.frequency,
          );
          
          await apiService.updateContact(updatedContact);
          
          // Update group member counts
          final updatedGroup = selectedGroup.copyWith(
            memberIds: [...selectedGroup.memberIds, contact.id],
            memberCount: selectedGroup.memberCount + 1,
          );
          await apiService.updateGroup(updatedGroup);
        } else {
          // Contact becomes unassigned
          final updatedContact = contact.copyWith(
            connectionType: 'Contact',
            period: 'Monthly',
            frequency: 2,
          );
          await apiService.updateContact(updatedContact);
        }
      }
      
      if (onSuccess != null) {
        // onSuccess('${affectedContacts.length} contacts reassigned successfully');
        
        //  Flushbar(
        //     padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
        //     flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
        //     forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
        //     messageText: Center(
        //         child: Text( '${affectedContacts.length} contacts reassigned successfully', style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
        //             color: Colors.white, fontWeight: FontWeight.w400),)),
        //   ).show(navigatorKey.currentContext!);

      }
    } catch (e) {
      if (onError != null) {
        // onError(e.toString());
      }
    }
  }
    
  Future<void> _reorderGroups(int oldIndex, int newIndex, List<SocialGroup> groups, ApiService apiService) async {
    if (oldIndex == newIndex) return;
    
    setState(() {
      _isReordering = true;
    });

    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      // Create a mutable copy of the list
      List<SocialGroup> updatedList = List.from(groups);
      final item = updatedList.removeAt(oldIndex);
      updatedList.insert(newIndex, item);
      
      // Update order indices
      final groupsWithUpdatedIndices = updatedList.asMap().entries.map((entry) {
        return entry.value.copyWith(orderIndex: entry.key);
      }).toList();
      
      // Save to Firestore
      await apiService.updateGroups(groupsWithUpdatedIndices);
      
      // Refresh the groups stream to show updated order
      setState(() {
        // This will trigger a rebuild with the new data
        _initializeStreams();
      });
      
      print('Groups reordered successfully');
    } catch (e) {
      print('Error reordering groups: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reordering groups: $e')),
      );
    } finally {
      setState(() {
        _isReordering = false;
      });
    }
  }
    
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    if (user == null) {
      return Scaffold(
        backgroundColor: themeProvider.getBackgroundColor(context),
        body: Center(child: Text('Please log in to view groups', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'))),
      );
    }

    return StreamProvider<List<Contact>>.value(
      value: apiService.getContactsStream().handleError((error) {
        print('Error in contacts stream: $error');
        return <Contact>[];
      }),
      initialData: const [],
      child: StreamProvider<List<Nudge>>.value(
        value: _nudgesStream ?? Stream.value([]),
        initialData: const [],
        child: Consumer2<List<Contact>, List<Nudge>>(
          builder: (context, contacts, nudges, child) {
            return Scaffold(
              backgroundColor: themeProvider.getBackgroundColor(context),
              appBar: widget.showAppBar 
                  ? AppBar(
                      title: const Text('Social Groups', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w800)),
                      iconTheme: const IconThemeData(color: Colors.white),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                         Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: ElevatedButton(
                            onPressed: () {
                              _showCreateGroupDialog(context, apiService, themeProvider: themeProvider);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.getSurfaceColor(context),
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Add Group',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'OpenSans'
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      centerTitle: false,
                      backgroundColor: theme.colorScheme.primary,
                     )
                  : null,
              body: Stack(
                children: [
                  // For embedded mode (dashboard)
                if (!widget.showAppBar)
                  StreamBuilder<List<SocialGroup>>(
                    stream: _groupsStream,
                    builder: (context, groupsSnapshot) {
                      if (groupsSnapshot.hasError) {
                        return _buildErrorState(groupsSnapshot.error.toString(), themeProvider: themeProvider);
                      }

                      if (!groupsSnapshot.hasData) {
                        return _buildLoadingState(themeProvider: themeProvider);
                      }

                      final groups = groupsSnapshot.data!;
                      allGroups = groups;
                      final sortedGroups = _sortGroups(groups);
                      final filteredGroups = sortedGroups.where((group) {
                        return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            group.description.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();
                      
                      if (groups.isEmpty) {
                        return _buildEmptyState(apiService, themeProvider: themeProvider);
                      }

                      return GestureDetector(
                        onTap: _dismissKeyboard,
                        child: Scaffold(
                          body: CustomScrollView(
                            // physics: const BouncingScrollPhysics(),
                            slivers: [
                              // Sliver App Bar with disappearing effect
                              SliverAppBar(
                                title: Text(
                                  'Social Groups',
                                  style: AppTextStyles.title2.copyWith(
                                    color: themeProvider.getTextPrimaryColor(context),
                                    fontSize: 22,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800
                                  ),
                                ),
                                backgroundColor: themeProvider.getBackgroundColor(context),
                                leading: Center(),
                                centerTitle: false,
                                surfaceTintColor: Colors.transparent,
                                floating: true,
                                actions: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _showCreateGroupDialog(context, apiService, themeProvider: themeProvider);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: themeProvider.getSurfaceColor(context),
                                        foregroundColor: theme.colorScheme.primary,
                                        side: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300, width: 1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Add Group',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'OpenSans'
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                snap: true,
                                pinned: false,
                              ),
                              
                              // Groups List - Using ReorderableListView directly in SliverList
                              SliverFillRemaining(
                                hasScrollBody: true,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _isReordering 
                                      ? const Center(child: CircularProgressIndicator())
                                      : ReorderableListView.builder(
                                          // Remove shrinkWrap and let it use natural scrolling
                                          itemCount: filteredGroups.length,
                                          itemBuilder: (context, index) {
                                            final group = filteredGroups[index];
                                            final groupMembers = contacts.where((contact) => 
                                              contact.connectionType == group.name || contact.connectionType == group.id
                                            ).toList();
                                            
                                            final progress = _calculateGroupProgress(groupMembers, nudges);
                                            
                                            return Container(
                                              key: Key(group.id),
                                              margin: const EdgeInsets.only(bottom: 12),
                                              child: _buildGroupCard(
                                                context, 
                                                group, 
                                                groupMembers, 
                                                progress, 
                                                apiService, 
                                                themeProvider: themeProvider
                                              ),
                                            );
                                          },
                                          onReorder: (oldIndex, newIndex) {
                                            _reorderGroups(oldIndex, newIndex, filteredGroups, apiService);
                                          },
                                          proxyDecorator: (child, index, animation) {
                                            return AnimatedBuilder(
                                              animation: animation,
                                              builder: (context, child) {
                                                final elevation = CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeInOut,
                                                ).value * 8;
                                                
                                                return Material(
                                                  elevation: elevation,
                                                  color: Colors.transparent,
                                                  shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                                                  child: child,
                                                );
                                              },
                                              child: child,
                                            );
                                          },
                                        ),
                                ),
                              ),
                              // Bottom padding for FAB
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 80),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                                  
                  // For standalone mode
                  if (widget.showAppBar)
                    StreamBuilder<List<SocialGroup>>(
                      stream: _groupsStream,
                      builder: (context, groupsSnapshot) {
                        if (groupsSnapshot.hasError) {
                          return _buildErrorState(groupsSnapshot.error.toString(), themeProvider: themeProvider);
                        }

                        if (!groupsSnapshot.hasData) {
                          return _buildLoadingState(themeProvider: themeProvider);
                        }

                        final groups = groupsSnapshot.data!;
                        allGroups = groups;
                        final sortedGroups = _sortGroups(groups);
                        final filteredGroups = sortedGroups.where((group) {
                          return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              group.description.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();
                        
                        if (groups.isEmpty) {
                          return _buildEmptyState(apiService, themeProvider: themeProvider);
                        }

                        return GestureDetector(
                          onTap: _dismissKeyboard,
                          child: Scaffold(
                            appBar: AppBar(
                              title: Text(
                                'Social Groups',
                                style: AppTextStyles.title2.copyWith(
                                  color: themeProvider.getTextPrimaryColor(context),
                                  fontSize: 16,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w800
                                ),
                              ),
                              centerTitle: false,
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                           /*  floatingActionButton: Padding(
                              padding: EdgeInsets.only(right: 10, bottom: 55),
                              child: FeedbackFloatingButton(
                                currentSection: 'groups',
                                extraActions: [
                                  FeedbackAction(
                                    label: 'New Group',
                                    icon: Icons.group_add,
                                    onPressed: () => _showCreateGroupDialog(context, apiService, themeProvider: themeProvider),
                                  ),
                                ],
                              ),
                            ), */
                            body: CustomScrollView(
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                // Groups List - Using ReorderableListView inside a SliverToBoxAdapter
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _isReordering 
                                        ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                                        : ReorderableListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: filteredGroups.length,
                                            itemBuilder: (context, index) {
                                              final group = filteredGroups[index];
                                              final groupMembers = contacts.where((contact) => 
                                                contact.connectionType == group.name || contact.connectionType == group.id
                                              ).toList();
                                              
                                              final progress = _calculateGroupProgress(groupMembers, nudges);
                                              
                                              return Container(
                                                key: Key(group.id),
                                                margin: const EdgeInsets.only(bottom: 12),
                                                child: _buildGroupCard(
                                                  context, 
                                                  group, 
                                                  groupMembers, 
                                                  progress, 
                                                  apiService, 
                                                  themeProvider: themeProvider
                                                ),
                                              );
                                            },
                                            onReorder: (oldIndex, newIndex) {
                                              _reorderGroups(oldIndex, newIndex, filteredGroups, apiService);
                                            },
                                            proxyDecorator: (child, index, animation) {
                                              return AnimatedBuilder(
                                                animation: animation,
                                                builder: (context, child) {
                                                  final elevation = CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeInOut,
                                                  ).value * 8;
                                                  
                                                  return Material(
                                                    elevation: elevation,
                                                    color: Colors.transparent,
                                                    shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                                                    child: child,
                                                  );
                                                },
                                                child: child,
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                
                                // Bottom padding
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 80),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  // Confetti animation
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        Colors.green,
                        Colors.blue,
                        Colors.pink,
                        Colors.orange,
                        Colors.purple
                      ],
                    ),
                  ),
                ],
              ),
              // Fixed FAB positioning for both modes
              /* floatingActionButton: Padding(
                padding: EdgeInsets.only(
                  bottom: widget.showAppBar ? 55.0 : 55.0,
                  right: 6.0,
                ),
                child: FeedbackFloatingButton(
                  currentSection: 'groups',
                  extraActions: [
                    FeedbackAction(
                      label: 'New Group',
                      icon: Icons.group_add,
                      onPressed: () => _showCreateGroupDialog(context, apiService, themeProvider: themeProvider),
                    ),
                  ],
                ),
              ), */
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context, 
    SocialGroup group, 
    List<Contact> members, 
    double progress, 
    ApiService apiService, 
    {required ThemeProvider themeProvider}
  ) {
    final theme = Theme.of(context);
    Color cardColor;
    try {
      cardColor = Color(int.parse(group.colorCode.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      cardColor = theme.colorScheme.primary;
    }
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: themeProvider.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showGroupDetails(context, group, members, apiService, themeProvider: themeProvider),
          onDoubleTap: () => _showDeleteConfirmation(context, group, apiService, themeProvider, true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Group icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getGroupIcon(group.name),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Group details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              group.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.getTextPrimaryColor(context),
                                fontFamily: 'OpenSans'
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${members.length} members',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.getTextSecondaryColor(context),
                              fontWeight: FontWeight.w300,
                              fontFamily: 'OpenSans'
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cardColor,
                            fontFamily: 'OpenSans'
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                
                Icon(Icons.chevron_right, color: themeProvider.getTextSecondaryColor(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
    
  Widget _buildErrorState(String error, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Oops! Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error, textAlign: TextAlign.center, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _initializeStreams()),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState({required ThemeProvider themeProvider}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            highlightColor: themeProvider.isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: themeProvider.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ApiService apiService, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    return Container(
      color: themeProvider.getBackgroundColor(context),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/empty_groups.png', width: 200, height: 200),
            const SizedBox(height: 24),
            Text('No Groups Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Create your first group to organize your contacts and stay connected',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans'),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showCreateGroupDialog(context, apiService, themeProvider: themeProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Create Your First Group', style: TextStyle(color: Colors.white, fontFamily: 'OpenSans')),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getGroupIcon(String groupName) {
    if (groupName.toLowerCase().contains('family')) return Icons.family_restroom;
    if (groupName.toLowerCase().contains('friend')) return Icons.people;
    if (groupName.toLowerCase().contains('work') || groupName.toLowerCase().contains('colleague')) return Icons.work;
    if (groupName.toLowerCase().contains('client')) return Icons.business_center;
    if (groupName.toLowerCase().contains('mentor')) return Icons.school;
    return Icons.group;
  }

  externalRefresh() async {
    setState(() => _initializeStreams());
    await Future.delayed(const Duration(seconds: 1));
  }

void _showCreateGroupDialog(BuildContext context, ApiService apiService, {required ThemeProvider themeProvider}) {
  final theme = Theme.of(context);
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  String _selectedFrequencyChoice = 'Monthly';
  String period = 'Monthly';
  int frequency = 1;
  String selectedColor = '#2596BE';

  final List<String> colorOptions = [
    '#2596BE',
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#F9A826',
    '#6C5CE7',
  ];

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: themeProvider.getSurfaceColor(context),
            title: Text('CREATE NEW GROUP', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary, fontSize: 16, fontFamily: 'OpenSans')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      labelStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        final frequencyData = FrequencyPeriodMapper.getFrequencyPeriod(newValue);
                        setState(() {
                          frequency = frequencyData['frequency'] as int;
                          period = frequencyData['period'] as String;
                        });
                      }
                    },
                    items: FrequencyPeriodMapper.frequencyMapping.keys.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Contact Frequency',
                      labelStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorOptions.map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000),
                            shape: BoxShape.circle,
                            border: selectedColor == color 
                              ? Border.all(color: themeProvider.getTextPrimaryColor(context), width: 2) 
                              : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    // First, get current groups to know how to update order indices
                  final currentGroups = List.from(allGroups);

                  // Increment orderIndex for all existing groups
                  for (int i = 0; i < currentGroups.length; i++) {
                    currentGroups[i] = currentGroups[i].copyWith(orderIndex: i + 1);
                  }

                  // Create new group with orderIndex 0
                  final newGroup = SocialGroup(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    description: descriptionController.text,
                    period: period,
                    frequency: frequency,
                    memberIds: [],
                    memberCount: 0,
                    lastInteraction: DateTime.now(),
                    colorCode: selectedColor,
                    birthdayNudgesEnabled: true,
                    anniversaryNudgesEnabled: true,
                    orderIndex: 0 // Set to 0 to appear at the top
                  );

                  // Update the groups list in the provider/state
                  // You'll need to update this based on how you're managing the groups
                  // If using setState:
                  setState(() {
                    allGroups = [newGroup, ...currentGroups];
                  });

// If using provider or other state management, adjust accordingly
                    
                    try {
                      await apiService.addGroup(newGroup);
                      _confettiController.play();
                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating group: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Create', style: TextStyle(color: Colors.white, fontFamily: 'OpenSans')),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showEditGroupDialog(BuildContext context, SocialGroup group, ApiService apiService, VoidCallback onUpdate, {required ThemeProvider themeProvider}) {
  final theme = Theme.of(context);
  final nameController = TextEditingController(text: group.name);
  final descriptionController = TextEditingController(text: group.description);
  String period = group.period;
  int frequency = group.frequency;
  String selectedColor = group.colorCode;
  bool birthdayNudgesEnabled = group.birthdayNudgesEnabled;
  bool anniversaryNudgesEnabled = group.anniversaryNudgesEnabled;
  String _selectedFrequencyChoice = FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period);

  final List<String> colorOptions = [
    '#2596BE',
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#F9A826',
    '#6C5CE7',
  ];

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: themeProvider.getSurfaceColor(context),
            title: Text('EDIT GROUP', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      labelStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        final frequencyData = FrequencyPeriodMapper.getFrequencyPeriod(newValue);
                        setState(() {
                          frequency = frequencyData['frequency'] as int;
                          period = frequencyData['period'] as String;
                        });
                      }
                    },
                    items: FrequencyPeriodMapper.frequencyMapping.keys.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Contact Frequency',
                      labelStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const SizedBox(height: 16),
                  Text('Date Nudges:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send a nudge for birthdays',
                          style: TextStyle(fontSize: 14, color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans'),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.5,
                        child: Switch(
                          inactiveThumbColor: themeProvider.isDarkMode ? Colors.grey[300] : Colors.white,
                          inactiveTrackColor: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey,
                          value: birthdayNudgesEnabled,
                          onChanged: (value) {
                            setState(() {
                              birthdayNudgesEnabled = value;
                            });
                          },
                        ),
                      )
                    ],
                  ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send a nudge for anniversaries',
                          style: TextStyle(fontSize: 14, color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans'),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.5,
                        child: Switch(
                          inactiveThumbColor: themeProvider.isDarkMode ? Colors.grey[300] : Colors.white,
                          inactiveTrackColor: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey,
                          value: anniversaryNudgesEnabled,
                          onChanged: (value) {
                            setState(() {
                              anniversaryNudgesEnabled = value;
                            });
                          },
                        )),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorOptions.map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000),
                            shape: BoxShape.circle,
                            border: selectedColor == color 
                              ? Border.all(color: themeProvider.getTextPrimaryColor(context), width: 2) 
                              : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    final updatedGroup = group.copyWith(
                      name: nameController.text,
                      description: descriptionController.text,
                      period: period,
                      frequency: frequency,
                      colorCode: selectedColor,
                      birthdayNudgesEnabled: birthdayNudgesEnabled,
                      anniversaryNudgesEnabled: anniversaryNudgesEnabled,
                    );

                    try {
                      final currentGroups = await apiService.getGroupsStream().first;
                      final updatedGroups = currentGroups.map((g) => 
                        g.id == group.id ? updatedGroup : g
                      ).toList();
                      
                      await apiService.updateGroups(updatedGroups);
                      onUpdate();
                      Navigator.of(context).pop();
                      
                     Flushbar(
                        padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                        flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                        forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                        messageText: Center(
                            child: Text( 'Updated "${updatedGroup.name}" group!', style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
                                color: Colors.white, fontWeight: FontWeight.w400),)),
                      ).show(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating group: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontFamily: 'OpenSans')),
              ),
            ],
          );
        },
      );
    },
  );
}

  _showSuccessMessage(String message) {
    Flushbar(
        padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
        flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
        forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
        backgroundColor: Colors.green,
        messageText: Center(
            child: Text( message, style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
                color: Colors.white, fontWeight: FontWeight.w400),)),
      ).show(context);
  }

  _showFailureMessage (String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showGroupDetails(
    BuildContext context, 
    SocialGroup group, 
    List<Contact> members, 
    ApiService apiService, 
    {required ThemeProvider themeProvider}
  ) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: theme.scaffoldBackgroundColor,
          ),
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                      child: Text(group.name[0], style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans')),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((group.name), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                          Text(group.description, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: themeProvider.getTextPrimaryColor(context)),
                      onPressed: () => _showEditGroupDialog(context, group, apiService, () {
                        setState(() {});
                      }, themeProvider: themeProvider),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(context, group, apiService, themeProvider, false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Contacts', '${members.length}', themeProvider: themeProvider),
                    _buildStatItem('Frequency', FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period), themeProvider: themeProvider),
                    _buildStatItem('Last Engaged', _formatDate(group.lastInteraction), themeProvider: themeProvider),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GROUP CONTACTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                    if (members.isNotEmpty)
                    PopupMenuButton<String>(
                      icon: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                          SizedBox(width: 4),
                          Text('Add More', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans', fontWeight: FontWeight.w600)),
                        ],
                      ),
                      onSelected: (String value) async {
                        Navigator.pop(modalContext); // Close the bottom sheet first
                        
                        if (value == 'import') {
                          // Navigate to import contacts screen with the pre-selected group
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImportContactsScreen(
                                groups: [group],
                                preSelectedGroup: group,
                              ),
                            ),
                          );
                          
                          if (result != null && result is List<Contact>) {
                            // Refresh the group details if contacts were imported
                            setState(() {});
                          }
                        } else if (value == 'existing') {
                          Navigator.pushNamed(context, '/contacts', arguments: {
                            'action': 'add_to_group',
                            'contacts': allContacts, 
                            'groupId': group.id,
                            'groupName': group.name,
                            'groupPeriod': group.period,
                            'groupFrequency': group.frequency,
                            'groupFrequencyDisplay': FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                          });
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'import',
                          child: Row(
                            children: [
                              Icon(Icons.import_contacts, size: 20),
                              SizedBox(width: 8),
                              Text('Import New Contacts'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'existing',
                          child: Row(
                            children: [
                              Icon(Icons.group_add, size: 20),
                              SizedBox(width: 8),
                              Text('Add Existing Contacts'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 48, color: themeProvider.getTextSecondaryColor(context)),
                            const SizedBox(height: 16),
                            Text('No members in this group', style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                            const SizedBox(height: 16),
                            
                            // Add Member Button with Popup Menu
                            PopupMenuButton<String>(
                              onSelected: (String value) async {
                                Navigator.pop(modalContext); // Close the bottom sheet first
                                
                                if (value == 'import') {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImportContactsScreen(
                                        groups: [group],
                                        preSelectedGroup: group,
                                      ),
                                    ),
                                  );
                                  
                                  if (result != null && result is List<Contact>) {
                                    setState(() {});
                                  }
                                } else if (value == 'existing') {
                                  Navigator.pushNamed(context, '/contacts', arguments: {
                                    'action': 'add_to_group',
                                    'contacts': allContacts, 
                                    'groupId': group.id,
                                    'groupName': group.name,
                                    'groupPeriod': group.period,
                                    'groupFrequency': group.frequency,
                                    'groupFrequencyDisplay': FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 20, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ADD MEMBERS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'OpenSans',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'import',
                                  child: Row(
                                    children: [
                                      Icon(Icons.import_contacts, size: 20, color: Color(0xff3CB3E9)),
                                      SizedBox(width: 12),
                                      Text(
                                        'Import New Contacts',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'existing',
                                  child: Row(
                                    children: [
                                      Icon(Icons.group_add, size: 20, color: Color(0xff3CB3E9)),
                                      SizedBox(width: 12),
                                      Text(
                                        'Add Existing Contacts',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final contact = members[index];
                          return Container(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: themeProvider.isDarkMode ? AppTheme.darkSurfaceVariant : Colors.transparent,
                                backgroundImage: contact.imageUrl.isNotEmpty
                                    ? NetworkImage(contact.imageUrl)
                                    : AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png') as ImageProvider,
                                child: contact.imageUrl.isEmpty
                                    ? Text(
                                        contact.name.isNotEmpty ? _getContactInitials(contact.name).toUpperCase() : '?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'OpenSans',
                                          fontSize: 16,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text((contact.name), style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                              subtitle: Text(contact.connectionType, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  // Close the bottom sheet first
                                  Navigator.pop(modalContext);
                                  
                                  // Use a small delay to ensure bottom sheet is closed
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    if (context.mounted) {
                                      _showRemoveContactOptions(
                                        context: context,
                                        contact: contact,
                                        currentGroup: group,
                                        allGroups: allGroups,
                                        apiService: apiService,
                                        themeProvider: themeProvider,
                                        onSuccess: (message) {
                                          _showSuccessMessage(message);
                                        },
                                        onError: (error) {
                                          // Show error message from parent context
                                          _showFailureMessage(error);
                                        },
                                      );
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                Navigator.pop(modalContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ContactDetailScreen(contact: contact),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
    
  void _showRemoveContactOptions({
    required BuildContext context,
    required Contact contact,
    required SocialGroup currentGroup,
    required List<SocialGroup> allGroups,
    required ApiService apiService,
    required ThemeProvider themeProvider,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) {
    final theme = Theme.of(context);
    final otherGroups = allGroups.where((g) => g.id != currentGroup.id).toList();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text(
          'Remove from Group',
          style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans'),
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a group to move ${contact.name} to.',
                style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans', fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (otherGroups.isNotEmpty) ...[
                ...otherGroups.map((g) {
                  return ListTile(
                    leading: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(int.parse(g.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(g.name, style: TextStyle(fontFamily: 'OpenSans', fontSize: 16, fontWeight: FontWeight.w500),),
                    onTap: () async {
                      // Close the dialog
                      Navigator.pop(dialogContext);
                      
                      try {
                        // Update contact with new group
                        final updatedContact = contact.copyWith(
                          connectionType: g.name,
                          period: g.period,
                          frequency: g.frequency,
                        );
                        await apiService.updateContact(updatedContact);
                        
                        // Update group member counts
                        final updatedOldGroup = currentGroup.copyWith(
                          memberIds: List.from(currentGroup.memberIds)..remove(contact.id),
                          memberCount: currentGroup.memberCount - 1,
                        );
                        await apiService.updateGroup(updatedOldGroup);
                        
                        final updatedNewGroup = g.copyWith(
                          memberIds: [...g.memberIds, contact.id],
                          memberCount: g.memberCount + 1,
                        );
                        await apiService.updateGroup(updatedNewGroup);
                        
                        // Call success callback
                        onSuccess('${contact.name} moved to ${g.name}');
                        
                        // Refresh the UI
                        setState(() {});
                        
                      } catch (e) {
                        onError(e.toString());
                      }
                    },
                  );
                }).toList(),
                const Divider(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
    
  Widget _buildStatItem(String label, String value, {required ThemeProvider themeProvider}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: themeProvider.getTextSecondaryColor(context), fontWeight: FontWeight.w600, fontFamily: 'OpenSans')),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7600) return 'N/A';
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    
    return '${(difference.inDays / 30).floor()}mo ago';
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

  int getRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return (hash.abs() % 6) + 1;
  }
}
import 'dart:async';

// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/main.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
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
  bool showBottomModal = false;
  GlobalKey<ScaffoldState> _modalScaffoldKey = GlobalKey<ScaffoldState>();
  
  // Add Completer for modal management
  // Completer<void>? _modalCompleter;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    _groupsStream = apiService.getGroupsStream().handleError((error) {
      //print('Error in groups stream: $error');
      return <SocialGroup>[];
    });
    
    _nudgesStream = apiService.getNudgesStream().handleError((error) {
      //print('Error in nudges stream: $error');
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text('Delete Group', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete the "${group.name}" group?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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
                        );
                        
                        // Show success message after all navigation is complete
                        if (context.mounted) {
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
                    showBottomModal = false;
                  });
                  
                }
                
              } catch (e) {
                if (context.mounted) {
                  _showFailureMessage('Error deleting group: $e');
                  setState(() {
                    showBottomModal = false;
                  });
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
        ],
      ),
    );
  }

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
            color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
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
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The "${deletedGroup.name}" group is being deleted. Please assign each contact to a new group.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
                        backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surfaceContainerLow,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${contactSelections.values.where((s) => s != null).length}/${affectedContacts.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
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
                                ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                : Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.5)
                              : themeProvider.isDarkMode 
                                  ? AppColors.darkSurfaceContainerHighest 
                                  : Theme.of(context).colorScheme.surfaceContainerLowest,
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
                                  backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
                                  backgroundImage: contact.imageUrl.isNotEmpty
                                      ? NetworkImage(contact.imageUrl)
                                      : AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png') as ImageProvider,
                                  child: contact.imageUrl.isEmpty
                                      ? Text(
                                          contact.name.isNotEmpty ? _getContactInitials(contact.name).toUpperCase() : '?',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
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
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: themeProvider.isDarkMode 
                                      ? AppColors.darkSurfaceContainerHighest 
                                      : Theme.of(context).colorScheme.surfaceContainerLowest,
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
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person_outline,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.outline,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'No group (unassigned)',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.outline,
                                                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
                            // Flushbar(
                            //   padding: EdgeInsets.all(10), 
                            //   borderRadius: BorderRadius.zero, 
                            //   duration: Duration(seconds: 2),
                            //   backgroundColor: Theme.of(context).colorScheme.tertiary,
                            //   flushbarPosition: FlushbarPosition.TOP, 
                            //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                            //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                            //   messageText: Center(
                            //     child: Text( 
                            //       'Please assign all ${unassignedContacts.length} contact${unassignedContacts.length > 1 ? 's' : ''} to a group', 
                            //       style: TextStyle(
                            //         fontFamily: GoogleFonts.beVietnamPro().fontFamily, 
                            //         fontSize: 14,
                            //         color: Theme.of(context).colorScheme.onSurface, 
                            //         fontWeight: FontWeight.w400
                            //       ),
                            //     ),
                            //   ),
                            // ).show(context);

                            TopMessageService().showMessage(
                              context: context,
                              message: 'Please assign all ${unassignedContacts.length} contact${unassignedContacts.length > 1 ? 's' : ''} to a group',
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              icon: Icons.info,
                            );
                          } else {
                            Navigator.pop(navigatorKey.currentContext!, contactSelections);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Apply Changes',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
    } catch (e) {
      rethrow;
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
        _initializeStreams();
      });
      
      //print('Groups reordered successfully');
    } catch (e) {
      //print('Error reordering groups: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error reordering groups: $e')),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'Error reordering groups: $e',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: Text('Please log in to view groups', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily))),
      );
    }

    return StreamProvider<List<Contact>>.value(
      value: apiService.getContactsStream().handleError((error) {
        //print('Error in contacts stream: $error');
        return <Contact>[];
      }),
      initialData: const [],
      child: StreamProvider<List<Nudge>>.value(
        value: _nudgesStream ?? Stream.value([]),
        initialData: const [],
        child: Consumer2<List<Contact>, List<Nudge>>(
          builder: (context, contacts, nudges, child) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: widget.showAppBar 
                  ? AppBar(
                      title: Text('Social Groups', style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22)),
                      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.surfaceContainerLowest),
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
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
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.onSurface, width: 1),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: GoogleFonts.beVietnamPro().fontFamily
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
                            slivers: [
                              // Sliver App Bar with disappearing effect
                              SliverAppBar(
                                title: Text(
                                  'Social Groups',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22)
                                ),
                                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                        foregroundColor: theme.colorScheme.primary,
                                        side: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.onSurface, width: 1),
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
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: GoogleFonts.beVietnamPro().fontFamily
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
                                                  shadowColor: AppColors.lightPrimary.withOpacity(0.3),
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
                              style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22)
                              ),
                              centerTitle: false,
                              leading: IconButton(
                                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                                onPressed: () => Navigator.pop(context),
                              ),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                            body: CustomScrollView(
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                // Groups List - Using ReorderableListView inside a SliverToBoxAdapter
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _isReordering 
                                        ? Center(child: CircularProgressIndicator(color: AppColors.lightPrimary))
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
                                                    shadowColor: AppColors.lightPrimary.withOpacity(0.3),
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
                      numberOfParticles: 20,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: [
                        AppColors.success,
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.tertiary,
                        AppColors.warning,
                        Theme.of(context).colorScheme.primary
                      ],
                    ),
                  ),
                ],
              ),
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
          onTap: () {
            setState(() {
              showBottomModal = true;
              _showGroupDetails(context, group, members, apiService, themeProvider: themeProvider);
            });
          },
          onDoubleTap: () => _showDeleteConfirmation(context, group, apiService, themeProvider, true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Group icon — emoji if set, otherwise fallback icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: group.emoji.isNotEmpty
                        ? group.emoji.startsWith('__icon_')
                            ? Icon(
                                _getGroupIconByKey(group.emoji.substring(7)),
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 24,
                              )
                            : Text(group.emoji,
                                style: const TextStyle(fontSize: 24))
                        : Icon(
                            _getGroupIcon(group.name),
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: GoogleFonts.beVietnamPro().fontFamily
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${members.length} members',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w300,
                              fontFamily: GoogleFonts.beVietnamPro().fontFamily
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cardColor,
                            fontFamily: GoogleFonts.beVietnamPro().fontFamily
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          Icon(Icons.error_outline, size: 64, color: Color.fromARGB(255, 206, 37, 85)),
          const SizedBox(height: 16),
          Text('Oops! Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _initializeStreams()),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Try Again', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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
            baseColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.surfaceContainerHigh,
            highlightColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
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
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/empty_groups.png', width: 200, height: 200),
            const SizedBox(height: 24),
            Text('No Groups Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Create your first group to organize your contacts and stay connected',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showCreateGroupDialog(context, apiService, themeProvider: themeProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text('Create Your First Group', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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

  IconData _getGroupIconByKey(String key) {
    switch (key) {
      case 'family':    return Icons.family_restroom;
      case 'friend':    return Icons.people;
      case 'colleague': return Icons.work;
      case 'work':      return Icons.work;
      case 'client':    return Icons.business_center;
      case 'mentor':    return Icons.school;
      default:          return Icons.group;
    }
  }

  externalRefresh() async {
    setState(() => _initializeStreams());
    await Future.delayed(const Duration(seconds: 1));
  }

void _showCreateGroupDialog(BuildContext context, ApiService apiService, {required ThemeProvider themeProvider}) {
  final nameController        = TextEditingController();
  final descriptionController = TextEditingController();
  String _selectedFrequency = 'Monthly';
  String period    = 'Monthly';
  int    frequency = 1;
  String selectedColor = '#751FE7';   // default: brand purple
  String selectedEmoji = '';          // empty = use icon picker
  IconData? selectedIconData;         // null = use emoji

  // Built-in icon options with display labels
  final List<Map<String, dynamic>> iconOptions = [
    {'icon': Icons.family_restroom, 'label': 'Family',    'key': 'family'},
    {'icon': Icons.people,          'label': 'Friends',   'key': 'friend'},
    {'icon': Icons.work,            'label': 'Colleague', 'key': 'colleague'},
    {'icon': Icons.business_center, 'label': 'Client',    'key': 'client'},
    {'icon': Icons.school,          'label': 'Mentor',    'key': 'mentor'},
  ];

  // Emoji options matching the mockup
  final List<String> emojiOptions = [
    '🏠', '👟', '🍕', '✈️',
    '🎵', '⚽', '🌿', '📚', '💡', '🎯',
    '🏋️', '🎮', '🐾', '🌍',
  ];

  // Palette matching the mockup
  final List<String> colorOptions = [
    '#751FE7', // purple  (brand)
    '#1A6E8C', // teal
    '#8B2252', // maroon
    '#C0252D', // crimson
    '#E07830', // orange
    '#00A86B', // emerald
    '#3B6FD4', // blue
    '#E05A7A', // pink
    '#D4A017', // amber
    '#00AEAE', // cyan
  ];

  // var width = MediaQuery.of(context).size.width;

  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isDark  = themeProvider.isDarkMode;
          final scheme  = Theme.of(context).colorScheme;
          final selectedColorValue = Color(
            int.parse(selectedColor.substring(1), radix: 16) + 0xFF000000,
          );

          // Card colours — white in light, deep surface in dark
          final cardBg   = isDark ? AppColors.darkSurfaceContainerLow   : Colors.white;
          final fieldBg  = isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFF0EDE9);
          final labelCol = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
          final hintCol  = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.14),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                  // Purple glow under CTA button area
                  BoxShadow(
                    color: const Color(0xFF751FE7).withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Header ────────────────────────────────────────────
                    Text(
                      'Create New Group',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: labelCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bring your people together and set a rhythm for staying in touch.',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: hintCol,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Group Name ────────────────────────────────────────
                    Text('Group Name',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: labelCol)),
                    const SizedBox(height: 8),
                    _DialogTextField(
                      controller: nameController,
                      hintText: 'e.g. College Roomies',
                      fieldBg: fieldBg,
                      labelCol: labelCol,
                      hintCol: hintCol,
                      scheme: scheme,
                    ),
                    const SizedBox(height: 18),

                    // ── Contact Frequency ─────────────────────────────────
                    Text('Contact Frequency',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: labelCol)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFrequency,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: hintCol, size: 22),
                          dropdownColor: isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : Colors.white,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 15, color: labelCol),
                          onChanged: (v) {
                            if (v == null) return;
                            final data = FrequencyPeriodMapper.getFrequencyPeriod(v);
                            setState(() {
                              _selectedFrequency = v;
                              frequency = data['frequency'] as int;
                              period    = data['period']    as String;
                            });
                          },
                          items: FrequencyPeriodMapper.frequencyMapping.keys
                              .map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k,
                                        style: GoogleFonts.beVietnamPro(
                                            color: labelCol)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Group Icon / Emoji ────────────────────────────────
                    Text('Group Icon',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: labelCol)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Built-in icons ──
                          Text('Icons',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: hintCol)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: iconOptions.map((opt) {
                              final icon   = opt['icon'] as IconData;
                              final key    = opt['key']  as String;
                              final label  = opt['label'] as String;
                              // Taken if any existing group name matches key
                              final isTaken = allGroups.any((g) =>
                                g.name.toLowerCase().contains(key));
                              final isSelected = selectedIconData == icon && selectedEmoji.isEmpty;
                              return GestureDetector(
                                onTap: isTaken ? null : () => setState(() {
                                  selectedIconData = icon;
                                  selectedEmoji    = '';
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedColorValue.withOpacity(0.18)
                                        : isTaken
                                            ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(color: selectedColorValue, width: 2)
                                        : Border.all(color: Colors.transparent),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(icon,
                                            size: 22,
                                            color: isTaken
                                                ? hintCol.withOpacity(0.35)
                                                : isSelected
                                                    ? selectedColorValue
                                                    : labelCol),
                                          const SizedBox(height: 2),
                                          Text(label,
                                            style: GoogleFonts.beVietnamPro(
                                              fontSize: 8,
                                              color: isTaken
                                                  ? hintCol.withOpacity(0.35)
                                                  : isSelected
                                                      ? selectedColorValue
                                                      : hintCol)),
                                        ],
                                      ),
                                      if (isTaken)
                                        Icon(Icons.block,
                                          size: 14,
                                          color: hintCol.withOpacity(0.4)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 10),
                          Divider(color: hintCol.withOpacity(0.15), height: 1),
                          const SizedBox(height: 10),

                          // ── Emoji ──
                          Text('Emoji',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: hintCol)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: emojiOptions.map((emoji) {
                              final isSelected = selectedEmoji == emoji;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  selectedEmoji    = emoji;
                                  selectedIconData = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedColorValue.withOpacity(0.18)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: selectedColorValue, width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(emoji,
                                        style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Group Color ───────────────────────────────────────
                    Text('Group Color',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: labelCol)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colorOptions.map((hex) {
                        final col = Color(
                            int.parse(hex.substring(1), radix: 16) + 0xFF000000);
                        final isSelected = selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      width: 2.5)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(
                                      color: col.withOpacity(0.45),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // ── Description ───────────────────────────────────────
                    Text('Description',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: labelCol)),
                    const SizedBox(height: 8),
                    _DialogTextField(
                      controller: descriptionController,
                      hintText: 'Tell us what this group is about...',
                      fieldBg: fieldBg,
                      labelCol: labelCol,
                      hintCol: hintCol,
                      scheme: scheme,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),

                    // ── Buttons ───────────────────────────────────────────
                   // Gradient "Create Group" pill button
                    GestureDetector(
                      onTap: () async {
                        if (nameController.text.trim().isEmpty) return;

                        final currentGroups = List<SocialGroup>.from(allGroups);
                        for (int i = 0; i < currentGroups.length; i++) {
                          currentGroups[i] =
                              currentGroups[i].copyWith(orderIndex: i + 1);
                        }

                        final newGroup = SocialGroup(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          period: period,
                          frequency: frequency,
                          memberIds: [],
                          memberCount: 0,
                          lastInteraction: DateTime.now(),
                          colorCode: selectedColor,
                          // Store emoji if chosen, otherwise encode the icon key
                          emoji: selectedEmoji.isNotEmpty
                              ? selectedEmoji
                              : selectedIconData != null
                                  ? '__icon_${iconOptions.firstWhere((o) => o['icon'] == selectedIconData, orElse: () => {'key': 'group'})['key']}'
                                  : '',
                          birthdayNudgesEnabled: true,
                          anniversaryNudgesEnabled: true,
                          orderIndex: 0,
                        );

                        setState(() {
                          allGroups = [newGroup, ...currentGroups];
                        });

                        try {
                          await apiService.addGroup(newGroup);
                          Navigator.of(context).pop();
                        } catch (e) {
                          TopMessageService().showMessage(
                            context: context,
                            message: 'Error creating group: $e',
                            backgroundColor:
                                Theme.of(context).colorScheme.tertiary,
                            icon: Icons.error,
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF751FE7).withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Create Group',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                     Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 15,
                            color: hintCol,
                            fontWeight: FontWeight.w500,
                          )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
  // Pre-select: decode __icon_ key → IconData, plain emoji stays as emoji.
  // If neither is set, infer from the group name (same logic as _getGroupIcon).
  String selectedEmoji = group.emoji.startsWith('__icon_') ? '' : group.emoji;

  // Built-in icon options — only the original 5 that _getGroupIcon recognises
  final List<Map<String, dynamic>> iconOptions = [
    {'icon': Icons.family_restroom, 'label': 'Family',  'key': 'family'},
    {'icon': Icons.people,          'label': 'Friends', 'key': 'friend'},
    {'icon': Icons.work,            'label': 'Colleague',    'key': 'colleague'},
    {'icon': Icons.business_center, 'label': 'Client',  'key': 'client'},
    {'icon': Icons.school,          'label': 'Mentor',  'key': 'mentor'},
  ];

  IconData? selectedIconData;
  if (group.emoji.startsWith('__icon_')) {
    // Explicitly stored icon key — restore it
    final key = group.emoji.substring(7);
    final match = iconOptions.where((o) => o['key'] == key).toList();
    if (match.isNotEmpty) selectedIconData = match.first['icon'] as IconData;
  } else if (group.emoji.isEmpty) {
    // No emoji — infer from group name the same way _getGroupIcon does
    final n = group.name.toLowerCase();
    if (n.contains('family'))                               selectedIconData = Icons.family_restroom;
    else if (n.contains('friend'))                          selectedIconData = Icons.people;
    else if (n.contains('work') || n.contains('colleague')) selectedIconData = Icons.work;
    else if (n.contains('client'))                          selectedIconData = Icons.business_center;
    else if (n.contains('mentor'))                          selectedIconData = Icons.school;
    // else: group uses the generic Icons.group fallback — leave selectedIconData null
  }

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
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            title: Text('EDIT GROUP', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
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
                        child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Contact Frequency',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? AppColors.darkSurfaceContainerHighest : Theme.of(context).colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                        borderRadius: BorderRadius.circular(14)
                      ),
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Icon / Emoji Picker ───────────────────────────────
                  Text('Group Icon',
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // ── 5 built-in icons ──────────────────────────
                        ...iconOptions.map((opt) {
                          final icon   = opt['icon']  as IconData;
                          final key    = opt['key']   as String;
                          final label  = opt['label'] as String;
                          final selCol = Color(
                            int.parse(selectedColor.substring(1), radix: 16) + 0xFF000000);
                          // Blocked if another group (not this one) uses this key
                          final isTaken = allGroups.any((g) =>
                            g.id != group.id &&
                            g.name.toLowerCase().contains(key));
                          final isSelected = selectedIconData == icon && selectedEmoji.isEmpty;
                          return GestureDetector(
                            onTap: isTaken ? null : () => setState(() {
                              selectedIconData = icon;
                              selectedEmoji    = '';
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selCol.withOpacity(0.18)
                                    : isTaken
                                        ? (themeProvider.isDarkMode
                                            ? Colors.white10
                                            : Colors.black.withOpacity(0.05))
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: selCol, width: 2)
                                    : Border.all(color: Colors.transparent),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(icon,
                                        size: 22,
                                        color: isTaken
                                            ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)
                                            : isSelected
                                                ? selCol
                                                : Theme.of(context).colorScheme.onSurface),
                                      const SizedBox(height: 2),
                                      Text(label,
                                        style: GoogleFonts.beVietnamPro(
                                          fontSize: 8,
                                          color: isTaken
                                              ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)
                                              : isSelected
                                                  ? selCol
                                                  : Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                  if (isTaken)
                                    Positioned(
                                      top: 4, right: 4,
                                      child: Icon(Icons.block,
                                        size: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.45)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // ── Emoji options ─────────────────────────────
                        ...['🏠','👟','🍕','✈️','🎵','⚽','🌿','📚','💡','🎯','🏋️','🎮','🐾','🌍']
                            .map((emoji) {
                          final isSel = selectedEmoji == emoji;
                          final selCol = Color(
                            int.parse(selectedColor.substring(1), radix: 16) + 0xFF000000);
                          return GestureDetector(
                            onTap: () => setState(() {
                              selectedEmoji    = emoji;
                              selectedIconData = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: isSel ? selCol.withOpacity(0.18) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSel ? Border.all(color: selCol, width: 2) : null,
                              ),
                              child: Center(child: Text(emoji,
                                  style: const TextStyle(fontSize: 22))),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('Date Nudges:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send a nudge for birthdays',
                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.5,
                        child: Switch(
                          inactiveThumbColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                          inactiveTrackColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.outline,
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
                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.5,
                        child: Switch(
                          inactiveThumbColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                          inactiveTrackColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.outline,
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
                  Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) 
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
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {

                    String previousName = group.name;
                    final updatedGroup = group.copyWith(
                      name: nameController.text,
                      description: descriptionController.text,
                      period: period,
                      frequency: frequency,
                      colorCode: selectedColor,
                      emoji: selectedEmoji.isNotEmpty
                          ? selectedEmoji
                          : selectedIconData != null
                              ? '__icon_${iconOptions.firstWhere((o) => o['icon'] == selectedIconData, orElse: () => {'key': 'group'})['key']}'
                              : '',
                      birthdayNudgesEnabled: birthdayNudgesEnabled,
                      anniversaryNudgesEnabled: anniversaryNudgesEnabled,
                    );
                    
                    try {
                      final currentGroups = await apiService.getGroupsStream().first;
                      final updatedGroups = currentGroups.map((g) => 
                        g.id == group.id ? updatedGroup : g
                      ).toList();
                      
                      await apiService.updateGroups(updatedGroups);
                      final contacts = await apiService.getContactsStream().first;
                      apiService.rescheduleGroupContactNudges(updatedGroup, contacts, previousName);
                      onUpdate();
                      Navigator.of(context).pop();
                      
                    //  Flushbar(
                    //     padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                    //     flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                    //     forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                    //     messageText: Center(
                    //         child: Text( 'Updated "${updatedGroup.name}" group!', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
                    //             color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
                    //   ).show(context);
                     TopMessageService().showMessage(
                        context: context,
                        message: 'Updated "${updatedGroup.name}" group!',
                        backgroundColor: AppColors.success,
                        icon: Icons.check,
                      );
                    } catch (e) {
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('Error updating group: $e')),
                      // );
                       TopMessageService().showMessage(
                        context: context,
                        message: 'Error updating group: $e',
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        icon: Icons.error,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
              ),
            ],
          );
        },
      );
    },
  );
}

  _showSuccessMessage(String message) {
    // Flushbar(
    //     padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
    //     flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //     forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
    //     backgroundColor: AppColors.success,
    //     messageText: Center(
    //         child: Text( message, style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
    //             color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
    //   ).show(context);
     TopMessageService().showMessage(
        context: context,
        message: message,
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
  }

  _showFailureMessage (String error) {
    TopMessageService().showMessage(
      context: context,
      message: error,
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      icon: Icons.error,
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
    if (!showBottomModal){
      return;
    }
    
    // Reset completer
    // _modalCompleter = Completer<void>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (modalContext) {
        return Container(
            key: _modalScaffoldKey,
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
                  // Center(
                  //   child: Container(
                  //     width: 60,
                  //     height: 5,
                  //     decoration: BoxDecoration(
                  //       color: Colors.transparent,
                  //       borderRadius: BorderRadius.circular(14),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                        child: Text(group.name[0], style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((group.name), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                            Text(group.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditGroupDialog(context, group, apiService, () {
                          setState(() {});
                        }, themeProvider: themeProvider);
                        } 
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.delete, color: Color.fromARGB(255, 206, 37, 85)),
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(context, group, apiService, themeProvider, false);
                        },
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
                      Text('GROUP CONTACTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                      if (members.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                            SizedBox(width: 4),
                            Text('Add More', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontWeight: FontWeight.w600)),
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
                            
                            if (result != null && result.isNotEmpty) {
                              // Play confetti when contacts are successfully imported
                              _confettiController.play();
                              
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
                              Icon(Icons.group_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text('No members in this group', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 20, color: Theme.of(context).colorScheme.onInverseSurface),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ADD MEMBERS',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onInverseSurface,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onInverseSurface, size: 20),
                                    ],
                                  ),
                                ),
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'import',
                                    child: Row(
                                      children: [
                                        Icon(Icons.import_contacts, size: 20, color: AppColors.lightPrimary),
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
                                        Icon(Icons.group_add, size: 20, color: AppColors.lightPrimary),
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
                                leading: ClipOval(
                                  child: SizedBox(
                                    width: 48, height: 48,
                                    child: contact.imageUrl.isNotEmpty
                                        ? Image.network(
                                            contact.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _avatarFallback(contact, themeProvider.isDarkMode),
                                          )
                                        : _avatarFallback(contact, themeProvider.isDarkMode),
                                  ),
                                ),
                                title: Text((contact.name), style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                                subtitle: Text(contact.connectionType, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                                trailing: IconButton(
                                  icon: Icon(Icons.remove_circle, color: Color.fromARGB(255, 206, 37, 85)),
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
    }).then((_) {
      setState(() {
        showBottomModal = false;
        // _modalCompleter = null;
      });
    });
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
    SocialGroup? selectedGroup;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Move to Another Group',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              content: Container(
                width: double.maxFinite,
               constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Contact identity card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: contact.imageUrl.isNotEmpty
                                ? NetworkImage(contact.imageUrl)
                                : null,
                            child: contact.imageUrl.isEmpty
                                ? Text(
                                    _getContactInitials(contact.name)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                    fontFamily:
                                        GoogleFonts.beVietnamPro().fontFamily,
                                  ),
                                ),
                                Text(
                                  'Currently in: ${currentGroup.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFamily:
                                        GoogleFonts.beVietnamPro().fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Select a group to move them to:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Groups list
                    if (otherGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No other groups available.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: otherGroups.length,
                          itemBuilder: (_, index) {
                            final group = otherGroups[index];
                            final isSelected = selectedGroup?.id == group.id;
                            final groupColor = Color(
                                int.parse(
                                    group.colorCode.substring(1, 7),
                                    radix: 16) +
                                    0xFF000000);

                            return GestureDetector(
                              onTap: () =>
                                  setDialogState(() => selectedGroup = group),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                          .withOpacity(0.10)
                                      : themeProvider.isDarkMode
                                          ? theme.colorScheme
                                              .surfaceContainerHighest
                                          : theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : themeProvider.isDarkMode
                                            ? AppColors
                                                .darkSurfaceContainerHighest
                                            : theme.colorScheme
                                                .surfaceContainerLowest,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Group colour + icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: groupColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getGroupIcon(group.name),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Group name + frequency
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onSurface,
                                              fontFamily: GoogleFonts
                                                  .beVietnamPro()
                                                  .fontFamily,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            FrequencyPeriodMapper
                                                .getConversationalChoice(
                                                    group.frequency,
                                                    group.period),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: groupColor,
                                              fontFamily: GoogleFonts
                                                  .beVietnamPro()
                                                  .fontFamily,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Check icon when selected
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),
                    Text(
                      '${contact.name} will inherit the frequency settings of the new group.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedGroup == null
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          try {
                            final updatedContact = contact.copyWith(
                              connectionType: selectedGroup!.name,
                              period: selectedGroup!.period,
                              frequency: selectedGroup!.frequency,
                            );
                            await apiService.updateContact(updatedContact);

                            final updatedOldGroup = currentGroup.copyWith(
                              memberIds: List.from(currentGroup.memberIds)
                                ..remove(contact.id),
                              memberCount: currentGroup.memberCount - 1,
                            );
                            await apiService.updateGroup(updatedOldGroup);

                            final updatedNewGroup = selectedGroup!.copyWith(
                              memberIds: [
                                ...selectedGroup!.memberIds,
                                contact.id
                              ],
                              memberCount: selectedGroup!.memberCount + 1,
                            );
                            await apiService.updateGroup(updatedNewGroup);

                            onSuccess(
                                '${contact.name} moved to ${selectedGroup!.name}');
                            setState(() {});
                          } catch (e) {
                            onError(e.toString());
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    'Move',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
    
  Widget _buildStatItem(String label, String value, {required ThemeProvider themeProvider}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
      ],
    );
  }

  Widget _avatarFallback(contact, bool isDark) {
    final initials = contact.name.isNotEmpty
        ? _getContactInitials(contact.name).toUpperCase()
        : '?';
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/contact-icons/${getRandomIndex(contact.id)}.png',
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black.withOpacity(isDark ? 0.38 : 0.20),
        ),
        Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
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


// ── Reusable text field for the create/edit dialogs ──────────────────────────
class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fieldBg;
  final Color labelCol;
  final Color hintCol;
  final ColorScheme scheme;
  final int maxLines;

  const _DialogTextField({
    required this.controller,
    required this.hintText,
    required this.fieldBg,
    required this.labelCol,
    required this.hintCol,
    required this.scheme,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.beVietnamPro(fontSize: 15, color: labelCol),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.beVietnamPro(fontSize: 14, color: hintCol),
        filled: true,
        fillColor: fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}


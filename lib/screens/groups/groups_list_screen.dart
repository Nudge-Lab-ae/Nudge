import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
// import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/auth_service.dart';
import '../../models/social_group.dart';
import '../../models/contact.dart';
import '../../models/nudge.dart';

enum SortOption { name, memberCount, frequency }

class GroupsListScreen extends StatefulWidget {
  final bool showAppBar;
  const GroupsListScreen({super.key, required this.showAppBar});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Stream<List<SocialGroup>>? _groupsStream;
  Stream<List<Nudge>>? _nudgesStream;
  List allContacts = [];
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  SortOption _currentSortOption = SortOption.name;
  bool _sortAscending = true;

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
    super.dispose();
  }

  // Calculate interaction progress for a group
  double _calculateGroupProgress(List<Contact> groupMembers, List<Nudge> allNudges) {
    if (groupMembers.isEmpty) return 0.0;

    double totalProgress = 0.0;
    int membersWithNudges = 0;

    for (final member in groupMembers) {
      // Get nudges for this specific contact
      final memberNudges = allNudges.where((nudge) => nudge.contactId == member.id).toList();
      
      if (memberNudges.isNotEmpty) {
        final totalNudges = memberNudges.length;
        final completedNudges = memberNudges.where((nudge) => nudge.isCompleted).length;
        final memberProgress = totalNudges > 0 ? completedNudges / totalNudges : 0.0;
        totalProgress += memberProgress;
        membersWithNudges++;
      }
    }

    // If no members have nudges, return 0
    if (membersWithNudges == 0) return 0.0;

    // Return average progress across members
    return totalProgress / membersWithNudges;
  }

  List<SocialGroup> _sortGroups(List<SocialGroup> groups) {
    List<SocialGroup> sortedGroups = List.from(groups);
    
    switch (_currentSortOption) {
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

  // Add this method to show delete confirmation
  void _showDeleteConfirmation(BuildContext context, SocialGroup group, ApiService apiService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete the "${group.name}" group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Get all contacts in this group
                final contacts = await apiService.getContactsStream().first;
                final groupContacts = contacts.where((c) => c.connectionType == group.name).toList();
                
                // Update contacts to remove this group assignment
                for (var contact in groupContacts) {
                  final updatedContact = contact.copyWith(
                    connectionType: '',
                    period: 'Monthly',
                    frequency: 2,
                  );
                  await apiService.updateContact(updatedContact);
                }
                
                // Delete the group
                final updatedGroups = await apiService.getGroupsStream().first;
                updatedGroups.removeWhere((g) => g.id == group.id);
                await apiService.updateGroups(updatedGroups);
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${group.name}" group')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting group: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view groups')),
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
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: !widget.showAppBar
          ? null
          :AppBar(
            title: Text('Social Groups', style: AppTextStyles.title3.copyWith(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: const Color(0xff3CB3E9),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreateGroupDialog(context, apiService),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Sticky Header Section
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search and Filter Row
                         SizedBox(
                          height: 10,
                        ),
                        Text('Social Groups', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search groups...',
                                      hintStyle: TextStyle(fontWeight: FontWeight.w600),
                                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    onChanged: (value) => setState(() => _searchQuery = value),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.filter_list, color: Colors.blue),
                                onPressed: () => _showFilterOptions(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Optional: Add some summary stats or quick actions here
                      ],
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<List<SocialGroup>>(
                    stream: _groupsStream,
                    builder: (context, groupsSnapshot) {
                      if (groupsSnapshot.hasError) {
                        return _buildErrorState(groupsSnapshot.error.toString());
                      }

                      if (!groupsSnapshot.hasData) {
                        return _buildLoadingState();
                      }

                      final groups = groupsSnapshot.data!;
                      
                      return Consumer<List<Contact>>(
                        builder: (context, contacts, child) {
                          return Consumer<List<Nudge>>(
                            builder: (context, nudges, child) {
                              final sortedGroups = _sortGroups(groups);
                              final filteredGroups = sortedGroups.where((group) {
                                return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                    group.description.toLowerCase().contains(_searchQuery.toLowerCase());
                              }).toList();
                              
                              if (groups.isEmpty) {
                                return _buildEmptyState(apiService);
                              }

                              return RefreshIndicator(
                                onRefresh: () async {
                                  setState(() => _initializeStreams());
                                  await Future.delayed(const Duration(seconds: 1));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 80.0), // Add bottom padding for FAB
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: filteredGroups.length,
                                    itemBuilder: (context, index) {
                                      final group = filteredGroups[index];
                                      final groupMembers = contacts.where((contact) => 
                                        contact.connectionType == group.name || contact.connectionType == group.id
                                        ).toList();
                                      
                                      final progress = _calculateGroupProgress(groupMembers, nudges);
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildGroupCard(context, group, groupMembers, progress, apiService),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                ],
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateGroupDialog(context, apiService),
            backgroundColor: const Color(0xff3CB3E9),
            icon: const Icon(Icons.group_add, color: Colors.white),
            label: const Text('New Group', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Oops! Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _initializeStreams()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3CB3E9),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
Widget _buildLoadingState() {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    itemBuilder: (context, index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    },
  );
}
  Widget _buildEmptyState(ApiService apiService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/empty_groups.png', width: 200, height: 200),
          const SizedBox(height: 24),
          const Text('No Groups Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Create your first group to organize your contacts and stay connected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showCreateGroupDialog(context, apiService),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3CB3E9),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Create Your First Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

Widget _buildGroupCard(BuildContext context, SocialGroup group, List<Contact> members, double progress, ApiService apiService) {
  // Add safety check for color code
  Color cardColor;
  try {
    cardColor = Color(int.parse(group.colorCode.replaceFirst('#', ''), radix: 16) + 0xFF000000);
  } catch (e) {
    cardColor = const Color(0xff3CB3E9); // Default color
  }
  
  // final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  
  return GestureDetector(
    onTap: () => _showGroupDetails(context, group, members, apiService),
    onLongPress: () => _showDeleteConfirmation(context, group, apiService),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Color indicator circle
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
            
            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group name and member count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${members.length} members',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Frequency badge
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
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    group.description.isEmpty ? 'No description' : group.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Chevron icon
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}
 
  // Widget _buildInteractionProgress(double progress, Color textColor) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Interaction Progress',
  //         style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8)),
  //       ),
  //       const SizedBox(height: 4),
  //       LinearProgressIndicator(
  //         value: progress,
  //         backgroundColor: textColor.withOpacity(0.2),
  //         valueColor: AlwaysStoppedAnimation<Color>(textColor),
  //         borderRadius: BorderRadius.circular(4),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(
  //         '${(progress * 100).toInt()}% complete',
  //         style: TextStyle(fontSize: 10, color: textColor),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildEmptyProgress(Color textColor) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //      Container(
  //         height: 40,
  //         decoration: BoxDecoration(
  //           color: Colors.transparent,
  //           borderRadius: BorderRadius.circular(4),
  //         ),
  //         child: Center(
  //           child: Text(
  //             'Add members to track progress',
  //             style: TextStyle(
  //               fontSize: 10,
  //               color: textColor.withOpacity(0.6),
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //       ),
       
  //     ],
  //   );
  // }

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

    void _showFilterOptions(BuildContext context) {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sort Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.sort_by_alpha),
                        title: const Text('Sort by Name'),
                        trailing: _currentSortOption == SortOption.name
                            ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                            : null,
                        onTap: () async{
                          setState(() {
                            if (_currentSortOption == SortOption.name) {
                              _sortAscending = !_sortAscending;
                            } else {
                              _currentSortOption = SortOption.name;
                              _sortAscending = true;
                            }
                          });
                          Navigator.pop(context);
                          externalRefresh();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('Sort by Member Count'),
                        trailing: _currentSortOption == SortOption.memberCount
                            ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                            : null,
                        onTap: () async{
                          setState(() {
                            if (_currentSortOption == SortOption.memberCount) {
                              _sortAscending = !_sortAscending;
                            } else {
                              _currentSortOption = SortOption.memberCount;
                              _sortAscending = true;
                            }
                          });
                          Navigator.pop(context);
                          externalRefresh();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: const Text('Sort by Interaction Frequency'),
                        trailing: _currentSortOption == SortOption.frequency
                            ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                            : null,
                        onTap: () async{
                          setState(() {
                            if (_currentSortOption == SortOption.frequency) {
                              _sortAscending = !_sortAscending;
                            } else {
                              _currentSortOption = SortOption.frequency;
                              _sortAscending = true;
                            }
                          });
                          Navigator.pop(context);
                          externalRefresh();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }

void _showCreateGroupDialog(BuildContext context, ApiService apiService) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  String _selectedFrequencyChoice = 'Monthly'; // Default value
  String period = 'Monthly';
  int frequency = 1;
  String selectedColor = '#2596BE';

  // Frequency options
  // final List<String> frequencyOptions = [
  //   'Every few days',
  //   'Weekly',
  //   'Every 2 weeks', 
  //   'Monthly',
  //   'Quarterly',
  //   'Twice a year',
  //   'Once a year'
  // ];

  // Predefined color options
  final List<String> colorOptions = [
    '#2596BE', // Primary blue
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#45B7D1', // Light blue
    '#F9A826', // Orange
    '#6C5CE7', // Purple
  ];

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New Group', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                       border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                      ),
                       enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                        border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                      ),
                       enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                    ),
                  ),
                  const SizedBox(height: 16),
               DropdownButtonFormField<String>(
                  value: _selectedFrequencyChoice,
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
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Contact Frequency',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                      ),
                       enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                  ),
                ),
                  const SizedBox(height: 16),
                  const Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              ? Border.all(color: Colors.black, width: 2) 
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
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
                      birthdayNudgesEnabled: true, // Default enabled
                      anniversaryNudgesEnabled: true, // Default enabled
                    );
                    
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
                  backgroundColor: const Color(0xff3CB3E9),
                ),
                child: const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showEditGroupDialog(BuildContext context, SocialGroup group, ApiService apiService, VoidCallback onUpdate) {
  final nameController = TextEditingController(text: group.name);
  final descriptionController = TextEditingController(text: group.description);
  String period = group.period;
  int frequency = group.frequency;
  String selectedColor = group.colorCode;
  bool birthdayNudgesEnabled = group.birthdayNudgesEnabled;
  bool anniversaryNudgesEnabled = group.anniversaryNudgesEnabled;
  String _selectedFrequencyChoice = FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period);

  // Frequency options
  // final List<String> frequencyOptions = [
  //   'Every few days',
  //   'Weekly',
  //   'Every 2 weeks', 
  //   'Monthly',
  //   'Quarterly',
  //   'Twice a year',
  //   'Once a year'
  // ];

  // Predefined color options
  final List<String> colorOptions = [
    '#2596BE', // Primary blue
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#45B7D1', // Light blue
    '#F9A826', // Orange
    '#6C5CE7', // Purple
  ];

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Group', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration:  InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                      ),
                       enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                      ),
                       enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                 DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
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
                        child: Text(value),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Contact Frequency',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                      ),
                        enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Nudges Section
                  const SizedBox(height: 16),
                  const Text('Date Nudges:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  const SizedBox(height: 8),
                  
                  // Birthday Nudges Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send a nudge for birthdays',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                     Transform.scale(
                      scale: 0.5,
                      child:  Switch(
                         inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey,
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
                  
                  // Anniversary Nudges Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send a nudge for anniversaries',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                      Transform.scale(
                      scale: 0.5,
                      child: Switch(
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey,
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
                  const Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              ? Border.all(color: Colors.black, width: 2) 
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
                child: const Text('Cancel'),
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
                      // Get current groups
                      final currentGroups = await apiService.getGroupsStream().first;
                      final updatedGroups = currentGroups.map((g) => 
                        g.id == group.id ? updatedGroup : g
                      ).toList();
                      
                      await apiService.updateGroups(updatedGroups);
                      onUpdate();
                      Navigator.of(context).pop();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Updated "${updatedGroup.name}" group')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating group: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3CB3E9),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _showGroupDetails(BuildContext context, SocialGroup group, List<Contact> members, ApiService apiService) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          // var size = MediaQuery.of(context).size;
          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.85,
            child: Scaffold(
            // floatingActionButton: Padding(
            //   padding: EdgeInsets.only(bottom: size.height*0.2),
            //   child: FeedbackFloatingButton(),
            // ),
            body:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                      child: Text(group.name[0], style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(group.description, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _showEditGroupDialog(context, group, apiService, () {
                          // Refresh the details after editing
                          setState(() {});
                        }),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red,),
                        onPressed: () => _showDeleteConfirmation(context, group, apiService),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Group stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Members', '${members.length}'),
                   _buildStatItem('Frequency', FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period)),
                    _buildStatItem('Last Engaged', _formatDate(group.lastInteraction)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Group Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (members.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/contacts', arguments: {
                          'action': 'add_to_group',
                          'contacts': allContacts, 
                          'groupId': group.id,
                          'groupName': group.name,
                          'groupPeriod': group.period,
                          'groupFrequency': group.frequency,
                          'groupFrequencyDisplay': FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                        });
                    },
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 4),
                          Text('Add More'),
                        ],
                      ),
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
                            const Icon(Icons.group_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No members in this group', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/contacts', arguments: {
                                  'action': 'add_to_group',
                                  'groupId': group.id,
                                  'groupName': group.name,
                                  'groupPeriod': group.period,
                                  'groupFrequency': group.frequency
                                });
                              },
                              child: const Text('Add Members', style: TextStyle(color: Color(0xff3CB3E9))),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final contact = members[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: contact.imageUrl.isNotEmpty
                                  ? NetworkImage(contact.imageUrl)
                                  : null,
                              child: contact.imageUrl.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            title: Text(contact.name, style: TextStyle(fontWeight: FontWeight.w600),),
                            subtitle: Text(contact.connectionType),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () async {
                                // Remove member from group
                                final updatedMemberIds = List<String>.from(group.memberIds)..remove(contact.id);
                                final updatedGroup = group.copyWith(
                                  memberIds: updatedMemberIds,
                                  memberCount: updatedMemberIds.length,
                                );
                                final updatedContact = contact;
                                updatedContact.connectionType = 'Contact';
                                print('updated contact is '); print (updatedContact.connectionType);
                                
                                try {
                                  await apiService.updateGroup(updatedGroup);
                                  await apiService.updateContact(updatedContact);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Removed ${contact.name} from ${group.name}')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error removing member: $e')),
                                  );
                                }
                              },
                            ),
                            onTap: () {
                              // Navigate to contact details
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContactDetailScreen(contact: contact),
                                ),
                              );
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          ));
        },
      );
    }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
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
}
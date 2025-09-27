import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/auth_service.dart';
import '../../models/social_group.dart';
import '../../models/contact.dart';

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
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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
                // Search bar with fun design
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(45, 161, 175, 1),
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
                  child: Row(
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
                          )
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
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: filteredGroups.length,
                              itemBuilder: (context, index) {
                                final group = filteredGroups[index];
                                final groupMembers = contacts.where((contact) => 
                                  contact.connectionType == group.name).toList();
                                
                                return _buildGroupCard(context, group, groupMembers, apiService);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            // Confetti animation for when a group is created
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
          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
          icon: const Icon(Icons.group_add, color: Colors.white),
          label: const Text('New Group', style: TextStyle(color: Colors.white)),
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
              backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
              backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Create Your First Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

Widget _buildGroupCard(BuildContext context, SocialGroup group, List<Contact> members, ApiService apiService) {
  // Add safety check for color code
  Color cardColor;
  try {
    cardColor = Color(int.parse(group.colorCode.replaceFirst('#', ''), radix: 16) + 0xFF000000);
  } catch (e) {
    cardColor = const Color.fromRGBO(45, 161, 175, 1); // Default color
  }
  
  final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  
  return GestureDetector(
    onTap: () => _showGroupDetails(context, group, members, apiService),
    onLongPress: () => _showDeleteConfirmation(context, group, apiService),
    child: Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Icon(
              _getGroupIcon(group.name),
              size: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${group.frequency}x/${group.period.substring(0, 1).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  group.description,
                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Members section
                // Row(
                //   children: [
                //     _buildMemberAvatars(members, textColor),
                //     const SizedBox(width: 8),
                   
                //   ],
                // ),
                 Text(
                      '${members.length} members',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                const SizedBox(height: 8),
                // Progress bar for interaction frequency
                _buildInteractionProgress(group, textColor),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  
// Widget _buildMemberAvatars(List<Contact> members, Color textColor) {
//   final displayMembers = members.take(3).toList();
  
//   return SizedBox(
//     width: 80, // Fixed width to prevent overflow
//     height: 32,
//     child: Stack(
//       children: [
//         for (int i = 0; i < displayMembers.length; i++)
//           Positioned(
//             left: i * 20.0,
//             child: Container(
//               width: 28,
//               height: 28,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 border: Border.all(color: textColor, width: 1.5),
//                 shape: BoxShape.circle,
//               ),
//               child: displayMembers[i].imageUrl.isNotEmpty
//                   ? ClipOval(
//                       child: Image.network(
//                         displayMembers[i].imageUrl,
//                         width: 28,
//                         height: 28,
//                         fit: BoxFit.cover,
//                         errorBuilder: (context, error, stackTrace) {
//                           return Icon(Icons.person, size: 16, color: textColor);
//                         },
//                       ),
//                     )
//                   : Icon(Icons.person, size: 16, color: textColor),
//             ),
//           ),
//         if (members.length > 3)
//           Positioned(
//             left: 60.0,
//             child: Container(
//               width: 28,
//               height: 28,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 border: Border.all(color: textColor, width: 1.5),
//                 shape: BoxShape.circle,
//               ),
//               child: Center(
//                 child: Text(
//                   '+${members.length - 3}',
//                   style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     ),
//   );
// }
  
  Widget _buildInteractionProgress(SocialGroup group, Color textColor) {
    // This is a simplified progress indicator - you might want to calculate
    // actual interaction progress based on your app's logic
    final double progress = 0.7; // Example value
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interaction Progress',
          style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: textColor.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% complete',
          style: TextStyle(fontSize: 10, color: textColor),
        ),
      ],
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
    String period = 'Monthly';
    int frequency = 4;
    String selectedColor = '#2596BE';

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
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: period,
                      onChanged: (String? newValue) {
                        setState(() => period = newValue!);
                      },
                      items: <String>['Weekly', 'Monthly', 'Quarterly', 'Annually']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        labelText: 'Contact Period',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: frequency.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Frequency (times per period)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        frequency = int.tryParse(value) ?? 4;
                      },
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
                      );
                      
                      try {
                        await apiService.addGroup(newGroup);
                        _confettiController.play(); // Play confetti animation
                        Navigator.of(context).pop();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creating group: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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
                          decoration: const InputDecoration(
                            labelText: 'Group Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: period,
                          onChanged: (String? newValue) {
                            setState(() => period = newValue!);
                          },
                          items: <String>['Weekly', 'Monthly', 'Quarterly', 'Annually']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          decoration: const InputDecoration(
                            labelText: 'Contact Period',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: frequency.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Frequency (times per period)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            frequency = int.tryParse(value) ?? group.frequency;
                          },
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
                        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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
          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
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
                    _buildStatItem('Frequency', '${group.frequency}x/${group.period.substring(0, 1).toLowerCase()}'),
                    _buildStatItem('Last Contact', _formatDate(group.lastInteraction)),
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
                            'groupId': group.id,
                            'groupName': group.name,
                            'groupPeriod': group.period,
                            'groupFrequency': group.frequency
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
                              child: const Text('Add Members', style: TextStyle(color: Color.fromRGBO(45, 161, 175, 1))),
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
                                
                                try {
                                  await apiService.updateGroup(updatedGroup);
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
          );
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
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    
    return '${(difference.inDays / 30).floor()}mo ago';
  }
}
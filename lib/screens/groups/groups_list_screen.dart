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
import '../../models/nudge.dart';
import '../../widgets/feedback_floating_button.dart';

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
  List allGroups = [];

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
                final contacts = await apiService.getContactsStream().first;
                final groupContacts = contacts.where((c) => c.connectionType == group.name).toList();
                
                for (var contact in groupContacts) {
                  final updatedContact = contact.copyWith(
                    connectionType: '',
                    period: 'Monthly',
                    frequency: 2,
                  );
                  await apiService.updateContact(updatedContact);
                }
                
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
        child: Consumer2<List<Contact>, List<Nudge>>(
          builder: (context, contacts, nudges, child) {
            return Scaffold(
              backgroundColor: widget.showAppBar ? Colors.grey[50] : Colors.white,
              appBar: widget.showAppBar 
                  ? AppBar(
                      title: const Text('Social Groups', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
                      iconTheme: const IconThemeData(color: Colors.white),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      backgroundColor: const Color(0xff3CB3E9),
                    )
                  : null,
              body: Stack(
                children: [
                  // For embedded mode (dashboard), use CustomScrollView with collapsible header
                  if (!widget.showAppBar)
                    StreamBuilder<List<SocialGroup>>(
                      stream: _groupsStream,
                      builder: (context, groupsSnapshot) {
                        if (groupsSnapshot.hasError) {
                          return _buildErrorState(groupsSnapshot.error.toString());
                        }

                        if (!groupsSnapshot.hasData) {
                          return _buildLoadingState();
                        }

                        final groups = groupsSnapshot.data!;
                        allGroups = groups;
                        final sortedGroups = _sortGroups(groups);
                        final filteredGroups = sortedGroups.where((group) {
                          return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              group.description.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();
                        
                        if (groups.isEmpty) {
                          return _buildEmptyState(apiService);
                        }

                        return Scaffold(
                          appBar: AppBar(
                            title: Text(
                                  'Social Groups',
                                  style: AppTextStyles.title2.copyWith(
                                    color: const Color(0xff555555),
                                    fontSize: 22,
                                  ),
                                ),
                            leading: Center(),
                          ),
                          body: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // // Collapsible SliverAppBar
                            // SliverAppBar(
                            //   title: Padding(
                            //     padding: const EdgeInsets.only(left: 8.0),
                            //     child: Text(
                            //       'Social Groups', 
                            //       style: AppTextStyles.title2.copyWith(
                            //         color: const Color(0xff555555), 
                            //         fontSize: 22
                            //       ),
                            //     ),
                            //   ),
                            //   leading: Center(),
                            //   centerTitle: false,
                            //   backgroundColor: Colors.white,
                            //   floating: true,
                            //   snap: true,
                            //   pinned: false,
                            // ),
                            // Groups List
                            SliverFillRemaining(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
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
                            ),
                            
                            // Bottom padding for FAB
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 80),
                            ),
                          ],
                        ));
                      },
                    ),
                  
                  // For standalone mode, use CustomScrollView with collapsible header
                  if (widget.showAppBar)
                    StreamBuilder<List<SocialGroup>>(
                      stream: _groupsStream,
                      builder: (context, groupsSnapshot) {
                        if (groupsSnapshot.hasError) {
                          return _buildErrorState(groupsSnapshot.error.toString());
                        }

                        if (!groupsSnapshot.hasData) {
                          return _buildLoadingState();
                        }

                        final groups = groupsSnapshot.data!;
                        final sortedGroups = _sortGroups(groups);
                        final filteredGroups = sortedGroups.where((group) {
                          return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              group.description.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();
                        
                        if (groups.isEmpty) {
                          return _buildEmptyState(apiService);
                        }

                        return Scaffold(
                          appBar: AppBar(
                            title: Text(
                                  'Social Groups',
                                  style: AppTextStyles.title2.copyWith(
                                    color: const Color(0xff555555),
                                    fontSize: 16,
                                  ),
                                ),
                          ),
                          body: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // Collapsible SliverAppBar for standalone mode
                            
                            
                            // Groups List
                            SliverFillRemaining(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ListView.builder(
                                    physics: const BouncingScrollPhysics(),
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
                              ),
                            
                            // Bottom padding for FAB
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 80),
                            ),
                          ],
                        ));
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
              floatingActionButton: Padding(
                padding: EdgeInsets.only(
                  bottom: widget.showAppBar ? 30.0 : 30.0,
                  right: 6.0,
                ),
                child: FeedbackFloatingButton(
                  currentSection: 'groups',
                  extraActions: [
                    FeedbackAction(
                      label: 'New Group',
                      icon: Icons.group_add,
                      onPressed: () => _showCreateGroupDialog(context, apiService),
                    ),
                  ],
                ),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            );
          },
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
    Color cardColor;
    try {
      cardColor = Color(int.parse(group.colorCode.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      cardColor = const Color(0xff3CB3E9);
    }
    
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
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            (group.name).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff555555),
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
                  ],
                ),
              ),
              
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
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

void _showCreateGroupDialog(BuildContext context, ApiService apiService) {
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
            title: const Text('CREATE NEW GROUP', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555), fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      labelStyle: const TextStyle(color: Color(0xff555555)),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(color: Color(0xff555555)),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
                    style: const TextStyle(color: Color(0xff555555)),
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
                      labelStyle: const TextStyle(color: Color(0xff555555)),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff555555))),
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
                      birthdayNudgesEnabled: true,
                      anniversaryNudgesEnabled: true,
                      orderIndex: allGroups.length
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
            title: const Text('EDIT GROUP', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      labelStyle: const TextStyle(color: Color(0xff555555)),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(color: Color(0xff555555)),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
                    style: const TextStyle(color: Color(0xff555555)),
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
                      labelStyle: const TextStyle(color: Color(0xff555555)),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const SizedBox(height: 16),
                  const Text('Date Nudges:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  const SizedBox(height: 8),
                  
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
                  const Text('Group Color', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff555555))),
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
          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.85,
            child: Scaffold(
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
                          Text((group.name), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff555555))),
                          Text(group.description, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xff555555)),
                        onPressed: () => _showEditGroupDialog(context, group, apiService, () {
                          setState(() {});
                        }),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(context, group, apiService),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
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
                    const Text('GROUP MEMBERS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff6e6e6e))),
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
                              child: const Text('ADD MEMBERS', style: TextStyle(color: Color(0xff3CB3E9))),
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
                            title: Text((contact.name), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xff555555))),
                            subtitle: Text(contact.connectionType, style: const TextStyle(color: Color(0xff555555))),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () async {
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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff555555))),
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
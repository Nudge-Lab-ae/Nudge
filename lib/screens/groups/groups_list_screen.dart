import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text('Delete Group', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
        content: Text('Are you sure you want to delete the "${group.name}" group?', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
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
                      centerTitle: false,
                      backgroundColor: theme.colorScheme.primary,
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

                        return Scaffold(
                          appBar: AppBar(
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
                          ),
                          body: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
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
                                        child: _buildGroupCard(context, group, groupMembers, progress, apiService, themeProvider: themeProvider),
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
                        );
                      },
                    ),
                  
                  // For standalone mode, use CustomScrollView with collapsible header
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
                        final sortedGroups = _sortGroups(groups);
                        final filteredGroups = sortedGroups.where((group) {
                          return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              group.description.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();
                        
                        if (groups.isEmpty) {
                          return _buildEmptyState(apiService, themeProvider: themeProvider);
                        }

                        return Scaffold(
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
                            leading: Center(),
                            backgroundColor: themeProvider.getBackgroundColor(context),
                          ),
                          body: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
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
                                        child: _buildGroupCard(context, group, groupMembers, progress, apiService, themeProvider: themeProvider),
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
              floatingActionButton: Padding(
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
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            );
          },
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

  Widget _buildGroupCard(BuildContext context, SocialGroup group, List<Contact> members, double progress, ApiService apiService, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    Color cardColor;
    try {
      cardColor = Color(int.parse(group.colorCode.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      cardColor = theme.colorScheme.primary;
    }
    
    return GestureDetector(
      onTap: () => _showGroupDetails(context, group, members, apiService, themeProvider: themeProvider),
      onLongPress: () => _showDeleteConfirmation(context, group, apiService),
      child: Container(
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
                            (group.name),
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

  void _showGroupDetails(BuildContext context, SocialGroup group, List<Contact> members, ApiService apiService, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) {
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
                      onPressed: () => _showDeleteConfirmation(context, group, apiService),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Members', '${members.length}', themeProvider: themeProvider),
                    _buildStatItem('Frequency', FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period), themeProvider: themeProvider),
                    _buildStatItem('Last Engaged', _formatDate(group.lastInteraction), themeProvider: themeProvider),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GROUP MEMBERS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
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
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                          SizedBox(width: 4),
                          Text('Add More', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
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
                            Icon(Icons.group_off, size: 48, color: themeProvider.getTextSecondaryColor(context)),
                            const SizedBox(height: 16),
                            Text('No members in this group', style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                              ),
                              child: Text('ADD MEMBERS', style: TextStyle(color: themeProvider.isDarkMode ?Colors.black: Colors.white, fontFamily: 'OpenSans')),
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
                                onPressed: () async {
                                  final updatedMemberIds = List<String>.from(group.memberIds)..remove(contact.id);
                                  final updatedGroup = group.copyWith(
                                    memberIds: updatedMemberIds,
                                    memberCount: updatedMemberIds.length,
                                  );
                                  final updatedContact = contact;
                                  updatedContact.connectionType = 'Contact';
                                  
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
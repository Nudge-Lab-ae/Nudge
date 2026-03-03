// notifications_screen.dart with Dark Mode
// import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/nudge.dart';
// import 'package:nudge/models/social_group.dart';
// import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/nudge_service.dart';
// import 'package:nudge/widgets/add_touchpoint_modal.dart';
// import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/widgets/log_interaction_modal.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  final String? pendingNudgeId;
  
  const NotificationsScreen({super.key, this.showAppBar = true, this.pendingNudgeId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0; // 0: Today, 1: This Week, 2: This Month
  final NudgeService _nudgeService = NudgeService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showCalendar = false;
  var apiService = ApiService();
  
  bool _isSelecting = false;
  Set<String> _selectedNudgeIds = {};
  bool _isCancellingInProgress = false;
  int _cancellationSuccessCount = 0;
  int _cancellationTotalCount = 0;
  int _cancellationErrorCount = 0;

  bool _hasProcessedPendingNudge = false;
  
  // Track if FAB menu is open

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _processOverdueNudges();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Process pending nudge after dependencies are loaded
    if (!_hasProcessedPendingNudge && widget.pendingNudgeId != null) {
      _processPendingNudge();
    }
  }

  Nudge defaultNudge(){
    return Nudge(id: '', nudgeId: '', contactId: '', contactName: '', nudgeType: '', message: '', scheduledTime: DateTime.now(), userId: '', period: '', frequency: 2, isPushNotification: false, priority: 1, isVIP: false, contactImageUrl: 'contactImageUrl', groupName: 'groupName');
  }

  Future<void> _processPendingNudge() async {
    if (_hasProcessedPendingNudge) return;
    
    // Small delay to ensure the stream has loaded data
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final userId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
    
    // Get all nudges to find the one with matching ID
    final allNudges = await _nudgeService.getAllNudges(userId);
    final targetNudge = allNudges.firstWhere(
      (nudge) => nudge.id == widget.pendingNudgeId,
      orElse: () => defaultNudge(),
    );
    
    if (targetNudge.id != '' && mounted) {
      // Get theme provider
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      
      // Trigger the showNudgeActions method
      _showNudgeActions(context, themeProvider, targetNudge);
      
      setState(() {
        _hasProcessedPendingNudge = true;
      });
    } else {
      print('Pending nudge not found: ${widget.pendingNudgeId}');
      setState(() {
        _hasProcessedPendingNudge = true; // Mark as processed even if not found
      });
    }
  }


  Future<void> _processOverdueNudges() async {
    try {
      final userId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
      final nudgeService = NudgeService();
      await nudgeService.processOverdueNudges(userId);
    } catch (e) {
      print('Error processing overdue nudges in UI: $e');
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedNudgeIds.clear();
    });
  }

  void _toggleSelectAll(List<Nudge> visibleNudges) {
    setState(() {
      if (_selectedNudgeIds.length == visibleNudges.length) {
        _selectedNudgeIds.clear();
      } else {
        _selectedNudgeIds = Set<String>.from(visibleNudges.map((nudge) => nudge.id));
      }
    });
  }

  Widget _buildSelectableNudgeItem(Nudge nudge, bool isSelected, bool isOverdue, BuildContext context, {required ThemeProvider themeProvider}) {
    // final theme = Theme.of(context);
    
    return ListTile(
      tileColor: themeProvider.getSurfaceColor(context),
      leading: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedNudgeIds.add(nudge.id);
            } else {
              _selectedNudgeIds.remove(nudge.id);
            }
          });
        },
      ),
      title: Text(
        nudge.contactName,
        style: TextStyle(
          fontFamily: 'OpenSans',
          fontWeight: FontWeight.w600,
          color: isOverdue ? const Color.fromRGBO(243, 87, 87, 1) : themeProvider.getTextPrimaryColor(context),
        ),
      ),
      subtitle: Text(nudge.message, style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')),
      trailing: Text(
        DateFormat('MMM d, h:mm a').format(nudge.scheduledTime),
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'OpenSans',
          color: isOverdue ? const Color.fromRGBO(243, 87, 87, 1) : themeProvider.getTextSecondaryColor(context),
        ),
      ),
      onTap: () {
        setState(() {
          if (_selectedNudgeIds.contains(nudge.id)) {
            _selectedNudgeIds.remove(nudge.id);
          } else {
            _selectedNudgeIds.add(nudge.id);
          }
        });
      },
    );
  }

  Widget _buildSelectionControls(List<Nudge> visibleNudges, {required ThemeProvider themeProvider}) {
    if (!_isSelecting) return const SizedBox.shrink();
    final theme = Theme.of(context);
    
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
              onPressed: () => _toggleSelectAll(visibleNudges),
              icon: Icon(
                _selectedNudgeIds.length == visibleNudges.length && _selectedNudgeIds.isNotEmpty
                  ? Icons.deselect 
                  : Icons.select_all,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                _selectedNudgeIds.length == visibleNudges.length && _selectedNudgeIds.isNotEmpty
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

  Widget _buildCancellationProgressOverlay({required ThemeProvider themeProvider}) {
    if (!_isCancellingInProgress) return const SizedBox.shrink();
    
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
              const Text(
                'Cancelling Nudges',
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _cancellationTotalCount > 0 
                    ? _cancellationSuccessCount / _cancellationTotalCount 
                    : 0,
                backgroundColor: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$_cancellationSuccessCount of $_cancellationTotalCount nudges cancelled'
                '${_cancellationErrorCount > 0 ? ' ($_cancellationErrorCount errors)' : ''}',
                style: TextStyle(fontSize: 14, color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelSelectedNudges(BuildContext context, ThemeProvider themeProvider) async {
    if (_selectedNudgeIds.isEmpty) return;
    
    final theme = Theme.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text('CANCEL NUDGES', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
        content: Text('Are you sure you want to cancel ${_selectedNudgeIds.length} nudge${_selectedNudgeIds.length == 1 ? '' : 's'}?', style: TextStyle(color: themeProvider.getTextPrimaryColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Nudges', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _startCancellationProcess();
    }
  }

  void _startCancellationProcess() async {
    final userId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
    
    setState(() {
      _isCancellingInProgress = true;
      _cancellationSuccessCount = 0;
      _cancellationErrorCount = 0;
      _cancellationTotalCount = _selectedNudgeIds.length;
    });
    
    for (String nudgeId in _selectedNudgeIds) {
      try {
        await _nudgeService.cancelNudge(nudgeId, userId);
        setState(() {
          _cancellationSuccessCount++;
        });
      } catch (e) {
        setState(() {
          _cancellationErrorCount++;
        });
        print('Error cancelling nudge $nudgeId: $e');
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cancelled $_cancellationSuccessCount nudge${_cancellationSuccessCount == 1 ? '' : 's'}${_cancellationErrorCount > 0 ? '. $_cancellationErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    setState(() {
      _isCancellingInProgress = false;
      _isSelecting = false;
      _selectedNudgeIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    var size = MediaQuery.of(context).size;
    
    if (user == null) {
      return Scaffold(
        backgroundColor: themeProvider.getBackgroundColor(context),
        body: Center(child: Text('Please log in to view notifications', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'))),
      );
    }
    
    // When used from dashboard (showAppBar: false), use CustomScrollView
    if (!widget.showAppBar) {
      return StreamBuilder<List<Nudge>>(
        stream: _nudgeService.getNudgesStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')));
          }
          
          final allNudges = snapshot.data ?? [];
          final filteredNudges = _getFilteredNudges(allNudges, _selectedFilter);
          
          return Scaffold(
            floatingActionButton: _selectedNudgeIds.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => _cancelSelectedNudges(context, themeProvider),
                  backgroundColor: Colors.red,
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: Text(
                    'CANCEL ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
                    style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
                  ),
                )
              : Center()/* FeedbackFloatingButton(
                  currentSection: 'notifications',
                  onMenuStateChanged: () {
                    _onFabMenuStateChanged();
                  },
                  extraActions: [
                    FeedbackAction(
                      label: 'Log Interaction',
                      icon: Icons.add,
                      onPressed: () {
                        _showAddTouchpointModal(context, themeProvider);
                      },
                    ),
                    FeedbackAction(
                      label: 'Create Nudge',
                      icon: Icons.notifications,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Create Nudge - Placeholder Action')),
                        );
                      },
                    ),
                    FeedbackAction(
                      label: 'Add Contact',
                      icon: Icons.person_add,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add Contact - Placeholder Action')),
                        );
                      },
                    ),
                    FeedbackAction(
                      label: 'View Stats',
                      icon: Icons.analytics,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('View Stats - Placeholder Action')),
                        );
                      },
                    ),
                  ],
                ) */,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: Stack(
              children: [
                // Main content
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Sliver App Bar with Calendar Toggle
                    SliverAppBar(
                      title: Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text('Nudges',style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,color: themeProvider.getTextPrimaryColor(context), fontFamily: 'Inter')),
                      ),
                      centerTitle: false,
                      leading: Center(),
                      backgroundColor: themeProvider.getBackgroundColor(context),
                      floating: true,
                      snap: true,
                      pinned: false,
                      surfaceTintColor: Colors.transparent,
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showCalendar = !_showCalendar;
                              });
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
                                  _showCalendar ? Icons.list : Icons.calendar_today,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showCalendar ? 'List View' : 'Calendar View',
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
                    ),
                    
                    // Selection Controls (only when selecting in list view)
                    if (_isSelecting && !_showCalendar)
                      SliverToBoxAdapter(
                        child: _buildSelectionControls(filteredNudges, themeProvider: themeProvider),
                      ),
                    
                    if (_showCalendar) ...[
                      // Calendar View
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: size.height*0.9,
                          child: Column(
                            children: [
                              // Calendar
                              _buildCalendarView(allNudges, themeProvider: themeProvider),
                              // Day's nudges with proper height constraint
                              SizedBox(
                                height: 30,
                              ),
                              Expanded(
                                child: _selectedDay != null
                                    ? _buildDayNudges(_getNudgesForDay(allNudges, _selectedDay!), context, themeProvider: themeProvider)
                                    : _buildEmptyDayState(themeProvider: themeProvider),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // List View - Filter Header
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverToBoxAdapter(
                          child: _buildFilterHeader(filteredNudges, themeProvider: themeProvider),
                        ),
                      ),
                      
                      // Nudges List
                      if (filteredNudges.isEmpty)
                        SliverFillRemaining(
                          child: _buildEmptyState(themeProvider: themeProvider),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final nudge = filteredNudges[index];
                                final isOverdue = !nudge.isCompleted && 
                                                nudge.scheduledTime.isBefore(DateTime.now());
                                final isSelected = _selectedNudgeIds.contains(nudge.id);
                                
                                return _isSelecting
                                    ? _buildSelectableNudgeItem(nudge, isSelected, isOverdue, context, themeProvider: themeProvider)
                                    : _buildNormalNudgeItem(nudge, isOverdue, context, themeProvider: themeProvider);
                              },
                              childCount: filteredNudges.length,
                            ),
                          ),
                        ),
                    ],
                    
                    // Bottom padding for FAB
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
                
                // Grey overlay when FAB menu is open
                // if (_isFabMenuOpen)
                //   Container(
                //     color: Colors.black.withOpacity(0.5),
                //     width: size.width,
                //     height: size.height,
                //   ),
                
                // Cancellation progress overlay
                _buildCancellationProgressOverlay(themeProvider: themeProvider),
              ],
            ),
          );
        },
      );
    }
    
    // Original implementation for standalone use
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudges & Reminders'),
        backgroundColor: theme.colorScheme.primary,
      ),
      floatingActionButton: _selectedNudgeIds.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: () => _cancelSelectedNudges(context, themeProvider),
            backgroundColor: Colors.red,
            icon: const Icon(Icons.cancel, color: Colors.white),
            label: Text(
              'CANCEL ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
              style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
            ),
          )
        : Center()/* FeedbackFloatingButton(
            currentSection: 'notifications',
            onMenuStateChanged: () {
                // _onFabMenuStateChanged();
            },
            extraActions: [
              FeedbackAction(
                label: 'Log Interaction',
                icon: Icons.add,
                onPressed: () {
                  _showAddTouchpointModal(context, themeProvider);
                },
              ),
              FeedbackAction(
                label: 'Create Nudge',
                icon: Icons.notifications,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Create Nudge - Placeholder Action')),
                  );
                },
              ),
              FeedbackAction(
                label: 'Add Contact',
                icon: Icons.person_add,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add Contact - Placeholder Action')),
                  );
                },
              ),
              FeedbackAction(
                label: 'View Stats',
                icon: Icons.analytics,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View Stats - Placeholder Action')),
                  );
                },
              ),
            ],
          )*/,
      body: StreamBuilder<List<Nudge>>(
        stream: _nudgeService.getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')));
          }
          
          final allNudges = snapshot.data ?? [];
          final filteredNudges = _getFilteredNudges(allNudges, _selectedFilter);
          
          return Stack(
            children: [
              Container(
                color: themeProvider.getBackgroundColor(context),
                child: Column(
                  children: [
                    // Header with title and view toggle
                    _buildHeader(themeProvider: themeProvider),
                    
                    if (_showCalendar) ...[
                      // Calendar View
                      SizedBox(
                        height: size.height*0.9,
                        child: Column(
                          children: [
                            // Calendar
                            _buildCalendarView(allNudges, themeProvider: themeProvider),
                            SizedBox(
                              height: 30,
                            ),
                            // Day's nudges with proper height constraint
                            Expanded(
                              child: _selectedDay != null
                                  ? _buildDayNudges(_getNudgesForDay(allNudges, _selectedDay!), context, themeProvider: themeProvider)
                                  : _buildEmptyDayState(themeProvider: themeProvider),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Selection Controls (only when selecting)
                      if (_isSelecting)
                        _buildSelectionControls(filteredNudges, themeProvider: themeProvider),
                      
                      // List View (Original)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildFilterHeader(filteredNudges, themeProvider: themeProvider),
                      ),
                      
                      Expanded(
                        child: filteredNudges.isEmpty
                            ? _buildEmptyState(themeProvider: themeProvider)
                            : _buildNudgeList(filteredNudges, themeProvider: themeProvider),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Cancellation progress overlay
              _buildCancellationProgressOverlay(themeProvider: themeProvider),
            ],
          );
        },
      ),
    );
  }

  // ... rest of your existing methods (_getContactInitials, getRandomIndex, _buildDayNudges, etc.) remain exactly the same ...
  
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

  Widget _buildDayNudges(List<Nudge> dayNudges, BuildContext context, {required ThemeProvider themeProvider}) {
    if (dayNudges.isEmpty) {
      return _buildEmptyDayState(themeProvider: themeProvider);
    }
    
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              DateFormat('EEEE, MMMM d, y').format(_selectedDay!),
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.bold,
                color: themeProvider.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dayNudges.length,
              itemBuilder: (context, index) {
                final nudge = dayNudges[index];
                final isOverdue = !nudge.isCompleted && 
                                nudge.scheduledTime.isBefore(DateTime.now());
                return _buildNormalNudgeItem(nudge, isOverdue, context, themeProvider: themeProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState({required ThemeProvider themeProvider}) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: themeProvider.getTextSecondaryColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No nudges scheduled',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'OpenSans',
                color: themeProvider.getTextSecondaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Nudge> _getNudgesForDay(List<Nudge> allNudges, DateTime day) {
    return allNudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      final targetDate = DateTime(day.year, day.month, day.day);
      return nudgeDate == targetDate;
    }).toList();
  }

  Widget _buildFilterHeader(List<Nudge> filteredNudges, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    final completedCount = filteredNudges.where((n) => n.isCompleted).length;
    final pendingCount = filteredNudges.where((n) => !n.isCompleted).length;
    final overdueCount = _getOverdueNudges(filteredNudges).length;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: themeProvider.isDarkMode
                  ? [
                      theme.colorScheme.primary.withOpacity(0.8),
                      theme.colorScheme.primary.withOpacity(0.6),
                    ]
                  : [
                      theme.colorScheme.primary.withOpacity(0.9),
                      Color.fromRGBO(45, 161, 175, 0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactStatItem(
                      icon: Icons.schedule,
                      value: filteredNudges.length.toString(),
                      label: 'Total',
                      themeProvider: themeProvider,
                    ),
                    _buildCompactStatItem(
                      icon: Icons.check_circle,
                      value: completedCount.toString(),
                      label: 'Completed',
                      themeProvider: themeProvider,
                    ),
                    _buildCompactStatItem(
                      icon: Icons.pending_actions,
                      value: pendingCount.toString(),
                      label: 'Pending',
                      themeProvider: themeProvider,
                    ),
                    if (overdueCount > 0) 
                      _buildCompactStatItem(
                        icon: Icons.warning,
                        value: overdueCount.toString(),
                        label: 'Overdue',
                        themeProvider: themeProvider,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildCompactFilterToggle('TODAY', 0, themeProvider: themeProvider),
                      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                      _buildCompactFilterToggle('THIS WEEK', 1, themeProvider: themeProvider),
                      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                      _buildCompactFilterToggle('THIS MONTH', 2, themeProvider: themeProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String value,
    required String label,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'OpenSans',
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFilterToggle(String text, int index, {required ThemeProvider themeProvider}) {
    bool isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'OpenSans',
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<Nudge> _getFilteredNudges(List<Nudge> allNudges, int filterIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tenDaysAgo = now.subtract(const Duration(days: 10));
    
    final ancientOverdueNudges = allNudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      return !nudge.isCompleted && nudgeDate.isBefore(tenDaysAgo);
    }).toList();
    
    if (ancientOverdueNudges.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processOverdueNudges();
      });
    }

    final overdueNudges = allNudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      return !nudge.isCompleted && 
            nudgeDate.isBefore(today) && 
            nudgeDate.isAfter(tenDaysAgo);
    }).toList();

    switch (filterIndex) {
      case 0: // Today
        final todayNudges = allNudges.where((nudge) {
          final nudgeDate = DateTime(
            nudge.scheduledTime.year,
            nudge.scheduledTime.month,
            nudge.scheduledTime.day,
          );
          return nudgeDate == today;
        }).toList();
        
        return [
          ...overdueNudges,
          ...todayNudges.where((nudge) => !overdueNudges.contains(nudge)),
        ];
        
      case 1: // This Week
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        
        final weekNudges = allNudges.where((nudge) {
          return nudge.scheduledTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
                nudge.scheduledTime.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();
        
        return [
          ...overdueNudges,
          ...weekNudges.where((nudge) => !overdueNudges.contains(nudge)),
        ];
        
      case 2: // This Month (Enhanced with next month extension if less than 5 days left)
        // Calculate days left in current month
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final daysLeftInMonth = lastDayOfMonth.difference(now).inDays;
        
        // Determine end date - if less than 5 days left, extend into next month
        final DateTime endDate;
        if (daysLeftInMonth < 5) {
          // Add 30 days to current date to get a full month window
          endDate = now.add(const Duration(days: 30));
        } else {
          // Use end of current month
          endDate = lastDayOfMonth;
        }
        
        // Start from beginning of current month
        final startOfMonth = DateTime(now.year, now.month, 1);
        
        final monthNudges = allNudges.where((nudge) {
          return nudge.scheduledTime.isAfter(startOfMonth.subtract(const Duration(days: 1))) && 
                nudge.scheduledTime.isBefore(endDate.add(const Duration(days: 1)));
        }).toList();
        
        return [
          ...overdueNudges,
          ...monthNudges.where((nudge) => !overdueNudges.contains(nudge)),
        ];
        
      default:
        return allNudges;
    }
  }
    
  List<Nudge> _getOverdueNudges(List<Nudge> nudges) {
    final now = DateTime.now();
    return nudges.where((nudge) {
      return !nudge.isCompleted && nudge.scheduledTime.isBefore(now);
    }).toList();
  }

  Widget _buildEmptyState({required ThemeProvider themeProvider}) {
    String message = '';
    switch (_selectedFilter) {
      case 0:
        message = 'No nudges scheduled for today';
        break;
      case 1:
        message = 'No nudges scheduled for this week';
        break;
      case 2:
        message = 'No nudges scheduled for this month';
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: themeProvider.getTextSecondaryColor(context),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'OpenSans',
              color: themeProvider.getTextPrimaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caught up! 🎉',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'OpenSans',
              color: themeProvider.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeList(List<Nudge> nudges, {required ThemeProvider themeProvider}) {
    if (_isSelecting) {
      return ListView.builder(
        itemCount: nudges.length,
        itemBuilder: (context, index) {
          final nudge = nudges[index];
          final isOverdue = !nudge.isCompleted && nudge.scheduledTime.isBefore(DateTime.now());
          final isSelected = _selectedNudgeIds.contains(nudge.id);
          return _buildSelectableNudgeItem(nudge, isSelected, isOverdue, context, themeProvider: themeProvider);
        },
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final overdueNudges = nudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      return !nudge.isCompleted && nudgeDate.isBefore(today);
    }).toList();
    
    final todayNudges = nudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      return nudgeDate == today;
    }).toList();
    
    final upcomingNudges = nudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      return nudgeDate.isAfter(today);
    }).toList();

    return ListView(
      children: [
        if (overdueNudges.isNotEmpty) ...[
          _buildSectionHeader('Overdue', overdueNudges.length, themeProvider: themeProvider),
          ...overdueNudges.map((nudge) {
            final isOverdue = true;
            return _buildNormalNudgeItem(nudge, isOverdue, context, themeProvider: themeProvider);
          }),
        ],
        if (todayNudges.isNotEmpty) ...[
          _buildSectionHeader('Today', todayNudges.length, themeProvider: themeProvider),
          ...todayNudges.map((nudge) => _buildNormalNudgeItem(nudge, false, context, themeProvider: themeProvider)),
        ],
        if (upcomingNudges.isNotEmpty) ...[
          _buildSectionHeader('Upcoming', upcomingNudges.length, themeProvider: themeProvider),
          ...upcomingNudges.map((nudge) => _buildNormalNudgeItem(nudge, false, context, themeProvider: themeProvider)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'OpenSans',
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ));
  }

  Widget _buildNormalNudgeItem(Nudge nudge, bool isOverdue, BuildContext context, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    final initials = _getContactInitials(nudge.contactName);
    final iconIndex = getRandomIndex(nudge.contactId);
    String message = 'Time to reconnect.';
    if (nudge.message.contains('Rescheduled') || nudge.isSnoozed){
      message = 'Time to reconnect | [Rescheduled]';
    }

    if (nudge.message.contains('birthday')){
      message = nudge.message;
    }
    
    return Dismissible(
      key: Key(nudge.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground('complete', context, themeProvider: themeProvider),
      secondaryBackground: _buildSwipeBackground('snooze', context, themeProvider: themeProvider),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Snooze action
          _showSnoozeDialog(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
          return false; // Don't dismiss immediately, handle in dialog
        } else {
          // Complete action
          return await _confirmCompleteNudge(nudge, context, themeProvider);
        }
      },
      onDismissed: (direction) {
        // This is called after confirmDismiss returns true
        // We don't need to do anything here as the list will update via Stream
        print('Nudge dismissed: ${nudge.id}');
      },
      child: GestureDetector(
        onTap: () => _showNudgeActions(context, themeProvider, nudge),
        onLongPress: () {
          if (!_isSelecting) {
            setState(() {
              _isSelecting = true;
              _selectedNudgeIds.add(nudge.id);
            });
          }
        },
        child: Card(
          margin: const EdgeInsets.symmetric(/* horizontal: 16, */ vertical: 4),
          elevation: 2,
          color: themeProvider.getSurfaceColor(context),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: themeProvider.isDarkMode ? AppTheme.darkSurfaceVariant : Colors.transparent,
                  backgroundImage: nudge.contactImageUrl.isNotEmpty
                      ? NetworkImage(nudge.contactImageUrl)
                      : AssetImage('assets/contact-icons/$iconIndex.png') as ImageProvider,
                  child: nudge.contactImageUrl.isEmpty
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'OpenSans',
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                if (nudge.isVIP)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    nudge.contactName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'OpenSans',
                      color: isOverdue ? const Color.fromRGBO(243, 87, 87, 1) : themeProvider.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                // Positioned(
                //   right: -70,
                //   child: isOverdue
                //   ?Icon(Icons.warning, color: const Color.fromARGB(255, 226, 14, 81) , size: 16)
                //   :Center()
                // )
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontFamily: 'OpenSans',
                    color: themeProvider.getTextSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: themeProvider.getTextSecondaryColor(context)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(nudge.scheduledTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'OpenSans',
                        color: isOverdue ? const Color.fromRGBO(243, 87, 87, 1)  : themeProvider.getTextSecondaryColor(context),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: nudge.isCompleted 
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : isOverdue
                  ? Padding(
                    padding: EdgeInsets.only(bottom: 50),
                    child: Icon(Icons.warning, color: const Color.fromRGBO(243, 87, 87, 1) , size: 16),
                  )
                  : const SizedBox(
                    height: 10,
                  ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmCompleteNudge(Nudge nudge, BuildContext context, ThemeProvider themeProvider) async {
    final theme = Theme.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text(
          'Complete Nudge',
          style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
        ),
        content: Text(
          'Mark nudge for ${nudge.contactName} as complete?',
          style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete', style: TextStyle(color: Colors.green, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Show the log interaction modal first and get the result
      final modalResult = await _showLogInteractionModalForNudge(context, themeProvider, nudge);
      
      // Check if interaction was successfully logged
      if (modalResult == null || modalResult['success'] != true) {
        try {
          // Get the contact data
          final contacts = await apiService.getAllContacts();
          final contact = contacts.firstWhere(
            (c) => c.name == nudge.contactName,
          );
          
          // Get the interaction date from the modal result
          final DateTime interactionDateTime = modalResult!['interactionDateTime'];
          
          // Calculate next scheduled time based on the interaction date
          DateTime nextScheduledTime = _calculateNextNudgeTime(
            contact, 
            interactionDateTime, // Use the actual interaction date as the reference point
          );
          
          // Cancel the current nudge
          await apiService.cancelSingleNudge(nudgeId: nudge.id);
          await apiService.deleteNudgeFromFirestore(nudgeId: nudge.id);

          if (nudge.nudgeType == 'event') {
            return true;
          }
          
          // Schedule a new nudge
          await apiService.scheduleSingleNudge(
            contactId: contact.id,
            scheduledTime: nextScheduledTime,
          );
          
          
        } catch (e) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('Error completing nudge: $e'),
          //     backgroundColor: Colors.red,
          //   ),
          // );
          return false; // Prevent dismissal
        }
      }

    }
    
    return false; // User cancelled or interaction modal closed without logging
  }
  
  Future<Map<String, dynamic>?> _showLogInteractionModalForNudge(BuildContext context, ThemeProvider themeProvider, Nudge nudge) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    try {
      // Get the full contact details first
      final contacts = await apiService.getAllContacts();
      final contact = contacts.firstWhere(
        (c) => c.name == nudge.contactName,
      );
      
      // Show the modal and wait for result
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: themeProvider.getSurfaceColor(context),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: LogInteractionModal(
              apiService: apiService,
              contact: contact,
              isDarkMode: themeProvider.isDarkMode,
            ),
          );
        },
      );
      
      return result; // Returns map with success and interactionDateTime
      
    } catch (e) {
      print('Error showing log interaction modal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Could not find contact details'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Widget _buildSwipeBackground(String action, BuildContext context, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    Color color;
    IconData icon;

    if (action == 'complete') {
      color = theme.colorScheme.primary;
      icon = Icons.check;
    } else {
      color = Colors.orange;
      icon = Icons.snooze;
    }

    return Container(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: action == 'complete' ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              action == 'complete' ? 'Complete' : 'Snooze',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'OpenSans'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNudgeActions(BuildContext context, ThemeProvider themeProvider, Nudge nudge) {
    if (_isSelecting) {
      setState(() {
        if (_selectedNudgeIds.contains(nudge.id)) {
          _selectedNudgeIds.remove(nudge.id);
        } else {
          _selectedNudgeIds.add(nudge.id);
        }
      });
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getSurfaceColor(context),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.person, color: themeProvider.getTextPrimaryColor(context)),
                title: Text('View Contact', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                onTap: () {
                  Navigator.pop(context);
                  _viewContact(nudge.contactId);
                },
              ),
              ListTile(
                leading: Icon(Icons.schedule, color: themeProvider.getTextPrimaryColor(context)),
                title: Text('Adjust Frequency', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                onTap: () {
                  Navigator.pop(context);
                  _showFrequencyDialog(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: Icon(Icons.snooze, color: themeProvider.getTextPrimaryColor(context)),
                title: Text('Snooze', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                onTap: () {
                  Navigator.pop(context);
                  _showSnoozeDialog(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: themeProvider.getTextPrimaryColor(context)),
                title: Text('Mark Complete', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                onTap: () {
                  Navigator.pop(context);
                  // _completeNudge(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                  _confirmCompleteNudge(nudge, context, themeProvider);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: themeProvider.getTextPrimaryColor(context)),
                title: Text('Cancel Nudge', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                onTap: () {
                  Navigator.pop(context);
                  _cancelNudge(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              if (!_isSelecting)
                ListTile(
                  leading: Icon(Icons.select_all, color: themeProvider.getTextPrimaryColor(context)),
                  title: Text('Select Multiple', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _isSelecting = true;
                      _selectedNudgeIds.add(nudge.id);
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _viewContact(String contactId) {
    final contacts = Provider.of<List<Contact>>(context, listen: false);
    final contact = contacts.firstWhere(
      (contact) => contact.id == contactId,
    );
    
    if (contact.id.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContactDetailScreen(contact: contact),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFrequencyDialog(Nudge nudge, ThemeProvider themeProvider, String userId) async{
    final theme = Theme.of(context);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final thisUser = await apiService.getUser();
    List<Map<String, dynamic>> groups = thisUser.groups!;
    List<Contact> contacts = await apiService.getAllContacts();
    Contact nudgeContact = contacts.where((contact) => contact.name == nudge.contactName).first;
    Map<String, dynamic> group = groups.where((group) => nudgeContact.connectionType == group['name']).first;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get current group settings
        String _selectedFrequencyChoice = FrequencyPeriodMapper.getConversationalChoice(
          nudge.frequency, 
          nudge.period
        );
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: themeProvider.getSurfaceColor(context),
              title: Text(
                'Adjust Group Frequency',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.w600,
                ), textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will update the "${group['name']}" group settings for ${nudge.contactName} and all other members.',
                    style: TextStyle(
                      color: themeProvider.getTextPrimaryColor(context),
                      fontFamily: 'OpenSans',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Group selection indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Group: ${nudge.groupName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.getTextPrimaryColor(context),
                                  fontFamily: 'OpenSans',
                                ),
                              ),
                              Text(
                                '${nudge.contactName} will be updated with group',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: themeProvider.getTextSecondaryColor(context),
                                  fontFamily: 'OpenSans',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Frequency dropdown (reusing the same selection as in groups_list_screen)
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyChoice,
                    style: TextStyle(
                      color: themeProvider.getTextPrimaryColor(context),
                      fontFamily: 'OpenSans',
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedFrequencyChoice = newValue;
                        });
                      }
                    },
                    items: FrequencyPeriodMapper.frequencyMapping.keys
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: themeProvider.getTextPrimaryColor(context),
                            fontFamily: 'OpenSans',
                          ),
                        ),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Contact Frequency',
                      labelStyle: TextStyle(
                        color: themeProvider.getTextPrimaryColor(context),
                        fontFamily: 'OpenSans',
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: themeProvider.isDarkMode 
                              ? AppTheme.darkCardBorder 
                              : Colors.grey,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: themeProvider.isDarkMode 
                              ? AppTheme.darkCardBorder 
                              : Colors.grey,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      fillColor: themeProvider.getSurfaceColor(context),
                      filled: true,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    'This will affect all contacts in the ${nudge.groupName} group',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'OpenSans',
                      color: themeProvider.getTextSecondaryColor(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontFamily: 'OpenSans',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Show loading dialog
                    Navigator.pop(context); // Close frequency dialog
                    
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    
                    try {
                      // Get frequency and period from selection
                      final frequencyData = FrequencyPeriodMapper.getFrequencyPeriod(
                        _selectedFrequencyChoice
                      );
                      final newPeriod = frequencyData['period'] as String;
                      final newFrequency = frequencyData['frequency'] as int;
                      
                      // Get all groups
                      final groups = await apiService.getGroupsStream().first;
                      
                      // Find the group to update
                      final groupToUpdate = groups.firstWhere(
                        (g) => g.name == nudge.groupName,
                      );
                      
                      if (groupToUpdate.id.isNotEmpty) {
                        // Update the group
                        final updatedGroup = groupToUpdate.copyWith(
                          period: newPeriod,
                          frequency: newFrequency,
                        );
                        
                        // Update groups list
                        final updatedGroups = groups.map((g) {
                          return g.id == groupToUpdate.id ? updatedGroup : g;
                        }).toList();
                        
                        await apiService.updateGroups(updatedGroups);
                        
                        // Get all contacts in this group
                        final allContacts = await apiService.getAllContacts();
                        final groupContacts = allContacts.where((contact) =>
                          contact.connectionType == groupToUpdate.name ||
                          contact.connectionType == groupToUpdate.id
                        ).toList();
                        
                        // Cancel all existing nudges for these contacts
                        final allNudges = await apiService.getAllNudges();
                        final contactNudges = allNudges.where((n) =>
                          groupContacts.any((c) => c.id == n.contactId)
                        ).toList();
                        
                        if (contactNudges.isNotEmpty) {
                          final nudgeIds = contactNudges.map((n) => n.id).toList();
                          await apiService.cancelMultipleNudge(nudgeIds: nudgeIds);
                          
                          // Also delete from Firestore
                          for (var nudge in contactNudges) {
                            await apiService.deleteNudgeFromFirestore(nudgeId: nudge.id);
                          }
                        }
                        
                        // Schedule new nudges for all contacts in the group
                        for (var contact in groupContacts) {
                          // Calculate next scheduled time based on new group settings
                          DateTime nextScheduledTime = _calculateNextNudgeTime(
                            contact,
                            DateTime.now(),
                          );
                          
                          await apiService.scheduleSingleNudge(
                            contactId: contact.id,
                            scheduledTime: nextScheduledTime,
                          );
                        }
                        
                        // Close loading dialog
                        if (context.mounted) Navigator.pop(context);
                        
                        // Show success message
                        if (context.mounted) {
                          Flushbar(
                            padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                            flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                            forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                            messageText: Center(
                                child: Text('Group "${groupToUpdate.name}" updated to $_selectedFrequencyChoice. '
                                '${groupContacts.length} contact nudges rescheduled.', style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
                                    color: Colors.white, fontWeight: FontWeight.w400),)),
                          ).show(context);
                        }
                      } else {
                        throw Exception('Group not found');
                      }
                    } catch (e) {
                      // Close loading dialog
                      if (context.mounted) Navigator.pop(context);
                      
                      // Show error message
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update group: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                  ),
                  child: const Text(
                    'Update Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'OpenSans',
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

  void _showSnoozeDialog(Nudge nudge, ThemeProvider themeProvider, String userId){
    final theme = Theme.of(context);
    int selectedSnoozeHours = 4;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: themeProvider.getSurfaceColor(context),
            title: Text('Snooze Nudge', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How long would you like to snooze this nudge?', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedSnoozeHours,
                  style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans'),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedSnoozeHours = newValue;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('4 hours')),
                    DropdownMenuItem(value: 24, child: Text('1 day')),
                    DropdownMenuItem(value: 72, child: Text('3 days')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
              ),
              TextButton(
                onPressed: () async{
                  Navigator.pop(context);
                  // _nudgeService.snoozeNudge(
                  //   nudge.id, 
                  //   userId, 
                  //   Duration(hours: selectedSnoozeHours),
                  //   nudge.contactName,
                  // );
                  final contacts = await apiService.getAllContacts();
                  final contact = contacts.firstWhere(
                    (c) => c.name == nudge.contactName,
                  );

                  final newScheduledTime = DateTime.now().add(Duration(hours: selectedSnoozeHours));
                  apiService.cancelSingleNudge(nudgeId: nudge.id);
                  apiService.scheduleSingleNudge(contactId: contact.id, scheduledTime: newScheduledTime, rescheduled: true);
                  
                  Flushbar(
                    padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                    flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                    forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                    messageText: Center(
                        child: Text('Nudge snoozed for $selectedSnoozeHours hour${selectedSnoozeHours > 1 ? 's' : ''}', style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
                            color: Colors.white, fontWeight: FontWeight.w400),)),
                  ).show(context);
                },
                child: Text('Snooze', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
              ),
            ],
          );
        },
      ),
    );
  }

  // void _completeNudge(Nudge nudge, String userId) async {
  //   try {
  //     // Step 1: Cancel the current nudge (this will delete it from Firestore and cancel its tasks)
  //     await apiService.cancelSingleNudge(nudgeId: nudge.id);
      
  //     // Step 2: Get the contact data to calculate next scheduled time
  //     final contacts = await apiService.getAllContacts();
  //     print(nudge.toMap()); print(nudge.id); print(contacts[0].id); print(' are the ids');
       
  //     final contact = contacts.firstWhere(
  //       (c) => c.name == nudge.contactName,
  //     );
      
  //     // Calculate next scheduled time based on contact's period and frequency
  //     DateTime nextScheduledTime = _calculateNextNudgeTime(contact, nudge.scheduledTime);
      
  //     // Step 3: Schedule a new nudge for the contact
  //     final result = await apiService.scheduleSingleNudge(
  //       contactId: contact.id,
  //       scheduledTime: nextScheduledTime,
  //     );
      
  //     if (result['success'] == true) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Nudge marked as completed. Next nudge scheduled for ${DateFormat('MMM d, h:mm a').format(nextScheduledTime)}',
  //           ),
  //           backgroundColor: Colors.green,
  //           duration: const Duration(seconds: 3),
  //         ),
  //       );
  //     } else {
  //       throw Exception('Failed to schedule next nudge');
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error completing nudge: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     print('Error completing nudge: $e');
  //   }
  // }

  // Helper method to calculate next nudge time based on interaction date
  DateTime _calculateNextNudgeTime(Contact contact, DateTime interactionDateTime) {
    DateTime nextTime;
    
    switch (contact.period.toLowerCase()) {
      case 'daily':
        nextTime = interactionDateTime.add(const Duration(days: 1));
        break;
      case 'weekly':
        nextTime = interactionDateTime.add(const Duration(days: 7));
        break;
      case 'monthly':
        nextTime = interactionDateTime.add(const Duration(days: 30));
        break;
      case 'quarterly':
        nextTime = interactionDateTime.add(const Duration(days: 91));
        break;
      case 'annually':
      case 'yearly':
        nextTime = interactionDateTime.add(const Duration(days: 365));
        break;
      default:
        nextTime = interactionDateTime.add(const Duration(days: 30));
    }
    
    // Adjust based on frequency (e.g., if frequency is 2 per month, schedule halfway through)
    if (contact.frequency > 1) {
      // Calculate the interval between nudges based on frequency
      final totalDays = nextTime.difference(interactionDateTime).inDays;
      final intervalDays = totalDays ~/ contact.frequency;
      nextTime = interactionDateTime.add(Duration(days: intervalDays));
    }
    
    // Add some randomness for time of day (between 9 AM and 5 PM)
    final randomHour = 9 + (interactionDateTime.millisecond % 8); // 9 AM - 5 PM
    final randomMinute = interactionDateTime.millisecond % 60;
    
    nextTime = DateTime(
      nextTime.year,
      nextTime.month,
      nextTime.day,
      randomHour,
      randomMinute,
    );
    
    // Ensure the next time is in the future
    final now = DateTime.now();
    if (nextTime.isBefore(now)) {
      // If calculated time is in the past, add one more interval
      final daysDiff = now.difference(nextTime).inDays + 1;
      nextTime = nextTime.add(Duration(days: daysDiff));
    }
    
    return nextTime;
  }

  void _cancelNudge(Nudge nudge, ThemeProvider themeProvider, String userId) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getSurfaceColor(context),
        title: Text('Cancel Nudge', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        content: Text('Are you sure you want to cancel the nudge for ${nudge.contactName}?', style: TextStyle(color: themeProvider.getTextPrimaryColor(context), fontFamily: 'OpenSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep', style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'OpenSans')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              apiService.cancelSingleNudge(nudgeId: nudge.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nudge for ${nudge.contactName} cancelled'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Cancel Nudge', style: TextStyle(color: Colors.red, fontFamily: 'OpenSans')),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(List<Nudge> allNudges, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final firstDay = DateTime(now.year - 1, 1, 1);
    final lastDay = DateTime(now.year + 1, 12, 31);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: themeProvider.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar<Nudge>(
        firstDay: firstDay,
        lastDay: lastDay,
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        calendarFormat: _calendarFormat,
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        eventLoader: (day) => _getNudgesForDay(allNudges, day),
        
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenSans',
            fontSize: 13,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenSans',
            fontSize: 13,
          ),
          defaultTextStyle: TextStyle(
            fontSize: 13,
            color: themeProvider.getTextPrimaryColor(context),
            fontFamily: 'OpenSans'
          ),
          weekendTextStyle: TextStyle(
            fontSize: 13,
            color: themeProvider.getTextPrimaryColor(context),
            fontFamily: 'OpenSans'
          ),
          markerDecoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
          outsideDaysVisible: false,
          cellPadding: const EdgeInsets.all(4),
          cellMargin: EdgeInsets.zero,
          outsideTextStyle: TextStyle(
            color: themeProvider.getTextSecondaryColor(context),
            fontFamily: 'OpenSans',
            fontSize: 13,
          ),
        ),
        
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 14,
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.w600,
            color: themeProvider.getTextPrimaryColor(context),
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
        ),
        
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: themeProvider.getTextPrimaryColor(context),
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenSans',
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: themeProvider.getTextPrimaryColor(context),
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenSans',
            fontSize: 12,
          ),
        ),
        
        rowHeight: 36,
        daysOfWeekHeight: 24,
      ),
    );
  }

  Widget _buildHeader({required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.getBackgroundColor(context),
        border: Border(
          bottom: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.1 : 0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.getSurfaceColor(context),
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: themeProvider.isDarkMode ? AppTheme.darkCardBorder : Colors.grey.shade300, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showCalendar ? Icons.list : Icons.calendar_today,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _showCalendar ? 'View in List' : 'View in Calendar',
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
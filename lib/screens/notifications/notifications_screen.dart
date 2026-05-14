// notifications_screen.dart with Dark Mode and Optimizations
import 'dart:async';

// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/main.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/widgets/log_interaction_modal.dart';
import 'package:nudge/widgets/stitch_top_bar.dart';
import 'package:shimmer/shimmer.dart';

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
  late ApiService apiService;
  
  bool _isSelecting = false;
  Set<String> _selectedNudgeIds = {};
  bool _isCompletionInProgress = false;
  int _completionSuccessCount = 0;
  int _completionTotalCount = 0;
  int _completionErrorCount = 0;

  bool _isCancellingInProgress = false;
  int _cancellationSuccessCount = 0;
  int _cancellationTotalCount = 0;
  int _cancellationErrorCount = 0;

  // bool _hasProcessedPendingNudge = false;
  bool _showCircularProgress = false;
  
  // Optimization: Cache for filtered nudges
  List<Nudge> _lastAllNudges = [];
  List<Nudge> _lastFilteredNudges = [];
  int _lastFilterIndex = -1;
  
  // Debounce timer for filter changes
  Timer? _filterDebounceTimer;
  
  // Cache for categorized nudges
  _CategorizedNudges? _lastCategorized;
  List<Nudge>? _lastCategorizedNudges;
  DateTime? _lastCategorizedDate;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    apiService = ApiService();
    _processOverdueNudges();
    // _processPendingNudge();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // if (!_hasProcessedPendingNudge && widget.pendingNudgeId != null) {
    //   _processPendingNudge();
    // }
    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      // Check if we're returning to this tab
      final modalRoute = ModalRoute.of(context);
      if (modalRoute?.isCurrent == true) {
        // We're on the current screen, ensure first load is false if we have data
        setState(() {
          // This will trigger a rebuild with the correct state
        });
      }
    }
  });
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    super.dispose();
  }

  Nudge defaultNudge() {
    return Nudge(
      id: '', 
      nudgeId: '', 
      contactId: '', 
      contactName: '', 
      nudgeType: '', 
      message: '', 
      scheduledTime: DateTime.now(), 
      userId: '', 
      period: '', 
      frequency: 2, 
      isPushNotification: false, 
      priority: 1, 
      isVIP: false, 
      contactImageUrl: 'contactImageUrl', 
      groupName: 'groupName'
    );
  }

  // Optimization: Memoized filtering
  List<Nudge> _getMemoizedFilteredNudges(List<Nudge> allNudges, int filterIndex) {
    if (_lastAllNudges == allNudges && _lastFilterIndex == filterIndex) {
      return _lastFilteredNudges;
    }
    
    final filtered = _getFilteredNudges(allNudges, filterIndex);
    
    _lastAllNudges = allNudges;
    _lastFilteredNudges = filtered;
    _lastFilterIndex = filterIndex;
    
    return filtered;
  }

  // Optimization: Categorized nudges for list view
  _CategorizedNudges _getCategorizedNudges(List<Nudge> nudges) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Return cached result if same data
    if (_lastCategorizedNudges == nudges && _lastCategorizedDate == today) {
      return _lastCategorized!;
    }
    
    final overdue = <Nudge>[];
    final todayNudges = <Nudge>[];
    final upcoming = <Nudge>[];
    
    for (final nudge in nudges) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      
      if (nudgeDate.isBefore(today)) {
        overdue.add(nudge);
      } else if (nudgeDate == today) {
        todayNudges.add(nudge);
      } else {
        upcoming.add(nudge);
      }
    }
    
    _lastCategorized = _CategorizedNudges(
      overdue: overdue,
      today: todayNudges,
      upcoming: upcoming,
    );
    _lastCategorizedNudges = nudges;
    _lastCategorizedDate = today;
    
    return _lastCategorized!;
  }

  // Debounced filter setter
  void _setFilter(int index) {
    if (_filterDebounceTimer?.isActive ?? false) {
      _filterDebounceTimer!.cancel();
    }
    
    _filterDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _selectedFilter = index;
        });
      }
    });
  }

  // Future<void> _processPendingNudge() async {
  //   if (_hasProcessedPendingNudge) return;
    
  //   await Future.delayed(const Duration(milliseconds: 500));
    
  //   if (!mounted) return;
    
  //   final userId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
  //   final allNudges = await _nudgeService.getAllNudges(userId);
  //   final targetNudge = allNudges.firstWhere(
  //     (nudge) => nudge.id == widget.pendingNudgeId,
  //     orElse: () => defaultNudge(),
  //   );
    
  //   if (targetNudge.id != '' && mounted) {
  //     final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  //     _showNudgeActions(context, themeProvider, targetNudge);
      
  //     setState(() {
  //       _hasProcessedPendingNudge = true;
  //     });
  //   } else {
  //     setState(() {
  //       _hasProcessedPendingNudge = true;
  //     });
  //   }
  // }

  Future<void> _processOverdueNudges() async {
    try {
      final userId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
      await _nudgeService.processOverdueNudges(userId);
    } catch (e) {
      //print('Error processing overdue nudges in UI: $e');
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

  // Loading shimmer
  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surfaceContainerHigh,
            highlightColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  // Error retry widget
  Widget _buildErrorRetry(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Color.fromARGB(255, 206, 37, 85)),
          const SizedBox(height: 16),
          Text(
            'Failed to load nudges',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {});
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: Text('Please log in to view notifications', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily))),
      );
    }
    
    if (!widget.showAppBar) {
      return Scaffold(
        body: StreamBuilder<List<Nudge>>(
          stream: _nudgeService.getNudgesStream(user.uid),
          builder: (context, snapshot) {
            // Handle connection states
           if (snapshot.connectionState == ConnectionState.waiting) {
              if (_isFirstLoad) {
                return _buildLoadingShimmer(themeProvider);
              } else {
                 if (snapshot.hasData) {
                  _isFirstLoad = false;
                }
              }
              // If not first load, continue showing content while loading in background
            } else {
              // Once we have data, set first load to false
              if (snapshot.hasData) {
                _isFirstLoad = false;
              }
            }
            
            if (snapshot.hasError) {
              //print('Error in nudges stream: ${snapshot.error}');
              return _buildErrorRetry(themeProvider);
            }
            
            final allNudges = snapshot.data ?? [];
            final filteredNudges = _getMemoizedFilteredNudges(allNudges, _selectedFilter);
            
            return Scaffold(
              floatingActionButton: _selectedNudgeIds.isNotEmpty && !_isCompletionInProgress && !_isCancellingInProgress
                ? Padding(
                  padding: EdgeInsets.only(top: size.height*0.75),
                  child: Column(
                  children: [
                    FloatingActionButton.extended(
                    onPressed: () => _completeSelectedNudges(context, themeProvider),
                    backgroundColor: AppColors.success,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      'COMPLETE ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
                      style: TextStyle(color: Colors.white, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                    ),
                  ),
                  SizedBox(height: 20,),
                  FloatingActionButton.extended(
                    onPressed: () => _cancelSelectedNudges(context, themeProvider),
                    backgroundColor: Color.fromARGB(255, 206, 37, 85),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: Text(
                      'CANCEL ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
                      style: TextStyle(color: Colors.white, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                    ),
                  )
                  ],
                ))
                : const SizedBox(),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              body: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 500,
                    slivers: [
                      // Stitch top bar (NUDGE wordmark + avatar)
                      SliverAppBar(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        titleSpacing: 0,
                        title: StitchTopBar(
                          avatarUrl: user.photoURL,
                          onTrailingTap: () =>
                              Navigator.pushNamed(context, '/settings'),
                        ),
                        floating: true,
                        snap: true,
                        pinned: false,
                        centerTitle: false,
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: StitchScreenTitle(
                                  title: 'Nudges',
                                  subtitle:
                                      'Today\'s reminders and the week ahead.',
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showCalendar = !_showCalendar;
                                  });
                                },
                                icon: Icon(
                                  _showCalendar
                                      ? Icons.list_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  _showCalendar ? 'List' : 'Calendar',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  foregroundColor: theme.colorScheme.primary,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_isSelecting && !_showCalendar)
                        SliverToBoxAdapter(
                          child: _buildSelectionControls(filteredNudges, themeProvider: themeProvider),
                        ),
                      
                      if (_showCalendar) ...[
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: size.height * 0.9,
                            child: Column(
                              children: [
                                _buildCalendarView(allNudges, themeProvider: themeProvider),
                                const SizedBox(height: 30),
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
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverToBoxAdapter(
                            child: _buildFilterHeader(filteredNudges, themeProvider: themeProvider),
                          ),
                        ),
                        
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
                                  
                                  if (_isSelecting) {
                                    final isSelected = _selectedNudgeIds.contains(nudge.id);
                                    return _buildSelectableNudgeItemWithKey(
                                      nudge, 
                                      isSelected, 
                                      isOverdue, 
                                      context, 
                                      themeProvider: themeProvider
                                    );
                                  } else {
                                    return _buildNormalNudgeItemWithKey(
                                      nudge, 
                                      isOverdue, 
                                      context, 
                                      themeProvider: themeProvider
                                    );
                                  }
                                },
                                childCount: filteredNudges.length,
                                addAutomaticKeepAlives: true,
                                addRepaintBoundaries: true,
                              ),
                            ),
                          )
                      ],
                      
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      ),
                    ],
                  ),
                  
                  _buildCancellationProgressOverlay(themeProvider: themeProvider),
                  _buildCompletionProgressOverlay(themeProvider: themeProvider),
                  if (_showCircularProgress)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            );
          },
        ),
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
            backgroundColor: Color.fromARGB(255, 206, 37, 85),
            icon: const Icon(Icons.cancel, color: Colors.white),
            label: Text(
              'CANCEL ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
            ),
          )
        : const SizedBox(),
      body: StreamBuilder<List<Nudge>>(
        stream: _nudgeService.getNudgesStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingShimmer(themeProvider);
          }
          
          if (snapshot.hasError) {
            return _buildErrorRetry(themeProvider);
          }
          
          final allNudges = snapshot.data ?? [];
          final filteredNudges = _getMemoizedFilteredNudges(allNudges, _selectedFilter);
          
          return Stack(
            children: [
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    _buildHeader(themeProvider: themeProvider),
                    
                    if (_showCalendar) ...[
                      SizedBox(
                        height: size.height * 0.9,
                        child: Column(
                          children: [
                            _buildCalendarView(allNudges, themeProvider: themeProvider),
                            const SizedBox(height: 30),
                            Expanded(
                              child: _selectedDay != null
                                  ? _buildDayNudges(_getNudgesForDay(allNudges, _selectedDay!), context, themeProvider: themeProvider)
                                  : _buildEmptyDayState(themeProvider: themeProvider),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (_isSelecting)
                        _buildSelectionControls(filteredNudges, themeProvider: themeProvider),
                      
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
              
              _buildCancellationProgressOverlay(themeProvider: themeProvider),
              if (_showCircularProgress)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }

  // Optimized nudge list builder
  Widget _buildNudgeList(List<Nudge> nudges, {required ThemeProvider themeProvider}) {
    final categorized = _getCategorizedNudges(nudges);
    
    return ListView(
      key: const PageStorageKey<String>('nudge_list'),
      children: [
        if (categorized.overdue.isNotEmpty) ...[
          _buildSectionHeader('Overdue', categorized.overdue.length, themeProvider: themeProvider),
          ...categorized.overdue.map((nudge) => _buildNormalNudgeItemWithKey(nudge, true, context, themeProvider: themeProvider)),
        ],
        if (categorized.today.isNotEmpty) ...[
          _buildSectionHeader('Today', categorized.today.length, themeProvider: themeProvider),
          ...categorized.today.map((nudge) => _buildNormalNudgeItemWithKey(nudge, false, context, themeProvider: themeProvider)),
        ],
        if (categorized.upcoming.isNotEmpty) ...[
          _buildSectionHeader('Upcoming', categorized.upcoming.length, themeProvider: themeProvider),
          ...categorized.upcoming.map((nudge) => _buildNormalNudgeItemWithKey(nudge, false, context, themeProvider: themeProvider)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSelectableNudgeItem(Nudge nudge, bool isSelected, bool isOverdue, BuildContext context, {required ThemeProvider themeProvider}) {
    final bool isBirthday = nudge.message.toLowerCase().contains('birthday');
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
          fontFamily: GoogleFonts.beVietnamPro().fontFamily,
          fontWeight: FontWeight.w600,
          color: isBirthday
                          ? Colors.green.shade600
                          : isOverdue ? Color.fromRGBO(243, 87, 87, 1) : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(nudge.message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
      trailing: Text(
        DateFormat('MMM d, h:mm a').format(nudge.scheduledTime),
        style: TextStyle(
          fontSize: 12,
          fontFamily: GoogleFonts.beVietnamPro().fontFamily,
          color: isBirthday
                          ? Colors.green.shade600
                          : isOverdue ? Color.fromRGBO(243, 87, 87, 1) : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildSelectableNudgeItemWithKey(Nudge nudge, bool isSelected, bool isOverdue, BuildContext context, {required ThemeProvider themeProvider}) {
    return RepaintBoundary(
      key: ValueKey('selectable_${nudge.id}_${isSelected}'),
      child: _buildSelectableNudgeItem(nudge, isSelected, isOverdue, context, themeProvider: themeProvider),
    );
  }

  Widget _buildNormalNudgeItemWithKey(Nudge nudge, bool isOverdue, BuildContext context, {required ThemeProvider themeProvider}) {
    return RepaintBoundary(
      key: ValueKey('nudge_${nudge.id}_${nudge.isCompleted}_${isOverdue}'),
      child: _buildNormalNudgeItem(nudge, isOverdue, context, themeProvider: themeProvider),
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
                style: TextStyle(color: theme.colorScheme.primary, fontSize: 15, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary),
                padding: EdgeInsets.only(left: 5, right: 5, top: 15, bottom: 15)
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exitSelectionMode,
              icon: Icon(Icons.cancel, color: Color.fromARGB(255, 206, 37, 85)),
              label: Text('CANCEL', style: TextStyle(color: Color.fromARGB(255, 206, 37, 85), fontSize: 15, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color.fromARGB(255, 206, 37, 85)),
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildCompletionProgressOverlay({required ThemeProvider themeProvider}) {
    if (!_isCompletionInProgress) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 256,
      left: 16,
      right: 50,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Completing Nudges',
                style: TextStyle(
                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 17, 213, 46),
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _completionTotalCount > 0 
                    ? _completionSuccessCount / _completionTotalCount 
                    : 0,
                backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surfaceContainerLowest,
                valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 13, 199, 54)),
              ),
              const SizedBox(height: 8),
              Text(
                '$_completionSuccessCount of $_completionTotalCount nudges completed'
                '${_completionErrorCount > 0 ? ' ($_completionErrorCount errors)' : ''}',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _buildCancellationProgressOverlay({required ThemeProvider themeProvider}) {
    if (!_isCancellingInProgress) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 256,
      left: 16,
      right: 50,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                'Cancelling Nudges',
                style: TextStyle(
                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 206, 37, 85),
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _cancellationTotalCount > 0 
                    ? _cancellationSuccessCount / _cancellationTotalCount 
                    : 0,
                backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surfaceContainerLowest,
                valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 206, 37, 85)),
              ),
              const SizedBox(height: 8),
              Text(
                '$_cancellationSuccessCount of $_cancellationTotalCount nudges cancelled'
                '${_cancellationErrorCount > 0 ? ' ($_cancellationErrorCount errors)' : ''}',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text('CANCEL NUDGES', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
        content: Text('Are you sure you want to cancel ${_selectedNudgeIds.length} nudge${_selectedNudgeIds.length == 1 ? '' : 's'}?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Cancel Nudges', style: TextStyle(color: Color.fromARGB(255, 206, 37, 85), fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _startCancellationProcess();
    }
  }


    Future<void> _completeSelectedNudges(BuildContext context, ThemeProvider themeProvider) async {
    if (_selectedNudgeIds.isEmpty) return;
    
    final theme = Theme.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text('COMPLETE NUDGES', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
        content: Text('Are you sure you want to complete ${_selectedNudgeIds.length} nudge${_selectedNudgeIds.length == 1 ? '' : 's'}?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Complete Nudges', style: TextStyle(color: Color.fromARGB(255, 14, 203, 67), fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _startCompletionProcess();
    }
  }

    void _startCompletionProcess() async {
    // final userId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
    
    setState(() {
      _isCompletionInProgress = true;
      _completionSuccessCount = 0;
      _completionErrorCount = 0;
      _completionTotalCount = _selectedNudgeIds.length;
    });
    final contacts = await apiService.getAllContacts();
    for (String nudgeId in _selectedNudgeIds) {
      try {
          Nudge thisNudge = _lastAllNudges.where((nudge) => nudge.id == nudgeId).first;
          final contact = contacts.firstWhere(
            (c) => c.name == thisNudge.contactName,
          );
          
          final DateTime interactionDateTime = DateTime.now();
          
          DateTime nextScheduledTime = _calculateNextNudgeTime(
            contact, 
            interactionDateTime,
          );
          
          await apiService.cancelSingleNudge(nudgeId: thisNudge.id);
          await apiService.deleteNudgeFromFirestore(nudgeId: thisNudge.id);

          if (thisNudge.nudgeType == 'event') {
            return;
          }
          
          await apiService.scheduleSingleNudge(
            contactId: contact.id,
            scheduledTime: nextScheduledTime,
          );

          setState(() {
          _completionSuccessCount++;
        });
          
        } catch (e) {
        setState(() {
          _completionErrorCount++;
        });
        //print('Error completing nudge $nudgeId: $e');
        return;
      }
    }
    
    if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       'Completed $_completionSuccessCount nudge${_completionSuccessCount == 1 ? '' : 's'}${_completionErrorCount > 0 ? '. $_completionErrorCount failed' : ''}',
      //     ),
      //     duration: const Duration(seconds: 3),
      //   ),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'Completed $_completionSuccessCount nudge${_completionSuccessCount == 1 ? '' : 's'}${_completionErrorCount > 0 ? '. $_completionErrorCount failed' : ''}',
          backgroundColor: AppColors.success,
          icon: Icons.check,
        );
    }
    
    setState(() {
      _isCompletionInProgress = false;
      _isSelecting = false;
      _selectedNudgeIds.clear();
    });
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
        //print('Error cancelling nudge $nudgeId: $e');
      }
    }
    
    if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       'Cancelled $_cancellationSuccessCount nudge${_cancellationSuccessCount == 1 ? '' : 's'}${_cancellationErrorCount > 0 ? '. $_cancellationErrorCount failed' : ''}',
      //     ),
      //     duration: const Duration(seconds: 3),
      //   ),
      // );
       TopMessageService().showMessage(
        context: context,
        message: 'Cancelled $_cancellationSuccessCount nudge${_cancellationSuccessCount == 1 ? '' : 's'}${_cancellationErrorCount > 0 ? '. $_cancellationErrorCount failed' : ''}',
        backgroundColor: Colors.blueGrey,
        icon: Icons.info,
      );
    }
    
    setState(() {
      _isCancellingInProgress = false;
      _isSelecting = false;
      _selectedNudgeIds.clear();
    });
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

  IconData _getGroupIcon(String groupName) {
    if (groupName.toLowerCase().contains('family')) return Icons.family_restroom;
    if (groupName.toLowerCase().contains('friend')) return Icons.people;
    if (groupName.toLowerCase().contains('work') || groupName.toLowerCase().contains('colleague')) return Icons.work;
    if (groupName.toLowerCase().contains('client')) return Icons.business_center;
    if (groupName.toLowerCase().contains('mentor')) return Icons.school;
    return Icons.group;
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
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
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
                return _buildNormalNudgeItemWithKey(nudge, isOverdue, context, themeProvider: themeProvider);
              },
              addAutomaticKeepAlives: false,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No nudges scheduled',
              style: TextStyle(
                fontSize: 16,
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      const Color.fromRGBO(45, 161, 175, 0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildCompactFilterToggle('TODAY', 0, themeProvider: themeProvider),
                      Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                      _buildCompactFilterToggle('THIS WEEK', 1, themeProvider: themeProvider),
                      Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
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
            color: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onInverseSurface, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            color: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.9),
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
        onTap: () => _setFilter(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
        
      case 2: // This Month
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final daysLeftInMonth = lastDayOfMonth.difference(now).inDays;
        
        final DateTime endDate;
        if (daysLeftInMonth < 5) {
          endDate = now.add(const Duration(days: 30));
        } else {
          endDate = lastDayOfMonth;
        }
        
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontFamily: GoogleFonts.beVietnamPro().fontFamily,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caught up! 🎉',
            style: TextStyle(
              fontSize: 14,
              fontFamily: GoogleFonts.beVietnamPro().fontFamily,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
              fontFamily: GoogleFonts.beVietnamPro().fontFamily,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNudgeAvatar(Nudge nudge, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final scheme = Theme.of(context).colorScheme;
    final initials = _getContactInitials(nudge.contactName);
    final iconIndex = getRandomIndex(nudge.contactId);
    final assetPath = 'assets/contact-icons/$iconIndex.png';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: nudge.contactImageUrl.isNotEmpty
                ? Image.network(
                    nudge.contactImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Image.asset(assetPath, fit: BoxFit.cover),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(assetPath, fit: BoxFit.cover),
                      Container(
                        color: Colors.black.withOpacity(isDark ? 0.38 : 0.20),
                      ),
                      Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
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
                  ),
          ),
        ),
        // VIP star badge
        if (nudge.isVIP)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.vipGold,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: const Icon(Icons.star, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildNormalNudgeItem(Nudge nudge, bool isOverdue, BuildContext context, {required ThemeProvider themeProvider}) {
    final theme = Theme.of(context);
    // final initials = _getContactInitials(nudge.contactName);
    // final iconIndex = getRandomIndex(nudge.contactId);
    String message = 'Time to reconnect.';
    
    final bool isBirthday = nudge.message.toLowerCase().contains('birthday');
    
    if (nudge.message.contains('Rescheduled') || nudge.isSnoozed){
      message = 'Time to reconnect | [Rescheduled]';
    }

    if (nudge.message.contains('birthday')){
      message = nudge.message;
    }
    
    // final Color? birthdayTextColor = isBirthday ? Colors.green.shade700 : null;
    // final Color? birthdaySubtitleColor = isBirthday ? Colors.green.shade600 : null;
    final Color? birthdayCardColor = isBirthday 
        ? (themeProvider.isDarkMode 
            ? const Color.fromARGB(255, 40, 143, 47).withOpacity(0.3) 
            : Colors.green.shade50) 
        : null;
    
    return Dismissible(
      key: Key(nudge.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground('complete', context, themeProvider: themeProvider),
      secondaryBackground: _buildSwipeBackground('snooze', context, themeProvider: themeProvider),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          _showSnoozeDialog(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
          return false;
        } else {
          return await _confirmCompleteNudge(nudge, context, themeProvider);
        }
      },
      onDismissed: (direction) {
        //print('Nudge dismissed: ${nudge.id}');
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
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0.7,
          color: birthdayCardColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: _buildNudgeAvatar(nudge, themeProvider),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    nudge.contactName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      color:/*  isBirthday
                          ? Colors.green.shade600
                          :  */isOverdue && !isBirthday
                          ? const Color.fromRGBO(243, 87, 87, 1) 
                          : (Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
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
                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time, 
                      size: 12, 
                      color: Theme.of(context).colorScheme.onSurfaceVariant
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(nudge.scheduledTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                        color: /* isBirthday
                          ? Colors.green.shade600
                          :  */ isOverdue  && !isBirthday
                            ? const Color.fromRGBO(243, 87, 87, 1)  
                            : (Theme.of(context).colorScheme.onSurfaceVariant),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: nudge.isCompleted 
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : isBirthday
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text('🎉', style: TextStyle(fontSize: 16)))
                  : isOverdue
                    ? Padding(
                      padding: const EdgeInsets.only(bottom: 50),
                      child: Icon(Icons.warning, color: const Color.fromRGBO(243, 87, 87, 1), size: 16),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text(
          'Complete Nudge',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Mark nudge for ${nudge.contactName} as complete?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Complete', style: TextStyle(color: AppColors.success, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final modalResult = await _showLogInteractionModalForNudge(context, themeProvider, nudge);
      
      if (modalResult == null || modalResult['success'] != true) {
        try {
          final contacts = await apiService.getAllContacts();
          final contact = contacts.firstWhere(
            (c) => c.name == nudge.contactName,
          );
          
          final DateTime interactionDateTime = modalResult!['interactionDateTime'];
          
          DateTime nextScheduledTime = _calculateNextNudgeTime(
            contact, 
            interactionDateTime,
          );
          
          await apiService.cancelSingleNudge(nudgeId: nudge.id);
          await apiService.deleteNudgeFromFirestore(nudgeId: nudge.id);

          if (nudge.nudgeType == 'event') {
            return true;
          }
          
          await apiService.scheduleSingleNudge(
            contactId: contact.id,
            scheduledTime: nextScheduledTime,
          );
          
        } catch (e) {
          return false;
        }
      }
    }
    
    return false;
  }
  
  Future<Map<String, dynamic>?> _showLogInteractionModalForNudge(BuildContext context, ThemeProvider themeProvider, Nudge nudge) async {
    try {
      final contacts = await apiService.getAllContacts();
      final contact = contacts.where((contact) {
        return contact.name == nudge.contactName;
      }).first;
      
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: navigatorKey.currentContext!,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: themeProvider.getSurfaceColor(navigatorKey.currentContext!),
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
      
      return result;
      
    } catch (e) {
      //print('Error showing log interaction modal: $e');
      // Flushbar(
      //   padding: const EdgeInsets.all(10), 
      //   borderRadius: BorderRadius.zero, 
      //   duration: const Duration(seconds: 2),
      //   flushbarPosition: FlushbarPosition.TOP, 
      //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
      //   messageText: Center(
      //     child: Text('Error: $e', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
      //         color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400)),
      //   ),
      // ).show(navigatorKey.currentContext!);
       TopMessageService().showMessage(
          context: context,
          message: 'Error: $e',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
      return null;
    }
  }

  Widget _buildSwipeBackground(String action, BuildContext context, {required ThemeProvider themeProvider}) {
    // final theme = Theme.of(context);
    Color color;
    IconData icon;

    if (action == 'complete') {
      color = const Color.fromARGB(255, 28, 174, 35);
      icon = Icons.check;
    } else {
      color = const Color.fromARGB(255, 243, 122, 57);
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
                title: Text('View Contact', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                onTap: () {
                  Navigator.pop(context);
                  _viewContact(nudge.contactName);
                },
              ),
              ListTile(
                leading: Icon(Icons.schedule, color: Theme.of(context).colorScheme.onSurface),
                title: Text('Adjust Frequency', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                onTap: () {
                  Navigator.pop(context);
                  _showFrequencyDialog(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: Icon(Icons.snooze, color: Theme.of(context).colorScheme.onSurface),
                title: Text('Snooze', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                onTap: () {
                  Navigator.pop(context);
                  _showSnoozeDialog(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onSurface),
                title: Text('Mark Complete', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmCompleteNudge(nudge, context, themeProvider);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: Theme.of(context).colorScheme.onSurface),
                title: Text('Cancel Nudge', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                onTap: () {
                  Navigator.pop(context);
                  _cancelNudge(nudge, themeProvider, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              if (!_isSelecting)
                ListTile(
                  leading: Icon(Icons.select_all, color: Theme.of(context).colorScheme.onSurface),
                  title: Text('Select Multiple', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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

  void _viewContact(String contactName) {
    final contacts = Provider.of<List<Contact>>(context, listen: false);
    final contact = contacts.firstWhere(
      (contact) => contact.name == contactName,
    );
    
    if (contact.id.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContactDetailScreen(contact: contact),
        ),
      );
    } else {
     TopMessageService().showMessage(
        context: context,
        message: 'Contact not found.',
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
    }
  }

  void _showSnoozeDialog(Nudge nudge, ThemeProvider themeProvider, String userId){
    final theme = Theme.of(context);
    int selectedSnoozeHours = 4;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            title: Text('Snooze Nudge', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How long would you like to snooze this nudge?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedSnoozeHours,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
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
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
              ),
              TextButton(
                onPressed: () async{
                  Navigator.pop(context);
                  final contacts = await apiService.getAllContacts();
                  final contact = contacts.firstWhere(
                    (c) => c.name == nudge.contactName,
                  );

                  final newScheduledTime = DateTime.now().add(Duration(hours: selectedSnoozeHours));
                  apiService.cancelSingleNudge(nudgeId: nudge.id);
                  apiService.scheduleSingleNudge(contactId: contact.id, scheduledTime: newScheduledTime, rescheduled: true);
                  
                  if (mounted) {
                    // Flushbar(
                    //   padding: const EdgeInsets.all(10), 
                    //   borderRadius: BorderRadius.zero, 
                    //   duration: const Duration(seconds: 2),
                    //   flushbarPosition: FlushbarPosition.TOP, 
                    //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                    //   messageText: Center(
                    //     child: Text('Nudge snoozed for $selectedSnoozeHours hour${selectedSnoozeHours > 1 ? 's' : ''}', 
                    //       style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
                    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400)),
                    //   ),
                    // ).show(context);
                     TopMessageService().showMessage(
                        context: context,
                        message: 'Nudge snoozed for $selectedSnoozeHours hour${selectedSnoozeHours > 1 ? 's' : ''}',
                        backgroundColor: Colors.blueGrey,
                        icon: Icons.info,
                      );
                  }
                },
                child: Text('Snooze', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
              ),
            ],
          );
        },
      ),
    );
  }

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
    
    if (contact.frequency > 1) {
      final totalDays = nextTime.difference(interactionDateTime).inDays;
      final intervalDays = totalDays ~/ contact.frequency;
      nextTime = interactionDateTime.add(Duration(days: intervalDays));
    }
    
    final randomHour = 9 + (interactionDateTime.millisecond % 8);
    final randomMinute = interactionDateTime.millisecond % 60;
    
    nextTime = DateTime(
      nextTime.year,
      nextTime.month,
      nextTime.day,
      randomHour,
      randomMinute,
    );
    
    final now = DateTime.now();
    if (nextTime.isBefore(now)) {
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text('Cancel Nudge', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
        content: Text('Are you sure you want to cancel the nudge for ${nudge.contactName}?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep', style: TextStyle(color: theme.colorScheme.primary, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              apiService.cancelSingleNudge(nudgeId: nudge.id);
              if (mounted) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text('Nudge for ${nudge.contactName} cancelled'),
                //     backgroundColor: AppColors.warning,
                //   ),
                // );
                TopMessageService().showMessage(
                  context: context,
                  message: 'Nudge for ${nudge.contactName} cancelled',
                  backgroundColor: Colors.blueGrey,
                  icon: Icons.info,
                );
              }
            },
            child: Text('Cancel Nudge', style: TextStyle(color: Color.fromARGB(255, 206, 37, 85), fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
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
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            fontSize: 13,
          ),
          selectedTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            fontSize: 13,
          ),
          defaultTextStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily
          ),
          weekendTextStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            fontSize: 13,
          ),
        ),
        
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 14,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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
        color: Theme.of(context).scaffoldBackgroundColor,
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
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              foregroundColor: theme.colorScheme.primary,
              shape: const StadiumBorder(),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
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

  void _showFrequencyDialog(Nudge nudge, ThemeProvider themeProvider, String userId) async {
    final theme = Theme.of(context);
    final apiService = Provider.of<ApiService>(context, listen: false);
    // final thisUser = await apiService.getUser();
    
    // Get all contacts and current groups
    List<Contact> contacts = await apiService.getAllContacts();
    List<SocialGroup> allGroups = await apiService.getGroupsStream().first;
    
    // Find the current contact and their group
    Contact nudgeContact = contacts.where((contact) => contact.name == nudge.contactName).first;
    SocialGroup? currentGroup = allGroups.firstWhere(
      (group) => group.name == nudgeContact.connectionType || group.id == nudgeContact.connectionType,
      orElse: () => SocialGroup.empty(),
    );
    
    // Variable to track selected group
    SocialGroup? selectedGroup;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              title: Text(
                'Adjust Social Group',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current contact info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: themeProvider.isDarkMode 
                                ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                : Colors.transparent,
                            backgroundImage: nudgeContact.imageUrl.isNotEmpty
                                ? NetworkImage(nudgeContact.imageUrl)
                                : AssetImage('assets/contact-icons/${getRandomIndex(nudgeContact.id)}.png') as ImageProvider,
                            child: nudgeContact.imageUrl.isEmpty
                                ? Text(
                                    _getContactInitials(nudgeContact.name).toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
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
                                  nudgeContact.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                  ),
                                ),
                                Text(
                                  'Current: ${currentGroup.name!='' ? currentGroup.name: 'No group'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      'Select a new group:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Groups list
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allGroups.length,
                        itemBuilder: (context, index) {
                          final group = allGroups[index];
                          final isSelected = selectedGroup?.id == group.id;
                          final isCurrentGroup = group.id == currentGroup.id;
                          
                          // Skip current group if you don't want to show it (optional)
                          // if (isCurrentGroup) return const SizedBox.shrink();
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedGroup = group;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? theme.colorScheme.primary.withOpacity(0.1)
                                    : themeProvider.isDarkMode 
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                        : Theme.of(context).colorScheme.surfaceDim,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : isCurrentGroup
                                          ? AppColors.success.withOpacity(0.3)
                                          : themeProvider.isDarkMode 
                                              ? AppColors.darkSurfaceContainerHighest 
                                              : Theme.of(context).colorScheme.surfaceContainerLowest,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Group icon with color
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getGroupIcon(group.name),
                                      color: Theme.of(context).colorScheme.onSurface,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Group details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                group.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                                ),
                                              ),
                                            ),
                                            if (isCurrentGroup)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success,
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  'Current',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
                                            fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                          ),
                                        ),
                                        // const SizedBox(height: 2),
                                        // Text(
                                        //   '${group.memberCount} members',
                                        //   style: TextStyle(
                                        //     fontSize: 11,
                                        //     color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        //     fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                                        //   ),
                                        // ),
                                      ],
                                    ),
                                  ),
                                  // Radio button or checkmark
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                      size: 24,
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
                      'The contact will inherit the frequency settings of the selected group.',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedGroup == null || selectedGroup?.id == currentGroup.id
                      ? null // Disable if no selection or same group
                      : () async {
                          // Show loading indicator
                          Navigator.pop(context); // Close selection dialog
                          _showMovingMessage();
                          // setState(() {
                          //   _showCircularProgress = true;
                          // });
                          
                          try {
                            // Update the contact with new group settings
                            final updatedContact = nudgeContact.copyWith(
                              connectionType: selectedGroup!.name,
                              period: selectedGroup!.period,
                              frequency: selectedGroup!.frequency,
                            );
                            
                            // Update contact in database
                            await apiService.updateContact(updatedContact);
                            
                            // Update group member counts (remove from old group, add to new group)
                            if (currentGroup.id.isNotEmpty) {
                              final updatedOldGroup = currentGroup.copyWith(
                                memberIds: List.from(currentGroup.memberIds)..remove(updatedContact.id),
                                memberCount: currentGroup.memberCount - 1,
                              );
                              await apiService.updateGroup(updatedOldGroup);
                            }
                            
                            final updatedNewGroup = selectedGroup!.copyWith(
                              memberIds: [...selectedGroup!.memberIds, updatedContact.id],
                              memberCount: selectedGroup!.memberCount + 1,
                            );
                            await apiService.updateGroup(updatedNewGroup);
                            
                            // Cancel the current nudge
                            await apiService.cancelSingleNudge(nudgeId: nudge.id);
                            await apiService.deleteNudgeFromFirestore(nudgeId: nudge.id);
                            
                            // Calculate and schedule new nudge based on new group's frequency
                            DateTime nextScheduledTime = _calculateNextNudgeTime(
                              updatedContact,
                              DateTime.now(),
                            );
                            
                            await apiService.scheduleSingleNudge(
                              contactId: updatedContact.id,
                              scheduledTime: nextScheduledTime,
                            );
                            
                            // setState(() {
                            //   _showCircularProgress = false;
                            // });
                            
                            // Show success message
                          _showSuccessMessage('${updatedContact.name} moved to "${selectedGroup!.name}" group');
                          } catch (e) {
                            // setState(() {
                            //   _showCircularProgress = false;
                            // });
                            
                            _showFailureMessage('Failed to reassign contact: $e');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedGroup == null || selectedGroup?.id == currentGroup.id
                        ? Theme.of(context).colorScheme.outline
                        : theme.colorScheme.primary,
                  ),
                  child: Text(
                    selectedGroup == null 
                        ? 'Select a Group' 
                        : (selectedGroup?.id == currentGroup.id 
                            ? 'Already in this Group' 
                            : 'Reassign to Group'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
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

  _showMovingMessage(){
    // Flushbar(
    //   padding: const EdgeInsets.all(10),
    //   borderRadius: BorderRadius.zero,
    //   duration: const Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP,
    //   backgroundColor: Colors.black,
    //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
    //   messageText: Center(
    //     child: Text(
    //       'Reassigning contact to new group...',
    //       style: TextStyle(
    //         fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    //         fontSize: 14,
    //         color: Theme.of(context).colorScheme.onSurface,
    //         fontWeight: FontWeight.w400,
    //       ),
    //     ),
    //   ),
    // ).show(navigatorKey.currentContext!);
     TopMessageService().showMessage(
        context: context,
        message: 'Reassigning contact to new group...',
        backgroundColor: Colors.blueGrey,
        icon: Icons.info,
      );
  }

  _showSuccessMessage(String message) {
    // Flushbar(
    //   padding: const EdgeInsets.all(10),
    //   borderRadius: BorderRadius.zero,
    //   duration: const Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP,
    //   backgroundColor: AppColors.success,
    //   dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
    //   messageText: Center(
    //     child: Text(
    //       message,
    //       style: TextStyle(
    //         fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    //         fontSize: 14,
    //         color: Theme.of(context).colorScheme.onSurface,
    //         fontWeight: FontWeight.w400,
    //       ),
    //     ),
    //   ),
    // ).show(navigatorKey.currentContext!);
     TopMessageService().showMessage(
        context: context,
        message: message,
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
  }

  _showFailureMessage(String message) {
    // Flushbar(
    //     padding: const EdgeInsets.all(10),
    //     borderRadius: BorderRadius.zero,
    //     duration: const Duration(seconds: 2),
    //     flushbarPosition: FlushbarPosition.TOP,
    //     backgroundColor: Theme.of(context).colorScheme.tertiary,
    //     dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //     forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
    //     messageText: Center(
    //       child: Text(
    //         message,
    //         style: TextStyle(
    //           fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    //           fontSize: 14,
    //           color: Theme.of(context).colorScheme.onSurface,
    //           fontWeight: FontWeight.w400,
    //         ),
    //       ),
    //     ),
    //   ).show(navigatorKey.currentContext!);
     TopMessageService().showMessage(
        context: context,
        message: message,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
  }

}

// Helper class for categorized nudges
class _CategorizedNudges {
  final List<Nudge> overdue;
  final List<Nudge> today;
  final List<Nudge> upcoming;
  
  _CategorizedNudges({
    required this.overdue,
    required this.today,
    required this.upcoming,
  });
}
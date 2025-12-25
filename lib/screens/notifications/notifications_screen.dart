import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/nudge.dart';
// import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  
  const NotificationsScreen({super.key, this.showAppBar = true});

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
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastOffset = 0.0;
  
  bool _isSelecting = false;
  Set<String> _selectedNudgeIds = {};
  bool _isCancellingInProgress = false;
  int _cancellationSuccessCount = 0;
  int _cancellationTotalCount = 0;
  int _cancellationErrorCount = 0;

   @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
     _scrollController.addListener(() {
      _handleScroll();
    });
    _processOverdueNudges();
  }

  void _handleScroll() {
    final currentOffset = _scrollController.offset;
    
    // Show header when scrolling up, hide when scrolling down
    if (currentOffset > _lastOffset && currentOffset > 50) {
      if (_showHeader) {
        setState(() {
          _showHeader = false;
        });
      }
    } else if (currentOffset < _lastOffset && _scrollController.offset <= 50) {
      if (!_showHeader) {
        setState(() {
          _showHeader = true;
        });
      }
    }
    
    _lastOffset = currentOffset;
  }

    // Add these selection methods:

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedNudgeIds.clear();
    });
  }

  void _toggleSelectAll(List<Nudge> visibleNudges) {
  setState(() {
    if (_selectedNudgeIds.length == visibleNudges.length) {
      // Deselect all
      _selectedNudgeIds.clear();
    } else {
      // Select all visible nudges
      _selectedNudgeIds = Set<String>.from(visibleNudges.map((nudge) => nudge.id));
    }
  });
}

  // List<Nudge> _getVisibleNudges(List<Nudge> allNudges) {
  //   return _getFilteredNudges(allNudges, _selectedFilter);
  // }

  Widget _buildSelectableNudgeItem(Nudge nudge, bool isSelected, bool isOverdue, BuildContext context) {
    return ListTile(
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
          fontWeight: FontWeight.w600,
          color: isOverdue ? Colors.orange[800] : const Color(0xff555555),
        ),
      ),
      subtitle: Text(nudge.message),
      trailing: Text(
        DateFormat('MMM d, h:mm a').format(nudge.scheduledTime),
        style: TextStyle(
          fontSize: 12,
          color: isOverdue ? Colors.orange[800] : Colors.grey[600],
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

  Widget _buildSelectionControls(List<Nudge> visibleNudges) {
    if (!_isSelecting) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: const Color.fromRGBO(45, 161, 175, 0.1),
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
                color: const Color(0xff3CB3E9),
              ),
              label: Text(
                _selectedNudgeIds.length == visibleNudges.length && _selectedNudgeIds.isNotEmpty
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

  Widget _buildCancellationProgressOverlay() {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cancelling Nudges',
                style: TextStyle(
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
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$_cancellationSuccessCount of $_cancellationTotalCount nudges cancelled'
                '${_cancellationErrorCount > 0 ? ' ($_cancellationErrorCount errors)' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelSelectedNudges(BuildContext context) async {
    if (_selectedNudgeIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CANCEL NUDGES', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff555555))),
        content: Text('Are you sure you want to cancel ${_selectedNudgeIds.length} nudge${_selectedNudgeIds.length == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Nudges', style: TextStyle(color: Colors.red)),
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
    
    // Process each selected nudge
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
    
    // Show result and clean up
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cancelled $_cancellationSuccessCount nudge${_cancellationSuccessCount == 1 ? '' : 's'}${_cancellationErrorCount > 0 ? '. $_cancellationErrorCount failed' : ''}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Reset everything
    setState(() {
      _isCancellingInProgress = false;
      _isSelecting = false;
      _selectedNudgeIds.clear();
    });
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

// Update the build method to handle both modes
@override
Widget build(BuildContext context) {
  final authService = Provider.of<AuthService>(context);
  final user = authService.currentUser;
  
  // When used from dashboard (showAppBar: false), use CustomScrollView
  if (!widget.showAppBar) {
    return StreamBuilder<List<Nudge>>(
      stream: _nudgeService.getNudgesStream(user!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final allNudges = snapshot.data ?? [];
        final filteredNudges = _getFilteredNudges(allNudges, _selectedFilter);
        
        return Scaffold(
           floatingActionButton: Padding(
              padding: EdgeInsets.only(right: 6,bottom: 30,),
              child: _selectedNudgeIds.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => _cancelSelectedNudges(context),
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: Text(
                      'CANCEL ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : FeedbackFloatingButton(
                    currentSection: 'notifications',
                  ),
            ),
          body: Stack(
            children: [
              CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Sliver App Bar with Calendar Toggle
                    SliverAppBar(
                      title: Padding(
                        padding: EdgeInsets.only(left: 30),
                        child: Text('Nudges',style: TextStyle(fontSize: 23,fontWeight: FontWeight.w600,color: Color(0xff555555))),
                        ),
                      centerTitle: false,
                      leading: Center(),
                      backgroundColor: Color(0xFFF9FAFB),
                      floating: true,
                      snap: true,
                      pinned: false,
                      actions: [
                        if (_isSelecting)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: _exitSelectionMode,
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showCalendar = !_showCalendar;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[50],
                                foregroundColor: const Color(0xff3CB3E9),
                                side: BorderSide(color: Colors.grey.shade300, width: 1),
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
                          child: _buildSelectionControls(filteredNudges),
                        ),
                    
                    if (_showCalendar) ...[
                      // Calendar View
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverToBoxAdapter(
                          child: _buildCalendarView(allNudges),
                        ),
                      ),
                      
                      if (_selectedDay != null)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: _buildDayNudges(_getNudgesForDay(allNudges, _selectedDay!), context),
                          ),
                        ),
                    ] else ...[
                      // List View - Filter Header
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverToBoxAdapter(
                          child: _buildFilterHeader(filteredNudges),
                        ),
                      ),
                      
                      // Nudges List
                      if (filteredNudges.isEmpty)
                        SliverFillRemaining(
                          child: _buildEmptyState(),
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
                                    ? _buildSelectableNudgeItem(nudge, isSelected, isOverdue, context)
                                    : _buildNormalNudgeItem(nudge, isOverdue, context);
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
              
              // Cancellation progress overlay
              _buildCancellationProgressOverlay(),
            ],
        ));
      },
    );
  }
  
    // Original implementation for standalone use
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudges & Reminders'),
        backgroundColor: const Color(0xff3CB3E9),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 50),
        child: _selectedNudgeIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _cancelSelectedNudges(context),
              backgroundColor: Colors.red,
              icon: const Icon(Icons.cancel, color: Colors.white),
              label: Text(
                'CANCEL ${_selectedNudgeIds.length} NUDGE${_selectedNudgeIds.length == 1 ? '' : 'S'}',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : FeedbackFloatingButton(
              currentSection: 'notifications',
            ),
      ),
    body: StreamBuilder<List<Nudge>>(
      stream: _nudgeService.getNudgesStream(Provider.of<AuthService>(context).currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final allNudges = snapshot.data ?? [];
        final filteredNudges = _getFilteredNudges(allNudges, _selectedFilter);
        
        return Stack(
          children: [
            Column(
              children: [
                // Header with title and view toggle
                _buildHeader(),
                
                if (_showCalendar) ...[
                  // Calendar View
                  _buildCalendarView(allNudges),
                  const SizedBox(height: 16),
                  if (_selectedDay != null)
                    _buildDayNudges(_getNudgesForDay(allNudges, _selectedDay!), context),
                ] else ...[
                  // Selection Controls (only when selecting)
                  if (_isSelecting)
                    _buildSelectionControls(filteredNudges),
                  
                  // List View (Original)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildFilterHeader(filteredNudges),
                  ),
                  
                  Expanded(
                    child: filteredNudges.isEmpty
                        ? _buildEmptyState()
                        : _buildNudgeList(filteredNudges),
                  ),
                ],
              ],
            ),
            
            // Cancellation progress overlay
            _buildCancellationProgressOverlay(),
          ],
        );
      },
    ),
  );
}


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // View Toggle moved to left
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[50],
              foregroundColor: const Color(0xff3CB3E9),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
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

  Widget _buildCalendarView(List<Nudge> allNudges) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar<Nudge>(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2025, 12, 31),
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
            color: const Color(0xff3CB3E9).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Color(0xff3CB3E9),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: Color(0xff3CB3E9),
            fontWeight: FontWeight.bold,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
          outsideDaysVisible: false,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xff555555),
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: Color(0xff3CB3E9),
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: Color(0xff3CB3E9),
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: Color(0xff555555),
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: Color(0xff555555),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

   Widget _buildDayNudges(List<Nudge> dayNudges, BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              DateFormat('EEEE, MMMM d, y').format(_selectedDay!),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff555555),
              ),
            ),
          ),
          const SizedBox(height: 8),
          dayNudges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No nudges scheduled',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dayNudges.length,
                    itemBuilder: (context, index) {
                      final nudge = dayNudges[index];
                      final isOverdue = !nudge.isCompleted && 
                                       nudge.scheduledTime.isBefore(DateTime.now());
                      return _buildNormalNudgeItem(nudge, isOverdue, context);
                    },
                  ),
                ),
        ],
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

  Widget _buildFilterHeader(List<Nudge> filteredNudges) {
    final completedCount = filteredNudges.where((n) => n.isCompleted).length;
    final pendingCount = filteredNudges.where((n) => !n.isCompleted).length;
    final overdueCount = _getOverdueNudges(filteredNudges).length;

    return Column(
      children: [
        // Compact Stats Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xff3CB3E9).withOpacity(0.9),
                const Color.fromRGBO(45, 161, 175, 0.7),
            ],
          ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Statistics in a compact row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactStatItem(
                      icon: Icons.schedule,
                      value: filteredNudges.length.toString(),
                      label: 'Total',
                    ),
                    _buildCompactStatItem(
                      icon: Icons.check_circle,
                      value: completedCount.toString(),
                      label: 'Completed',
                    ),
                    _buildCompactStatItem(
                      icon: Icons.pending_actions,
                      value: pendingCount.toString(),
                      label: 'Pending',
                    ),
                    if (overdueCount > 0) 
                      _buildCompactStatItem(
                        icon: Icons.warning,
                        value: overdueCount.toString(),
                        label: 'Overdue',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Compact filter buttons
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildCompactFilterToggle('TODAY', 0),
                      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                      _buildCompactFilterToggle('THIS WEEK', 1),
                      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                      _buildCompactFilterToggle('THIS MONTH', 2),
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
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFilterToggle(String text, int index) {
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
              fontWeight: FontWeight.w600,
              color: isSelected ? const Color(0xff3CB3E9) : Colors.white,
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
    
    // Separate truly overdue (more than 10 days) from recently overdue
    
    // These should be processed by the overdue manager
    final ancientOverdueNudges = allNudges.where((nudge) {
      final nudgeDate = DateTime(
        nudge.scheduledTime.year,
        nudge.scheduledTime.month,
        nudge.scheduledTime.day,
      );
      return !nudge.isCompleted && nudgeDate.isBefore(tenDaysAgo);
    }).toList();
    
    // If we find ancient overdue nudges, trigger processing
    if (ancientOverdueNudges.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processOverdueNudges();
      });
    }
  
  // Always get overdue nudges first
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
      
      // Combine overdue (for today) + today's scheduled nudges
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
      
      // Combine overdue (for this week) + this week's scheduled nudges
      return [
        ...overdueNudges,
        ...weekNudges.where((nudge) => !overdueNudges.contains(nudge)),
      ];
      
    case 2: // This Month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      final monthNudges = allNudges.where((nudge) {
        return nudge.scheduledTime.isAfter(startOfMonth.subtract(const Duration(days: 1))) && 
               nudge.scheduledTime.isBefore(endOfMonth.add(const Duration(days: 1)));
      }).toList();
      
      // Combine overdue (for this month) + this month's scheduled nudges
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

  Widget _buildEmptyState() {
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
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caught up! 🎉',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeList(List<Nudge> nudges) {
    if (_isSelecting) {
      // Flat list for selection mode
      return ListView.builder(
        itemCount: nudges.length,
        itemBuilder: (context, index) {
          final nudge = nudges[index];
          final isOverdue = !nudge.isCompleted && nudge.scheduledTime.isBefore(DateTime.now());
          final isSelected = _selectedNudgeIds.contains(nudge.id);
          return _buildSelectableNudgeItem(nudge, isSelected, isOverdue, context);
        },
      );
    }

    // Original grouped list for normal mode
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
          _buildSectionHeader('Overdue', overdueNudges.length),
          ...overdueNudges.map((nudge) {
            final isOverdue = true;
            return _buildNormalNudgeItem(nudge, isOverdue, context);
          }),
        ],
        if (todayNudges.isNotEmpty) ...[
          _buildSectionHeader('Today', todayNudges.length),
          ...todayNudges.map((nudge) => _buildNormalNudgeItem(nudge, false, context)),
        ],
        if (upcomingNudges.isNotEmpty) ...[
          _buildSectionHeader('Upcoming', upcomingNudges.length),
          ...upcomingNudges.map((nudge) => _buildNormalNudgeItem(nudge, false, context)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff3CB3E9),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xff3CB3E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ));
  }

  Widget _buildNormalNudgeItem(Nudge nudge, bool isOverdue, BuildContext context) {
    return Dismissible(
      key: Key(nudge.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground('complete', context),
      secondaryBackground: _buildSwipeBackground('snooze', context),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left - snooze
          _showSnoozeDialog(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
          return false; // Don't dismiss, let the dialog handle it
        } else {
          // Swipe right - complete
          _completeNudge(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
          return true;
        }
      },
      child: GestureDetector(
        onTap: () => _showNudgeActions(context, nudge),
       onLongPress: () {
          // Enter selection mode on long press
          if (!_isSelecting) {
            setState(() {
              _isSelecting = true;
              _selectedNudgeIds.add(nudge.id);
            });
          }
        },
        child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 2,
        color: isOverdue ? Colors.orange[50] : null,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: nudge.contactImageUrl.isNotEmpty
                    ? NetworkImage(nudge.contactImageUrl)
                    : null,
                backgroundColor: const Color(0xff3CB3E9),
                child: nudge.contactImageUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
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
                    color: isOverdue ? Colors.orange[800] :  const Color(0xff555555),
                  ),
                ),
              ),
              if (isOverdue)
                Icon(Icons.warning, color: Colors.orange[800], size: 16),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nudge.message),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(nudge.scheduledTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.orange[800] : Colors.grey[600],
                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (nudge.groupName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Chip(
                  label: Text(
                    nudge.groupName,
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          trailing: nudge.isCompleted 
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const SizedBox(
                  height: 10,
                ),
        ),
      ),
    ));
  }

  Widget _buildSwipeBackground(String action, BuildContext context) {
    Color color;
    IconData icon;

    if (action == 'complete') {
      color = Colors.green;
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }


  void _showNudgeActions(BuildContext context, Nudge nudge) {
    if (_isSelecting) {
      // If in selection mode, toggle selection on tap
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
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('View Contact'),
                onTap: () {
                  Navigator.pop(context);
                  _viewContact(nudge.contactId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Adjust Frequency'),
                onTap: () {
                  Navigator.pop(context);
                  _showFrequencyDialog(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.snooze),
                title: const Text('Snooze'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnoozeDialog(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Mark Complete'),
                onTap: () {
                  Navigator.pop(context);
                  _completeNudge(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel Nudge'),
                onTap: () {
                  Navigator.pop(context);
                  _cancelNudge(nudge, Provider.of<AuthService>(context, listen: false).currentUser!.uid);
                },
              ),
              if (!_isSelecting)
                ListTile(
                  leading: const Icon(Icons.select_all),
                  title: const Text('Select Multiple'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _isSelecting = true;
                      // _selectionMode = 'cancel';
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

  void _showFrequencyDialog(Nudge nudge, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedPeriod = nudge.period;
        int selectedFrequency = nudge.frequency;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Adjust Nudge Frequency'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Change how often you want to be reminded to contact ${nudge.contactName}:'),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Period',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Daily',
                      'Weekly', 
                      'Monthly',
                      'Quarterly',
                      'Yearly',
                    ].map((String period) {
                      return DropdownMenuItem<String>(
                        value: period,
                        child: Text(period),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedPeriod = newValue;
                          selectedFrequency = _getDefaultFrequencyForPeriod(newValue);
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<int>(
                    value: selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Times per $selectedPeriod',
                      border: const OutlineInputBorder(),
                    ),
                    items: _getFrequencyOptionsForPeriod(selectedPeriod).map((int frequency) {
                      return DropdownMenuItem<int>(
                        value: frequency,
                        child: Text('$frequency time${frequency > 1 ? 's' : ''}'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedFrequency = newValue;
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    _getFrequencyDescription(selectedPeriod, selectedFrequency),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final contacts = Provider.of<List<Contact>>(context, listen: false);
                      final contact = contacts.firstWhere(
                        (contact) => contact.id == nudge.contactId,
                      );
                      
                      if (contact.id.isEmpty) {
                        throw Exception('Contact not found');
                      }
                      
                      await _nudgeService.cancelNudge(nudge.id, userId);
                      
                      final success = await _nudgeService.scheduleNudgeForContact(
                        contact,
                        userId,
                        period: selectedPeriod,
                        frequency: selectedFrequency,
                      );
                      
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Frequency updated to $selectedFrequency times per $selectedPeriod'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        throw Exception('Failed to schedule updated nudge');
                      }
                    } catch (error) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update frequency: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnoozeDialog(Nudge nudge, String userId) {
    int selectedSnoozeHours = 4;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Snooze Nudge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How long would you like to snooze this nudge?'),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedSnoozeHours,
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _nudgeService.snoozeNudge(
                    nudge.id, 
                    userId, 
                    Duration(hours: selectedSnoozeHours),
                    nudge.contactName,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Nudge snoozed for $selectedSnoozeHours hour${selectedSnoozeHours > 1 ? 's' : ''}'),
                      backgroundColor: const Color(0xff3CB3E9),
                    ),
                  );
                },
                child: const Text('Snooze'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _completeNudge(Nudge nudge, String userId) {
    _nudgeService.markNudgeAsComplete(nudge.id, userId, nudge.contactId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nudge marked as completed'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _cancelNudge(Nudge nudge, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Nudge'),
        content: Text('Are you sure you want to cancel the nudge for ${nudge.contactName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nudgeService.cancelNudge(nudge.id, userId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nudge for ${nudge.contactName} cancelled'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Cancel Nudge', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<int> _getFrequencyOptionsForPeriod(String period) {
    switch (period) {
      case 'Daily':
        return [1, 2, 3, 4];
      case 'Weekly':
        return [1, 2, 3, 4, 5, 6, 7];
      case 'Monthly':
        return [1, 2, 3, 4, 6, 8, 12];
      case 'Quarterly':
        return [1, 2, 3, 4, 6, 12];
      case 'Yearly':
        return [1, 2, 3, 4, 6, 12];
      default:
        return [1, 2, 3, 4];
    }
  }

  int _getDefaultFrequencyForPeriod(String period) {
    switch (period) {
      case 'Daily':
        return 1;
      case 'Weekly':
        return 1;
      case 'Monthly':
        return 2;
      case 'Quarterly':
        return 3;
      case 'Yearly':
        return 4;
      default:
        return 1;
    }
  }

  String _getFrequencyDescription(String period, int frequency) {
    if (frequency == 1) {
      return 'Once per $period';
    } else {
      return '$frequency times per $period';
    }
  }
}
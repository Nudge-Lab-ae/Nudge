// lib/screens/notifications/notifications_screen.dart
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; // Add this package to pubspec.yaml
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/models/nudge.dart';
// import 'package:nudge/screens/contacts/contact_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  const NotificationsScreen({super.key, required this.showAppBar});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  String _activeFilter = 'upcoming'; // 'upcoming', 'completed', 'overdue'
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showCalendar = false;
  String _statsTimeFrame = 'week'; // 'day', 'week', 'month'

  // Dunbar's Principle thresholds
  static const int weeklyThreshold = 20;
  static const int monthlyThreshold = 80;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view nudges')),
      );
    }
    
    final nudgeService = NudgeService();
    
    return StreamBuilder<List<Nudge>>(
      stream: nudgeService.getNudgesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color.fromRGBO(45, 161, 175, 1))),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        
        final allNudges = snapshot.data ?? [];
        final now = DateTime.now();
        
        // Filter to show only next nudge per contact for list views
        final nextNudgePerContact = _getNextNudgePerContact(allNudges);
        
        // Categorize nudges
        final upcomingNudges = nextNudgePerContact.where((nudge) => 
          nudge.scheduledTime.isAfter(now) && !nudge.isCompleted
        ).toList();
        
        final completedNudges = nextNudgePerContact.where((nudge) => nudge.isCompleted).toList();
        
        final overdueNudges = nextNudgePerContact.where((nudge) => 
          nudge.scheduledTime.isBefore(now) && !nudge.isCompleted
        ).toList();

        // Group by time periods
        final todayNudges = _getNudgesForPeriod(upcomingNudges, 'today');
        final thisWeekNudges = _getNudgesForPeriod(upcomingNudges, 'thisWeek');
        final nextWeekNudges = _getNudgesForPeriod(upcomingNudges, 'nextWeek');

        // Calculate stats for current time frame
        final stats = _calculateNudgeStats(allNudges, _statsTimeFrame);
        final showWarning = _shouldShowWarning(stats['scheduledCount'] ?? 0, _statsTimeFrame);

        return Scaffold(
          appBar: _buildAppBar(),
          body: _showCalendar 
              ? _buildCalendarView(allNudges, user.uid)
              : _buildListView(
                  todayNudges, 
                  thisWeekNudges, 
                  nextWeekNudges, 
                  completedNudges, 
                  overdueNudges, 
                  user.uid,
                  stats,
                  showWarning,
                ),
          floatingActionButton: _buildCalendarToggle(),
        );
      },
    );
  }

AppBar _buildAppBar() {
    return AppBar(
      title: Text('Nudges', style: AppTextStyles.title3.copyWith(color: Colors.black, fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.black),
      leading: Center(),
      leadingWidth: 0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      actions: [
        if (!_showCalendar) 
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filter Nudges',
          ),
        IconButton(
          icon: const Icon(Icons.add_alarm),
          onPressed: () => _showScheduleOptions(context),
          tooltip: 'Schedule Nudges',
        ),
      ],
    );
  }

  Widget _buildCalendarToggle() {
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _showCalendar = !_showCalendar;
        });
      },
      backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      child: Icon(_showCalendar ? Icons.list : Icons.calendar_today, color: Colors.white),
    );
  }

  Widget _buildCalendarView(List<Nudge> allNudges, String userId) {
    final events = LinkedHashMap<DateTime, List<Nudge>>(
      equals: isSameDay,
      hashCode: (DateTime key) => key.day * 1000000 + key.month * 10000 + key.year,
    )..addAll(_groupNudgesByDate(allNudges));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TableCalendar<Nudge>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) => events[day] ?? [],
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: Color.fromRGBO(45, 161, 175, 1),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color.fromRGBO(45, 161, 175, 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color.fromRGBO(45, 161, 175, 1)),
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildDayEvents(events[_selectedDay] ?? [], userId),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    List<Nudge> todayNudges,
    List<Nudge> thisWeekNudges, 
    List<Nudge> nextWeekNudges,
    List<Nudge> completedNudges,
    List<Nudge> overdueNudges,
    String userId,
    Map<String, int> stats,
    bool showWarning,
  ) {
    List<Nudge> displayedNudges;
    
    switch (_activeFilter) {
      case 'completed':
        displayedNudges = completedNudges;
        break;
      case 'overdue':
        displayedNudges = overdueNudges;
        break;
      default:
        displayedNudges = [...todayNudges, ...thisWeekNudges, ...nextWeekNudges];
    }

    return Column(
      children: [
        // Stats Header with Time Frame Filter
        _buildStatsHeader(stats, showWarning),
        
        // Warning Banner if needed
        if (showWarning) _buildWarningBanner(stats['scheduledCount'] ?? 0, _statsTimeFrame),
        
        // Interactive Filter Chips
        _buildFilterChips(todayNudges.length + thisWeekNudges.length + nextWeekNudges.length, 
                         completedNudges.length, overdueNudges.length),
        
        // Nudge List with Sections
        Expanded(
          child: _activeFilter == 'upcoming' 
              ? _buildGroupedNudgeList(todayNudges, thisWeekNudges, nextWeekNudges, userId)
              : _buildNudgeList(displayedNudges, userId, showSections: false),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(Map<String, int> stats, bool showWarning) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scheduled Nudges',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              DropdownButton<String>(
                value: _statsTimeFrame,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                underline: Container(height: 0),
                onChanged: (String? newValue) {
                  setState(() {
                    _statsTimeFrame = newValue!;
                  });
                },
                items: <String>['day', 'week', 'month'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value == 'day' ? 'Today' : 
                      value == 'week' ? 'This Week' : 'This Month',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Scheduled', stats['scheduledCount'] ?? 0, 
                  showWarning ? Colors.orange : const Color.fromRGBO(45, 161, 175, 1)),
              _buildStatItem('Completed', stats['completedCount'] ?? 0, Colors.green),
              _buildStatItem('Total', (stats['scheduledCount'] ?? 0) + (stats['completedCount'] ?? 0), Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(int scheduledCount, String timeFrame) {
    String message;
    if (timeFrame == 'week' && scheduledCount > weeklyThreshold) {
      message = "🔥 You're scheduling a high number of connections this week — you may feel stretched. Consider spreading them out.";
    } else if (timeFrame == 'month' && scheduledCount > monthlyThreshold) {
      message = "🔥 Looks like lots of nudges this month — you might feel overwhelmed.";
    } else {
      message = "🔥 You're about to exceed your recommended number of daily notifications based on your group settings.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[800], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: _showGoalSettings,
            child: Text(
              'Review goal settings',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int upcomingCount, int completedCount, int overdueCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFilterChip('Upcoming', upcomingCount, 'upcoming', Icons.upcoming),
          _buildFilterChip('Completed', completedCount, 'completed', Icons.check_circle),
          _buildFilterChip('Overdue', overdueCount, 'overdue', Icons.warning),
        ],
      ),
    );
  }


  Widget _buildFilterChip(String label, int count, String filter, IconData icon) {
    final isActive = _activeFilter == filter;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : const Color.fromRGBO(45, 161, 175, 1)),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.black,
          )),
        ],
      ),
      selected: isActive,
      onSelected: (selected) {
        setState(() {
          _activeFilter = filter;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color.fromRGBO(45, 161, 175, 1),
      checkmarkColor: Colors.white,
      shape: StadiumBorder(side: BorderSide(
        color: isActive ? const Color.fromRGBO(45, 161, 175, 1) : Colors.grey.shade300,
      )),
    );
  }

  Widget _buildGroupedNudgeList(List<Nudge> today, List<Nudge> thisWeek, List<Nudge> nextWeek, String userId) {
    final sections = [
      _buildNudgeSection('Today', today, userId, today.isEmpty),
      _buildNudgeSection('This Week', thisWeek, userId, thisWeek.isEmpty),
      _buildNudgeSection('Next Week', nextWeek, userId, nextWeek.isEmpty),
    ];

    return ListView.builder(
      controller: _scrollController,
      itemCount: sections.length,
      itemBuilder: (context, index) => sections[index],
    );
  }

  Widget _buildNudgeSection(String title, List<Nudge> nudges, String userId, bool isEmpty) {
    if (isEmpty && title != 'Today') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(45, 161, 175, 1),
            ),
          ),
        ),
        if (isEmpty)
          _buildEmptySection(title)
        else
          ...nudges.map((nudge) => _buildNudgeCard(nudge, userId)).toList(),
      ],
    );
  }

  Widget _buildEmptySection(String period) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.celebration, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No nudges $period',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeList(List<Nudge> nudges, String userId, {bool showSections = true}) {
    if (nudges.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: nudges.length,
      itemBuilder: (context, index) => _buildNudgeCard(nudges[index], userId),
    );
  }

  Widget _buildNudgeCard(Nudge nudge, String userId) {
    final nudgeService = NudgeService();
    final isOverdue = nudge.scheduledTime.isBefore(DateTime.now()) && !nudge.isCompleted;
    
    return Dismissible(
      key: Key(nudge.id),
      background: _buildSwipeBackground(Icons.snooze, Colors.blue),
      secondaryBackground: _buildSwipeBackground(Icons.check, Colors.green, isLeft: false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Mark as complete
          nudgeService.markNudgeAsComplete(nudge.id, userId, nudge.contactId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nudge marked as complete')),
          );
          return true;
        } else {
          // Snooze
          _snoozeNudge(nudge, userId);
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: _buildContactAvatar(nudge),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect with ${nudge.contactName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: nudge.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              if (nudge.groupName.isNotEmpty)
                Chip(
                  label: Text(
                    nudge.groupName,
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('MMM dd, yyyy • hh:mm a').format(nudge.scheduledTime)} • ${nudge.frequency}',
              ),
              if (isOverdue)
                const Text(
                  'Overdue',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handlePopupAction(value, nudge, userId),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'view_contact',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('View Contact'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'adjust_frequency',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 8),
                    Text('Adjust Frequency'),
                  ],
                ),
              ),
              if (!nudge.isCompleted)
                const PopupMenuItem(
                  value: 'mark_complete',
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 20, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark Complete'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'snooze',
                child: Row(
                  children: [
                    Icon(Icons.snooze, size: 20),
                    SizedBox(width: 8),
                    Text('Snooze'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
          onTap: () {
            _showNudgeDetails(nudge, context, userId);
          },
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(IconData icon, Color color, {bool isLeft = true}) {
    return Container(
      color: color,
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildContactAvatar(Nudge nudge) {
    // In a real app, you would fetch the contact's image URL
    // For now, we'll use initials as a fallback
    final initials = nudge.contactName.split(' ').map((n) => n[0]).take(2).join();
    
    return CircleAvatar(
      backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      child: nudge.contactImageUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                nudge.contactImageUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            )
          : Text(
              initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildDayEvents(List<Nudge> dayNudges, String userId) {
    if (dayNudges.isEmpty) {
      return const Center(
        child: Text('No nudges scheduled for this day'),
      );
    }

    return ListView.builder(
      itemCount: dayNudges.length,
      itemBuilder: (context, index) => _buildNudgeCard(dayNudges[index], userId),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.celebration,
              size: 80,
              color: Color.fromRGBO(45, 161, 175, 1),
            ),
            const SizedBox(height: 24),
            const Text(
              'Every nudge brings you closer to stronger connections 💬',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showScheduleOptions(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Schedule Your First Nudge', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Nudges',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...['upcoming', 'completed', 'overdue'].map((filter) {
                return RadioListTile(
                  title: Text(
                    filter == 'upcoming' ? 'Upcoming' : 
                    filter == 'completed' ? 'Completed' : 'Overdue',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: filter,
                  groupValue: _activeFilter,
                  onChanged: (value) {
                    setState(() {
                      _activeFilter = value!;
                    });
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Helper methods for data processing
  List<Nudge> _getNextNudgePerContact(List<Nudge> allNudges) {
    final Map<String, Nudge> nextNudges = {};
    
    for (final nudge in allNudges) {
      if (!nextNudges.containsKey(nudge.contactId) || 
          nudge.scheduledTime.isBefore(nextNudges[nudge.contactId]!.scheduledTime)) {
        nextNudges[nudge.contactId] = nudge;
      }
    }
    
    return nextNudges.values.toList();
  }

  List<Nudge> _getNudgesForPeriod(List<Nudge> nudges, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (period) {
      case 'today':
        return nudges.where((nudge) => 
          isSameDay(nudge.scheduledTime, today)
        ).toList();
      case 'thisWeek':
        final endOfWeek = today.add(const Duration(days: 7));
        return nudges.where((nudge) => 
          nudge.scheduledTime.isAfter(today) && 
          nudge.scheduledTime.isBefore(endOfWeek) &&
          !isSameDay(nudge.scheduledTime, today)
        ).toList();
      case 'nextWeek':
        final startOfNextWeek = today.add(const Duration(days: 7));
        final endOfNextWeek = today.add(const Duration(days: 14));
        return nudges.where((nudge) => 
          nudge.scheduledTime.isAfter(startOfNextWeek) && 
          nudge.scheduledTime.isBefore(endOfNextWeek)
        ).toList();
      default:
        return nudges;
    }
  }

  Map<DateTime, List<Nudge>> _groupNudgesByDate(List<Nudge> nudges) {
    final Map<DateTime, List<Nudge>> events = {};
    
    for (final nudge in nudges) {
      final date = DateTime(nudge.scheduledTime.year, nudge.scheduledTime.month, nudge.scheduledTime.day);
      if (events[date] == null) {
        events[date] = [];
      }
      events[date]!.add(nudge);
    }
    
    return events;
  }

  void _handlePopupAction(String value, Nudge nudge, String userId) {
    final nudgeService = NudgeService();
    
    switch (value) {
      case 'view_contact':
        // Navigate to contact details
        // You'll need to fetch the contact first
        break;
      // case 'adjust_frequency':
      //   _showFrequencyDialog(nudge, userId);
      //   break;
      case 'mark_complete':
        nudgeService.markNudgeAsComplete(nudge.id, userId, nudge.contactId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nudge marked as complete')),
        );
        break;
      case 'snooze':
        _snoozeNudge(nudge, userId);
        break;
      case 'delete':
        _deleteNudge(nudge, userId);
        break;
    }
  }

    void _showScheduleOptions(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamProvider<List<Contact>>.value(
          initialData: [],
          value: apiService.getContactsStream(),
          child: StreamProvider<List<SocialGroup>>.value(
            value: apiService.getGroupsStream(),
            initialData: [],
            child: Consumer2<List<Contact>, List<SocialGroup>>(
              builder: (context, contacts, groups, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Schedule Nudges',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('For all contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.of(context).pop();
                          final nudgeService = NudgeService();
                          nudgeService.showNudgeScheduleDialog(
                            context, contacts, groups, authService.currentUser!.uid
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.group),
                        title: const Text('By group', style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.of(context).pop();
                          final nudgeService = NudgeService();
                          nudgeService.showNudgeScheduleDialog(
                            context, contacts, groups, authService.currentUser!.uid
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Manual selection', style: TextStyle(fontWeight: FontWeight.w600),),
                        onTap: () {
                          Navigator.of(context).pop();
                          final nudgeService = NudgeService();
                          nudgeService.showNudgeScheduleDialog(
                            context, contacts, groups, authService.currentUser!.uid
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
            )
          )
        );
      },
    );
  }

  Map<String, int> _calculateNudgeStats(List<Nudge> allNudges, String timeFrame) {
    final now = DateTime.now();
    int scheduledCount = 0;
    int completedCount = 0;

    for (final nudge in allNudges) {
      final isInTimeFrame = _isInTimeFrame(nudge.scheduledTime, timeFrame, now);
      
      if (isInTimeFrame) {
        if (nudge.isCompleted) {
          completedCount++;
        } else {
          scheduledCount++;
        }
      }
    }

    return {
      'scheduledCount': scheduledCount,
      'completedCount': completedCount,
    };
  }

  bool _isInTimeFrame(DateTime nudgeTime, String timeFrame, DateTime now) {
    switch (timeFrame) {
      case 'day':
        return isSameDay(nudgeTime, now);
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return nudgeTime.isAfter(startOfWeek) && nudgeTime.isBefore(endOfWeek);
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1);
        return nudgeTime.isAfter(startOfMonth) && nudgeTime.isBefore(endOfMonth);
      default:
        return false;
    }
  }

  bool _shouldShowWarning(int scheduledCount, String timeFrame) {
    switch (timeFrame) {
      case 'week':
        return scheduledCount > weeklyThreshold;
      case 'month':
        return scheduledCount > monthlyThreshold;
      case 'day':
        return scheduledCount > (weeklyThreshold ~/ 7); // Daily threshold = weekly/7
      default:
        return false;
    }
  }

  void _showGoalSettings() {
    // Navigate to goal settings screen or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Goal Settings'),
        content: const Text('Consider adjusting your contact frequencies or spreading out your nudges to maintain quality interactions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showScheduleOptions(context);
            },
            child: const Text('Adjust Schedule'),
          ),
        ],
      ),
    );
  }



  void _snoozeNudge(Nudge nudge, String userId) {
    final nudgeService = NudgeService();
    
    showDialog(
      context: context,
      builder: (context) {
        String snoozeDuration = '1 day';
        
        return AlertDialog(
          title: const Text('Snooze Nudge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How long would you like to snooze this nudge?'),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: snoozeDuration,
                onChanged: (String? newValue) {
                  snoozeDuration = newValue!;
                },
                items: <String>['1 hour', '1 day', '3 days', '1 week']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Calculate duration
                Duration duration;
                switch (snoozeDuration) {
                  case '1 hour':
                    duration = const Duration(hours: 1);
                    break;
                  case '3 days':
                    duration = const Duration(days: 3);
                    break;
                  case '1 week':
                    duration = const Duration(days: 7);
                    break;
                  default:
                    duration = const Duration(days: 1);
                }
                
                await nudgeService.snoozeNudge(
                  nudge.id, 
                  userId, 
                  duration,
                  nudge.contactName
                );
                
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nudge snoozed')),
                );
              },
              child: const Text('Snooze'),
            ),
          ],
        );
      },
    );
  }

  void _deleteNudge(Nudge nudge, String userId) {
    final nudgeService = NudgeService();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Nudge', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete the nudge for ${nudge.contactName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: ()  {
                nudgeService.cancelNudge(nudge.id, userId).then((value){
                });
                Navigator.of(context).pop();
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nudge deleted')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

  void _showNudgeDetails(Nudge nudge, BuildContext context, String userId) {
    final nudgeService = NudgeService();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nudge: ${nudge.contactName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scheduled: ${DateFormat('MMM dd, yyyy • hh:mm a').format(nudge.scheduledTime)}'),
              Text('Frequency: ${nudge.frequency}'),
              const SizedBox(height: 10),
              Text('Status: ${nudge.isCompleted ? 'Completed' : 'Pending'}'),
              if (nudge.isCompleted && nudge.completedAt != null)
                Text('Completed: ${DateFormat('MMM dd, yyyy').format(nudge.completedAt!)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (!nudge.isCompleted)
              ElevatedButton(
                onPressed: () {
                  nudgeService.markNudgeAsComplete(nudge.id, userId, nudge.contactId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nudge marked as complete')),
                  );
                },
                child: const Text('Mark Complete'),
              ),
          ],
        );
      },
    );
  }

}


  
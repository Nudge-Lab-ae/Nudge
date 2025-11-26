import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/nudge.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
// import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  
  const NotificationsScreen({super.key, this.showAppBar = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0; // 0: Today, 1: This Week, 2: This Month
  final NudgeService _nudgeService = NudgeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar 
          ? AppBar(
              title: const Text('Nudges & Reminders'),
              backgroundColor: const Color(0xff3CB3E9),
            )
          : null,
      floatingActionButton: FloatingActionButton(
      onPressed: () {
        // Get contacts and groups from context
        final contacts = Provider.of<List<Contact>>(context, listen: false);
        final groups = Provider.of<List<SocialGroup>>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Call the existing nudge scheduling function
        _nudgeService.showNudgeScheduleDialog(context, contacts, groups, authService.currentUser!.uid);
      },
      backgroundColor: const Color(0xff3CB3E9),
      child: const Icon(Icons.add, color: Colors.white),
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
          final overdueNudges = _getOverdueNudges(allNudges);
          
          return Column(
            children: [
              // Warning Banner for Overdue Nudges
              if (overdueNudges.isNotEmpty) _buildWarningBanner(overdueNudges),
              
              // Header with Stats and Filters
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildFilterHeader(filteredNudges),
              ),
              
              // Nudge List
              Expanded(
                child: filteredNudges.isEmpty
                    ? _buildEmptyState()
                    : _buildNudgeList(filteredNudges),
              ),
            ],
          );
        },
      ),
    );
  }

  // Warning Banner for Overdue Nudges
  Widget _buildWarningBanner(List<Nudge> overdueNudges) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${overdueNudges.length} overdue nudge${overdueNudges.length > 1 ? 's' : ''} need${overdueNudges.length > 1 ? '' : 's'} attention',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFilter = 0; // Switch to Today view
              });
            },
            child: Text(
              'View',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(List<Nudge> filteredNudges) {
    final completedCount = filteredNudges.where((n) => n.isCompleted).length;
    final pendingCount = filteredNudges.where((n) => !n.isCompleted).length;
    final overdueCount = _getOverdueNudges(filteredNudges).length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xff3CB3E9).withOpacity(0.9),
              const Color.fromRGBO(45, 161, 175, 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Statistics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  filteredNudges.length.toString(),
                  Icons.schedule,
                ),
                _buildStatItem(
                  'Completed',
                  completedCount.toString(),
                  Icons.check_circle,
                ),
                _buildStatItem(
                  'Pending',
                  pendingCount.toString(),
                  Icons.pending_actions,
                ),
                if (overdueCount > 0) 
                  _buildStatItem(
                    'Overdue',
                    overdueCount.toString(),
                    Icons.warning,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Filter Toggle Buttons
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildFilterToggle('Today', 0),
                  _buildFilterToggle('This Week', 1),
                  _buildFilterToggle('This Month', 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToggle(String text, int index) {
    bool isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected 
                  ? const Color(0xff3CB3E9)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<Nudge> _getFilteredNudges(List<Nudge> allNudges, int filterIndex) {
    final now = DateTime.now();
    
    switch (filterIndex) {
      case 0: // Today
        return allNudges.where((nudge) {
          final nudgeDate = DateTime(
            nudge.scheduledTime.year,
            nudge.scheduledTime.month,
            nudge.scheduledTime.day,
          );
          final today = DateTime(now.year, now.month, now.day);
          return nudgeDate == today;
        }).toList();
        
      case 1: // This Week
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return allNudges.where((nudge) {
          return nudge.scheduledTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
                 nudge.scheduledTime.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();
        
      case 2: // This Month
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        return allNudges.where((nudge) {
          return nudge.scheduledTime.isAfter(startOfMonth.subtract(const Duration(days: 1))) && 
                 nudge.scheduledTime.isBefore(endOfMonth.add(const Duration(days: 1)));
        }).toList();
        
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
    // Separate overdue, today, and upcoming nudges for better organization
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 80.0), // Add bottom padding for FAB
      child: ListView(
        children: [
          if (overdueNudges.isNotEmpty) ...[
            _buildSectionHeader('Overdue', overdueNudges.length),
            ...overdueNudges.map((nudge) => _buildNudgeItem(nudge, context, isOverdue: true)),
          ],
          if (todayNudges.isNotEmpty) ...[
            _buildSectionHeader('Today', todayNudges.length),
            ...todayNudges.map((nudge) => _buildNudgeItem(nudge, context)),
          ],
          if (upcomingNudges.isNotEmpty) ...[
            _buildSectionHeader('Upcoming', upcomingNudges.length),
            ...upcomingNudges.map((nudge) => _buildNudgeItem(nudge, context)),
          ],
          const SizedBox(height: 20), // Extra space at the bottom
        ],
      ),
    );
  }
  // Widget _buildNudgeList(List<Nudge> nudges) {
  //   // Separate overdue, today, and upcoming nudges for better organization
  //   final now = DateTime.now();
  //   final today = DateTime(now.year, now.month, now.day);
    
  //   final overdueNudges = nudges.where((nudge) {
  //     final nudgeDate = DateTime(
  //       nudge.scheduledTime.year,
  //       nudge.scheduledTime.month,
  //       nudge.scheduledTime.day,
  //     );
  //     return !nudge.isCompleted && nudgeDate.isBefore(today);
  //   }).toList();
    
  //   final todayNudges = nudges.where((nudge) {
  //     final nudgeDate = DateTime(
  //       nudge.scheduledTime.year,
  //       nudge.scheduledTime.month,
  //       nudge.scheduledTime.day,
  //     );
  //     return nudgeDate == today;
  //   }).toList();
    
  //   final upcomingNudges = nudges.where((nudge) {
  //     final nudgeDate = DateTime(
  //       nudge.scheduledTime.year,
  //       nudge.scheduledTime.month,
  //       nudge.scheduledTime.day,
  //     );
  //     return nudgeDate.isAfter(today);
  //   }).toList();

  //   return ListView(
  //     children: [
  //       if (overdueNudges.isNotEmpty) ...[
  //         _buildSectionHeader('Overdue', overdueNudges.length),
  //         ...overdueNudges.map((nudge) => _buildNudgeItem(nudge, context, isOverdue: true)),
  //       ],
  //       if (todayNudges.isNotEmpty) ...[
  //         _buildSectionHeader('Today', todayNudges.length),
  //         ...todayNudges.map((nudge) => _buildNudgeItem(nudge, context)),
  //       ],
  //       if (upcomingNudges.isNotEmpty) ...[
  //         _buildSectionHeader('Upcoming', upcomingNudges.length),
  //         ...upcomingNudges.map((nudge) => _buildNudgeItem(nudge, context)),
  //       ],
  //     ],
  //   );
  // }

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
      ),
    );
  }

  Widget _buildNudgeItem(Nudge nudge, BuildContext context, {bool isOverdue = false}) {
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
                    color: isOverdue ? Colors.orange[800] : null,
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
              : PopupMenuButton<String>(
                  onSelected: (value) => _handlePopupAction(value, nudge),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'view_contact',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 20),
                          SizedBox(width: 8),
                          Text('View Contact'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'adjust_frequency',
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 20),
                          SizedBox(width: 8),
                          Text('Adjust Frequency'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'snooze',
                      child: Row(
                        children: [
                          Icon(Icons.snooze, size: 20),
                          SizedBox(width: 8),
                          Text('Snooze'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'complete',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text('Mark Complete'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 20),
                          SizedBox(width: 8),
                          Text('Cancel Nudge'),
                        ],
                      ),
                    ),
                  ],
                ),
          onTap: () {
            if (nudge.isCompleted) return;
            _showNudgeActions(context, nudge);
          },
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(String action, BuildContext context) {
    Color color;
    IconData icon;
    // Alignment alignment;

    if (action == 'complete') {
      color = Colors.green;
      icon = Icons.check;
      // alignment = Alignment.centerLeft;
    } else {
      color = Colors.orange;
      icon = Icons.snooze;
      // alignment = Alignment.centerRight;
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
        );
      },
    );
  }

  void _handlePopupAction(String value, Nudge nudge) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    switch (value) {
      case 'view_contact':
        _viewContact(nudge.contactId);
        break;
      case 'adjust_frequency':
        _showFrequencyDialog(nudge, authService.currentUser!.uid);
        break;
      case 'snooze':
        _showSnoozeDialog(nudge, authService.currentUser!.uid);
        break;
      case 'complete':
        _completeNudge(nudge, authService.currentUser!.uid);
        break;
      case 'cancel':
        _cancelNudge(nudge, authService.currentUser!.uid);
        break;
    }
  }

  void _viewContact(String contactId) {
    final contacts = Provider.of<List<Contact>>(context, listen: false);
    final contact = contacts.firstWhere(
      (contact) => contact.id == contactId,
      // orElse: () => Contact.empty(),
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
                        // orElse: () => Contact.empty(),
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
    int selectedSnoozeHours = 1;
    
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
                    DropdownMenuItem(value: 1, child: Text('1 hour')),
                    DropdownMenuItem(value: 2, child: Text('2 hours')),
                    DropdownMenuItem(value: 4, child: Text('4 hours')),
                    DropdownMenuItem(value: 8, child: Text('8 hours')),
                    DropdownMenuItem(value: 24, child: Text('1 day')),
                    DropdownMenuItem(value: 48, child: Text('2 days')),
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
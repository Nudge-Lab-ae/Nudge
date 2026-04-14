// lib/screens/contacts/contacts_list_screen.dart
// import 'package:another_flushbar/flushbar.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/import_contacts_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:provider/provider.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/theme/app_theme.dart';
import 'contact_detail_screen.dart';
import 'add_contact_screen.dart';
import '../../models/contact.dart';
import '../../services/auth_service.dart';

class ContactsListScreen extends StatefulWidget {
  final String? filter;
  final String? mode;
  final bool showAppBar;
  final Function hideButton;

  const ContactsListScreen({
    super.key,
    this.filter,
    this.mode,
    required this.showAppBar,
    required this.hideButton,
  });

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedContacts = {};
  bool _isSelecting = false;
  String? _selectionMode;
  List<Contact> totalContacts = [];
  String _currentFilter = 'all';
  bool _isDeletingInProgress = false;
  int _deletionSuccessCount = 0;
  int _deletionTotalCount = 0;
  int _deletionErrorCount = 0;
  bool _isAddingToGroupInProgress = false;
  int _addingSuccessCount = 0;
  int _addingTotalCount = 0;
  int _addingErrorCount = 0;
  String? _currentGroupName;
  bool emptyContacts = false;
  List<SocialGroup> allGroups = [];
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  bool _showConfetti = false;

  // ── Avatar palette: pastel bg + high-contrast text ────────────────────────
  static const List<(Color, Color)> _avatarPalette = [
    (Color(0xFFEDE9FE), Color(0xFF5B21B6)), // lavender / deep violet
    (Color(0xFFFFE4E6), Color(0xFFBE123C)), // rose / crimson
    (Color(0xFFD1FAE5), Color(0xFF065F46)), // mint / emerald
    (Color(0xFFFFEDD5), Color(0xFF9A3412)), // peach / burnt orange
    (Color(0xFFDBEAFE), Color(0xFF1E40AF)), // sky / navy
    (Color(0xFFFDF4FF), Color(0xFF7E22CE)), // lilac / purple
    (Color(0xFFFEF9C3), Color(0xFF854D0E)), // lemon / amber
    (Color(0xFFCCFBF1), Color(0xFF134E4A)), // teal / dark teal
  ];

  (Color, Color) _getAvatarColors(String id) {
    if (id.isEmpty) return _avatarPalette[0];
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = id.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return _avatarPalette[hash.abs() % _avatarPalette.length];
  }

  // Dark-mode variants: slightly deeper bg, same text
  (Color, Color) _getAvatarColorsDark(String id) {
    final (bg, text) = _getAvatarColors(id);
    return (bg.withOpacity(0.22), Color(0xffcccccc));
  }

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter ?? 'all';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (routeArgs?['action'] == 'add_to_group') {
        setState(() {
          _isSelecting = true;
          _selectionMode = 'add_to_group';
        });
      }
    });
  }

  fetchGroups() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final groups = await apiService.getGroupsStream().first;
    setState(() => allGroups = groups);
  }

  // ── Ring helpers ───────────────────────────────────────────────────────────

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':  return AppColors.vipGold;
      case 'middle': return Colors.lightBlue;
      case 'outer':  return  AppColors.lightPrimary;
      default:       return const Color(0xff897ED6);
    }
  }

  String _getRingLabel(String ring) {
    switch (ring) {
      case 'inner':  return 'Inner Circle';
      case 'middle': return 'Middle Circle';
      case 'outer':  return 'Outer Circle';
      default:       return 'Unknown';
    }
  }

  int getRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return (hash.abs() % 6) + 1;
  }

  Widget _buildContactAvatar(
    Contact contact, {
    required bool isDark,
    required ColorScheme scheme,
    double size = 54,
  }) {
    final initials = _getContactInitials(contact.name);
    final assetPath = 'assets/contact-icons/${getRandomIndex(contact.id)}.png';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: contact.imageUrl.isNotEmpty
                ? Image.network(
                    contact.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(assetPath, fit: BoxFit.cover),
                      // Semi-transparent overlay so initials always readable
                      Container(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.18),
                      ),
                      Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: size * 0.30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
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
        if (contact.isVIP)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.vipGold,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: const Icon(Icons.star, size: 10, color: Colors.white),
            ),
          ),
      ],
    );
  }
    
  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isAddToGroupMode = routeArgs?['action'] == 'add_to_group';
    final groupName = routeArgs?['groupName'];
    final groupPeriod = routeArgs?['groupPeriod'];
    final groupFrequency = routeArgs?['groupFrequency'];

    if (user == null || emptyContacts) {
      return _buildEmptyState(themeProvider: themeProvider);
    }

    // ── Dashboard embedded (no app bar) ───────────────────────────────────────
    if (!widget.showAppBar) {
      return StreamProvider<List<Contact>>(
        create: (context) => apiService.getContactsStream(),
        initialData: const [],
        child: Consumer<List<Contact>>(
          builder: (context, contacts, child) {
            totalContacts = contacts;
            final filteredContacts = _applyFilter(contacts, _currentFilter);
            if (totalContacts.isEmpty) {
              return _buildEmptyState(themeProvider: themeProvider);
            }
            final searchedContacts = filteredContacts.where((c) {
              return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  c.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  c.socialGroups.any((g) => g.toLowerCase().contains(_searchQuery.toLowerCase()));
            }).toList();

            return GestureDetector(
              onTap: _dismissKeyboard,
              child: Scaffold(
                floatingActionButton: Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 55),
                  child: _selectedContacts.isNotEmpty &&
                          !_isDeletingInProgress &&
                          !_isAddingToGroupInProgress
                      ? FloatingActionButton.extended(
                          onPressed: () => _selectionMode == 'add_to_group'
                              ? _addMultipleContactsToGroup(context, groupName!,
                                  groupPeriod!, groupFrequency!, totalContacts, themeProvider)
                              : _deleteSelectedContacts(context),
                          backgroundColor: _selectionMode == 'add_to_group'
                              ? theme.colorScheme.primary
                              : const Color.fromARGB(255, 206, 37, 85),
                          icon: Icon(
                            _selectionMode == 'add_to_group'
                                ? Icons.group_add
                                : Icons.delete,
                            color: Colors.white,
                          ),
                          label: Text(
                            _selectionMode == 'add_to_group'
                                ? 'ADD ${_selectedContacts.length} CONTACTS'
                                : 'DELETE ${_selectedContacts.length} CONTACTS',
                            style: GoogleFonts.beVietnamPro(color: Colors.white),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                body: Stack(
                  children: [
                    CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // AppBar
                        SliverAppBar(
                          title: isAddToGroupMode
                              ? Text('Add to $groupName',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w700))
                              : Text('Contacts',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22)),
                          backgroundColor: theme.scaffoldBackgroundColor,
                          leading: const SizedBox.shrink(),
                          centerTitle: isAddToGroupMode,
                          surfaceTintColor: Colors.transparent,
                          floating: true,
                          snap: true,
                          pinned: false,
                          actions: [
                            if (!isAddToGroupMode)
                              _buildPopupMenu(context, themeProvider),
                          ],
                        ),

                        // Selection controls
                        if (_isSelecting)
                          SliverToBoxAdapter(
                            child: _buildSelectionControls(
                                themeProvider: themeProvider),
                          ),

                        // Add-to-group hint
                        if (isAddToGroupMode && !_isSelecting)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: Text(
                                'Long press on contacts to select multiple',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),

                        // Search + filter
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: Column(children: [
                              _buildSearchAndFilterBar(themeProvider: themeProvider),
                              if (_currentFilter != 'all' && _currentFilter != '')
                                _buildFilterTitleRow(themeProvider: themeProvider),
                            ]),
                          ),
                        ),

                        // Frequently contacted (only when not searching/filtering)
                        if (_searchQuery.isEmpty &&
                            /* _currentFilter == 'all' && */
                            !_isSelecting &&
                            contacts.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildFrequentlyContactedSection(
                                contacts, themeProvider),
                          ),

                        // Contact list
                        if (searchedContacts.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Text(
                                filteredContacts.isEmpty
                                    ? 'No contacts found'
                                    : 'No results for "$_searchQuery"',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final contact = searchedContacts[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _isSelecting
                                        ? _buildSelectableContactTile(contact,
                                            _selectedContacts.contains(contact.id),
                                            themeProvider: themeProvider)
                                        : _buildNormalContactTile(
                                            contact,
                                            isAddToGroupMode,
                                            groupName,
                                            groupPeriod,
                                            groupFrequency,
                                            themeProvider: themeProvider,
                                          ),
                                  );
                                },
                                childCount: searchedContacts.length,
                              ),
                            ),
                          ),

                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),

                    if (_showConfetti)
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          numberOfParticles: 20,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          colors: [
                            AppColors.success,
                            theme.colorScheme.secondary,
                            theme.colorScheme.tertiary,
                            AppColors.warning,
                            theme.colorScheme.primary,
                          ],
                        ),
                      ),

                    _buildDeletionProgressOverlay(themeProvider: themeProvider),
                    _buildAddingToGroupProgressOverlay(themeProvider: themeProvider),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // ── Standalone (with app bar) ──────────────────────────────────────────────
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: _buildNormalAppBar(context, isAddToGroupMode, groupName,
            themeProvider: themeProvider),
        body: Stack(
          children: [
            Column(
              children: [
                if (isAddToGroupMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Long press on contacts to select multiple',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                _buildSelectionControls(themeProvider: themeProvider),
                Expanded(
                  child: StreamProvider<List<Contact>>(
                    create: (context) => apiService.getContactsStream(),
                    initialData: const [],
                    child: Consumer<List<Contact>>(
                      builder: (context, contacts, child) {
                        totalContacts = contacts;
                        final filteredContacts =
                            _applyFilter(contacts, _currentFilter);

                        if (filteredContacts.isEmpty) {
                          return _buildEmptyState(
                              filter: _currentFilter,
                              themeProvider: themeProvider);
                        }

                        final searchedContacts =
                            filteredContacts.where((c) {
                          return c.name.toLowerCase().contains(
                                  _searchQuery.toLowerCase()) ||
                              c.connectionType.toLowerCase().contains(
                                  _searchQuery.toLowerCase()) ||
                              c.socialGroups.any((g) => g.toLowerCase().contains(
                                  _searchQuery.toLowerCase()));
                        }).toList();

                        return CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // Search + filter
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              sliver: SliverToBoxAdapter(
                                child: Column(children: [
                                  _buildSearchAndFilterBar(
                                      themeProvider: themeProvider),
                                  if (_currentFilter != 'all' &&
                                      _currentFilter != '')
                                    _buildFilterTitleRow(
                                        themeProvider: themeProvider),
                                ]),
                              ),
                            ),

                            // Frequently contacted
                            if (_searchQuery.isEmpty &&
                                _currentFilter == 'all' &&
                                !_isSelecting &&
                                contacts.isNotEmpty)
                              SliverToBoxAdapter(
                                child: _buildFrequentlyContactedSection(
                                    contacts, themeProvider),
                              ),

                            if (searchedContacts.isEmpty)
                              SliverFillRemaining(
                                child: Center(
                                  child: Text(
                                    'No results for "$_searchQuery"',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 15,
                                        color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final contact = searchedContacts[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _isSelecting
                                            ? _buildSelectableContactTile(
                                                contact,
                                                _selectedContacts
                                                    .contains(contact.id),
                                                themeProvider: themeProvider)
                                            : _buildNormalContactTile(
                                                contact,
                                                isAddToGroupMode,
                                                groupName,
                                                groupPeriod,
                                                groupFrequency,
                                                themeProvider: themeProvider,
                                              ),
                                      );
                                    },
                                    childCount: searchedContacts.length,
                                  ),
                                ),
                              ),

                            const SliverToBoxAdapter(
                                child: SizedBox(height: 100)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            _buildDeletionProgressOverlay(themeProvider: themeProvider),
            _buildAddingToGroupProgressOverlay(themeProvider: themeProvider),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 55),
          child: _selectedContacts.isNotEmpty &&
                  !_isDeletingInProgress &&
                  !_isAddingToGroupInProgress
              ? FloatingActionButton.extended(
                  onPressed: () => _selectionMode == 'add_to_group'
                      ? _addMultipleContactsToGroup(context, groupName!,
                          groupPeriod!, groupFrequency!, totalContacts, themeProvider)
                      : _deleteSelectedContacts(context),
                  backgroundColor: _selectionMode == 'add_to_group'
                      ? theme.colorScheme.primary
                      : const Color.fromARGB(255, 206, 37, 85),
                  icon: Icon(
                    _selectionMode == 'add_to_group'
                        ? Icons.group_add
                        : Icons.delete,
                    color: Colors.white,
                  ),
                  label: Text(
                    _selectionMode == 'add_to_group'
                        ? 'ADD ${_selectedContacts.length} CONTACTS'
                        : 'DELETE ${_selectedContacts.length} CONTACTS',
                    style: GoogleFonts.beVietnamPro(color: Colors.white),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ── Frequently contacted section ──────────────────────────────────────────

  Widget _buildFrequentlyContactedSection(
      List<Contact> contacts, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = themeProvider.isDarkMode;

    // Sort by most recently contacted, take up to 8
    // ── Score each contact by logged interaction activity ─────────────────
    // Primary: interactions in the last 90 days (interactionCountInWindow)
    // Secondary: timestamp of the most recent logged interaction
    // Tiebreaker: inner-circle / VIP contacts are lifted when scores are close
    DateTime _mostRecentInteraction(Contact c) {
      if (c.interactionHistory.isEmpty) return DateTime(2000);
      final timestamps = c.interactionHistory.values
          .whereType<Map>()
          .map((e) => e['timestamp'])
          .whereType<int>()
          .toList();
      if (timestamps.isEmpty) return DateTime(2000);
      return DateTime.fromMillisecondsSinceEpoch(
          timestamps.reduce((a, b) => a > b ? a : b));
    }

    // Build a numeric score for each contact:
    //   base  = interactions in the 90-day window  (0-n)
    //   bonus = +2 for inner-circle, +1 for VIP/middle-circle
    // When the top scores are all identical (everyone has 0 or 1 interactions)
    // the bonus ensures inner/VIP contacts surface first.
    final maxWindow = contacts.isEmpty
        ? 1
        : contacts
            .map((c) => c.interactionCountInWindow)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 999);

    double _score(Contact c) {
      final base = c.interactionCountInWindow.toDouble();
      double bonus = 0;
      if (c.computedRing == 'inner') bonus += 2;
      if (c.isVIP) bonus += 1;
      if (c.computedRing == 'middle') bonus += 0.5;
      // Only apply the bonus as a tiebreaker when activity scores are low
      // (i.e. when the max window count is ≤ 2, which means most contacts
      // have similar or zero interaction counts).
      final bonusWeight = maxWindow <= 2 ? 1.0 : 0.3;
      return base + bonus * bonusWeight;
    }

    final scored = [...contacts]
      ..sort((a, b) {
        final scoreDiff = _score(b).compareTo(_score(a));
        if (scoreDiff != 0) return scoreDiff;
        // Same composite score → sort by most-recent interaction timestamp
        return _mostRecentInteraction(b)
            .compareTo(_mostRecentInteraction(a));
      });
    final shown = scored.take(8).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Contacted',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final contact = shown[index];
                final initials = _getContactInitials(contact.name);
                final (bgColor, textColor) = isDark
                    ? _getAvatarColorsDark(contact.id)
                    : _getAvatarColors(contact.id);
                final ringColor = _getRingColor(contact.computedRing);
                final firstName = contact.name.split(' ').first;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactDetailScreen(contact: contact),
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: bgColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: contact.imageUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      contact.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(initials,
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: textColor)),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(initials,
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: textColor)),
                                  ),
                          ),
                          // Ring dot
                          Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: ringColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        firstName,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Normal contact tile ───────────────────────────────────────────────────

  Widget _buildNormalContactTile(
    Contact contact,
    bool isAddToGroupMode,
    String? groupName,
    String? groupPeriod,
    int? groupFrequency, {
    required ThemeProvider themeProvider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = themeProvider.isDarkMode;
    final initials = _getContactInitials(contact.name);
    final (bgColor, textColor) =
        isDark ? _getAvatarColorsDark(contact.id) : _getAvatarColors(contact.id);
    final ringColor = _getRingColor(contact.computedRing);
    final ringLabel = _getRingLabel(contact.computedRing);

    return GestureDetector(
      onTap: () {
        if (isAddToGroupMode &&
            groupName != null &&
            groupPeriod != null &&
            groupFrequency != null) {
          _addContactToGroup(
              context, contact, groupName, groupPeriod, groupFrequency);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactDetailScreen(contact: contact),
            ),
          );
        }
      },
      onLongPress: () {
        setState(() {
          _isSelecting = true;
          _selectionMode =
              widget.mode == 'add_to_group' ? 'add_to_group' : 'delete';
          _selectedContacts.add(contact.id);
        });
        widget.hideButton();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.14 : 0.055),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────────────────────
            _buildContactAvatar(contact, isDark: isDark, scheme: scheme),
            const SizedBox(width: 14),

            // ── Text content ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    contact.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Connection type · Ring label · dot
                  Row(
                    children: [
                      if (contact.connectionType.isNotEmpty) ...[
                        Text(
                          contact.connectionType,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        ringLabel,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ringColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // VIP star
                      // if (contact.isVIP) ...[
                      //   const SizedBox(width: 6),
                      //   Icon(
                      //     Icons.star_rounded,
                      //     size: 14,
                      //     color: AppColors.vipGold,
                      //   ),
                      // ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Chevron ───────────────────────────────────────────────────────
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Selectable tile ───────────────────────────────────────────────────────

  Widget _buildSelectableContactTile(
    Contact contact,
    bool isSelected, {
    required ThemeProvider themeProvider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = themeProvider.isDarkMode;
    final initials = _getContactInitials(contact.name);
    final (bgColor, textColor) =
        isDark ? _getAvatarColorsDark(contact.id) : _getAvatarColors(contact.id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedContacts.contains(contact.id)) {
            _selectedContacts.remove(contact.id);
          } else {
            _selectedContacts.add(contact.id);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withOpacity(0.08)
              : (isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: scheme.primary.withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
              ),
              child: contact.imageUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(contact.imageUrl, fit: BoxFit.cover))
                  : Center(
                      child: Text(initials,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor)),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(contact.connectionType,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search & filter bar ───────────────────────────────────────────────────

  Widget _buildSearchAndFilterBar({required ThemeProvider themeProvider}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = themeProvider.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark
                    ? scheme.surfaceContainerLow
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.beVietnamPro(
                    color: scheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search your universe...',
                  hintStyle: GoogleFonts.beVietnamPro(
                      color: scheme.outline, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: scheme.outline, size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  filled: false,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerLow
                  : scheme.surfaceContainerLowest,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.tune_rounded, color: scheme.primary, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: isDark
                  ? scheme.surfaceContainerHigh
                  : scheme.surfaceContainerLowest,
              onSelected: (v) => setState(() => _currentFilter = v),
              itemBuilder: (_) => ['all', 'vip']
                  .map((v) => PopupMenuItem<String>(
                        value: v,
                        child: Text(_getFilterLabel(v),
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                color: scheme.onSurface)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTitleRow({required ThemeProvider themeProvider}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            const SizedBox(width: 8),
            Text(_getFilterTitle(_currentFilter),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary)),
          ]),
          TextButton(
            onPressed: () => setState(() => _currentFilter = 'all'),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Clear',
                style: GoogleFonts.beVietnamPro(
                    color: scheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Selection controls ────────────────────────────────────────────────────

  Widget _buildSelectionControls({required ThemeProvider themeProvider}) {
    if (!_isSelecting) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final apiService = Provider.of<ApiService>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.primary.withOpacity(0.06),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                apiService.scheduleTestNudges(_selectedContacts.toList());
                _toggleSelectAll();
              },
              icon: Icon(
                _selectedContacts.length == _getVisibleContactsCount()
                    ? Icons.deselect
                    : Icons.select_all,
                color: scheme.primary,
              ),
              label: Text(
                _selectedContacts.length == _getVisibleContactsCount() &&
                        _selectedContacts.isNotEmpty
                    ? 'DESELECT ALL'
                    : 'SELECT ALL',
                style: GoogleFonts.beVietnamPro(
                    color: scheme.primary, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.primary),
                  padding: EdgeInsets.only(
                    left: 5, right: 5, top: 15, bottom: 15
                  )
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exitSelectionMode,
              icon: Icon(Icons.cancel, color: const Color.fromARGB(255, 206, 37, 85),),
              label: Text('CANCEL',
                  style: GoogleFonts.beVietnamPro(
                      color: const Color.fromARGB(255, 206, 37, 85), fontSize: 14)),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color.fromARGB(255, 206, 37, 85),)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Popup menu ────────────────────────────────────────────────────────────

  Widget _buildPopupMenu(BuildContext context, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'select_delete') {
          setState(() {
            _isSelecting = true;
            _selectionMode = 'delete';
          });
          widget.hideButton();
        } else if (value == 'import_contacts') {
          _importContacts();
        } else if (value == 'delete_all') {
          _deleteAllContacts(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'import_contacts',
          child: Row(children: [
            Icon(Icons.import_contacts, color: scheme.outline),
            const SizedBox(width: 8),
            Text('Import Contacts',
                style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'select_delete',
          child: Row(children: [
            Icon(Icons.delete_outline, color: scheme.error),
            const SizedBox(width: 8),
            Text('Select to Delete',
                style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete_all',
          child: Row(children: [
            Icon(Icons.delete_forever, color: scheme.error),
            const SizedBox(width: 8),
            Text('Delete All Contacts',
                style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
          ]),
        ),
      ],
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildNormalAppBar(
    BuildContext context,
    bool isAddToGroupMode,
    String? groupName, {
    required ThemeProvider themeProvider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      iconTheme: IconThemeData(color: scheme.primary),
      title: isAddToGroupMode
          ? Text('Add to $groupName',
              style: GoogleFonts.plusJakartaSans(
                  color: scheme.onSurface, fontWeight: FontWeight.w700))
          : Text('Contacts',
              style: GoogleFonts.plusJakartaSans(
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      centerTitle: isAddToGroupMode,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (!isAddToGroupMode)
          _buildPopupMenu(context, themeProvider),
      ],
    );
  }

  // ── Progress overlays ─────────────────────────────────────────────────────

  Widget _buildDeletionProgressOverlay(
      {required ThemeProvider themeProvider}) {
    if (!_isDeletingInProgress) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 216,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Deleting Contacts',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.error)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _deletionTotalCount > 0
                  ? _deletionSuccessCount / _deletionTotalCount
                  : 0,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.error),
            ),
            const SizedBox(height: 8),
            Text(
              '$_deletionSuccessCount of $_deletionTotalCount deleted'
              '${_deletionErrorCount > 0 ? ' ($_deletionErrorCount errors)' : ''}',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: scheme.onSurface),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAddingToGroupProgressOverlay(
      {required ThemeProvider themeProvider}) {
    if (!_isAddingToGroupInProgress) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 16,
      left: 16,
      right: 50,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Adding to $_currentGroupName',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _addingTotalCount > 0
                  ? _addingSuccessCount / _addingTotalCount
                  : 0,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '$_addingSuccessCount of $_addingTotalCount added'
              '${_addingErrorCount > 0 ? ' ($_addingErrorCount errors)' : ''}',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: scheme.onSurface),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(
      {String? filter, required ThemeProvider themeProvider}) {
    final scheme = Theme.of(context).colorScheme;
    String title;
    String description;
    switch (filter) {
      case 'vip':
        title = 'No Favourite Contacts yet';
        description = 'Mark contacts as Favourite to see them here';
        break;
      case 'needs_attention':
        title = 'No contacts need care';
        description = 'All your contacts have been contacted recently';
        break;
      default:
        title = 'No contacts yet';
        description = 'Add your first contact to get started';
    }

    return Scaffold(
      floatingActionButton:
          Padding(padding: const EdgeInsets.only(right: 10, bottom: 55),
          child: const SizedBox.shrink()),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.contacts_rounded,
                      size: 40, color: scheme.primary),
                ),
                const SizedBox(height: 24),
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(description,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 15, color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddContactScreen())),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: Text('Add Contact Manually',
                        style: GoogleFonts.beVietnamPro(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importFromContactPicker,
                    icon: const Icon(Icons.import_contacts),
                    label: const Text('Import from Contacts'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                if (Theme.of(context).platform == TargetPlatform.android) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ImportContactsScreen(groups: allGroups))),
                      icon: const Icon(Icons.smart_button),
                      label: const Text('Smart Import (Android)'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
                if (filter != null && filter != 'all') ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => setState(() => _currentFilter = 'all'),
                    child: Text('Clear Filter',
                        style: GoogleFonts.beVietnamPro(
                            color: scheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '?';
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedContacts.clear();
      _selectionMode = null;
    });
    widget.hideButton();
  }

  void _toggleSelectAll() {
    final visible = _getVisibleContacts();
    setState(() {
      if (_selectedContacts.length == visible.length) {
        _selectedContacts.clear();
      } else {
        _selectedContacts = Set<String>.from(visible.map((c) => c.id));
      }
    });
  }

  List<Contact> _getVisibleContacts() {
    List<Contact> contacts = [];
    try {
      contacts = widget.mode == 'add_to_group'
          ? totalContacts
          : Provider.of<List<Contact>>(context, listen: false);
    } catch (_) {
      contacts = totalContacts;
    }
    final filtered = _applyFilter(contacts, _currentFilter);
    return filtered
        .where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.socialGroups.any(
                (g) => g.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();
  }

  int _getVisibleContactsCount() => _getVisibleContacts().length;

  List<Contact> _applyFilter(List<Contact> contacts, String? filter) {
    switch (filter) {
      case 'vip':
        return contacts.where((c) => c.isVIP).toList();
      case 'needs_attention':
        return contacts
            .where((c) => c.lastContacted.isBefore(
                DateTime.now().subtract(const Duration(days: 30))))
            .toList();
      default:
        return contacts;
    }
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'vip':     return 'Favourites';
      case 'needs_attention': return 'Needs Care';
      default:        return 'All Contacts';
    }
  }

  String _getFilterTitle(String filter) {
    switch (filter) {
      case 'vip':     return 'Favourite Contacts';
      case 'needs_attention': return 'Contacts Needing Care';
      default:        return 'All Contacts';
    }
  }

  // int getRandomIndex(String seed) {
  //   if (seed.isEmpty) return 1;
  //   var hash = 0;
  //   for (var i = 0; i < seed.length; i++) {
  //     hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
  //   }
  //   return (hash.abs() % 6) + 1;
  // }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _importContacts() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ImportContactsScreen(isOnboarding: false)));
    _handleImportResult(result);
  }

  void _handleImportResult(dynamic result) {
    if (result is Map<String, dynamic> && result['showConfetti'] == true) {
      showConfetti();
    }
  }

  void showConfetti() {
    setState(() => _showConfetti = true);
    _confettiController.play();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  Future<void> _importFromContactPicker() async {
    Navigator.pushNamed(context, '/import_contacts');
  }

  Future<void> _deleteSelectedContacts(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Contacts',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: scheme.error)),
        content: Text(
            'Delete ${_selectedContacts.length} contacts? This cannot be undone.',
            style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(color: scheme.primary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: GoogleFonts.beVietnamPro(color: scheme.error))),
        ],
      ),
    );
    if (confirmed == true) _startDeletionProcess();
  }

  void _startDeletionProcess() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _isDeletingInProgress = true;
      _deletionSuccessCount = 0;
      _deletionErrorCount = 0;
      _deletionTotalCount = _selectedContacts.length;
    });
    for (final id in _selectedContacts) {
      try {
        await apiService.deleteContact(id);
        setState(() => _deletionSuccessCount++);
      } catch (_) {
        setState(() => _deletionErrorCount++);
      }
    }
    apiService.cancelNudgesForContacts(_selectedContacts.toList());
    TopMessageService().showMessage(
      context: context,
      message:
          'Deleted $_deletionSuccessCount contacts${_deletionErrorCount > 0 ? '. $_deletionErrorCount failed' : ''}',
      backgroundColor: AppColors.success,
      icon: Icons.check,
    );
    setState(() {
      _isDeletingInProgress = false;
      _isSelecting = false;
      _selectedContacts.clear();
      _selectionMode = null;
    });
    widget.hideButton();
  }

  Future<void> _deleteAllContacts(BuildContext context) async {
    final contacts =
        Provider.of<List<Contact>>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    if (contacts.isEmpty) {
      TopMessageService().showMessage(
        context: context,
        message: 'No contacts to delete.',
        backgroundColor: scheme.surfaceContainerHighest,
        icon: Icons.info,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete All Contacts',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: scheme.error)),
        content: Text(
            'Delete all ${contacts.length} contacts? This cannot be undone.',
            style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(color: scheme.primary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete All',
                  style: GoogleFonts.beVietnamPro(color: scheme.error))),
        ],
      ),
    );
    if (confirmed == true) _startBulkDeletionProcess(contacts);
  }

  void _startBulkDeletionProcess(List<Contact> contacts) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _isDeletingInProgress = true;
      _deletionSuccessCount = 0;
      _deletionErrorCount = 0;
      _deletionTotalCount = contacts.length;
    });
    for (final contact in contacts) {
      try {
        await apiService.deleteContact(contact.id);
        setState(() => _deletionSuccessCount++);
      } catch (_) {
        setState(() => _deletionErrorCount++);
      }
    }
    TopMessageService().showMessage(
      context: context,
      message:
          'Deleted $_deletionSuccessCount contacts${_deletionErrorCount > 0 ? '. $_deletionErrorCount failed' : ''}',
      backgroundColor: AppColors.success,
      icon: Icons.check,
    );
    setState(() => _isDeletingInProgress = false);
  }

  Future<void> _addMultipleContactsToGroup(
    BuildContext context,
    String groupName,
    String groupPeriod,
    int groupFrequency,
    List<Contact> contacts,
    ThemeProvider themeProvider,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add to Group',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: scheme.primary)),
        content: Text(
            'Add ${_selectedContacts.length} contacts to "$groupName"?',
            style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(color: scheme.error))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add to Group',
                  style: GoogleFonts.beVietnamPro(color: scheme.primary))),
        ],
      ),
    );
    if (confirmed != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _isAddingToGroupInProgress = true;
      _addingSuccessCount = 0;
      _addingErrorCount = 0;
      _addingTotalCount = _selectedContacts.length;
      _currentGroupName = groupName;
    });

    final added = <Contact>[];
    for (final id in _selectedContacts) {
      try {
        final contact = contacts.firstWhere((c) => c.id == id);
        final updated = contact.copyWith(
            connectionType: groupName,
            period: groupPeriod,
            frequency: groupFrequency);
        await apiService.updateContact(updated);
        added.add(updated);
        setState(() => _addingSuccessCount++);
      } catch (_) {
        setState(() => _addingErrorCount++);
      }
    }

    if (added.isNotEmpty) {
      final ids = added.map((c) => c.id).toList();
      apiService.cancelNudgesForContacts(ids);
      apiService.scheduleNudgesForContacts(contactIds: ids);
    }

    TopMessageService().showMessage(
      context: context,
      message:
          'Added $_addingSuccessCount contacts to $groupName${_addingErrorCount > 0 ? '. $_addingErrorCount failed' : ''}',
      backgroundColor: AppColors.success,
      icon: Icons.check,
    );
    widget.hideButton();
    setState(() {
      _isAddingToGroupInProgress = false;
      _isSelecting = false;
      _selectedContacts.clear();
      _selectionMode = null;
      _currentGroupName = null;
    });
  }

  void _addContactToGroup(
    BuildContext context,
    Contact contact,
    String groupName,
    String groupPeriod,
    int groupFrequency,
  ) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;

    if (contact.connectionType.isNotEmpty &&
        contact.connectionType != groupName) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Override Group',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, color: scheme.primary)),
          content: Text(
              '${contact.name} is already in "${contact.connectionType}". '
              'Override to "$groupName"?',
              style: GoogleFonts.beVietnamPro(color: scheme.onSurface)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: GoogleFonts.beVietnamPro(color: scheme.primary))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Override',
                    style: GoogleFonts.beVietnamPro(color: scheme.primary))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final updated = contact.copyWith(
          connectionType: groupName,
          period: groupPeriod,
          frequency: groupFrequency);
      await apiService.updateContact(updated);
      await apiService.cancelNudgesForContacts([contact.id]);
      await apiService.scheduleNudgesForContacts(contactIds: [contact.id]);
      TopMessageService().showMessage(
        context: context,
        message: 'Added ${contact.name} to $groupName',
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
      Navigator.pop(context);
    } catch (e) {
      TopMessageService().showMessage(
        context: context,
        message: 'Failed to add contact: $e',
        backgroundColor: AppColors.lightError,
        icon: Icons.error,
      );
    }
  }

  void sendTestNudges() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    apiService.scheduleTestNudges(_selectedContacts.toList());
  }
}
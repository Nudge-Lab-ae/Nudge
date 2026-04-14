// lib/screens/admin/ai_testing_screen.dart
//
// Admin-only screen. Accessible from Settings when adminProvider.isAdmin == true.
// Lets admins configure the Anthropic API key and run live tests of all 4 integrations.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/user.dart' as app_user;
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/claude_service.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class AITestingScreen extends StatefulWidget {
  const AITestingScreen({super.key});

  @override
  State<AITestingScreen> createState() => _AITestingScreenState();
}

class _AITestingScreenState extends State<AITestingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // API key
  final TextEditingController _keyController = TextEditingController();
  bool _keyObscured = true;
  bool _keySaving = false;
  bool _keyLoaded = false;

  // Shared state
  List<Contact> _contacts = [];
  app_user.User? _user;
  bool _loadingData = true;
  Contact? _selectedContact;

  // Per-tab results + loading flags
  String _nudgeResult = '';
  bool _nudgeLoading = false;

  String _cardResult = '';
  bool _cardLoading = false;
  String _cardOccasion = 'Christmas';
  final List<String> _occasions = [
    'Christmas', 'Eid', 'Easter', 'Birthday', 'Work Anniversary',
    'New Year', 'Diwali', 'Hanukkah', 'General Reconnection',
  ];

  String _digestResult = '';
  bool _digestLoading = false;

  // Chat tab
  final TextEditingController _chatInput = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  bool _chatLoading = false;
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyController.dispose();
    _chatInput.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final futures = await Future.wait([
        _apiService.getAllContacts(),
        _apiService.getUser(),
        ClaudeService.readApiKey(),
      ]);
      final contacts = futures[0] as List<Contact>;
      final user = futures[1] as app_user.User;
      final key = futures[2] as String?;
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _user = user;
          _selectedContact = contacts.isNotEmpty ? contacts.first : null;
          if (key != null && key.isNotEmpty) {
            _keyController.text = '${key.substring(0, 8)}••••••••';
            _keyLoaded = true;
          }
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _saveKey() async {
    final raw = _keyController.text.trim();
    if (!raw.startsWith('sk-ant-')) {
      _showSnack('Key must start with sk-ant-', error: true);
      return;
    }
    setState(() => _keySaving = true);
    try {
      await ClaudeService.saveApiKey(raw);
      final visible = raw.length > 12 ? 12 : raw.length;
      setState(() {
        _keyLoaded = true;
        _keyController.text = '${raw.substring(0, visible)}••••••••';
      });
      _showSnack('API key saved ✓');
    } on FirebaseFunctionsException catch (e) {
      _showSnack('Save failed: ${e.message}', error: true);
    } catch (e) {
      _showSnack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _keySaving = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.lightError : AppColors.success,
    ));
  }

  // ── Individual test runners ────────────────────────────────────────────────

  Future<void> _testNudge() async {
    if (_selectedContact == null || _user == null) return;
    setState(() { _nudgeLoading = true; _nudgeResult = ''; });
    try {
      final result = await ClaudeService.generateNudgeCopy(
        contact: _selectedContact!, user: _user!);
      setState(() => _nudgeResult = result);
    } catch (e) {
      setState(() => _nudgeResult = 'Error: $e');
    } finally {
      if (mounted) setState(() => _nudgeLoading = false);
    }
  }

  Future<void> _testCard() async {
    if (_selectedContact == null || _user == null) return;
    setState(() { _cardLoading = true; _cardResult = ''; });
    try {
      final result = await ClaudeService.generateGreetingCard(
        contact: _selectedContact!, occasion: _cardOccasion, user: _user!);
      setState(() => _cardResult = result);
    } catch (e) {
      setState(() => _cardResult = 'Error: $e');
    } finally {
      if (mounted) setState(() => _cardLoading = false);
    }
  }

  Future<void> _testDigest() async {
    if (_user == null) return;
    setState(() { _digestLoading = true; _digestResult = ''; });
    try {
      final stats = {
        'completedNudges': _contacts.fold(0, (s, c) => s + c.completedNudges),
        'newInteractions': _contacts.fold(0, (s, c) => s + c.interactionCountInWindow),
      };
      final result = await ClaudeService.generateWeeklyDigest(
        user: _user!, contacts: _contacts, weeklyStats: stats);
      setState(() => _digestResult = result);
    } catch (e) {
      setState(() => _digestResult = 'Error: $e');
    } finally {
      if (mounted) setState(() => _digestLoading = false);
    }
  }

  Future<void> _sendChat() async {
    final msg = _chatInput.text.trim();
    if (msg.isEmpty || _user == null) return;
    _chatInput.clear();
    setState(() {
      _chatHistory.add({'role': 'user', 'content': msg});
      _chatLoading = true;
    });
    _scrollToBottom();
    try {
      final history = List<Map<String, String>>.from(_chatHistory)..removeLast();
      final reply = await ClaudeService.chat(
        userMessage: msg,
        user: _user!,
        contacts: _contacts,
        conversationHistory: history,
      );
      setState(() => _chatHistory.add({'role': 'assistant', 'content': reply}));
    } catch (e) {
      setState(() =>
          _chatHistory.add({'role': 'assistant', 'content': 'Error: $e'}));
    } finally {
      if (mounted) setState(() => _chatLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textP = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final textS = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF5F2EE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI Integration Testing',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w800, color: textP)),
          Text('Admin only · Claude Sonnet 4',
            style: GoogleFonts.beVietnamPro(fontSize: 11, color: textS)),
        ]),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.lightPrimary,
          padding: EdgeInsets.zero,
          isScrollable: true,
          unselectedLabelColor: textS,
          indicatorColor: AppColors.lightPrimary,
          labelStyle: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Nudge Copy'),
            Tab(text: 'Card'),
            Tab(text: 'Digest'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.lightPrimary))
          : Column(children: [
              // ── API Key configuration bar ──────────────────────────────
              _buildKeyBar(isDark, cardBg, textP, textS),
              const Divider(height: 1),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNudgeTab(isDark, cardBg, textP, textS),
                    _buildCardTab(isDark, cardBg, textP, textS),
                    _buildDigestTab(isDark, cardBg, textP, textS),
                    _buildChatTab(isDark, cardBg, textP, textS),
                  ],
                ),
              ),
            ]),
    );
  }

  // ── API Key bar ────────────────────────────────────────────────────────────
  Widget _buildKeyBar(bool isDark, Color cardBg, Color textP, Color textS) {
    return Container(
      color: isDark
          ? AppColors.darkSurfaceContainerHigh
          : const Color(0xFFEDE9FE),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.lightPrimary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.vpn_key_rounded,
              size: 14, color: AppColors.lightPrimary)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _keyController,
            obscureText: _keyObscured,
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: textP),
            onTap: () {
              if (_keyLoaded) _keyController.clear();
              setState(() => _keyLoaded = false);
            },
            decoration: InputDecoration(
              hintText: 'sk-ant-api03-…  (Anthropic API key)',
              hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: textS),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurfaceContainerHighest
                  : Colors.white,
              suffixIcon: IconButton(
                icon: Icon(_keyObscured
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                    size: 16, color: textS),
                onPressed: () =>
                    setState(() => _keyObscured = !_keyObscured)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _keySaving ? null : _saveKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
            child: _keySaving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Save',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ── Contact picker shared widget ───────────────────────────────────────────
  Widget _contactPicker(bool isDark, Color cardBg, Color textP, Color textS) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.darkSurfaceContainerHighest
              : const Color(0xFFECE7E2))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Contact>(
          value: _selectedContact,
          isExpanded: true,
          dropdownColor: cardBg,
          style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: textS, size: 20),
          onChanged: (c) => setState(() => _selectedContact = c),
          items: _contacts.map((c) => DropdownMenuItem(
            value: c,
            child: Text(
              '${c.name}  ·  ${c.connectionType}  ·  CDI ${c.cdi.toStringAsFixed(0)}',
              style: GoogleFonts.beVietnamPro(color: textP)),
          )).toList(),
        ),
      ),
    );
  }

  // ── Result box ────────────────────────────────────────────────────────────
  Widget _resultBox(String result, bool loading, bool isDark, Color textP) {
    final fieldBg = isDark
        ? AppColors.darkSurfaceContainerHighest
        : const Color(0xFFF0EDE9);
    if (loading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: fieldBg, borderRadius: BorderRadius.circular(14)),
        child: const Center(child: CircularProgressIndicator(
            color: AppColors.lightPrimary, strokeWidth: 2)));
    }
    if (result.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: result.startsWith('Error')
              ? AppColors.lightError.withOpacity(0.4)
              : AppColors.lightPrimary.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            result.startsWith('Error')
                ? Icons.error_outline_rounded
                : Icons.auto_awesome_rounded,
            size: 14,
            color: result.startsWith('Error')
                ? AppColors.lightError
                : AppColors.lightPrimary),
          const SizedBox(width: 6),
          Text(
            result.startsWith('Error') ? 'Error' : 'Claude Output',
            style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: result.startsWith('Error')
                  ? AppColors.lightError
                  : AppColors.lightPrimary,
              letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: result)),
            child: Icon(Icons.copy_rounded, size: 14,
                color: AppColors.lightPrimary)),
        ]),
        const SizedBox(height: 10),
        Text(result,
          style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: textP, height: 1.55)),
      ]),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    final textS = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;
    return Text(label.toUpperCase(),
      style: GoogleFonts.beVietnamPro(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: textS, letterSpacing: 0.8));
  }

  // ── Tab 1: Nudge Copy ──────────────────────────────────────────────────────
  Widget _buildNudgeTab(bool isDark, Color cardBg, Color textP, Color textS) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _featureBadge('1', 'Personalised Nudge Copy', isDark),
        const SizedBox(height: 6),
        Text('Generates a warm, contact-specific push notification message '
            'using CDI, notes and last contact date.',
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: textS)),
        const SizedBox(height: 20),
        _sectionLabel('Select Contact', isDark),
        const SizedBox(height: 8),
        _contactPicker(isDark, cardBg, textP, textS),
        if (_selectedContact != null) ...[
          const SizedBox(height: 12),
          _contactDataChips(_selectedContact!, isDark),
        ],
        const SizedBox(height: 20),
        _runButton(
          label: 'Generate Nudge Message',
          icon: Icons.send_rounded,
          loading: _nudgeLoading,
          onTap: _testNudge,
        ),
        const SizedBox(height: 16),
        _resultBox(_nudgeResult, _nudgeLoading, isDark, textP),
      ]),
    );
  }

  // ── Tab 2: Greeting Card ───────────────────────────────────────────────────
  Widget _buildCardTab(bool isDark, Color cardBg, Color textP, Color textS) {
    // final fieldBg = isDark
    //     ? AppColors.darkSurfaceContainerHighest
    //     : const Color(0xFFF0EDE9);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _featureBadge('2', 'Greeting Card Generator', isDark),
        const SizedBox(height: 6),
        Text('Creates a personal message for a specific occasion, drawing on '
            'relationship notes and mood history.',
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: textS)),
        const SizedBox(height: 20),
        _sectionLabel('Select Contact', isDark),
        const SizedBox(height: 8),
        _contactPicker(isDark, cardBg, textP, textS),
        const SizedBox(height: 16),
        _sectionLabel('Occasion', isDark),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark
                ? AppColors.darkSurfaceContainerHighest
                : const Color(0xFFECE7E2))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _cardOccasion,
              isExpanded: true,
              dropdownColor: cardBg,
              style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
              onChanged: (v) => setState(() => _cardOccasion = v!),
              items: _occasions.map((o) => DropdownMenuItem(
                value: o,
                child: Text(o, style: GoogleFonts.beVietnamPro(color: textP)),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _runButton(
          label: 'Generate Greeting Card',
          icon: Icons.card_giftcard_rounded,
          loading: _cardLoading,
          onTap: _testCard,
        ),
        const SizedBox(height: 16),
        _resultBox(_cardResult, _cardLoading, isDark, textP),
      ]),
    );
  }

  // ── Tab 3: Weekly Digest ───────────────────────────────────────────────────
  Widget _buildDigestTab(bool isDark, Color cardBg, Color textP, Color textS) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _featureBadge('3', 'Weekly Digest Narration', isDark),
        const SizedBox(height: 6),
        Text('Turns CDI/CSS numbers into a warm, human-readable narrative '
            'covering wins, drift, and one action to take.',
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: textS)),
        const SizedBox(height: 16),
        // Stats summary
        _statsRow(isDark, textP, textS),
        const SizedBox(height: 20),
        _runButton(
          label: 'Generate Weekly Digest',
          icon: Icons.analytics_rounded,
          loading: _digestLoading,
          onTap: _testDigest,
        ),
        const SizedBox(height: 16),
        _resultBox(_digestResult, _digestLoading, isDark, textP),
      ]),
    );
  }

  Widget _statsRow(bool isDark, Color textP, Color textS) {
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final stats = [
      ('Contacts', '${_contacts.length}'),
      ('VIP', '${_contacts.where((c) => c.isVIP).length}'),
      ('Needs Attention', '${_contacts.where((c) => c.needsAttention).length}'),
      ('Avg CDI', _contacts.isEmpty ? '–'
          : '${(_contacts.fold(0.0, (s, c) => s + c.cdi) / _contacts.length).toStringAsFixed(0)}'),
    ];
    return Row(children: stats.map((s) => Expanded(child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(s.$2, style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: AppColors.lightPrimary)),
        Text(s.$1, style: GoogleFonts.beVietnamPro(
          fontSize: 10, color: textS)),
      ]),
    ))).toList());
  }

  // ── Tab 4: Chat ────────────────────────────────────────────────────────────
  Widget _buildChatTab(bool isDark, Color cardBg, Color textP, Color textS) {
    final fieldBg = isDark
        ? AppColors.darkSurfaceContainerHighest
        : const Color(0xFFF0EDE9);

    final quickPrompts = [
      'Who should I reach out to today?',
      'Which relationships need the most attention?',
      'Give me my weekly relationship summary',
      'Help me write a reconnection message for someone I haven\'t spoken to in a while',
    ];

    return Column(children: [
      if (_chatHistory.isEmpty)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _featureBadge('4', 'Relationship AI Assistant', isDark),
              const SizedBox(height: 8),
              Text('Ask anything about your relationships. '
                  'Claude has read access to your contact data.',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: textS, height: 1.5)),
              const SizedBox(height: 24),
              Text('TRY ASKING',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: textS, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              ...quickPrompts.map((p) => GestureDetector(
                onTap: () {
                  _chatInput.text = p;
                  _sendChat();
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.lightPrimary.withOpacity(0.2))),
                  child: Row(children: [
                    Expanded(child: Text(p,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: textP))),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.lightPrimary),
                  ]),
                ),
              )),
            ]),
          ),
        )
      else
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _chatHistory.length + (_chatLoading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _chatHistory.length && _chatLoading) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 8, height: 8,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.lightPrimary)),
                      const SizedBox(width: 8),
                      Text('Thinking…',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, color: textS)),
                    ]),
                  ),
                );
              }
              final msg = _chatHistory[i];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(ctx).size.width * 0.82),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.lightPrimary
                        : cardBg,
                    borderRadius: BorderRadius.circular(16)),
                  child: Text(msg['content'] ?? '',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      color: isUser ? Colors.white : textP,
                      height: 1.5)),
                ),
              );
            },
          ),
        ),

      // Input row
      Container(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
        color: isDark
            ? AppColors.darkSurfaceContainerHigh
            : Colors.white,
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(9999)),
              child: TextField(
                controller: _chatInput,
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendChat(),
                decoration: InputDecoration(
                  hintText: 'Ask about your relationships…',
                  hintStyle: GoogleFonts.beVietnamPro(
                      fontSize: 14, color: textS),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _chatLoading ? null : _sendChat,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.lightPrimary.withOpacity(0.3),
                  blurRadius: 8)]),
              child: _chatLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18)),
          ),
        ]),
      ),
    ]);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _featureBadge(String num, String label, bool isDark) {
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: AppColors.lightPrimary,
          borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text(num,
          style: const TextStyle(
            color: Colors.white, fontSize: 12,
            fontWeight: FontWeight.w800)))),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: isDark
            ? AppColors.darkOnSurface
            : AppColors.lightOnSurface)),
    ]);
  }

  Widget _contactDataChips(Contact c, bool isDark) {
    final items = [
      'CDI: ${c.cdi.toStringAsFixed(0)}',
      'CSS: ${c.css.toStringAsFixed(0)}',
      '${c.computedRing} circle',
      '${DateTime.now().difference(c.lastContacted).inDays}d ago',
      if (c.isVIP) '★ VIP',
      if (c.needsAttention) '⚑ Attention',
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: items.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.lightPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: AppColors.lightPrimary.withOpacity(0.2))),
        child: Text(s, style: GoogleFonts.beVietnamPro(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.lightPrimary)),
      )).toList(),
    );
  }

  Widget _runButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: loading ? 0.6 : 1.0,
        child: Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)]),
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [BoxShadow(
              color: AppColors.lightPrimary.withOpacity(0.3),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: Center(child: loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(label, style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                ])),
        ),
      ),
    );
  }
}

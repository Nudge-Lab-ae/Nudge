// lib/screens/ai/nudge_ai_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/subscription.dart';
import 'package:nudge/providers/subscription_provider.dart';
import 'package:nudge/screens/subscription/paywall_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NudgeAIScreen extends StatefulWidget {
  const NudgeAIScreen({super.key});

  @override
  State<NudgeAIScreen> createState() => _NudgeAIScreenState();
}

class _NudgeAIScreenState extends State<NudgeAIScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'AI Assistant',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF751FE7),
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: const Color(0xFF751FE7),
          indicatorWeight: 2,
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: 'Chat'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Insights'),
                  if (!sub.hasAIInsights) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline, size: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatTab(apiService: _apiService),
          _InsightsTab(apiService: _apiService),
        ],
      ),
    );
  }
}

// ── Chat Tab ──────────────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  final ApiService apiService;
  const _ChatTab({required this.apiService});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  static const _dailyCountKey = 'nudge_ai_daily_count';
  static const _dailyDateKey = 'nudge_ai_daily_date';
  static const _freeLimit = 5;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  int _todayCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDailyCount();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final savedDate = prefs.getString(_dailyDateKey) ?? '';
    if (savedDate != today) {
      await prefs.setString(_dailyDateKey, today);
      await prefs.setInt(_dailyCountKey, 0);
      setState(() => _todayCount = 0);
    } else {
      setState(() => _todayCount = prefs.getInt(_dailyCountKey) ?? 0);
    }
  }

  Future<void> _incrementDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_dailyDateKey, today);
    final newCount = (prefs.getInt(_dailyCountKey) ?? 0) + 1;
    await prefs.setInt(_dailyCountKey, newCount);
    setState(() => _todayCount = newCount);
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      text:
          "Hi! I'm your Nudge AI assistant. Ask me anything about your relationships — who to reconnect with, how to strengthen connections, or how to approach a conversation.",
      isUser: false,
    ));
  }

  bool _canSend(SubscriptionProvider sub) {
    if (!sub.isFree) return true;
    return _todayCount < _freeLimit;
  }

  Future<void> _sendMessage(SubscriptionProvider sub) async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!_canSend(sub)) {
      _showLimitDialog(sub);
      return;
    }

    final userMessage = _ChatMessage(text: text, isUser: true);
    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    await _incrementDailyCount();

    try {
      final history = _messages
          .where((m) => !m.isTypingIndicator)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      // Remove last user message from history (it's the current message)
      final contextHistory = history.length > 1
          ? history.sublist(0, history.length - 1)
          : <Map<String, dynamic>>[];

      final response = await widget.apiService.chatWithAI(
        message: text,
        history: contextHistory,
      );

      final reply = response['reply'] as String? ??
          response['message'] as String? ??
          'I couldn\'t process that. Please try again.';

      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Something went wrong. Please try again.',
          isUser: false,
          isError: true,
        ));
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showLimitDialog(SubscriptionProvider sub) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Daily Limit Reached',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Free accounts get $_freeLimit AI messages per day. Upgrade to Plus or Pro for unlimited conversations.',
          style: GoogleFonts.beVietnamPro(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PaywallScreen(
                    highlightTier: SubscriptionTier.plus),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF751FE7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = context.watch<SubscriptionProvider>();
    final remaining = _freeLimit - _todayCount;
    final atLimit = sub.isFree && _todayCount >= _freeLimit;

    return Column(
      children: [
        if (sub.isFree && !atLimit && _todayCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: const Color(0xFF751FE7).withOpacity(0.08),
            child: Text(
              '$remaining message${remaining == 1 ? '' : 's'} remaining today',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: const Color(0xFF751FE7),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isSending && index == _messages.length) {
                return _TypingIndicator();
              }
              return _MessageBubble(
                  message: _messages[index], theme: theme);
            },
          ),
        ),
        _buildInputBar(sub, theme, atLimit),
      ],
    );
  }

  Widget _buildInputBar(
      SubscriptionProvider sub, ThemeData theme, bool atLimit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: atLimit
            ? GestureDetector(
                onTap: () => _showLimitDialog(sub),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF751FE7).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF751FE7).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 16, color: Color(0xFF751FE7)),
                      const SizedBox(width: 8),
                      Text(
                        'Upgrade for unlimited AI chat',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          color: const Color(0xFF751FE7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Ask anything about your relationships...',
                        hintStyle: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF751FE7), width: 1.5),
                        ),
                      ),
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface),
                      onSubmitted: (_) => _sendMessage(sub),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isSending ? null : () => _sendMessage(sub),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isSending
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF751FE7),
                                  Color(0xFF4A0FAA)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isSending
                            ? theme.colorScheme.surfaceContainerHighest
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: _isSending
                            ? theme.colorScheme.onSurfaceVariant
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isTypingIndicator;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isTypingIndicator = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ThemeData theme;

  const _MessageBubble({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUser
                ? null
                : message.isError
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          child: Text(
            message.text,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              height: 1.5,
              color: isUser
                  ? Colors.white
                  : message.isError
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 60),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final delay = i * 0.33;
                  final value =
                      ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
                  final opacity = value < 0.5
                      ? value * 2
                      : (1.0 - value) * 2;
                  return Container(
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.onSurfaceVariant
                          .withOpacity(0.3 + opacity * 0.5),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Insights Tab ──────────────────────────────────────────────────────────────

class _InsightsTab extends StatefulWidget {
  final ApiService apiService;
  const _InsightsTab({required this.apiService});

  @override
  State<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<_InsightsTab> {
  List<Contact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await widget.apiService.getAllContacts();
      if (mounted) setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final theme = Theme.of(context);

    if (!sub.hasAIInsights) {
      return _buildLockedState(context, theme);
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(
        color: Color(0xFF751FE7),
      ));
    }

    final insights = _buildInsights();

    if (insights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                'Add more contacts to unlock insights',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF751FE7),
      onRefresh: _loadContacts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Relationship Insights',
            subtitle: 'Based on your connection data',
          ),
          const SizedBox(height: 16),
          ...insights,
        ],
      ),
    );
  }

  List<Widget> _buildInsights() {
    final now = DateTime.now();
    final List<Widget> widgets = [];

    // Reach out today — contacts overdue by frequency/period
    final overdue = _contacts.where((c) {
      if (c.frequency <= 0) return false;
      final days = _periodToDays(c.period) ~/ c.frequency;
      if (days <= 0) return false;
      return now.difference(c.lastContacted).inDays >= days;
    }).toList()
      ..sort((a, b) => a.lastContacted.compareTo(b.lastContacted));

    if (overdue.isNotEmpty) {
      widgets.add(_InsightCard(
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFFE6543A),
        title: 'Reach out today',
        subtitle: '${overdue.length} contact${overdue.length == 1 ? '' : 's'} haven\'t heard from you',
        contacts: overdue.take(5).toList(),
        accentColor: const Color(0xFFE6543A),
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // Fading connections — CDI < 40 or needsAttention
    final fading = _contacts.where((c) {
      return c.needsAttention || c.cdi < 40;
    }).toList()
      ..sort((a, b) => a.cdi.compareTo(b.cdi));

    if (fading.isNotEmpty) {
      widgets.add(_InsightCard(
        icon: Icons.trending_down_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: 'Fading connections',
        subtitle: '${fading.length} relationship${fading.length == 1 ? '' : 's'} need attention',
        contacts: fading.take(5).toList(),
        accentColor: const Color(0xFFF59E0B),
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // Thriving — CDI > 70 and contacted recently
    final thriving = _contacts.where((c) {
      final daysSince = now.difference(c.lastContacted).inDays;
      return c.cdi > 70 && daysSince <= 30;
    }).toList()
      ..sort((a, b) => b.cdi.compareTo(a.cdi));

    if (thriving.isNotEmpty) {
      widgets.add(_InsightCard(
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFF22C55E),
        title: 'Thriving connections',
        subtitle: '${thriving.length} strong relationship${thriving.length == 1 ? '' : 's'}',
        contacts: thriving.take(5).toList(),
        accentColor: const Color(0xFF22C55E),
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // VIP contacts who haven't been contacted recently
    final vipOverdue = _contacts.where((c) {
      return c.isVIP && now.difference(c.lastContacted).inDays > 14;
    }).toList()
      ..sort((a, b) => a.lastContacted.compareTo(b.lastContacted));

    if (vipOverdue.isNotEmpty) {
      widgets.add(_InsightCard(
        icon: Icons.star_rounded,
        iconColor: const Color(0xFF751FE7),
        title: 'VIP check-in',
        subtitle: '${vipOverdue.length} VIP contact${vipOverdue.length == 1 ? '' : 's'} awaiting connection',
        contacts: vipOverdue.take(5).toList(),
        accentColor: const Color(0xFF751FE7),
      ));
    }

    return widgets;
  }

  int _periodToDays(String period) {
    switch (period.toLowerCase()) {
      case 'weekly': return 7;
      case 'monthly': return 30;
      case 'quarterly': return 90;
      case 'annually': return 365;
      default: return 30;
    }
  }

  Widget _buildLockedState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Relationship Insights',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'AI-powered insights about your connections are available on Plus and Pro plans.',
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      const PaywallScreen(highlightTier: SubscriptionTier.plus),
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF751FE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Upgrade to Plus',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Contact> contacts;
  final Color accentColor;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.contacts,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: contacts.map((c) => _ContactChip(contact: c, accentColor: accentColor)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final Contact contact;
  final Color accentColor;

  const _ContactChip({required this.contact, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = contact.name.isNotEmpty
        ? contact.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: accentColor.withOpacity(0.2),
            backgroundImage: contact.imageUrl.isNotEmpty
                ? NetworkImage(contact.imageUrl)
                : null,
            child: contact.imageUrl.isEmpty
                ? Text(
                    initials,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: accentColor),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            contact.name.split(' ').first,
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// lib/services/claude_service.dart
//
// All Claude API calls go through this service.
// The Anthropic key is stored in Firebase Remote Config (key: "anthropic_api_key")
// so it never touches client source code.  Admins who cannot use Remote Config
// can fall back to passing the key in Firestore doc admins/{uid}/config.apiKey.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../models/user.dart' as app_user;

class ClaudeService {
  static const String _model = 'claude-sonnet-4-20250514';
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const int _maxTokens = 1024;

  // ── Key resolution ─────────────────────────────────────────────────────────
  // Reads from Firestore admins/{uid}/config rather than hardcoding.
  // You set this once via the admin panel or Firebase console.
  static Future<String?> _resolveApiKey() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .collection('config')
          .doc('claude')
          .get();
      print('got the key'); 
      print(uid);
      if (doc.exists) print(doc.data()?['apiKey'] as String);
      if (doc.exists) return doc.data()?['apiKey'] as String?;
      return null;
    } catch (e) {
      debugPrint('[ClaudeService] Key resolution failed: $e');
      return null;
    }
  }

  // ── Core call ──────────────────────────────────────────────────────────────
  static Future<String> _call({
    required String system,
    required String userMessage,
    int maxTokens = _maxTokens,
    String? apiKey,
  }) async {
    final key = apiKey ?? await _resolveApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('Claude API key not configured. '
          'Set it in the Admin AI Testing panel under Settings.');
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception('Claude API error ${response.statusCode}: '
          '${body['error']?['message'] ?? response.body}');
    }

    final data = jsonDecode(response.body);
    final text = (data['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');
    return text.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. PERSONALISED NUDGE COPY
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> generateNudgeCopy({
    required Contact contact,
    required app_user.User user,
    String? apiKey,
  }) async {
    final daysSince =
        DateTime.now().difference(contact.lastContacted).inDays;

    final system = '''You write warm, one-sentence push notification messages for Nudge, 
a relationship management app. Your tone is encouraging, never guilt-inducing or pushy.
Keep messages under 120 characters. Write only the message text — no quotes, no prefix.''';

    final userMsg = '''Write a personalised nudge notification for this contact:

Name: ${contact.name}
Relationship: ${contact.connectionType}
Days since last interaction: $daysSince
Connection Depth Index (CDI): ${contact.cdi.toStringAsFixed(0)}/100
Circle: ${contact.computedRing}
Notes about them: ${contact.notes.isEmpty ? 'None' : contact.notes}
Upcoming birthday: ${contact.birthday != null ? _daysUntilBirthday(contact.birthday!) : 'none this week'}
Favourite (VIP): ${contact.isVIP}''';

    return _call(system: system, userMessage: userMsg, maxTokens: 200, apiKey: apiKey);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. GREETING CARD GENERATOR
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> generateGreetingCard({
    required Contact contact,
    required String occasion,
    required app_user.User user,
    String? apiKey,
  }) async {
    final system = '''You write warm, personal greeting card messages for the Nudge app.
Messages should feel genuine and specific — not generic. Use the relationship context and any
personal notes to make it feel handcrafted. 2–4 sentences max.
Return only the message text — no subject line, no "Dear X", no sign-off template.''';

    final userMsg = '''Write a $occasion greeting card message:

Recipient: ${contact.name}
Relationship to sender: ${contact.connectionType}
Personal notes: ${contact.notes.isEmpty ? 'None stored' : contact.notes}
Sender's name: ${user.username}
Mood history summary: ${_summariseMoodHistory(contact)}
Occasion: $occasion''';

    return _call(system: system, userMessage: userMsg, maxTokens: 300, apiKey: apiKey);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. WEEKLY DIGEST NARRATION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> generateWeeklyDigest({
    required app_user.User user,
    required List<Contact> contacts,
    required Map<String, dynamic> weeklyStats,
    String? apiKey,
  }) async {
    final system = '''You narrate Nudge's weekly relationship digest. 
Your tone is warm, encouraging and never guilt-inducing. 
Write in second person ("you"). 3–5 short paragraphs. 
Highlight wins, flag anyone drifting gently, suggest one action.''';

    // Build a concise data snapshot — avoid sending huge payloads
    final topContacts = (List<Contact>.from(contacts)
          ..sort((a, b) => b.cdi.compareTo(a.cdi)))
        .take(5)
        .map((c) => {
              'name': c.name,
              'cdi': c.cdi.toStringAsFixed(0),
              'css': c.css.toStringAsFixed(0),
              'ring': c.computedRing,
              'daysSince':
                  DateTime.now().difference(c.lastContacted).inDays,
            })
        .toList();

    final needsAttention =
        contacts.where((c) => c.needsAttention).map((c) => c.name).toList();

    final driftingContacts = contacts
        .where((c) =>
            DateTime.now().difference(c.lastContacted).inDays > 21 &&
            !c.needsAttention)
        .take(3)
        .map((c) => c.name)
        .toList();

    final userMsg = '''Generate a weekly digest narrative for:

User: ${user.username}
Nudges completed this week: ${weeklyStats['completedNudges'] ?? 0}
New interactions logged: ${weeklyStats['newInteractions'] ?? 0}

Top contacts by closeness:
${jsonEncode(topContacts)}

Contacts flagged as needing attention: ${needsAttention.isEmpty ? 'None' : needsAttention.join(', ')}
Contacts who may be drifting (21+ days): ${driftingContacts.isEmpty ? 'None' : driftingContacts.join(', ')}
VIP contacts: ${contacts.where((c) => c.isVIP).map((c) => c.name).join(', ')}''';

    return _call(system: system, userMessage: userMsg, maxTokens: 600, apiKey: apiKey);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. RELATIONSHIP AI ASSISTANT — single turn
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> chat({
    required String userMessage,
    required app_user.User user,
    required List<Contact> contacts,
    required List<Map<String, dynamic>> conversationHistory,
    String? apiKey,
  }) async {
    final system = '''You are the Nudge Relationship Assistant — a warm, insightful AI built into 
the Nudge app. You help the user manage and deepen their relationships.
You have access to their contact data below. Be specific, actionable and concise.
Never fabricate data not provided. If asked to generate a nudge or greeting card, do so directly.
Today's date: ${DateTime.now().toIso8601String().split('T').first}

USER PROFILE:
Name: ${user.username}

CONTACTS SNAPSHOT (top 20 by CDI):
${_buildContactsSnapshot(contacts)}''';

    // Build message history for multi-turn context
    final messages = <Map<String, dynamic>>[
      ...conversationHistory,
      {'role': 'user', 'content': userMessage},
    ];

    final key = apiKey ?? await _resolveApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('Claude API key not configured.');
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 800,
        'system': system,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
          'Claude API error ${response.statusCode}: ${body['error']?['message']}');
    }

    final data = jsonDecode(response.body);
    return (data['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n')
        .trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADMIN: save / read API key
  // ══════════════════════════════════════════════════════════════════════════

  // Key is written server-side via a Cloud Function because the admins
  // collection has "allow write: if false" in Firestore rules.
  static Future<void> saveApiKey(String key) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Not authenticated');
    }
    final callable = FirebaseFunctions.instance
        .httpsCallable('saveClaudeApiKey');
    await callable.call({'apiKey': key});
  }

  static Future<String?> readApiKey() => _resolveApiKey();

  // ══════════════════════════════════════════════════════════════════════════
  // Private helpers
  // ══════════════════════════════════════════════════════════════════════════

  static String _daysUntilBirthday(DateTime birthday) {
    final now = DateTime.now();
    var next = DateTime(now.year, birthday.month, birthday.day);
    if (next.isBefore(now)) next = DateTime(now.year + 1, birthday.month, birthday.day);
    final days = next.difference(now).inDays;
    if (days == 0) return 'today';
    if (days <= 7) return 'in $days days';
    return 'not this week';
  }

  static String _summariseMoodHistory(Contact contact) {
    final history = contact.interactionHistory;
    if (history.isEmpty) return 'No mood data';
    // Take last 5 mood values if stored
    final moods = history.values
        .whereType<Map>()
        .where((e) => e.containsKey('mood'))
        .map((e) => e['mood'])
        .take(5)
        .toList();
    if (moods.isEmpty) return 'No mood data';
    final avg = moods.fold<num>(0, (s, m) => s + (m as num)) / moods.length;
    final label = avg >= 4 ? 'Positive' : avg >= 2.5 ? 'Mixed' : 'Draining';
    return '$label (avg ${avg.toStringAsFixed(1)}/5 over last ${moods.length} interactions)';
  }

  static String _buildContactsSnapshot(List<Contact> contacts) {
    final sorted = (List<Contact>.from(contacts)
          ..sort((a, b) => b.cdi.compareTo(a.cdi)))
        .take(20);
    return sorted.map((c) {
      final days = DateTime.now().difference(c.lastContacted).inDays;
      return '- ${c.name} | ${c.connectionType} | CDI: ${c.cdi.toStringAsFixed(0)} | '
          'CSS: ${c.css.toStringAsFixed(0)} | ${c.computedRing} circle | '
          '${days}d since contact${c.isVIP ? " | ★ VIP" : ""}${c.needsAttention ? " | ⚑ Needs attention" : ""}'
          '${c.notes.isNotEmpty ? " | Notes: ${c.notes.substring(0, c.notes.length.clamp(0, 60))}" : ""}';
    }).join('\n');
  }
}

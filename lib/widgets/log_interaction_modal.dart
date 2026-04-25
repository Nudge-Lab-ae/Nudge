// lib/widgets/log_interaction_modal.dart
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/services/api_service.dart';
import 'package:confetti/confetti.dart';
import 'package:nudge/services/message_service.dart';
import '../../models/contact.dart';

class LogInteractionModal extends StatefulWidget {
  final ApiService apiService;
  final Contact contact;
  final bool isDarkMode;

  const LogInteractionModal({
    required this.apiService,
    required this.contact,
    required this.isDarkMode,
  });

  @override
  State<LogInteractionModal> createState() => LogInteractionModalState();
}

class LogInteractionModalState extends State<LogInteractionModal> {
  final TextEditingController _notesController = TextEditingController();
  String?   _selectedInteractionType;
  bool      _isLoading    = false;
  DateTime  _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _showConfetti = false;
  late ConfettiController _confettiController;
  int? _moodScore; // no default — user must choose

  final List<String> _moodEmojis = ['😔','😐','🙂','😄','💞'];
  final List<String> _moodLabels = ['DRAINING','OKAY','GOOD','GREAT','AMAZING'];

  final List<Map<String,dynamic>> _interactionTypes = [
    {'key':'call',    'label':'Call',    'icon':Icons.phone_rounded},
    {'key':'message', 'label':'Message', 'icon':Icons.chat_bubble_rounded},
    {'key':'meet',    'label':'Meet',    'icon':Icons.people_rounded},
    {'key':'other',   'label':'Other',   'icon':Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final p = await showDatePicker(context: context,
      initialDate: _selectedDate, firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)));
    if (p != null) setState(() => _selectedDate = p);
  }

  Future<void> _selectTime() async {
    final p = await showTimePicker(context: context, initialTime: _selectedTime);
    if (p != null) setState(() => _selectedTime = p);
  }

  Future<void> _logInteraction() async {
    if (_selectedInteractionType == null) {
      TopMessageService().showMessage(context: context,
        message: 'Please select an interaction type.',
        backgroundColor: Theme.of(context).colorScheme.tertiary, icon: Icons.error);
      return;
    }
    if (_moodScore == null) {
      TopMessageService().showMessage(context: context,
        message: 'Please select how this interaction felt.',
        backgroundColor: Theme.of(context).colorScheme.tertiary, icon: Icons.error);
      return;
    }

    setState(() { _showConfetti = true; _isLoading = true; });

    final dt = DateTime(_selectedDate.year,_selectedDate.month,_selectedDate.day,
        _selectedTime.hour,_selectedTime.minute);

    widget.apiService.logInteraction(
      contactId: widget.contact.id,
      interactionType: _selectedInteractionType!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      interactionDate: dt.toIso8601String(),
      mood: _moodScore!);

    _confettiController.play();
    TopMessageService().showMessage(context: context,
      message: 'Touchpoint logged for ${widget.contact.name}! Next nudge has been rescheduled.',
      backgroundColor: AppColors.success);

    setState(() => _isLoading = false);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context, {
        'success': true,
        'interactionDateTime': dt,
      });
    });
  }

  // ── Relative date/time ────────────────────────────────────────────────────

  String _relativeDateLabel(DateTime date) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(date.year, date.month, date.day);
    final diff  = sel.difference(today).inDays;
    if (diff == 0)  return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1)  return 'Tomorrow';
    final d = diff.abs();
    if (diff < 0) {
      if (d <= 7)   return '$d day${d>1?'s':''} ago';
      if (d <= 30)  { final w=(d/7).floor();  return '$w week${w>1?'s':''} ago'; }
      if (d <= 365) { final m=(d/30).floor(); return '$m month${m>1?'s':''} ago'; }
      final y=(d/365).floor(); return '$y year${y>1?'s':''} ago';
    }
    if (diff <= 7)   return 'in $diff day${diff>1?'s':''}';
    if (diff <= 30)  { final w=(diff/7).ceil();  return 'in $w week${w>1?'s':''}'; }
    if (diff <= 365) { final m=(diff/30).ceil(); return 'in $m month${m>1?'s':''}'; }
    final y=(diff/365).ceil(); return 'in $y year${y>1?'s':''}';
  }

  String _relativeTimeLabel(DateTime date, TimeOfDay time) {
    final now = DateTime.now();
    final sel = DateTime(date.year,date.month,date.day,time.hour,time.minute);
    if (sel.year!=now.year||sel.month!=now.month||sel.day!=now.day) return '';
    final diff = now.difference(sel);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes>1?'s':''} ago';
    final h = diff.inHours; return '$h hour${h>1?'s':''} ago';
  }

  String _formattedDate() {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[_selectedDate.month-1]} ${_selectedDate.day}';
  }
  String _formattedTime() => _selectedTime.format(context);

  // ── Contact initials helper ───────────────────────────────────────────────
  String _initials(String name) {
    final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
    if (p.length == 1) return p.first[0].toUpperCase();
    return '?';
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDarkMode;
    // final scheme  = Theme.of(context).colorScheme;
    final bgColor = isDark ? AppColors.darkSurfaceContainerLow  : Colors.white;
    final fieldBg = isDark ? AppColors.darkSurfaceContainerHigh : const Color(0xFFF0EDE9);
    final textP   = isDark ? AppColors.darkOnSurface            : AppColors.lightOnSurface;
    final textS   = isDark ? AppColors.darkOnSurfaceVariant     : AppColors.lightOnSurfaceVariant;

    final dateLabel = _relativeDateLabel(_selectedDate);
    final timeLabel = _relativeTimeLabel(_selectedDate, _selectedTime);
    final inits     = _initials(widget.contact.name);

    return Stack(children: [
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: BoxDecoration(color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            // Center(child: Container(
            //   margin: const EdgeInsets.only(top:12, bottom:4),
            //   width:36, height:4,
            //   decoration: BoxDecoration(color:scheme.outlineVariant,
            //     borderRadius:BorderRadius.circular(9999)))),

            Expanded(child: ListView(
              padding: const EdgeInsets.fromLTRB(24,12,24,32),
              children: [

                // ── Header ────────────────────────────────────────────────
                Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
                  Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                    Text('Log Touchpoint', style:GoogleFonts.plusJakartaSans(
                      fontSize:24, fontWeight:FontWeight.w800, color:textP)),
                    const SizedBox(height:2),
                    Text('Keep track of your meaningful connections.',
                      style:GoogleFonts.beVietnamPro(fontSize:13, color:textS, height:1.4)),
                  ]),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width:32,height:32,
                      decoration:BoxDecoration(color:fieldBg, shape:BoxShape.circle),
                      child:Icon(Icons.close_rounded, size:16, color:textS))),
                ]),
                const SizedBox(height:20),

                // ── Selected contact card ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark?const Color.fromARGB(255, 152, 125, 199).withOpacity(0.3):AppColors.lightPrimary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark?const Color.fromARGB(255, 152, 125, 199).withOpacity(0.3):AppColors.lightPrimary.withOpacity(0.2))),
                  child: Row(children:[
                    // Avatar: initials on purple circle
                    Container(width:44, height:44,
                      decoration: const BoxDecoration(
                        shape:BoxShape.circle, color:AppColors.lightPrimary),
                      child: Center(child:Text(inits,
                        style:GoogleFonts.plusJakartaSans(
                          fontSize:18, fontWeight:FontWeight.w800,
                          color:Colors.white)))),
                    const SizedBox(width:14),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                      Text(widget.contact.name,
                        style:GoogleFonts.plusJakartaSans(
                          fontSize:16, fontWeight:FontWeight.w700, color:textP)),
                      if (widget.contact.connectionType.isNotEmpty)
                        Text(widget.contact.connectionType,
                          style:GoogleFonts.beVietnamPro(fontSize:12, color:textS)),
                    ])),
                  ])),
                const SizedBox(height:22),

                // ── Interaction Type ──────────────────────────────────────
                Text('Interaction Type', style:GoogleFonts.plusJakartaSans(
                  fontSize:16, fontWeight:FontWeight.w700, color:textP)),
                const SizedBox(height:10),
                Wrap(spacing:10, runSpacing:10,
                  children: _interactionTypes.map((t) {
                    final key   = t['key']   as String;
                    final label = t['label'] as String;
                    final icon  = t['icon']  as IconData;
                    final isSel = _selectedInteractionType == key;
                    return GestureDetector(
                      onTap: () => setState(() =>
                          _selectedInteractionType = isSel ? null : key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds:180),
                        padding: const EdgeInsets.symmetric(horizontal:18, vertical:12),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.lightPrimary : fieldBg,
                          borderRadius: BorderRadius.circular(9999)),
                        child: Row(mainAxisSize:MainAxisSize.min, children:[
                          Icon(icon, size:16, color:isSel?Colors.white:textS),
                          const SizedBox(width:6),
                          Text(label, style:GoogleFonts.beVietnamPro(
                            fontSize:14, fontWeight:FontWeight.w600,
                            color:isSel?Colors.white:textP)),
                        ])));
                  }).toList()),
                const SizedBox(height:22),

                // ── How did it feel? ──────────────────────────────────────
                Text('How did it feel?', style:GoogleFonts.plusJakartaSans(
                  fontSize:16, fontWeight:FontWeight.w700, color:textP)),
                const SizedBox(height:14),
                Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (i) {
                    final sel = _moodScore != null && _moodScore == i+1;
                    return GestureDetector(
                      onTap: () => setState(() => _moodScore = sel ? null : i+1),
                      child: Column(children:[
                        AnimatedContainer(
                          duration: const Duration(milliseconds:180),
                          width:sel?58:52, height:sel?58:52,
                          decoration: BoxDecoration(shape:BoxShape.circle,
                            color:sel?Colors.transparent:fieldBg,
                            border:sel?Border.all(color:AppColors.lightPrimary,width:2.5):null),
                          child:Center(child:Text(_moodEmojis[i],
                            style:TextStyle(fontSize:sel?30:26)))),
                        const SizedBox(height:6),
                        Text(_moodLabels[i], style:GoogleFonts.beVietnamPro(
                          fontSize:9,
                          fontWeight:sel?FontWeight.w700:FontWeight.w500,
                          color:sel?AppColors.lightPrimary:textS)),
                      ]));
                  })),
                const SizedBox(height:22),

                // ── Date & Time ───────────────────────────────────────────
                Row(children:[
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                    Text('Date', style:GoogleFonts.plusJakartaSans(
                      fontSize:16, fontWeight:FontWeight.w700, color:textP)),
                    const SizedBox(height:8),
                    GestureDetector(onTap:_selectDate,
                      child:Container(
                        padding:const EdgeInsets.symmetric(horizontal:16, vertical:14),
                        decoration:BoxDecoration(color:fieldBg,
                          borderRadius:BorderRadius.circular(14)),
                        child:Row(children:[
                          Icon(Icons.calendar_month_rounded, size:18,
                            color:isDark?const Color.fromARGB(255, 152, 125, 199):AppColors.lightPrimary),
                          const SizedBox(width:10),
                          Text(_formattedDate(), style:GoogleFonts.beVietnamPro(
                            fontSize:14, fontWeight:FontWeight.w600, color:textP)),
                        ]))),
                  ])),
                  const SizedBox(width:14),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                    Text('Time', style:GoogleFonts.plusJakartaSans(
                      fontSize:16, fontWeight:FontWeight.w700, color:textP)),
                    const SizedBox(height:8),
                    GestureDetector(onTap:_selectTime,
                      child:Container(
                        padding:const EdgeInsets.symmetric(horizontal:16, vertical:14),
                        decoration:BoxDecoration(color:fieldBg,
                          borderRadius:BorderRadius.circular(14)),
                        child:Row(children:[
                          Icon(Icons.access_time_rounded, size:18,
                            color:isDark?const Color.fromARGB(255, 152, 125, 199):AppColors.lightPrimary),
                          const SizedBox(width:10),
                          Text(_formattedTime(), style:GoogleFonts.beVietnamPro(
                            fontSize:14, fontWeight:FontWeight.w600, color:textP)),
                        ]))),
                  ])),
                ]),
                const SizedBox(height:10),

                // ── Relative date/time indicator ──────────────────────────
                Container(
                  padding:const EdgeInsets.symmetric(vertical:8, horizontal:14),
                  decoration:BoxDecoration(
                    color:isDark?const Color.fromARGB(255, 152, 125, 199).withOpacity(0.1): AppColors.lightPrimary.withOpacity(0.08),
                    borderRadius:BorderRadius.circular(12),
                    border:Border.all(color: isDark?const Color.fromARGB(255, 152, 125, 199): AppColors.lightPrimary.withOpacity(0.25))),
                  child:Row(children:[
                    Icon(Icons.info_outline_rounded,
                      size:15, color: isDark?const Color.fromARGB(255, 152, 125, 199):AppColors.lightPrimary),
                    const SizedBox(width:8),
                    Expanded(child:Text(dateLabel,
                      style:GoogleFonts.beVietnamPro(fontSize:13,
                        fontWeight:FontWeight.w600, color:isDark?const Color.fromARGB(255, 152, 125, 199): AppColors.lightPrimary))),
                    if (timeLabel.isNotEmpty)
                      Container(
                        padding:const EdgeInsets.symmetric(horizontal:8, vertical:2),
                        decoration:BoxDecoration(
                          color:AppColors.success.withOpacity(0.15),
                          borderRadius:BorderRadius.circular(9999)),
                        child:Text(timeLabel, style:GoogleFonts.beVietnamPro(
                          fontSize:11, fontWeight:FontWeight.w600,
                          color:isDark?AppColors.darkOnSurface:AppColors.success))),
                  ])),
                const SizedBox(height:22),

                // ── Notes ─────────────────────────────────────────────────
                TextField(
                  controller:_notesController, maxLines:3,
                  style:GoogleFonts.beVietnamPro(fontSize:14, color:textP),
                  decoration:InputDecoration(
                    hintText:'Notes (optional)...',
                    hintStyle:GoogleFonts.beVietnamPro(fontSize:14, color:textS),
                    filled:true, fillColor:fieldBg, contentPadding:const EdgeInsets.all(16),
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),
                      borderSide:BorderSide.none),
                    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),
                      borderSide:BorderSide.none),
                    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),
                      borderSide:BorderSide(color:AppColors.lightPrimary, width:1.5)))),
                const SizedBox(height:24),

                // ── Log Button ────────────────────────────────────────────
                GestureDetector(
                  onTap: _isLoading ? null : _logInteraction,
                  child: AnimatedOpacity(
                    duration:const Duration(milliseconds:200),
                    opacity: (_selectedInteractionType!=null && _moodScore!=null)
                        ? 1.0 : 0.45,
                    child:Container(
                      width:double.infinity, height:54,
                      decoration:BoxDecoration(
                        gradient:const LinearGradient(
                          colors:[Color(0xFF751FE7),Color(0xFF9C4DFF)]),
                        borderRadius:BorderRadius.circular(9999),
                        boxShadow:[BoxShadow(
                          color:AppColors.lightPrimary.withOpacity(0.35),
                          blurRadius:16, offset:const Offset(0,5))]),
                      child:Center(child:_isLoading
                          ? const SizedBox(width:22,height:22,
                              child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                          : Text('Log Touchpoint', style:GoogleFonts.plusJakartaSans(
                              fontSize:16, fontWeight:FontWeight.w700,
                              color:Colors.white)))))),
              ],
            )),
          ]),
      ),

      if (_showConfetti)
        Align(alignment:Alignment.topCenter,
          child:ConfettiWidget(confettiController:_confettiController,
            numberOfParticles:20, blastDirectionality:BlastDirectionality.explosive,
            shouldLoop:false,
            colors:[AppColors.success, Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.tertiary, AppColors.warning,
              Theme.of(context).colorScheme.primary])),
    ]);
  }
}

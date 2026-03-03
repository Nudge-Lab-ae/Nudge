// complete_profile_screen.dart - Enhanced with Social Universe Preview
import 'package:flutter/material.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// Add this new widget for the roadmap step (fixed version)
class RoadmapStepWidget extends StatefulWidget {
  const RoadmapStepWidget({super.key});

  @override
  State<RoadmapStepWidget> createState() => _RoadmapStepWidgetState();
}

class _RoadmapStepWidgetState extends State<RoadmapStepWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _expandedFeature;
  
  // Roadmap phases data
  final List<Map<String, dynamic>> _phases = [
    {
      'id': 'launch',
      'emoji': '🟢',
      'label': 'NOW',
      'title': 'Ready for You',
      'color': const Color(0xFF059669),
      'features': [
        {
          'name': 'Social Universe',
          'desc': 'See your connections come to life — visualize and explore your circles like never before',
        },
        {
          'name': 'Smart Reminders',
          'desc': 'Never miss a birthday, milestone, or the perfect moment to check in on someone you care about',
        },
        {
          'name': 'Connection Profiles',
          'desc': 'Keep track of what matters — preferences, memories, and notes for every relationship',
        },
        {
          'name': 'Social Groups',
          'desc': 'Organize and manage your circles — keep your crew, your colleagues, and your closest connections all in one place',
        },
      ],
    },
    {
      'id': 'soon',
      'emoji': '🔵',
      'label': 'NEXT UP',
      'title': 'More Ways to Connect',
      'color': const Color(0xFF2563EB),
      'features': [
        {
          'name': 'Gamification & Streaks',
          'desc': 'Earn points, keep streaks alive, tackle challenges and complete quests — staying connected has never been this fun',
        },
        {
          'name': 'Shareable Awards & Badges',
          'desc': 'Unlock badges at every milestone and share awards that celebrate your strongest connections',
        },
        {
          'name': 'Smarter Insights',
          'desc': 'Deeper patterns, better nudges — your relationship intelligence gets a serious upgrade',
        },
        {
          'name': 'Digest & Widgets',
          'desc': 'Weekly summaries and home screen widgets so your connections are always top of mind',
        },
        {
          'name': 'Mood Reflections',
          'desc': 'Log how interactions make you feel — and unlock richer, more personal insights over time',
        },
      ],
    },
    {
      'id': 'horizon',
      'emoji': '🟣',
      'label': 'ON THE HORIZON',
      'title': 'Big Things Ahead',
      'color': const Color(0xFF7C3AED),
      'features': [
        {
          'name': 'Calendar Mapping',
          'desc': 'Stop waiting \'til you\'re 80 to meet up — let us find the perfect time in everyone\'s schedule',
        },
        {
          'name': 'AI Relationship Assistant',
          'desc': 'Context-aware conversation starters, hyper-personalised insights, and proactive suggestions to deepen every connection',
        },
        {
          'name': 'Milestones & Greeting Cards',
          'desc': 'Auto-generated celebrations for anniversaries and personalised cards for any occasion — powered by what you know about the people in your life',
        },
        {
          'name': 'Journal & Voice Notes',
          'desc': 'Reflect on your relationships through guided journaling or capture thoughts hands-free with voice notes',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _expandedFeature = null;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentPhase = _phases[_tabController.index];
    final phaseColor = currentPhase['color'] as Color;
    
    return Expanded(
      child: Column(
        children: [
          // Header Section - Fixed at top
          Container(
            color: themeProvider.getBackgroundColor(context),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Roadmap pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: phaseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LIVE ROADMAP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: phaseColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Title with gradient effect
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        themeProvider.isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                        phaseColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      "What's Coming\nto NUDGE",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Description
                Center(
                  child: Text(
                    'Your relationships are about to get a whole lot stronger. Here\'s what we\'re building for you.',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            ),
          ),
          
          // Tab Bar - FIXED VERSION with dynamic width based on content
          Container(
            color: themeProvider.getBackgroundColor(context),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade900 
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _phases.length,
                      itemBuilder: (context, index) {
                        final phase = _phases[index];
                        final isSelected = _tabController.index == index;
                        
                        return GestureDetector(
                          onTap: () {
                            _tabController.animateTo(index);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? phase['color'].withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  phase['emoji'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  phase['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? phase['color']
                                        : (themeProvider.isDarkMode 
                                            ? Colors.grey.shade500 
                                            : Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Phase Title
          Container(
            color: themeProvider.getBackgroundColor(context),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                currentPhase['title'],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          // Scrollable Features List
          Expanded(
            child: Container(
              color: themeProvider.getBackgroundColor(context),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                itemCount: (currentPhase['features'] as List).length,
                itemBuilder: (context, index) {
                  final feature = (currentPhase['features'] as List)[index];
                  final featureKey = '${currentPhase['id']}-$index';
                  final isExpanded = _expandedFeature == featureKey;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedFeature = isExpanded ? null : featureKey;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isExpanded 
                            ? phaseColor.withOpacity(0.05)
                            : (themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExpanded
                              ? phaseColor.withOpacity(0.3)
                              : (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: phaseColor.withOpacity(isExpanded ? 1 : 0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  feature['name'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isExpanded ? FontWeight.w600 : FontWeight.w500,
                                    color: isExpanded
                                        ? (themeProvider.isDarkMode ? Colors.white : Colors.black)
                                        : (themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                size: 20,
                                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Text(
                                feature['desc'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
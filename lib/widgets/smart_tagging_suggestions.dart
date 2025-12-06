// lib/widgets/smart_tagging_suggestions.dart
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../services/tagging_service.dart';
import '../services/api_service.dart';

class SmartTaggingSuggestions extends StatefulWidget {
  final Contact contact;
  
  const SmartTaggingSuggestions({super.key, required this.contact});

  @override
  State<SmartTaggingSuggestions> createState() => _SmartTaggingSuggestionsState();
}

class _SmartTaggingSuggestionsState extends State<SmartTaggingSuggestions> {
  List<String> _suggestedTags = [];
  String _suggestedRelationship = '';
  bool _isLoading = true;
  bool _callLogsAvailable = false;
  // Map<String, dynamic>? _callStatistics;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

Future<void> _loadSuggestions() async {
  try {
    // Get call logs
    final callLogs = await TaggingService.getCallLogs();
    _callLogsAvailable = callLogs.isNotEmpty;
    
    // Get call statistics for this contact
    // final callStats = await TaggingService.getCallStatistics(widget.contact);
    
    // Get suggestions
    final tagSuggestions = _callLogsAvailable
        ? await TaggingService.suggestTagsFromCallLogs(widget.contact, callLogs)
        : TaggingService.suggestTags(widget.contact, []);
    
    final relationshipSuggestion = _callLogsAvailable
        ? TaggingService.suggestRelationshipDepth(widget.contact, callLogs)
        : TaggingService.suggestRelationshipDepth(widget.contact, []);
    
    setState(() {
      _suggestedTags = tagSuggestions;
      _suggestedRelationship = relationshipSuggestion;
      // _callStatistics = callStats;
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading suggestions: $e');
    setState(() {
      _isLoading = false;
    });
  }
}
  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_callLogsAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enable call log access for smarter suggestions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        if (_suggestedRelationship.isNotEmpty)
          _buildRelationshipSuggestion(apiService),
        
        if (_suggestedTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTagSuggestions(apiService),
        ],
        
        if (_suggestedTags.isEmpty && _suggestedRelationship.isEmpty)
          const Text('No suggestions available'),
      ],
    );
  }

//   Widget _buildCallStatistics() {
//   if (_callStatistics == null || _callStatistics!['totalCalls'] == 0) {
//     return const SizedBox();
//   }
  
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       const SizedBox(height: 16),
//       const Text(
//         'Call Statistics',
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//         ),
//       ),
//       const SizedBox(height: 8),
//       Card(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text('Total Calls:'),
//                   Text(_callStatistics!['totalCalls'].toString()),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text('Average Duration:'),
//                   Text('${_callStatistics!['avgDuration']} seconds'),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text('Outgoing Calls:'),
//                   Text(_callStatistics!['outgoingCalls'].toString()),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text('Incoming Calls:'),
//                   Text(_callStatistics!['incomingCalls'].toString()),
//                 ],
//               ),
//               if (_callStatistics!['lastCall'] != null) ...[
//                 const SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Last Call:'),
//                     Text(DateFormat('MMM dd, yyyy').format(_callStatistics!['lastCall'])),
//                   ],
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     ],
//   );
// }

  Widget _buildRelationshipSuggestion(ApiService apiService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relationship Insight',
          style: TextStyle(
            color: Color(0xff555555),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, size: 20),
                    const SizedBox(width: 8),
                   Text(
                      'Suggested Tag: $_suggestedRelationship',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff555555)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on your interaction patterns, we suggest this relationship level.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    // Update contact with suggested relationship
                    final updatedContact = widget.contact.copyWith(
                      connectionType: _suggestedRelationship,
                    );
                    
                    try {
                      await apiService.updateContact(updatedContact);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Relationship updated!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating relationship: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3CB3E9),
                  ),
                  child:  Text('Apply Suggestion', style: AppTextStyles.button.copyWith(color: Colors.white),),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagSuggestions(ApiService apiService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TAG SUGGESTIONS',
          style: TextStyle(
            color: Color(0xff6e6e6e),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedTags.map((tag) {
            return FilterChip(
              label: Text(tag, style: TextStyle(color: Color(0xff555555)),),
              onSelected: (selected) async {
                if (selected) {
                  // Add tag to contact
                  final updatedTags = List<String>.from(widget.contact.tags);
                  if (!updatedTags.contains(tag)) {
                    updatedTags.add(tag);
                    
                    final updatedContact = widget.contact.copyWith(
                      tags: updatedTags,
                    );
                    
                    try {
                      await apiService.updateContact(updatedContact);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added tag: $tag')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding tag: $e')),
                      );
                    }
                  }
                }
              },
              backgroundColor: const Color.fromRGBO(37, 150, 190, 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }
}
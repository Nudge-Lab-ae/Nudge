// // lib/widgets/analytics_chart.dart (Custom Implementation)
// import 'package:flutter/material.dart';
// import 'package:nudge/theme/app_theme.dart';
// import '../models/analytics.dart';

// class AnalyticsChart extends StatelessWidget {
//   final Analytics analytics;

//   const AnalyticsChart({super.key, required this.analytics});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Contacts by Type',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             // Custom bar chart
//             ...analytics.contactsByType.entries.map((entry) {
//               final percentage = (entry.value / analytics.totalContacts) * 100;
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 4.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(entry.key),
//                         Text('${entry.value} (${percentage.toStringAsFixed(1)}%)'),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     LinearProgressIndicator(
//                       value: entry.value / analytics.totalContacts,
//                       backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
//                       valueColor: AlwaysStoppedAnimation<Color>(
//                         _getColorForType(entry.key),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }).toList(),
//             const SizedBox(height: 20),
//             const Text(
//               'Nudge Success Rate',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             LinearProgressIndicator(
//               value: analytics.successRate / 100,
//               backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
//               valueColor: AlwaysStoppedAnimation<Color>(
//                 analytics.successRate >= 70
//                     ? AppColors.success
//                     : analytics.successRate >= 40
//                         ? AppColors.warning
//                         : Theme.of(context).colorScheme.error,
//               ),
//             ),
//             const SizedBox(height: 5),
//             Text(
//               '${analytics.successRate.toStringAsFixed(1)}%',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: analytics.successRate >= 70
//                     ? AppColors.success
//                     : analytics.successRate >= 40
//                         ? AppColors.warning
//                         : Theme.of(context).colorScheme.error,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Color _getColorForType(String type) {
//     final colorMap = {
//       'Family': AppColors.lightPrimary,
//       'Friend': AppColors.success,
//       'Colleague': AppColors.warning,
//       'Client': Theme.of(context).colorScheme.primary,
//       'Mentor': Theme.of(context).colorScheme.secondary,
//     };
//     return colorMap[type] ?? Theme.of(context).colorScheme.outline;
//   }
// }
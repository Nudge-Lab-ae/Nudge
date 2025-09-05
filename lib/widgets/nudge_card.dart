import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/nudge.dart';

class NudgeCard extends StatelessWidget {
  final Nudge nudge;
  final Function()? onComplete;
  final Function()? onSnooze;

  const NudgeCard({
    super.key,
    required this.nudge,
    this.onComplete,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getNudgeIcon(nudge.nudgeType),
                  color: _getNudgeColor(nudge.nudgeType),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nudge.contactName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (nudge.isSnoozed)
                  const Chip(
                    label: Text('Snoozed'),
                    backgroundColor: Colors.orange,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              nudge.message,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  DateFormat('MMM d, y - h:mm a').format(nudge.scheduledTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (!nudge.isCompleted && onComplete != null)
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: onComplete,
                    tooltip: 'Mark as completed',
                  ),
                if (!nudge.isCompleted && onSnooze != null)
                  IconButton(
                    icon: const Icon(Icons.snooze, color: Colors.orange),
                    onPressed: onSnooze,
                    tooltip: 'Snooze reminder',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNudgeIcon(String nudgeType) {
    switch (nudgeType) {
      case 'birthday':
        return Icons.cake;
      case 'anniversary':
        return Icons.favorite;
      case 'followup':
        return Icons.refresh;
      default:
        return Icons.notifications;
    }
  }

  Color _getNudgeColor(String nudgeType) {
    switch (nudgeType) {
      case 'birthday':
        return Colors.pink;
      case 'anniversary':
        return Colors.red;
      case 'followup':
        return Colors.blue;
      default:
        return const Color.fromRGBO(37, 150, 190, 1);
    }
  }
}
import 'package:flutter/material.dart';

class SocialGroupChip extends StatelessWidget {
  final String label;

  const SocialGroupChip({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
        ),
      ),
    );
  }
}
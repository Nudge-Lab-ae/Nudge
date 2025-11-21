// lib/widgets/connection_type_chip.dart
import 'package:flutter/material.dart';

class ConnectionTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final String? count;
  final ValueChanged<bool>? onSelected;

  const ConnectionTypeChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.count,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected != null ? () => onSelected!(!isSelected) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xff3CB3E9)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xff3CB3E9)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  count!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
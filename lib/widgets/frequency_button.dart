import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';

class FrequencyButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final String? count;

  const FrequencyButton({
    super.key,
    required this.text,
    required this.isSelected,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 80,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.lightPrimary
            : Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.lightPrimary
              : Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                count!,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

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
            ? const Color(0xff3CB3E9)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xff3CB3E9)
              : Colors.grey.shade300,
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